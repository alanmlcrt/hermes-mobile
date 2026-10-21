import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:sqflite/sqflite.dart';

import '../models/connection.dart';
import '../models/connection_gateway.dart';
import '../models/draft.dart';
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
  }) : _now = now ?? (() => DateTime.now().toUtc()) {
    _events = gateway.events.listen(_onEvent);
    _snapshots = gateway.snapshots.listen(_onSnapshot);
  }
  final Database database;
  final ConnectionGateway gateway;
  final EventMapping mapping;
  final DateTime Function() _now;
  final _bindings = <TimelineKey, ({String runtime, int generation})>{};
  final _cache = <TimelineKey, TimelineProjection>{};
  final _queues = <TimelineKey, Future<void>>{};
  final _changes = StreamController<TimelineKey>.broadcast(sync: true);
  StreamSubscription<GatewayEvent>? _events;
  StreamSubscription<ConnectionSnapshot>? _snapshots;

  /// Délai maximal entre deux écritures pendant un flux de texte.
  static const flushInterval = Duration(milliseconds: 400);
  final _dirty = <TimelineKey>{};
  final _timers = <TimelineKey, Timer>{};
  bool _disposed = false;

  static void _log(String code) => developer.log(code, name: 'hermes.conversation');

  @override
  Stream<TimelineKey> get changes => _changes.stream;

  @override
  TimelineProjection projection(TimelineKey key) =>
      _cache[key] ?? const TimelineProjection();

  @override
  Future<TimelineProjection> load(TimelineKey key) async {
    await _enqueue(key, (p) => null);
    return projection(key);
  }

  /// Liaison runtime ↔ session durable, après `ensureSession`.
  void bind(TimelineKey key, String runtime, int generation) {
    final previous = _bindings[key];
    _bindings[key] = (runtime: runtime, generation: generation);
    if (previous?.runtime == runtime && previous?.generation == generation) {
      return;
    }
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
    final at = p.items.indexWhere((i) => i.turn == turn);
    final items = [...p.items]..insert(at < 0 ? p.items.length : at, item);
    return p.copyWith(
      items: items,
      userTurns: turn,
      workState: p.turns >= turn ? p.workState : WorkState.sending,
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
          _enqueue(
            entry.key,
            (p) => _apply(p, event),
            immediate: !streaming,
          ),
        );
      }
    }
  }

  /// Perte de socket : un tour en cours n'est ni terminé ni échoué, il n'est
  /// plus synchronisé.
  void _onSnapshot(ConnectionSnapshot snapshot) {
    if (snapshot.link == LinkState.connected) return;
    for (final key in _cache.keys.toList()) {
      if (_cache[key]!.inFlight) unawaited(_enqueue(key, _unsynced));
    }
  }

  static TimelineProjection? _unsynced(TimelineProjection p) =>
      p.inFlight ? p.copyWith(workState: WorkState.unknown) : null;

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
        if (last is ActivityItem && last.kind == kind && last.turn == p.turns) {
          return p;
        }
        return p.copyWith(items: [...p.items, ActivityItem(p.turns, kind)]);
      case EventEffect.terminal:
        return _finish(p, e, m);
      case EventEffect.ignore:
        return p;
    }
  }

  static TimelineProjection _startTurn(TimelineProjection p) => p.copyWith(
    turns: p.turns + 1,
    workState: WorkState.running,
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
        items: [
          ...p.items.take(p.items.length - 1),
          ResponseItem(p.turns, joined),
        ],
      );
    }
    return p.copyWith(items: [...p.items, ResponseItem(p.turns, text)]);
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
        if (!_disposed) _timers[key] ??= Timer(flushInterval, () => _flush(key));
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
    await _changes.close();
  }
}
