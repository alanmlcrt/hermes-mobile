import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../models/app_error.dart';
import '../models/connection.dart';
import '../models/connection_gateway.dart';
import '../models/draft.dart';
import '../models/history.dart';
import '../models/profile.dart';
import '../models/timeline.dart';
import 'event_mapping.dart';
import 'hermes_adapter.dart';

/// Seul auteur de la projection distante (`conversation_*`). Ne crée ni session
/// ni opération : l'outbox lui signale la liaison runtime et les demandes
/// acceptées. Ne ferme pas la base partagée.
class ConversationRepository implements ConversationGateway {
  ConversationRepository(
    this.database, {
    required this.gateway,
    required this.mapping,
    DateTime Function()? now,
    this.timeout = rpcTimeout,
  }) : _now = now ?? (() => DateTime.now().toUtc()) {
    _events = gateway.events.listen(_onEvent);
    _snapshots = gateway.snapshots.listen(_onSnapshot);
  }
  final Database database;
  final ConnectionGateway gateway;
  final EventMapping mapping;
  final DateTime Function() _now;
  final Duration timeout;

  /// Posé par l'outbox : seul appelant de `session.resume`.
  SessionResumer? resumer;
  final _bindings = <TimelineKey, ({String runtime, int generation})>{};
  final _cache = <TimelineKey, TimelineProjection>{};
  final _queues = <TimelineKey, Future<void>>{};
  final _changes = StreamController<TimelineKey>.broadcast(sync: true);
  final _resyncs = <TimelineKey, ({int generation, Future<void> future})>{};
  final _loaded = <TimelineKey>{};
  final _resyncing = <TimelineKey>{};
  final _failed = <TimelineKey>{};
  final _synced = <TimelineKey, int>{};
  int _seenGeneration = 0;
  StreamSubscription<GatewayEvent>? _events;
  StreamSubscription<ConnectionSnapshot>? _snapshots;

  /// Délai maximal entre deux écritures pendant un flux de texte.
  static const flushInterval = Duration(milliseconds: 400);
  final _dirty = <TimelineKey>{};
  final _timers = <TimelineKey, Timer>{};
  bool _disposed = false;

  static void _log(String code) =>
      developer.log(code, name: 'hermes.conversation');

  @override
  Stream<TimelineKey> get changes => _changes.stream;

  @override
  TimelineProjection projection(TimelineKey key) =>
      _cache[key] ?? const TimelineProjection();

  @override
  Future<TimelineProjection> load(TimelineKey key) async {
    _loaded.add(key);
    await _enqueue(key, (p) => null);
    // Fil ouvert après la connexion (relance) : sa resynchronisation n'a pas eu lieu.
    if (_canResync && _synced[key] != gateway.socketGeneration) {
      unawaited(resync(key));
    }
    return projection(key);
  }

  /// Plus grand `row_id` utilisateur connu (0 si aucun), sans file ni réseau.
  Future<int> maxUserRow(TimelineKey key) async {
    final p = _cache[key] ?? await _read(key);
    return p.items.whereType<UserItem>().fold<int>(
      0,
      (m, i) => max(m, i.userRowId ?? 0),
    );
  }

  /// Liaison runtime ↔ session durable, après `ensureSession`.
  void bind(TimelineKey key, String runtime, int generation) {
    final previous = _bindings[key];
    _bindings[key] = (runtime: runtime, generation: generation);
    if (previous?.runtime == runtime && previous?.generation == generation) {
      return;
    }
    // La resynchronisation décide elle-même du curseur.
    if (_resyncing.contains(key)) return;
    // Mémoire aussitôt : une resynchronisation déjà en file ne rejoue pas l'ancien curseur.
    final cached = _cache[key];
    if (cached?.seq != null) _cache[key] = cached!.copyWith(resetSeq: true);
    // Un autre runtime n'a pas forcément la même numérotation de `seq`.
    unawaited(
      _enqueue(key, (p) => p.seq == null ? null : p.copyWith(resetSeq: true)),
    );
  }

