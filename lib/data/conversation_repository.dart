import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../models/app_error.dart';
import '../models/attachment.dart';
import '../models/connection.dart';
import '../models/connection_gateway.dart';
import '../models/draft.dart';
import '../models/history.dart';
import '../models/profile.dart';
import '../models/result.dart';
import '../models/timeline.dart';
import 'event_mapping.dart';
import 'hermes_adapter.dart';
import 'storage/attachment_files.dart';
import 'storage/result_files.dart';

/// Registre des réponses et décisions locales aux interventions
/// (`intervention_answers`), tenu par `InterventionRepository`.
abstract interface class QuestionLedger {
  /// Ids parmi [ids] pour lesquels une réponse locale existe déjà.
  Future<Set<String>> answered(Iterable<String> ids);

  /// L'intervention est close côté projection (prise en compte, expirée…).
  Future<void> settle(String requestId, QuestionState state);
}

/// Seul auteur de la projection distante (`conversation_*`). Ne crée ni session
/// ni opération : l'outbox lui signale la liaison runtime et les demandes
/// acceptées. Ne ferme pas la base partagée.
class ConversationRepository implements ConversationGateway, ResultGateway {
  ConversationRepository(
    this.database, {
    required this.gateway,
    required this.mapping,
    this.downloads,
    this.opener,
    ResultFiles? resultFiles,
    DateTime Function()? now,
    this.timeout = rpcTimeout,
  }) : resultFiles = resultFiles ?? ResultFiles(),
       _now = now ?? (() => DateTime.now().toUtc()) {
    _lastSelectedProfile = gateway.snapshot.selectedProfile;
    _events = gateway.events.listen(_onEvent);
    _snapshots = gateway.snapshots.listen(_onSnapshot);
  }
  final Database database;
  final ConnectionGateway gateway;
  final EventMapping mapping;
  final ResultDownloads? downloads;
  final ResultOpener? opener;
  final ResultFiles resultFiles;
  final DateTime Function() _now;
  final Duration timeout;

  /// Posé par l'outbox : seul appelant de `session.resume`.
  SessionResumer? resumer;

  /// Posé par `InterventionRepository`.
  QuestionLedger? questions;

  /// État local de la réponse à une question ou de la décision sur une
  /// autorisation (envoi, envoyée, inconnue) ; jamais appliqué à une carte
  /// déjà close. [choice] : décision envoyée, retenue par une autorisation.
  Future<void> markQuestion(
    TimelineKey key,
    String requestId,
    QuestionState state, {
    String? choice,
  }) => _enqueue(key, (p) {
    final at = p.items.indexWhere(
      (i) => i is InterventionItem && i.requestId == requestId,
    );
    if (at < 0) return null;
    final item = p.items[at] as InterventionItem;
    if (item.state.settled) return null;
    final InterventionItem? next = item is ApprovalItem && choice != null
        ? item.copyWith(state: state, choice: choice)
        : item.state == state
        ? null
        : item.copyWith(state: state);
    if (next == null) return null;
    return p.copyWith(items: [...p.items]..[at] = next);
  });
  AttachmentFiles attachmentFiles = AttachmentFiles();

  /// Queued outside receipt reconciliation: that may already own this queue.
  void refreshAttachments(TimelineKey key) {
    final generation = gateway.socketGeneration;
    final profile = gateway.snapshot.selectedProfile;
    final connection = gateway.snapshot.connection?.key;
    unawaited(
      _enqueue(
        key,
        (p) => p,
        hydrateAttachments: true,
        canPublish: () =>
            !_disposed &&
            generation == gateway.socketGeneration &&
            gateway.snapshot.connection?.key == connection &&
            gateway.snapshot.selectedProfile == profile,
      ),
    );
  }

  /// Télécharge la copie locale d'un résultat et met sa carte à jour ; toute
  /// erreur reste dans la carte, jamais dans une fausse réussite.
  @override
  Future<void> downloadResult(TimelineKey key, String resultKey) async {
    final p = _cache[key] ?? await _read(key);
    final item = p.items
        .whereType<ResultItem>()
        .where((i) => i.resultKey == resultKey)
        .firstOrNull;
    if (item == null || item.state == ResultState.downloading) return;
    final localKey = item.localKey ?? item.resultKey;
    final downloads = this.downloads;
    if (downloads == null) {
      await _setResultState(
        key,
        resultKey,
        (i) => i.copyWith(
          state: ResultState.failed,
          errorCode: 'result.unavailable',
        ),
      );
      return;
    }
    final active = (key, resultKey);
    if (!_downloading.add(active)) return;
    try {
      await _setResultState(
        key,
        resultKey,
        (i) => i.copyWith(
          state: ResultState.downloading,
          localKey: localKey,
          clearError: true,
        ),
      );
      final target = await resultFiles.file(key, localKey);
      final downloaded = await downloads.download(key, item.path, target.path);
      await _setResultState(
        key,
        resultKey,
        (i) => i.copyWith(
          state: ResultState.downloaded,
          bytes: downloaded.bytes,
          clearBytes: downloaded.bytes == null,
          // L'extension connue prime ; le type reçu ne comble que le vide.
          mediaType: i.mediaType.isNotEmpty
              ? i.mediaType
              : downloaded.mediaType ?? '',
          localKey: localKey,
          clearError: true,
        ),
      );
    } on AppError catch (error) {
      await _failResult(key, resultKey, error.code);
    } catch (_) {
      await _failResult(key, resultKey, 'result.unavailable');
    } finally {
      _downloading.remove(active);
    }
  }