  /// Demande acceptée par Hermes : texte exact, jamais relu depuis le brouillon.
  Future<void> accepted(
    TimelineKey key,
    OperationKey operation,
    String text, {
    int? userRowId,
  }) => _enqueue(key, (p) {
    if (p.items.any((i) => i is UserItem && i.operation == operation)) {
      return null;
    }
    final turn = p.userTurns + 1;
    final item = UserItem(
      turn,
      text,
      operation: operation,
      userRowId: userRowId,
    );
    // Tour déjà démarré sans bulle (événement arrivé avant la réponse de
    // soumission) : la bulle passe devant ses éléments.
    final items = [
      for (final existing in p.items)
        if (turn == 1 && existing is ActivityItem && existing.turn == 0)
          ActivityItem(turn, existing.kind)
        else
          existing,
    ];
    final at = items.indexWhere((i) => i.turn == turn);
    items.insert(at < 0 ? items.length : at, item);
    return p.copyWith(
      items: items,
      userTurns: turn,
      workState: p.turns >= turn ? p.workState : WorkState.sending,
      companionPhase: p.turns >= turn
          ? p.companionPhase
          : CompanionPhase.neutral,
      clearError: true,
    );
  });

  void _onEvent(GatewayEvent event) {
    for (final entry in _bindings.entries) {
      if (entry.value.runtime == event.sessionId &&
          entry.value.generation == event.generation) {
        final effect = mapping.map(event.type, event.payload).effect;
        // Le flux de texte est écrit par lots ; début et fin de tour aussitôt.
        final streaming =
            effect == EventEffect.textDelta ||
            effect == EventEffect.interim ||
            effect == EventEffect.activity;
        unawaited(
          _enqueue(entry.key, (p) => _apply(p, event), immediate: !streaming),
        );
      }
    }
  }

  /// Perte de socket : un tour en cours n'est ni terminé ni échoué, il n'est
  /// plus synchronisé.
  void _onSnapshot(ConnectionSnapshot snapshot) {
    if (snapshot.link == LinkState.connected) {
      // Une fois par nouvelle socket, pour les fils affichés ou actifs.
      if (gateway.socketGeneration == _seenGeneration || !_canResync) return;
      _seenGeneration = gateway.socketGeneration;
      for (final key in {..._cache.keys, ..._bindings.keys}) {
        unawaited(_resyncIfActive(key));
      }
      return;
    }
    for (final key in _cache.keys.toList()) {
      if (_cache[key]!.inFlight) unawaited(_enqueue(key, _unsynced));
    }
  }

  bool get _canResync =>
      !_disposed &&
      resumer != null &&
      gateway.snapshot.link == LinkState.connected &&
      gateway.snapshot.capabilities.every(
        (c) => c.name != 'conversation' || c.state == CapabilityState.present,
      );

  /// Reprise de la session puis rejeu depuis le curseur quand c'est sûr, sinon
  /// snapshot par l'historique. Sérialisé avec les événements du fil ; ne
  /// soumet jamais rien.
  Future<void> resync(TimelineKey key) {
    final generation = gateway.socketGeneration;
    final pending = _resyncs[key];
    if (pending != null && pending.generation == generation) {
      return pending.future;
    }
    // Une reprise d'une ancienne socket en cours : la nouvelle passe après elle.
    late final ({int generation, Future<void> future}) entry;
    final future = _serial(key, () => _resync(key)).whenComplete(() {
      if (identical(_resyncs[key], entry)) {
        _resyncs.remove(key);
        if (!_changes.isClosed) _changes.add(key);
      }
    });
    entry = (generation: generation, future: future);
    _resyncs[key] = entry;
    if (!_changes.isClosed) _changes.add(key);
    return future;
  }

  @override
  bool resyncing(TimelineKey key) => _resyncs.containsKey(key);

  @override
  bool resumeFailed(TimelineKey key) => _failed.contains(key);

  void _setFailed(TimelineKey key, bool failed) {
    if (failed ? !_failed.add(key) : !_failed.remove(key)) return;
    if (!_changes.isClosed) _changes.add(key);
  }

  /// Lecture seule du serveur : une liste par (connexion, profil), jamais
  /// conservée. Autre connexion que la courante : refus, rien n'est demandé.
  @override
  Future<List<SessionSummary>> sessions(
    ConnectionKey connection,
    ProfileKey profile,
  ) async {
    if (gateway.snapshot.connection?.key != connection) {
      throw const AppError('connection.mismatch');
    }
    return HermesRpc.sessions(
      await gateway.call(
        'session.list',
        HermesRpc.listParams(profile),
        timeout: timeout,
      ),
    );
  }

  /// Fil affiché ou dont le travail est en cours/incertain ; les autres se
  /// resynchronisent à l'ouverture ([load]).
  Future<void> _resyncIfActive(TimelineKey key) async {
    try {
      final p = _cache[key] ?? await _read(key);
      if (_loaded.contains(key) ||
          p.inFlight ||
          p.workState == WorkState.unknown ||
          await resumer?.hasUnknown(key) == true) {
        await resync(key);
      }
    } catch (_) {
      _log('conversation.resync_failed');
    }
  }

  Future<void> _serial(TimelineKey key, Future<void> Function() task) =>
      _queues[key] = (_queues[key] ?? Future.value()).then((_) => task());

  Future<void> _resync(TimelineKey key) async {
    final resumer = this.resumer;
    if (resumer == null || _disposed) return;
    _resyncing.add(key);
    try {
      final before = _bindings[key];
      final current = _cache[key] ?? await _read(key);
      _cache[key] = current;
      final info = await resumer.resume(key);
      final generation = info.generation;
      // Socket changée pendant la reprise : la suivante resynchronise.
      if (generation != gateway.socketGeneration) return;
      final epoch = gateway.replayEpoch;
      int? latest;
      TimelineProjection? next;
      // Une opération incertaine se tranche sur un snapshot, jamais sur un rejeu.
      if (!await resumer.hasUnknown(key) &&
          before?.runtime == info.runtime &&
          current.seq != null &&
          epoch != null &&
          current.replayEpoch == epoch) {
        try {
          final since = HermesRpc.since(
            await gateway.call(
              'session.events.since',
              HermesRpc.sinceParams(info.runtime, current.seq!),
              timeout: timeout,
            ),
            runtime: info.runtime,
            generation: generation,
            replayEpoch: epoch,
          );
          latest = since.latest;
          next = _replay(current, since, info);
        } on RpcError {
          /* rejeu indisponible : snapshot */
        } on AppError {
          /* idem */
        }
      }
      List<int>? userRows;
      if (next == null) {
        final rows = HermesRpc.history(
          await gateway.call(
            'session.history',
            HermesRpc.historyParams(info.runtime),
            timeout: timeout,
          ),
        );
        userRows = [
          for (final r in rows)
            if (r.user) r.row,
        ];
        // Curseur lu après l'historique : ce qui précède est dans le snapshot.
        latest = null;
        if (epoch != null) {
          try {
            latest = HermesRpc.since(
              await gateway.call(
                'session.events.since',
                HermesRpc.sinceParams(
                  info.runtime,
                  current.replayEpoch == epoch ? current.seq ?? 0 : 0,
                ),
                timeout: timeout,
              ),
              runtime: info.runtime,
              generation: generation,
              replayEpoch: epoch,
            ).latest;
          } on RpcError {
            /* curseur vide */
          } on AppError {
            /* idem */
          }
        }
        next = _fromHistory(
          current,
          rows,
          info,
        ).copyWith(replayEpoch: epoch, seq: latest, resetSeq: latest == null);
      }
      await _write(key, next);
      _dirty.remove(key);
      _timers.remove(key)?.cancel();
      _cache[key] = next;
      if (!_changes.isClosed) _changes.add(key);
      _synced[key] = generation;
      _setFailed(key, false);
      if (userRows != null) await resumer.reconcile(key, info, userRows);
    } catch (_) {
      // Rien n'est renvoyé : la projection précédente et les opérations restent.
      _setFailed(key, true);
      _log('conversation.resync_failed');
    } finally {
      _resyncing.remove(key);
    }
  }