  Future<void> _failResult(TimelineKey key, String resultKey, String code) =>
      _setResultState(
        key,
        resultKey,
        (i) => i.copyWith(
          state: ResultState.failed,
          errorCode: code,
          clearBytes: true,
        ),
      );

  /// Ouvre la copie locale ; sans elle, la carte redevient téléchargeable.
  @override
  Future<void> openResult(TimelineKey key, String resultKey) async {
    final p = _cache[key] ?? await _read(key);
    final item = p.items
        .whereType<ResultItem>()
        .where((i) => i.resultKey == resultKey)
        .firstOrNull;
    if (item == null ||
        item.state != ResultState.downloaded ||
        item.localKey == null) {
      throw const AppError('result.missing');
    }
    final file = await resultFiles.file(key, item.localKey!);
    if (!await file.exists()) {
      await _setResultState(
        key,
        resultKey,
        (i) => i.copyWith(state: ResultState.available, clearError: true),
      );
      throw const AppError('result.unreadable');
    }
    final opener = this.opener;
    if (opener == null) throw const AppError('result.open');
    await opener.open(
      file.path,
      item.mediaType.isEmpty ? null : item.mediaType,
    );
  }

  Future<void> _setResultState(
    TimelineKey key,
    String resultKey,
    ResultItem Function(ResultItem) change,
  ) => _enqueue(key, (p) {
    final at = p.items.indexWhere(
      (item) => item is ResultItem && item.resultKey == resultKey,
    );
    if (at < 0) return null;
    final next = change(p.items[at] as ResultItem);
    return p.copyWith(items: [...p.items]..[at] = next);
  });

  /// Relit une carte résultat avec son fichier : un téléchargement interrompu
  /// par un redémarrage devient réessayable, une copie locale disparue rend
  /// la carte de nouveau téléchargeable.
  Future<ResultItem> _hydrateResult(TimelineKey key, ResultItem item) async {
    final localKey = item.localKey ?? item.resultKey;
    if (item.state == ResultState.downloading) {
      if (_downloading.contains((key, item.resultKey))) return item;
      try {
        await resultFiles.remove(key, localKey);
      } catch (_) {
        /* copie partielle inaccessible : l'état reste réessayable */
      }
      return item.copyWith(state: ResultState.interrupted, clearError: true);
    }
    if (item.state == ResultState.downloaded) {
      var exists = false;
      try {
        exists = await (await resultFiles.file(key, localKey)).exists();
      } catch (_) {
        /* stockage illisible : la copie n'est pas présentée comme sûre */
      }
      if (!exists) {
        return item.copyWith(state: ResultState.available, clearError: true);
      }
    }
    return item;
  }

  Future<TimelineProjection> _withAttachments(
    TimelineKey key,
    TimelineProjection p,
  ) async {
    final operations = await database.rawQuery(
      'SELECT o.* FROM outbox_operations o JOIN outbox_drafts d ON d.draft_key = o.draft_key '
      'WHERE o.state = ? AND o.connection_key = ? AND o.profile_key = ? '
      'AND d.connection_key = o.connection_key AND d.profile_key = o.profile_key '
      'AND COALESCE(o.stored_session_id, d.stored_session_id) = ? '
      'AND d.stored_session_id = ?',
      [
        OperationState.accepted.name,
        key.connection.value,
        key.profile.value,
        key.session,
        key.session,
      ],
    );
    final items = <TimelineItem>[];
    for (final item in p.items) {
      if (item is ResultItem) {
        items.add(await _hydrateResult(key, item));
        continue;
      }
      if (item is! UserItem) {
        items.add(item);
        continue;
      }
      final matches = operations
          .where(
            (o) => item.userRowId == null
                ? o['operation_key'] == item.operation.value &&
                      (o['user_row_id'] == null ||
                          operations
                                  .where(
                                    (other) =>
                                        other['user_row_id'] ==
                                        o['user_row_id'],
                                  )
                                  .length ==
                              1)
                : o['user_row_id'] == item.userRowId,
          )
          .toList();
      final pieces = <Attachment>[];
      var notificationUnfollowed = false;
      var userRowId = item.userRowId;
      if (matches.length == 1) {
        final op = matches.single;
        notificationUnfollowed = op['notification_unfollowed'] == 1;
        userRowId ??= op['user_row_id'] as int?;
        final rows = await database.rawQuery(
          'SELECT a.*, s.state AS snapshot_state, s.reference AS snapshot_reference '
          'FROM outbox_operation_attachments s JOIN outbox_attachments a '
          'ON a.attachment_key = s.attachment_key AND a.operation_key = s.operation_key '
          'WHERE s.operation_key = ? AND a.draft_key = ? AND a.sent = 1 '
          'AND s.connection_key = ? AND s.profile_key = ? AND s.stored_session_id = ? '
          'AND a.connection_key = s.connection_key AND a.profile_key = s.profile_key '
          'AND a.stored_session_id = s.stored_session_id ORDER BY s.position',
          [
            op['operation_key'],
            op['draft_key'],
            key.connection.value,
            key.profile.value,
            key.session,
          ],
        );
        for (final row in rows) {
          final cleaned = row['cleaned'] == 1;
          var localPath = '';
          var missing = true;
          if (!cleaned) {
            try {
              final file = await attachmentFiles.file(
                DraftKey(op['draft_key'] as String),
                row['attachment_key'] as String,
              );
              missing = !await file.exists();
              localPath = file.path;
            } catch (_) {
              // Preview availability must never erase durable message metadata.
            }
          }
          pieces.add(
            Attachment(
              key: row['attachment_key'] as String,
              name: row['name'] as String,
              mediaType: row['media_type'] as String,
              bytes: row['bytes'] as int,
              localPath: localPath,
              missing: missing,
              state: AttachmentState.values.byName(
                row['snapshot_state'] as String,
              ),
              sent: true,
              cleaned: cleaned,
            ),
          );
        }
      }
      items.add(
        UserItem(
          item.turn,
          item.text,
          operation: item.operation,
          userRowId: userRowId,
          attachments: pieces,
          notificationUnfollowed: notificationUnfollowed,
        ),
      );
    }
    return p.copyWith(items: items);
  }