  /// Applique les événements manqués ; `null` quand le rejeu n'est pas sûr
  /// (tronqué, autre epoch, trou de `seq`, travail indéterminé).
  TimelineProjection? _replay(
    TimelineProjection current,
    ({List<GatewayEvent> events, int? latest, bool truncated, String? epoch})
    since,
    Resumed info,
  ) {
    final seen = current.seq!;
    final fresh = since.events.where((e) => e.seq! > seen).toList()
      ..sort((a, b) => a.seq!.compareTo(b.seq!));
    var expected = seen + 1;
    for (final e in fresh) {
      if (e.seq != expected++) return null;
    }
    if (since.truncated ||
        (since.epoch != null && since.epoch != current.replayEpoch) ||
        since.latest != expected - 1) {
      return null;
    }
    // Le tour perdu de vue continue : ses fragments ne démarrent pas un autre tour.
    var p = current.workState == WorkState.unknown
        ? current.copyWith(workState: WorkState.running)
        : current;
    for (final e in fresh) {
      p = _apply(p, e) ?? p;
    }
    // L'accusé local ne prouve aucun démarrage ; la reprise le confirme mais
    // sans événement frais le snapshot fournit le contenu et le tour courants.
    if (info.running && p.workState == WorkState.sending) return null;
    if (info.running && p.workState == WorkState.running) {
      p = p.copyWith(
        companionPhase:
            info.partial?.isNotEmpty == true ||
                p.items.whereType<ResponseItem>().any(
                  (item) => item.turn == p.turns && item.text.isNotEmpty,
                )
            ? CompanionPhase.reading
            : CompanionPhase.concentrating,
      );
    }
    return !info.running && (p.inFlight || p.workState == WorkState.unknown)
        ? null
        : p;
  }

  /// Reconstruit le fil depuis `session.history` ; les liens locaux se font par
  /// `row_id`, puis par position pour les bulles sans ligne, jamais par le texte.
  TimelineProjection _fromHistory(
    TimelineProjection p,
    List<({int row, bool user, String text})> rows,
    Resumed info,
  ) {
    final linked = {
      for (final i in p.items)
        if (i is UserItem && i.userRowId != null) i.userRowId!: i,
    };
    final loose = [
      for (final i in p.items)
        if (i is UserItem && i.userRowId == null) i,
    ];
    // Les bulles sans ligne sont les plus récentes : elles prennent les dernières.
    final free = [
      for (final r in rows)
        if (r.user && !linked.containsKey(r.row)) r.row,
    ];
    final skip = max(0, free.length - loose.length);
    final byPosition = {
      for (var i = 0; i < loose.length && skip + i < free.length; i++)
        free[skip + i]: loose[i],
    };
    final items = <TimelineItem>[];
    var turn = 0;
    void answer(String text) {
      final at = max(turn, 1);
      final last = items.lastOrNull;
      if (last is ResponseItem && last.turn == at) {
        items[items.length - 1] = ResponseItem(at, '${last.text}\n\n$text');
      } else {
        items.add(ResponseItem(at, text));
      }
    }

    for (final r in rows) {
      if (r.user) {
        final known = linked[r.row] ?? byPosition[r.row];
        items.add(
          UserItem(
            ++turn,
            known?.text ?? r.text,
            operation: known?.operation ?? OperationKey('row-${r.row}'),
            userRowId: r.row,
          ),
        );
      } else {
        answer(r.text);
      }
    }
    final partial = info.partial;
    final tail = items.lastOrNull;
    if (info.running &&
        partial != null &&
        !(tail is ResponseItem && tail.text.contains(partial))) {
      answer(partial);
    }
    final WorkState? work;
    if (info.running) {
      work = WorkState.running;
    } else if (info.queued) {
      work = WorkState.sending;
    } else if (info.inflight) {
      work = WorkState.unknown; // un tour existe mais n'est pas suivi
    } else if (p.workState == WorkState.failed ||
        p.workState == WorkState.stopped) {
      work = p.workState; // fin du dernier tour conservée
    } else if (rows.isEmpty) {
      work = p.inFlight ? WorkState.unknown : p.workState;
    } else {
      work = rows.last.user ? WorkState.unknown : WorkState.succeeded;
    }
    return TimelineProjection(
      items: items,
      workState: work,
      companionPhase: info.running
          ? (items.whereType<ResponseItem>().any(
                  (item) => item.turn == max(turn, 1) && item.text.isNotEmpty,
                )
                ? CompanionPhase.reading
                : CompanionPhase.concentrating)
          : CompanionPhase.neutral,
      errorCode: work == WorkState.failed ? p.errorCode : null,
      turns: max(turn, info.running ? 1 : 0),
      userTurns: turn,
    );
  }