  /// Téléchargements vivants : une hydratation concurrente ne les interrompt
  /// pas ; après un redémarrage, l'ensemble est vide.
  final _downloading = <(TimelineKey, String)>{};

  final _bindings = <TimelineKey, ({String runtime, int generation})>{};
  final _stopRevisions = <TimelineKey, int>{};
  final _pendingBoundaries = <TimelineKey, int>{};
  ProfileKey? _lastSelectedProfile;

  /// Lecture sans attente : une fin reçue mais encore en file invalide déjà la cible.
  StopTarget? stopTarget(TimelineKey key) {
    final binding = _bindings[key];
    final p = projection(key);
    if (binding == null ||
        binding.generation != gateway.socketGeneration ||
        gateway.snapshot.link != LinkState.connected ||
        gateway.snapshot.connection?.key != key.connection ||
        resyncing(key) ||
        (_pendingBoundaries[key] ?? 0) > 0 ||
        !p.working) {
      return null;
    }
    return StopTarget(
      key,
      binding.runtime,
      binding.generation,
      p.turns,
      _stopRevisions[key] ?? 0,
    );
  }

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
    await _enqueue(key, (p) => p, hydrateAttachments: true);
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
    _stopRevisions.update(key, (v) => v + 1, ifAbsent: () => 1);
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
        if (existing is ActivityItem && existing.turn == 0)
          existing.copyWith(turn: turn)
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
  }, hydrateAttachments: true);

  void _onEvent(GatewayEvent event) {
    for (final entry in _bindings.entries) {
      if (entry.value.runtime == event.sessionId &&
          entry.value.generation == event.generation) {
        if (_isDuplicate(projection(entry.key), event)) continue;
        final effect = mapping.map(event.type, event.payload).effect;
        final boundary =
            effect == EventEffect.turnStart || effect == EventEffect.terminal;
        if (boundary) {
          _stopRevisions.update(entry.key, (v) => v + 1, ifAbsent: () => 1);
          _pendingBoundaries.update(entry.key, (v) => v + 1, ifAbsent: () => 1);
        }
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
          ).whenComplete(() {
            if (boundary) {
              _pendingBoundaries.update(entry.key, (v) => v - 1);
            }
            if (effect == EventEffect.terminal) {
              unawaited(_terminal(entry.key, event));
            }
          }),
        );
      }
    }
  }

  /// Perte de socket : un tour en cours n'est ni terminé ni échoué, il n'est
  /// plus synchronisé.
  void _onSnapshot(ConnectionSnapshot snapshot) {
    final profileChanged = snapshot.selectedProfile != _lastSelectedProfile;
    _lastSelectedProfile = snapshot.selectedProfile;
    for (final key in _bindings.keys) {
      if (snapshot.link != LinkState.connected ||
          snapshot.connection?.key != key.connection ||
          profileChanged) {
        _stopRevisions.update(key, (v) => v + 1, ifAbsent: () => 1);
      }
    }
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

  // ── Marqueurs locaux (7.3) ──────────────────────────────────────────────

  static const _markerWhere =
      'connection_key = ? AND profile_key = ? AND stored_session_id = ?';
  static List<Object?> _markerArgs(TimelineKey k) => [
    k.connection.value,
    k.profile.value,
    k.session,
  ];
  final _viewing = <TimelineKey>{};

  @override
  Future<Map<String, ConversationMarker>> markers(
    ConnectionKey connection,
    ProfileKey profile,
  ) async {
    final rows = await database.query(
      'conversation_markers',
      where: 'connection_key = ? AND profile_key = ?',
      whereArgs: [connection.value, profile.value],
    );
    return {
      for (final r in rows)
        r['stored_session_id'] as String: ConversationMarker(
          pinOrder: r['pin_order'] as int?,
          unread: r['unread'] == 1,
        ),
    };
  }

  /// Écrit [values] sur la ligne de [key], créée au besoin.
  Future<void> _mark(
    DatabaseExecutor db,
    TimelineKey key,
    Map<String, Object?> values,
  ) async {
    final updated = await db.update(
      'conversation_markers',
      values,
      where: _markerWhere,
      whereArgs: _markerArgs(key),
    );
    if (updated == 0) {
      await db.insert('conversation_markers', {
        'connection_key': key.connection.value,
        'profile_key': key.profile.value,
        'stored_session_id': key.session,
        ...values,
      });
    }
  }

  @override
  Future<void> setPinned(TimelineKey key, bool pinned) => database.transaction((
    txn,
  ) async {
    if (!pinned) return _mark(txn, key, {'pin_order': null});
    final rows = await txn.query(
      'conversation_markers',
      columns: ['pin_order'],
      where: _markerWhere,
      whereArgs: _markerArgs(key),
    );
    if (rows.firstOrNull?['pin_order'] != null) return;
    // ponytail: séquence globale (MAX + 1), suffisante pour un téléphone.
    final max = await txn.rawQuery(
      'SELECT MAX(pin_order) AS m FROM conversation_markers',
    );
    await _mark(txn, key, {'pin_order': ((max.single['m'] as int?) ?? 0) + 1});
  });

  @override
  Future<void> setUnread(TimelineKey key, bool unread) =>
      _mark(database, key, {'unread': unread ? 1 : 0});

  @override
  void viewing(TimelineKey key, bool open) {
    if (!open) {
      _viewing.remove(key);
      return;
    }
    _viewing.add(key);
    unawaited(
      setUnread(key, false).catchError((Object _) {
        _log('markers.write_failed');
      }),
    );
  }

  /// Fin de tour appliquée (réussite, erreur, arrêt confirmé) : non lu si le
  /// fil n'est pas affiché. Sans identité (`seq`) ou déjà vue : rien.
  Future<void> _terminal(TimelineKey key, GatewayEvent e) async {
    final p = projection(key);
    if (e.seq == null || p.seq != e.seq || p.replayEpoch != e.replayEpoch) {
      return;
    }
    if (p.workState != WorkState.succeeded &&
        p.workState != WorkState.failed &&
        p.workState != WorkState.stopped) {
      return;
    }
    final id = jsonEncode([e.replayEpoch, e.seq]);
    try {
      await database.transaction((txn) async {
        final rows = await txn.query(
          'conversation_markers',
          columns: ['seen_terminal'],
          where: _markerWhere,
          whereArgs: _markerArgs(key),
        );
        if (rows.firstOrNull?['seen_terminal'] == id) return;
        await _mark(txn, key, {
          'seen_terminal': id,
          if (!_viewing.contains(key)) 'unread': 1,
        });
      });
      if (!_changes.isClosed) _changes.add(key);
    } catch (_) {
      _log('markers.write_failed');
    }
  }

  /// Mutations distantes en cours, une au plus par session.
  final _mutations = <TimelineKey>{};

  /// `session.title` absente (-32601) : (connexion, génération de socket).
  ({ConnectionKey connection, int generation})? _renameMissing;

  @override
  bool renameMissing(ConnectionKey connection) =>
      _renameMissing?.connection == connection &&
      _renameMissing?.generation == gateway.socketGeneration;

  /// Runtime lié sur la socket courante, sinon reprise existante (jamais de
  /// création), puis `session.title`. Le titre n'est publié nulle part ici :
  /// l'appelant affiche la confirmation, l'historique la réconcilie.
  @override
  Future<String> rename(TimelineKey key, String title) async {
    if (gateway.snapshot.connection?.key != key.connection) {
      throw const AppError('connection.mismatch');
    }
    if (renameMissing(key.connection)) throw const AppError('rename.missing');
    if (!_mutations.add(key)) throw const AppError('rename.busy');
    try {
      final binding = _bindings[key];
      var generation = gateway.socketGeneration;
      String runtime;
      if (binding != null && binding.generation == generation) {
        runtime = binding.runtime;
      } else {
        final resumer = this.resumer;
        if (resumer == null) throw const AppError('rename.unreachable');
        try {
          final resumed = await resumer.resume(key);
          runtime = resumed.runtime;
          generation = resumed.generation;
        } on RpcError {
          throw const AppError('rename.unreachable');
        } on AppError catch (e) {
          // Rien n'a été renommé : seule la reprise a échoué.
          if (e.code == 'transport.offline') rethrow;
          throw const AppError('rename.unreachable');
        }
        // Socket changée pendant la reprise : l'identifiant runtime est périmé.
        if (generation != gateway.socketGeneration ||
            gateway.snapshot.connection?.key != key.connection) {
          throw const AppError('rename.unreachable');
        }
      }
      final Map<String, dynamic> result;
      try {
        result = await gateway.call(
          HermesRpc.sessionTitle,
          HermesRpc.titleParams(runtime, key.profile, title),
          timeout: timeout,
        );
      } on RpcError catch (e) {
        if (e.code == HermesRpc.methodNotFound) {
          _renameMissing = (connection: key.connection, generation: generation);
          throw const AppError('rename.missing');
        }
        throw const AppError('rename.refused');
      }
      final titled = HermesRpc.titled(result);
      if (titled.pending) throw const AppError('rename.pending');
      return titled.title;
    } finally {
      _mutations.remove(key);
    }
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
    _stopRevisions.update(key, (v) => v + 1, ifAbsent: () => 1);
    try {
      final before = _bindings[key];
      final current = _cache[key] ?? await _read(key);
      _cache[key] = current;
      final selectedProfile = gateway.snapshot.selectedProfile;
      final connection = gateway.snapshot.connection?.key;
      final info = await resumer.resume(key);
      final generation = info.generation;
      bool currentScope() =>
          !_disposed &&
          generation == gateway.socketGeneration &&
          gateway.snapshot.link == LinkState.connected &&
          gateway.snapshot.connection?.key == connection &&
          gateway.snapshot.selectedProfile == selectedProfile;
      // Socket changée pendant la reprise : la suivante resynchronise.
      if (generation != gateway.socketGeneration) return;
      final epoch = gateway.replayEpoch;
      int? latest;
      TimelineProjection? next;
      var open = info.openRequests;
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
          open = since.openRequests ?? open;
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
            final cursor = HermesRpc.since(
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
            );
            latest = cursor.latest;
            open = cursor.openRequests ?? open;
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
      next = await _reconcileQuestions(
        current,
        next,
        open,
        runtime: info.runtime,
        generation: generation,
        replayEpoch: epoch,
      );
      if (!currentScope()) return;
      await _write(key, next);
      _dirty.remove(key);
      _timers.remove(key)?.cancel();
      _settle(current, next);
      _cache[key] = next;
      if (!_changes.isClosed) _changes.add(key);
      _synced[key] = generation;
      _setFailed(key, false);
      if (userRows != null) await resumer.reconcile(key, info, userRows);
      if (!currentScope()) return;
      next = await _withAttachments(key, next);
      if (!currentScope()) return;
      await _write(key, next);
      if (!currentScope()) return;
      _cache[key] = next;
      if (!_changes.isClosed) _changes.add(key);
    } catch (_) {
      // Rien n'est renvoyé : la projection précédente et les opérations restent.
      _setFailed(key, true);
      _log('conversation.resync_failed');
    } finally {
      _resyncing.remove(key);
    }
  }

  /// Interventions après reprise : seules celles de `open_requests` restent
  /// ouvertes (une réponse locale non reçue le dit) ; les autres sont closes,
  /// sans jamais renvoyer la réponse locale. Sans `open_requests` (champ
  /// facultatif), rien n'est fermé : les cartes gardent leur état.
  Future<TimelineProjection> _reconcileQuestions(
    TimelineProjection before,
    TimelineProjection next,
    List<Map<String, Object?>>? open, {
    required String runtime,
    required int generation,
    required String? replayEpoch,
  }) async {
    final requests = [
      for (final entry in open ?? const <Map<String, Object?>>[])
        ?HermesRpc.serverRequest(
          entry,
          runtime: runtime,
          generation: generation,
          replayEpoch: replayEpoch,
        ),
    ];
    final ids = {for (final r in requests) r.payload['id'] as String};
    // Un snapshot ne reconstruit pas les cartes : les précédentes non closes
    // sont reprises dans le tour courant.
    final kept = {
      for (final i in next.items)
        if (i is InterventionItem) i.requestId,
    };
    var p = next.copyWith(
      items: [
        for (final i in next.items)
          if (open != null &&
              i is InterventionItem &&
              !i.state.settled &&
              !ids.contains(i.requestId))
            i.copyWith(state: QuestionState.closed)
          else
            i,
        // Non closes avant la reprise : rouvrables, sinon closes (sans renvoi).
        for (final i in before.items)
          if (i is InterventionItem &&
              !kept.contains(i.requestId) &&
              !i.state.settled)
            (open == null || ids.contains(i.requestId)
                    ? i
                    : i.copyWith(state: QuestionState.closed))
                .atTurn(max(max(next.turns, next.userTurns), 1)),
      ],
    );
    final known = {
      for (final i in p.items)
        if (i is InterventionItem) i.requestId,
    };
    Set<String> answered = const {};
    final unseen = ids.difference(known);
    if (unseen.isNotEmpty) {
      try {
        answered = await questions?.answered(unseen) ?? const {};
      } catch (_) {
        _log('conversation.questions_unavailable');
      }
    }
    for (final r in requests) {
      final id = r.payload['id'] as String;
      p = _ask(
        p,
        answered.contains(id)
            ? GatewayEvent(
                sessionId: r.sessionId,
                type: r.type,
                payload: {...r.payload, 'answered_locally': true},
                generation: r.generation,
                replayEpoch: r.replayEpoch,
              )
            : r,
        reopen: true,
      );
    }
    return _afterQuestions(p);
  }

  /// Ouvre (ou rouvre, après reprise) la carte d'une requête `clarify` ou
  /// `approval`.
  static TimelineProjection _ask(
    TimelineProjection p,
    GatewayEvent e, {
    bool reopen = false,
  }) {
    final id = e.payload['id'];
    if (id is! String) return p;
    final at = p.items.indexWhere(
      (i) => i is InterventionItem && i.requestId == id,
    );
    if (at >= 0) {
      final item = p.items[at] as InterventionItem;
      // Une question close n'est jamais reproposée.
      if (item.state.settled) return p;
      final retry =
          reopen &&
          (item.state == QuestionState.sent ||
              item.state == QuestionState.unknown);
      if (!retry && item.state != QuestionState.open) return p;
      final items = [...p.items]
        ..[at] = item.copyWith(
          state: QuestionState.open,
          previousUnanswered: item.previousUnanswered || retry,
        );
      return p.copyWith(items: items, workState: _waiting(items));
    }
    final card = _card(id, e);
    if (card == null) return p;
    final turned = p.working && p.turns > 0 ? p : _startTurn(p);
    final items = [
      ...turned.items,
      card.atTurn(max(turned.turns, turned.userTurns)),
    ];
    return turned.copyWith(items: items, workState: _waiting(items));
  }

  /// Nouvelle carte (tour posé par l'appelant) ; `null` si inexploitable.
  static InterventionItem? _card(String id, GatewayEvent e) {
    final previous = e.payload['answered_locally'] == true;
    if (e.type == HermesRpc.approvalEvent) {
      final command = e.payload['command'];
      final description = e.payload['description'];
      final choices = e.payload['choices'];
      if (command is! String) return null;
      return ApprovalItem(
        0,
        requestId: id,
        description: description is String ? description : '',
        command: command,
        choices: [
          if (choices is List)
            for (final c in choices)
              if (c is String) c,
        ],
        allowSession: e.payload['allow_session'] == true,
        allowPermanent: e.payload['allow_permanent'] == true,
        previousUnanswered: previous,
      );
    }
    final raw = e.payload['questions'];
    final questions = [
      if (raw is List)
        for (final q in raw) ?ClarifyQuestion.fromJson(q),
    ];
    if (questions.isEmpty) return null;
    return QuestionItem(
      0,
      requestId: id,
      questions: questions,
      previousUnanswered: previous,
    );
  }

  /// État d'attente quand une carte est ouverte : une autorisation prime sur
  /// une question.
  static WorkState _waiting(List<TimelineItem> items) =>
      items.any((i) => i is ApprovalItem && i.state == QuestionState.open)
      ? WorkState.waitingApproval
      : WorkState.waitingInput;

  /// `request.cancel {id, method, reason}` : carte fermée, plus de saisie.
  static TimelineProjection _cancel(TimelineProjection p, GatewayEvent e) {
    final id = e.payload['id'];
    final at = p.items.indexWhere(
      (i) => i is InterventionItem && i.requestId == id,
    );
    if (at < 0) return p;
    final item = p.items[at] as InterventionItem;
    if (item.state.settled) return p;
    final reason = e.payload['reason'];
    return _afterQuestions(
      p.copyWith(
        items: [...p.items]
          ..[at] = item.copyWith(
            state: reason == 'timeout' || reason == 'expired'
                ? QuestionState.expired
                : QuestionState.cancelled,
          ),
      ),
    );
  }

  /// Fin de l'outil `clarify` : la réponse envoyée est prise en compte ; une
  /// question encore ouverte a été tranchée ailleurs.
  static TimelineProjection _clarifyDone(TimelineProjection p) {
    final at = p.items.lastIndexWhere(
      (i) => i is QuestionItem && !i.state.settled,
    );
    if (at < 0) return p;
    final item = p.items[at] as QuestionItem;
    return _afterQuestions(
      p.copyWith(
        items: [...p.items]
          ..[at] = item.copyWith(
            state: item.state == QuestionState.open
                ? QuestionState.closed
                : QuestionState.confirmed,
          ),
      ),
    );
  }

  /// Fin de l'outil qui attendait une autorisation (tout `tool.complete`
  /// hors clarify) : la dernière décision envoyée (`sent` ou `unknown`) est
  /// confirmée si le résultat concorde avec elle (`deny` ⇔ `result.status =
  /// "blocked"`, `once` ⇔ non bloqué) ; sinon la carte ne change pas. Aucun
  /// événement ne porte l'id : si deux outils concordants tournent en
  /// parallèle, la mauvaise carte peut être confirmée (accepté, comme pour
  /// clarify). Une carte ouverte ou en cours d'envoi n'est pas touchée.
  static TimelineProjection _approvalDone(
    TimelineProjection p,
    Map<String, dynamic> payload,
  ) {
    final at = p.items.lastIndexWhere(
      (i) =>
          i is ApprovalItem &&
          (i.state == QuestionState.sent || i.state == QuestionState.unknown),
    );
    if (at < 0) return p;
    final item = p.items[at] as ApprovalItem;
    final result = payload['result'];
    final blocked = result is Map && result['status'] == 'blocked';
    final agrees = blocked
        ? item.choice == ApprovalChoice.deny
        : item.choice == ApprovalChoice.once;
    if (!agrees) return p;
    return _afterQuestions(
      p.copyWith(
        items: [...p.items]
          ..[at] = item.copyWith(
            state: QuestionState.confirmed,
            blocked: blocked,
          ),
      ),
    );
  }

  /// Plus aucune carte ouverte : le tour reprend son état « en cours » ;
  /// sinon `waitingApproval` si une autorisation est ouverte, `waitingInput`
  /// pour une question.
  static TimelineProjection _afterQuestions(TimelineProjection p) {
    final waiting = p.items.any(
      (i) => i is InterventionItem && i.state == QuestionState.open,
    );
    if (waiting && p.working) {
      return p.copyWith(workState: _waiting(p.items));
    }
    if (!waiting &&
        (p.workState == WorkState.waitingInput ||
            p.workState == WorkState.waitingApproval)) {
      return p.copyWith(workState: WorkState.running);
    }
    return p;
  }

  /// Signale au registre les questions closes par cette transition.
  void _settle(TimelineProjection before, TimelineProjection after) {
    final ledger = questions;
    if (ledger == null) return;
    final previous = {
      for (final i in before.items)
        if (i is InterventionItem) i.requestId: i.state,
    };
    for (final i in after.items) {
      if (i is InterventionItem &&
          i.state.settled &&
          previous[i.requestId] != i.state) {
        unawaited(
          ledger
              .settle(i.requestId, i.state)
              .catchError((Object _) => _log('conversation.settle_failed')),
        );
      }
    }
  }

  /// Applique les événements manqués ; `null` quand le rejeu n'est pas sûr
  /// (tronqué, autre epoch, trou de `seq`, travail indéterminé).
  TimelineProjection? _replay(
    TimelineProjection current,
    ({
      List<GatewayEvent> events,
      int? latest,
      bool truncated,
      String? epoch,
      List<Map<String, Object?>>? openRequests,
    })
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
    if (info.running && p.working) {
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

  static bool _isDuplicate(TimelineProjection p, GatewayEvent e) =>
      e.seq != null &&
      p.seq != null &&
      p.replayEpoch == e.replayEpoch &&
      e.seq! <= p.seq!;

  TimelineProjection? _apply(TimelineProjection p, GatewayEvent e) {
    final seq = e.seq;
    if (_isDuplicate(p, e)) {
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
        return text == null || text.isEmpty ? p : _append(_ensureTurn(p), text);
      case EventEffect.interim:
        final text = HermesRpc.interimText(e.payload);
        return text == null || text.isEmpty
            ? p
            : _append(_ensureTurn(p), text, sealed: true);
      case EventEffect.intervention:
        return e.type == HermesRpc.requestCancel ? _cancel(p, e) : _ask(p, e);
      case EventEffect.activity:
        if (m.activityCompleted) {
          p = e.payload['name'] == HermesRpc.clarify
              ? _clarifyDone(p)
              : _approvalDone(p, e.payload);
        }
        final rawId = e.payload['tool_id'];
        final id =
            m.activityKind == ActivityKind.tool &&
                rawId is String &&
                rawId.isNotEmpty
            ? rawId
            : null;
        final kind = id == null
            ? ActivityKind.unknown
            : m.activityKind == ActivityKind.tool
            ? ActivityKind.forTool(e.payload['name'])
            : m.activityKind!;
        // Un début reçu après le terminal précédent, mais avant tout accusé,
        // reste provisoire : ne jamais reprendre la fin d'un ancien même ID.
        final betweenTurns =
            p.userTurns <= p.turns &&
            (p.workState == WorkState.succeeded ||
                p.workState == WorkState.failed ||
                p.workState == WorkState.stopped);
        final provisional =
            betweenTurns &&
            (m.activityStarted ||
                p.items.any((item) => item is ActivityItem && item.turn == 0));
        final turn = provisional ? 0 : max(p.turns, p.userTurns);
        final items = [...p.items];
        if (id != null) {
          final at = items.indexWhere(
            (item) =>
                item is ActivityItem &&
                item.turn == turn &&
                item.toolId == id &&
                _sameActivityContext(item, e),
          );
          if (at >= 0) {
            final old = items[at] as ActivityItem;
            final activity = old.copyWith(
              started: old.started || m.activityStarted,
              completed: old.completed || m.activityCompleted,
              detailPatch: m.activityDetails,
            );
            items[at] = activity;
            _insertResult(items, activity, e);
            return p.copyWith(items: items);
          }
        }
        final activity = ActivityItem(
          turn,
          kind,
          toolId: id,
          started: m.activityStarted,
          completed: m.activityCompleted,
          details: Map.unmodifiable(
            {...m.activityDetails}..removeWhere((k, v) => v == null),
          ),
          eventKey: jsonEncode([
            e.replayEpoch,
            e.seq,
            items.length,
            e.generation,
          ]),
        );
        items.add(activity);
        _insertResult(items, activity, e);
        return p.copyWith(items: items);
      case EventEffect.terminal:
        return _finish(p, e, m);
      case EventEffect.ignore:
        return p;
    }
  }

  /// Seul un `tool.complete` de `write_file` avec `args.path` absolu produit
  /// une carte, insérée juste après son activité et dédupliquée par une clé
  /// stable. Un chemin relatif ou seulement cité ne produit rien.
  static void _insertResult(
    List<TimelineItem> items,
    ActivityItem activity,
    GatewayEvent event,
  ) {
    if (!activity.completed || activity.eventKey == null) return;
    final rawName = event.payload['name'] ?? activity.details['name'];
    final name = rawName is String
        ? rawName.trim().split(RegExp(r'\s')).first
        : null;
    if (name != 'write_file') return;
    final args = activity.details['args'];
    if (args is! Map) return;
    final rawPath = args['path'];
    if (rawPath is! String) return;
    final path = rawPath.trim();
    if (!ResultPaths.isAbsolute(path)) return;
    final fileName = ResultPaths.name(path);
    if (fileName == null) return;
    final key = ResultKey.of(activity.eventKey!);
    if (items.any((item) => item is ResultItem && item.resultKey == key)) {
      return;
    }
    final at = items.indexOf(activity);
    items.insert(
      (at < 0 ? items.length : at) + 1,
      ResultItem(
        activity.turn,
        resultKey: key,
        path: path,
        name: fileName,
        mediaType: ResultPaths.mediaTypeFor(fileName),
        localKey: key,
      ),
    );
  }

  // La clé garde le contexte d'origine même si une reprise échoue et que le
  // curseur de la projection avance déjà sur la nouvelle socket.
  static bool _sameActivityContext(ActivityItem item, GatewayEvent event) {
    final key = item.eventKey;
    if (key == null) return false;
    try {
      final parts = jsonDecode(key);
      if (parts is! List || parts.isEmpty) return false;
      if (parts.first != null) return parts.first == event.replayEpoch;
      return event.replayEpoch == null &&
          parts.length >= 4 &&
          parts[3] == event.generation;
    } on FormatException {
      return false;
    }
  }

  static TimelineProjection _startTurn(TimelineProjection p) => p.copyWith(
    items: [
      for (final item in p.items)
        if (item is ActivityItem && item.turn == 0)
          item.copyWith(turn: p.turns + 1)
        else if (item is ResultItem && item.turn == 0)
          item.atTurn(p.turns + 1)
        else
          item,
    ],
    turns: p.turns + 1,
    workState: WorkState.running,
    companionPhase: CompanionPhase.concentrating,
    clearError: true,
  );

  static TimelineProjection _ensureTurn(TimelineProjection p) =>
      p.working && p.turns > 0 ? p : _startTurn(p);

  static TimelineProjection _append(
    TimelineProjection p,
    String text, {
    bool sealed = false,
  }) {
    if (text.isEmpty) return p;
    // Seul un fragment/interim non vide déclenche le repli, jamais le terminal.
    final items = [...p.items];
    var start = items.length;
    while (start > 0 &&
        items[start - 1] is ActivityItem &&
        (items[start - 1].turn == p.turns ||
            (items[start - 1].turn == 0 && p.turns == 1 && p.userTurns == 0))) {
      start--;
    }
    if (items.length - start >= 2) {
      for (var i = start; i < items.length; i++) {
        items[i] = (items[i] as ActivityItem).copyWith(responseReceived: true);
      }
      p = p.copyWith(items: items);
    }
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
    // Le tour est fini : aucune intervention ne peut plus être reçue ni
    // confirmée.
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is InterventionItem && !item.state.settled) {
        items[i] = item.copyWith(state: QuestionState.closed);
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
    bool hydrateAttachments = false,
    bool Function()? canPublish,
  }) => _queues[key] = (_queues[key] ?? Future.value()).then((_) async {
    try {
      final current = _cache[key] ?? await _read(key);
      if (canPublish?.call() == false) return;
      _cache[key] = current;
      var changed = change(current);
      if (changed == null) return;
      if (hydrateAttachments) changed = await _withAttachments(key, changed);
      if (canPublish?.call() == false) return;
      if (immediate) {
        await _write(key, changed);
        _dirty.remove(key);
        _timers.remove(key)?.cancel();
      } else {
        _dirty.add(key);
        _timers[key] ??= Timer(flushInterval, () => _flush(key));
      }
      if (canPublish?.call() == false) return;
      _settle(current, changed);
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