  static TimelineProjection? _unsynced(TimelineProjection p) => p.inFlight
      ? p.copyWith(
          workState: WorkState.unknown,
          companionPhase: CompanionPhase.neutral,
        )
      : null;

  TimelineProjection? _apply(TimelineProjection p, GatewayEvent e) {
    final seq = e.seq;
    if (seq != null &&
        p.seq != null &&
        p.replayEpoch == e.replayEpoch &&
        seq <= p.seq!) {
      return null;
    }
    return _reduce(p, e, mapping.map(e.type, e.payload)).copyWith(
      replayEpoch: e.replayEpoch,
      seq: seq,
      resetSeq: seq == null && p.replayEpoch != e.replayEpoch,
    );
  }

  TimelineProjection _reduce(
    TimelineProjection p,
    GatewayEvent e,
    MappedEvent m,
  ) {
    switch (m.effect) {
      case EventEffect.turnStart:
        return _startTurn(p);
      case EventEffect.textDelta:
        final text = HermesRpc.eventText(e.payload);
        return text == null ? p : _append(_ensureTurn(p), text);
      case EventEffect.interim:
        final text = HermesRpc.interimText(e.payload);
        return text == null ? p : _append(_ensureTurn(p), text, sealed: true);
      case EventEffect.activity:
        final last = p.items.lastOrNull;
        final kind = m.activityKind ?? 'unknown';
        // Une demande acceptée attend parfois encore message.start.
        final turn = max(p.turns, p.userTurns);
        if (last is ActivityItem && last.kind == kind && last.turn == turn) {
          return p;
        }
        return p.copyWith(items: [...p.items, ActivityItem(turn, kind)]);
      case EventEffect.terminal:
        return _finish(p, e, m);
      case EventEffect.ignore:
        return p;
    }
  }

  static TimelineProjection _startTurn(TimelineProjection p) => p.copyWith(
    turns: p.turns + 1,
    workState: WorkState.running,
    companionPhase: CompanionPhase.concentrating,
    clearError: true,
  );

  static TimelineProjection _ensureTurn(TimelineProjection p) =>
      p.workState == WorkState.running && p.turns > 0 ? p : _startTurn(p);

  static TimelineProjection _append(
    TimelineProjection p,
    String text, {
    bool sealed = false,
  }) {
    final last = p.items.lastOrNull;
    if (last is ResponseItem && last.turn == p.turns) {
      final joined = sealed ? '${last.text}\n\n$text' : '${last.text}$text';
      return p.copyWith(
        companionPhase: CompanionPhase.reading,
        items: [
          ...p.items.take(p.items.length - 1),
          ResponseItem(p.turns, joined),
        ],
      );
    }
    return p.copyWith(
      companionPhase: CompanionPhase.reading,
      items: [...p.items, ResponseItem(p.turns, text)],
    );
  }

  static TimelineProjection _finish(
    TimelineProjection p,
    GatewayEvent e,
    MappedEvent m,
  ) {
    var work = m.workState ?? WorkState.unknown;
    if (work != WorkState.stopped && HermesRpc.hasTurnError(e.payload)) {
      work = WorkState.failed;
    }
    final items = [...p.items];
    final full = HermesRpc.eventText(e.payload);
    if (e.type == HermesRpc.turnEnd &&
        full != null &&
        e.payload['partial'] != true) {
      // Le texte final fait foi quand il n'y a pas de segments à départager.
      final answers = [
        for (var i = 0; i < items.length; i++)
          if (items[i] is ResponseItem && items[i].turn == p.turns) i,
      ];
      if (answers.isEmpty) {
        items.add(ResponseItem(p.turns, full));
      } else if (answers.length == 1) {
        items[answers.single] = ResponseItem(p.turns, full);
      }
    }
    // Lignes serveur liées par position dans le tour, jamais par le texte.
    final rows = HermesRpc.persistedUserRows(e.payload);
    var position = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is UserItem && item.turn == p.turns) {
        if (item.userRowId == null && position < rows.length) {
          items[i] = item.withRow(rows[position]);
        }
        position++;
      }
    }
    return p.copyWith(
      items: items,
      workState: work,
      companionPhase: CompanionPhase.neutral,
      errorCode: work == WorkState.failed ? 'turn.error' : null,
      clearError: work != WorkState.failed,
    );
  }

  /// Mutations sérialisées par session. [change] rend `null` quand rien ne
  /// change. Immédiat : écrit avant d'émettre, et un échec garde la projection
  /// précédente. Sinon : émis aussitôt, écrit au plus tard après [flushInterval]
  /// (projection et curseur toujours ensemble).
  Future<void> _enqueue(
    TimelineKey key,
    TimelineProjection? Function(TimelineProjection) change, {
    bool immediate = true,
  }) => _queues[key] = (_queues[key] ?? Future.value()).then((_) async {
    try {
      final current = _cache[key] ?? await _read(key);
      _cache[key] = current;
      final changed = change(current);
      if (changed == null) return;
      if (immediate) {
        await _write(key, changed);
        _dirty.remove(key);
        _timers.remove(key)?.cancel();
      } else {
        _dirty.add(key);
        _timers[key] ??= Timer(flushInterval, () => _flush(key));
      }
      _cache[key] = changed;
      if (!_changes.isClosed) _changes.add(key);
    } catch (_) {
      _log('conversation.apply_failed');
    }
  });

  void _flush(TimelineKey key) {
    _timers.remove(key);
    _queues[key] = (_queues[key] ?? Future.value()).then((_) async {
      if (!_dirty.contains(key)) return;
      try {
        await _write(key, _cache[key]!);
        _dirty.remove(key);
      } catch (_) {
        _log('conversation.write_failed');
        if (!_disposed) {
          _timers[key] ??= Timer(flushInterval, () => _flush(key));
        }
      }
    });
  }

  Future<TimelineProjection> _read(TimelineKey key) async {
    final rows = await database.query(
      'conversation_timelines',
      where: 'connection_key = ? AND profile_key = ? AND stored_session_id = ?',
      whereArgs: [key.connection.value, key.profile.value, key.session],
    );
    if (rows.isEmpty) return const TimelineProjection();
    final row = rows.single;
    final stored = TimelineProjection.fromJson(
      Map<String, Object?>.from(jsonDecode(row['projection'] as String) as Map),
      replayEpoch: row['replay_epoch'] as String?,
      seq: row['seq'] as int?,
    );
    // Relue sans socket liée : le travail en cours n'est plus suivi.
    final live =
        _bindings[key]?.generation == gateway.socketGeneration &&
        gateway.snapshot.link == LinkState.connected;
    return live ? stored : _unsynced(stored) ?? stored;
  }

  Future<void> _write(TimelineKey key, TimelineProjection p) =>
      database.insert('conversation_timelines', {
        'connection_key': key.connection.value,
        'profile_key': key.profile.value,
        'stored_session_id': key.session,
        'projection': jsonEncode(p.toJson()),
        'replay_epoch': p.replayEpoch,
        'seq': p.seq,
        'updated_at': _now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _events?.cancel();
    await _snapshots?.cancel();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    await Future.wait(_queues.values);
    for (final key in _dirty.toList()) {
      try {
        await _write(key, _cache[key]!);
      } catch (_) {
        _log('conversation.write_failed');
      }
    }
    _dirty.clear();
    _failed.clear();
    await _changes.close();
  }
}
