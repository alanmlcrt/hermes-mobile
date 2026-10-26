import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../models/app_error.dart';
import '../models/attachment.dart';
import '../models/connection.dart';
import '../models/connection_gateway.dart';
import '../models/draft.dart';
import '../models/profile.dart';
import '../models/timeline.dart';
import 'conversation_repository.dart';
import 'hermes_adapter.dart';
import 'file_limits.dart';
import 'attachment_transport.dart';
import 'storage/attachment_files.dart';

/// Seul auteur des brouillons et des opérations (`outbox_*`). Ne ferme pas la
/// base partagée.
class OutboxRepository implements OutboxGateway, SessionResumer, StopGateway {
  OutboxRepository(
    this.database, {
    required this.gateway,
    DateTime Function()? now,
    this.timeout = rpcTimeout,
    this.onStep,
    this.conversation,
    AttachmentFiles? attachmentFiles,
    Future<FileLimits> Function()? loadFileLimits,
  }) : _now = now ?? (() => DateTime.now().toUtc()) {
    _attachmentFiles = attachmentFiles ?? AttachmentFiles();
    conversation?.attachmentFiles = _attachmentFiles;
    _loadFileLimits = loadFileLimits ?? FileLimits.load;
    _events = gateway.events.listen(_onEvent);
    conversation?.resumer = this;
  }
  final Database database;
  final ConnectionGateway gateway;
  final DateTime Function() _now;
  final Duration timeout;
  late final AttachmentFiles _attachmentFiles;
  late final Future<FileLimits> Function() _loadFileLimits;
  final _attachmentWrites = <DraftKey, Future<void>>{};
  final _receiptChecks = <DraftKey, Future<void>>{};

  @override
  Future<List<AttachmentLimit>> attachmentLimits() async =>
      (await _loadFileLimits()).limits;

  @override
  Future<List<Attachment>> attachments(DraftKey key) async {
    await _recover(key);
    final rows = await database.query(
      'outbox_attachments',
      where: 'draft_key = ?',
      whereArgs: [key.value],
      orderBy: 'position, rowid',
    );
    return [for (final row in rows) await _attachment(key, row)];
  }

  Future<Attachment> _attachment(DraftKey key, Map<String, Object?> row) async {
    final file = await _attachmentFiles.file(
      key,
      row['attachment_key'] as String,
    );
    return Attachment(
      key: row['attachment_key'] as String,
      name: row['name'] as String,
      mediaType: row['media_type'] as String,
      bytes: row['bytes'] as int,
      localPath: file.path,
      missing: !await file.exists(),
      state: AttachmentState.values.byName(row['state'] as String),
      reference: row['reference'] as String?,
      errorCode: row['error_code'] as String?,
      sent: row['sent'] == 1,
      cleaned: row['cleaned'] == 1,
    );
  }

  @override
  Future<void> retryAttachment(DraftKey key, String attachmentKey) =>
      _writeAttachment(key, () async {
        await database.update(
          'outbox_attachments',
          {'state': AttachmentState.selected.name, 'error_code': null},
          where:
              'draft_key = ? AND attachment_key = ? AND sent = 0 '
              'AND state IN (?, ?)',
          whereArgs: [
            key.value,
            attachmentKey,
            AttachmentState.failed.name,
            AttachmentState.uncertain.name,
          ],
        );
      });

  Future<void> _writeAttachment(DraftKey key, Future<void> Function() work) {
    if (status(key).busy) {
      return Future.error(const AppError('attachment.busy'));
    }
    final next = (_attachmentWrites[key] ?? Future<void>.value())
        .catchError((_) {})
        .then((_) async {
          try {
            await work();
          } on AppError {
            rethrow;
          } catch (_) {
            throw const AppError('storage.unavailable');
          }
          if (!_changes.isClosed) _changes.add(key);
        });
    _attachmentWrites[key] = next;
    void finished() {
      if (identical(_attachmentWrites[key], next)) {
        _attachmentWrites.remove(key);
      }
    }

    next.then((_) => finished(), onError: (Object _) => finished());
    return next;
  }

  @override
  Future<void> addAttachment(DraftKey key, PickedFile picked) =>
      _writeAttachment(key, () async {
        if (await draft(key) == null) throw const AppError('draft.not_found');
        final limits = await _loadFileLimits();
        final type = picked.mediaType;
        final maximum = limits.maxBytesFor(type);
        if (maximum == null) throw const AppError('attachment.type');
        final refusal = limits.refusal(
          type,
          await _attachmentFiles.length(picked),
        );
        if (refusal != null) throw AppError(refusal);
        final attachmentKey = randomUuid();
        final file = await _attachmentFiles.copy(
          key,
          attachmentKey,
          picked,
          maximum,
        );
        try {
          final position =
              (await database.rawQuery(
                    'SELECT MAX(position) AS p FROM outbox_attachments WHERE draft_key = ?',
                    [key.value],
                  )).single['p']
                  as int?;
          await database.insert('outbox_attachments', {
            'attachment_key': attachmentKey,
            'draft_key': key.value,
            'name': picked.name,
            'media_type': type,
            'bytes': await file.length(),
            'state': AttachmentState.selected.name,
            'position': (position ?? -1) + 1,
            'created_at': _now().toIso8601String(),
          });
        } catch (_) {
          await _attachmentFiles.remove(key, attachmentKey);
          rethrow;
        }
      });

  @override
  Future<void> removeAttachment(DraftKey key, String attachmentKey) =>
      _writeAttachment(key, () async {
        final rows = await database.query(
          'outbox_attachments',
          where: 'draft_key = ? AND attachment_key = ?',
          whereArgs: [key.value, attachmentKey],
        );
        if (rows.isEmpty) return;
        if (rows.single['sent'] == 1) {
          throw const AppError('attachment.retained');
        }
        // Garder une sauvegarde privée jusqu’au commit : un échec SQLite après
        // suppression des octets doit encore permettre de restaurer la pièce.
        final original = await _attachmentFiles.file(key, attachmentKey);
        final backup = await _attachmentFiles.file(key, randomUuid());
        final exists = await original.exists();
        if (exists) await original.copy(backup.path);
        var cleanupBackup = false;
        try {
          await database.transaction((t) async {
            await t.delete(
              'outbox_attachments',
              where: 'draft_key = ? AND attachment_key = ?',
              whereArgs: [key.value, attachmentKey],
            );
            await _attachmentFiles.remove(key, attachmentKey);
          });
          cleanupBackup = true;
        } catch (_) {
          if (exists && !await original.exists()) {
            await backup.rename(original.path);
          }
          cleanupBackup = true;
          rethrow;
        } finally {
          // Après le commit, un reliquat de sauvegarde ne doit pas transformer
          // un retrait réussi en erreur ni empêcher la restauration précédente.
          try {
            if (cleanupBackup && await backup.exists()) await backup.delete();
          } catch (_) {
            /* nettoyage différé du reliquat privé */
          }
        }
      });

  /// Observateur du pipeline nommé (tests, diagnostic) ; jamais de contenu.
  final void Function(String step)? onStep;

  /// Reçoit la liaison runtime et les demandes acceptées ; jamais d'ordre inverse.
  final ConversationRepository? conversation;
  final _writes = <DraftKey, Future<void>>{};
  final _recovered = <DraftKey>{};
  final _status = <DraftKey, SendStatus>{};
  final _runtime = <DraftKey, ({String id, int generation})>{};
  final _turns = <DraftKey, int>{};
  final _storedIds = <DraftKey, String>{};
  final _timelineKeys = <DraftKey, TimelineKey>{};
  final _ensuring = <DraftKey, Future<String>>{};
  final _stopping = <DraftKey, Future<void>>{};
  final _stopLocks = <TimelineKey>{};
  final _stopAttempted = <(TimelineKey, int)>{};
  static (TimelineKey, int) _stopScope(StopTarget target) =>
      (target.key, target.turn);
  final _stops = <DraftKey, ({StopTarget target, StopStatus status})>{};
  final _stopRecovered = <DraftKey>{};

  @override
  bool canStop(DraftKey key) {
    final timeline = _timelineKeys[key];
    final target = timeline == null ? null : conversation?.stopTarget(timeline);
    return target != null &&
        !_stopping.containsKey(key) &&
        !_stopLocks.contains(target.key) &&
        !_stopAttempted.contains(_stopScope(target));
  }

  @override
  StopStatus? stopStatus(DraftKey key) {
    final op = _stops[key];
    if (op == null) return null;
    final current = conversation?.projection(op.target.key);
    // Un ancien arrêt ne porte jamais sur le tour suivant.
    if (current != null && current.turns > op.target.turn) return null;
    if ((op.status.state == StopState.requested ||
            op.status.state == StopState.preparing) &&
        conversation?.stopTarget(op.target.key) != op.target &&
        current?.workState != WorkState.stopped) {
      return const StopStatus(StopState.unknown, errorCode: 'stop.unknown');
    }
    return op.status;
  }

  @override
  Future<void> stop(DraftKey key) =>
      _stopping[key] ??= _stop(key).whenComplete(() {
        _stopping.remove(key);
        if (!_changes.isClosed) _changes.add(key);
      });

  void _setStop(DraftKey key, StopTarget target, StopStatus status) {
    _stops[key] = (target: target, status: status);
    if (!_changes.isClosed) _changes.add(key);
  }

  Future<void> _stop(DraftKey key) async {
    // Capturer AVANT la première attente : aucune reprise pour envoyer l'arrêt.
    final prior = _stops[key];
    final timeline = _timelineKeys[key];
    final target = timeline == null ? null : conversation?.stopTarget(timeline);
    if (target == null || !_stopLocks.add(target.key)) return;
    if (_stopAttempted.contains(_stopScope(target))) {
      _stopLocks.remove(target.key);
      return;
    }
    if (prior?.target == target && prior?.status.state != StopState.failed) {
      _stopLocks.remove(target.key);
      return;
    }
    final operation = OperationKey.create();
    var persisted = false;
    bool valid() => conversation?.stopTarget(target.key) == target;
    Future<void> finish(StopStatus status) async {
      if (persisted) {
        try {
          await database.update(
            'outbox_stops',
            {'state': status.state.name, 'error_code': status.errorCode},
            where: 'operation_key = ?',
            whereArgs: [operation.value],
          );
        } catch (_) {
          /* restaurée incertaine ; jamais de renvoi */
        }
      }
      _setStop(key, target, status);
    }

    _setStop(key, target, const StopStatus(StopState.preparing));
    try {
      final draft = await this.draft(key);
      if (!valid() ||
          draft == null ||
          draft.connection != target.key.connection ||
          draft.profile != target.key.profile ||
          draft.storedSessionId != target.key.session) {
        await finish(
          const StopStatus(StopState.stale, errorCode: 'stop.stale'),
        );
        return;
      }
      await database.insert('outbox_stops', {
        'operation_key': operation.value,
        'draft_key': key.value,
        'connection_key': target.key.connection.value,
        'profile_key': target.key.profile.value,
        'stored_session_id': target.key.session,
        'runtime': target.runtime,
        'generation': target.generation,
        'observed_turn': target.turn,
        'state': StopState.preparing.name,
        'created_at': _now().toIso8601String(),
      });
      persisted = true;
      if (!valid()) {
        await finish(
          const StopStatus(StopState.stale, errorCode: 'stop.stale'),
        );
        return;
      }
      // Aucune attente entre cette dernière garde et l'unique écriture réseau.
      _setStop(key, target, const StopStatus(StopState.requested));
      _stopAttempted.add(_stopScope(target));
      final result = await gateway.call(
        'session.interrupt',
        HermesRpc.interruptParams(target.runtime, target.key.profile),
        timeout: timeout,
      );
      final interrupted = HermesRpc.interrupted(result);
      await finish(
        StopStatus(
          interrupted ? StopState.requested : StopState.failed,
          errorCode: interrupted ? null : 'stop.not_interrupted',
        ),
      );
    } on RpcError catch (e) {
      await finish(StopStatus(StopState.failed, errorCode: 'rpc.${e.code}'));
    } catch (e) {
      await finish(
        StopStatus(
          persisted ? StopState.unknown : StopState.failed,
          errorCode: !persisted
              ? 'storage.unavailable'
              : e is AppError && e.code == 'contract.invalid_response'
              ? e.code
              : 'stop.unknown',
        ),
      );
    } finally {
      _stopLocks.remove(target.key);
    }
  }

  Future<void> _recoverStop(DraftKey key) async {
    if (_stopRecovered.contains(key)) return;
    final rows = await database.query(
      'outbox_stops',
      where: 'draft_key = ?',
      whereArgs: [key.value],
      orderBy: 'created_at DESC, rowid DESC',
      limit: 1,
    );
    _stopRecovered.add(key);
    if (rows.isEmpty || _stops.containsKey(key)) return;
    final row = rows.single;
    final target = StopTarget(
      TimelineKey(
        ConnectionKey(row['connection_key'] as String),
        ProfileKey(row['profile_key'] as String),
        row['stored_session_id'] as String,
      ),
      row['runtime'] as String,
      row['generation'] as int,
      row['observed_turn'] as int,
      -1,
    );
    final state = StopState.values.byName(row['state'] as String);
    final uncertain =
        state == StopState.preparing || state == StopState.requested;
    if (uncertain || state == StopState.unknown || state == StopState.failed) {
      _stopAttempted.add(_stopScope(target));
    }
    _setStop(
      key,
      target,
      StopStatus(
        uncertain ? StopState.unknown : state,
        errorCode: uncertain ? 'stop.unknown' : row['error_code'] as String?,
      ),
    );
  }

  final _changes = StreamController<DraftKey>.broadcast(sync: true);
  StreamSubscription<GatewayEvent>? _events;

  @override
  Stream<DraftKey> get changes => _changes.stream;

  @override
  Future<Draft> openNewDraft(
    ConnectionKey connection,
    ProfileKey profile,
  ) async {
    // Un brouillon qui a une session reste sur sa conversation (liste d'historique).
    Future<List<Map<String, Object?>>> reusable() => database.query(
      'outbox_drafts',
      where:
          'connection_key = ? AND profile_key = ? '
          'AND stored_session_id IS NULL',
      whereArgs: [connection.value, profile.value],
      limit: 1,
    );
    var rows = await reusable();
    if (rows.isEmpty) {
      // L'index unique partiel départage deux ouvertures concurrentes.
      await database.insert('outbox_drafts', {
        'draft_key': DraftKey.create().value,
        'connection_key': connection.value,
        'profile_key': profile.value,
        'body': '',
        'updated_at': _now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      rows = await reusable();
    }
    return _draft(rows.single);
  }

  @override
  Future<Draft> openContinuation(
    ConnectionKey connection,
    ProfileKey profile,
    String storedSessionId,
  ) async {
    Future<List<Map<String, Object?>>> existing() => database.query(
      'outbox_drafts',
      where: 'connection_key = ? AND profile_key = ? AND stored_session_id = ?',
      whereArgs: [connection.value, profile.value, storedSessionId],
    );
    var rows = await existing();
    if (rows.isEmpty) {
      // L'index unique départage deux ouvertures concurrentes.
      await database.insert('outbox_drafts', {
        'draft_key': DraftKey.create().value,
        'connection_key': connection.value,
        'profile_key': profile.value,
        'stored_session_id': storedSessionId,
        'body': '',
        'updated_at': _now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      rows = await existing();
    }
    return _draft(rows.single);
  }

  @override
  Future<void> reassignNewDraft(DraftKey key, ProfileKey profile) async {
    try {
      // Les saisies en vol (source et cible) sont écrites avant de déplacer
      // les textes.
      await Future.wait(_writes.values.map((w) => w.catchError((_) {})));
      await Future.wait(
        _attachmentWrites.values.map((w) => w.catchError((_) {})),
      );
      await database.transaction((t) async {
        final rows = await t.query(
          'outbox_drafts',
          where: 'draft_key = ?',
          whereArgs: [key.value],
        );
        if (rows.isEmpty) throw const AppError('draft.not_found');
        final source = _draft(rows.single);
        if (source.storedSessionId != null || source.profile == profile) return;
        final targets = await t.query(
          'outbox_drafts',
          where:
              'connection_key = ? AND profile_key = ? '
              'AND stored_session_id IS NULL',
          whereArgs: [source.connection.value, profile.value],
        );
        if (targets.isNotEmpty) {
          final target = _draft(targets.single);
          // Un envoi en cours garde son profil : rien ne bouge.
          if (status(target.key).busy || status(key).busy) {
            throw const AppError('draft.profile_busy');
          }
          final pieces = await t.query(
            'outbox_attachments',
            where: 'draft_key = ?',
            whereArgs: [target.key.value],
            limit: 1,
          );
          if (target.body.isEmpty &&
              pieces.isEmpty &&
              !_attachmentWrites.containsKey(target.key)) {
            await t.delete(
              'outbox_attachments',
              where: 'draft_key = ?',
              whereArgs: [target.key.value],
            );
            await t.delete(
              'outbox_operations',
              where: 'draft_key = ?',
              whereArgs: [target.key.value],
            );
            await t.delete(
              'outbox_drafts',
              where: 'draft_key = ?',
              whereArgs: [target.key.value],
            );
          } else {
            // L'index unique interdit deux brouillons neufs sur un profil :
            // l'échange passe par une valeur provisoire.
            Future<void> move(DraftKey draft, String to) => t.update(
              'outbox_drafts',
              {'profile_key': to},
              where: 'draft_key = ?',
              whereArgs: [draft.value],
            );
            await move(key, '');
            await move(target.key, source.profile.value);
          }
        }
        await t.update(
          'outbox_drafts',
          {'profile_key': profile.value},
          where: 'draft_key = ?',
          whereArgs: [key.value],
        );
      });
    } on AppError {
      rethrow;
    } catch (_) {
      throw const AppError('storage.unavailable');
    }
  }

  @override
  Future<Draft?> draft(DraftKey key) async {
    await _recover(key);
    await _recoverStop(key);
    final rows = await database.query(
      'outbox_drafts',
      where: 'draft_key = ?',
      whereArgs: [key.value],
    );
    return rows.isEmpty ? null : _draft(rows.single);
  }

  @override
  Future<void> saveText(DraftKey key, String body) {
    final previous = _writes[key] ?? Future.value();
    final next = previous.catchError((_) {}).then((_) async {
      final count = await database.rawUpdate(
        'UPDATE outbox_drafts SET body = ?, updated_at = ?, '
        'revision = revision + 1 WHERE draft_key = ?',
        [body, _now().toIso8601String(), key.value],
      );
      if (count != 1) throw const AppError('storage.unavailable');
    });
    _writes[key] = next;
    return next.catchError(
      (Object _) => throw const AppError('storage.unavailable'),
      test: (error) => error is! AppError,
    );
  }

  /// Au premier accès d'une exécution : l'état persisté de la dernière
  /// opération redevient visible ; un envoi interrompu est « incertain ».
  Future<void> _recover(DraftKey key) async {
    if (!_recovered.add(key) || _status[key] != null) return;
    await database.update(
      'outbox_attachments',
      {
        'state': AttachmentState.uncertain.name,
        'error_code': 'attachment.unknown',
      },
      where: 'draft_key = ? AND state = ?',
      whereArgs: [key.value, AttachmentState.uploading.name],
    );
    await database.rawUpdate(
      'UPDATE outbox_operation_attachments SET state = ?, error_code = ? '
      'WHERE state = ? AND operation_key IN '
      '(SELECT operation_key FROM outbox_operations WHERE draft_key = ?)',
      [
        AttachmentState.uncertain.name,
        'attachment.unknown',
        AttachmentState.uploading.name,
        key.value,
      ],
    );
    final rows = await database.query(
      'outbox_operations',
      where: 'draft_key = ?',
      whereArgs: [key.value],
      orderBy: 'created_at DESC, rowid DESC',
      limit: 1,
    );
    if (rows.isEmpty || _status[key] != null) return;
    final operation = OperationKey(rows.single['operation_key'] as String);
    final state = rows.single['state'] as String;
    if (state == OperationState.preparing.name ||
        state == OperationState.sending.name) {
      await _persist(
        operation,
        OperationState.unknown,
        errorCode: 'send.unknown',
      );
      _set(
        key,
        const SendStatus(
          state: OperationState.unknown,
          errorCode: 'send.unknown',
        ),
      );
    } else if (state == OperationState.unknown.name ||
        state == OperationState.failed.name) {
      _set(
        key,
        SendStatus(
          state: OperationState.values.byName(state),
          errorCode: rows.single['error_code'] as String? ?? 'send.unknown',
          retryable: state == OperationState.failed.name,
        ),
      );
    }
  }

  @override
  SendStatus status(DraftKey key) {
    final current = _status[key] ?? const SendStatus();
    final turn = _turns[key] != null && _turns[key] == gateway.socketGeneration;
    if (turn == current.turnActive) return current;
    return SendStatus(
      state: current.state,
      errorCode: current.errorCode,
      retryable: current.retryable,
      turnActive: turn,
    );
  }

  void _set(DraftKey key, [SendStatus status = const SendStatus()]) {
    _status[key] = status;
    if (!_changes.isClosed) _changes.add(key);
  }

  void _onEvent(GatewayEvent event) {
    for (final entry in _runtime.entries) {
      if (entry.value.id != event.sessionId ||
          entry.value.generation != event.generation) {
        continue;
      }
      if (event.type == HermesRpc.turnStart) {
        _turns[entry.key] = event.generation;
      } else if (event.type == HermesRpc.turnEnd ||
          event.type == HermesRpc.sessionError) {
        _turns.remove(entry.key);
        unawaited(_checkPendingReceipts(entry.key, entry.value.id));
      } else {
        continue;
      }
      if (!_changes.isClosed) _changes.add(entry.key);
    }
  }

  /// Création ou reprise de la session, sérialisée par brouillon : deux appels
  /// concurrents partagent le même vol et une seule `session.create` part.
  Future<String> ensureSession(
    DraftKey key,
  ) => _ensuring[key] ??= _ensure(key).whenComplete(() {
    // Bloc, pas flèche : `remove` rend le Future lui-même (attente circulaire).
    _ensuring.remove(key);
  });

  Future<String> _ensure(DraftKey key) async {
    final g = gateway;
    onStep?.call('ensureSession');
    final draft = await this.draft(key);
    if (draft == null) throw const AppError('draft.not_found');
    final cached = _runtime[key];
    if (draft.storedSessionId != null &&
        cached != null &&
        cached.generation == g.socketGeneration) {
      return cached.id;
    }
    // Lue avant l'appel : une reconnexion pendant l'attente rend l'id périmé.
    final generation = g.socketGeneration;
    final String runtime;
    final String stored;
    var running = false;
    if (draft.storedSessionId == null) {
      final result = await g.call(
        'session.create',
        HermesRpc.createParams(draft.profile, _idempotencyKey(draft)),
        timeout: timeout,
      );
      final created = HermesRpc.created(result);
      // Persisté avant toute soumission : la session survit à un échec.
      await database.update(
        'outbox_drafts',
        {'stored_session_id': created.stored},
        where: 'draft_key = ? AND stored_session_id IS NULL',
        whereArgs: [key.value],
      );
      runtime = created.runtime;
      stored = created.stored;
    } else {
      final result = await g.call(
        'session.resume',
        HermesRpc.resumeParams(draft.storedSessionId!, draft.profile),
        timeout: timeout,
      );
      final resumed = HermesRpc.resumed(result);
      runtime = resumed.runtime;
      stored = draft.storedSessionId!;
      running = resumed.running;
    }
    _runtime[key] = (id: runtime, generation: generation);
    _storedIds[key] = stored;
    _timelineKeys[key] = TimelineKey(draft.connection, draft.profile, stored);
    conversation?.bind(
      TimelineKey(draft.connection, draft.profile, stored),
      runtime,
      generation,
    );
    if (running) {
      _turns[key] = generation;
      if (!_changes.isClosed) _changes.add(key);
    }
    return runtime;
  }

  static String _idempotencyKey(Draft draft) =>
      '${draft.profile.value}/${draft.key.value}';

  void _assertAttachmentScope(Draft draft, int generation) {
    if (gateway.snapshot.connection?.key != draft.connection ||
        gateway.socketGeneration != generation ||
        gateway.snapshot.link != LinkState.connected) {
      throw const AppError('attachment.scope_changed');
    }
  }

  @override
  Future<void> send(DraftKey key) async {
    // Gardes synchrones : aucun second envoi ne passe avant le premier await.
    if (status(key).busy || status(key).turnActive) return;
    final g = gateway;
    if (g.snapshot.link != LinkState.connected ||
        g.snapshot.capabilities.any(
          (c) => c.name == 'conversation' && c.state != CapabilityState.present,
        )) {
      _set(
        key,
        const SendStatus(
          state: OperationState.failed,
          errorCode: 'send.unavailable',
          retryable: true,
        ),
      );
      return;
    }
    _set(key, const SendStatus(state: OperationState.preparing));
    final operation = OperationKey.create();
    final Draft draft;
    final List<Attachment> pieces;
    try {
      // Un prompt peut avoir été accepté malgré l'échec de son commit local.
      final unresolved = await database.rawQuery(
        'SELECT operation_key FROM outbox_operations o WHERE draft_key = ? '
        'AND state IN (?, ?) AND (error_code IS NULL OR error_code = ?) '
        'AND EXISTS (SELECT 1 FROM outbox_operation_attachments a '
        'WHERE a.operation_key = o.operation_key)',
        [
          key.value,
          OperationState.sending.name,
          OperationState.unknown.name,
          'send.unknown',
        ],
      );
      if (unresolved.isNotEmpty) {
        _set(
          key,
          const SendStatus(
            state: OperationState.unknown,
            errorCode: 'send.unknown',
          ),
        );
        return;
      }
      // Les saisies en vol sont écrites avant de figer le texte envoyé.
      await (_writes[key] ?? Future.value()).catchError((_) {});
      final found = await this.draft(key);
      await (_attachmentWrites[key] ?? Future<void>.value()).catchError((_) {});
      pieces = (await attachments(key)).where((a) => !a.sent).toList();
      if (pieces.any((a) => a.mediaType == 'image/jpeg')) {
        _set(
          key,
          const SendStatus(
            state: OperationState.failed,
            errorCode: 'attachment.jpeg_unverified',
          ),
        );
        return;
      }
      if (pieces.any(
        (a) =>
            a.state == AttachmentState.failed ||
            a.state == AttachmentState.uncertain ||
            a.state == AttachmentState.uploading,
      )) {
        _set(
          key,
          const SendStatus(
            state: OperationState.failed,
            errorCode: 'attachment.retry_required',
          ),
        );
        return;
      }
      if (found == null || (found.body.trim().isEmpty && pieces.isEmpty)) {
        _set(key);
        return;
      }
      draft = found;
      await database.transaction((t) async {
        final stamp = _now().toIso8601String();
        await t.insert('outbox_operations', {
          'operation_key': operation.value,
          'draft_key': key.value,
          'connection_key': draft.connection.value,
          'profile_key': draft.profile.value,
          'body': draft.body,
          'revision': draft.revision,
          'state': OperationState.preparing.name,
          'created_at': stamp,
          'updated_at': stamp,
        });
        await t.rawUpdate(
          'UPDATE outbox_drafts SET idempotency_key = COALESCE(idempotency_key, ?) '
          'WHERE draft_key = ?',
          [_idempotencyKey(draft), key.value],
        );
        for (var index = 0; index < pieces.length; index++) {
          final piece = pieces[index];
          await t.update(
            'outbox_attachments',
            {
              'operation_key': operation.value,
              'connection_key': draft.connection.value,
              'profile_key': draft.profile.value,
            },
            where: 'draft_key = ? AND attachment_key = ? AND sent = 0',
            whereArgs: [key.value, piece.key],
          );
          await t.insert('outbox_operation_attachments', {
            'operation_key': operation.value,
            'attachment_key': piece.key,
            'position': index,
            'connection_key': draft.connection.value,
            'profile_key': draft.profile.value,
            'state': piece.state.name,
            'reference': piece.reference,
          });
        }
      });
    } catch (_) {
      _set(
        key,
        const SendStatus(
          state: OperationState.failed,
          errorCode: 'storage.unavailable',
          retryable: true,
        ),
      );
      return;
    }

    var runtime = '';
    var generation = g.socketGeneration;
    late final List<Attachment> sentPieces;
    late final String prompt;
    try {
      if (pieces.isNotEmpty) _assertAttachmentScope(draft, generation);
      runtime = await ensureSession(key);
      if (pieces.isNotEmpty) _assertAttachmentScope(draft, generation);
      if (status(key).turnActive) {
        await _finish(
          key,
          operation,
          OperationState.failed,
          'send.turn_active',
          true,
        );
        return;
      }
      onStep?.call('attachments');
      final scoped = await this.draft(key);
      if (scoped == null ||
          scoped.connection != draft.connection ||
          scoped.profile != draft.profile ||
          scoped.storedSessionId != _storedIds[key]) {
        throw const AppError('attachment.scope_changed');
      }
      await database.transaction((t) async {
        await t.update(
          'outbox_operations',
          {'stored_session_id': scoped.storedSessionId},
          where: 'operation_key = ?',
          whereArgs: [operation.value],
        );
        await t.update(
          'outbox_operation_attachments',
          {'stored_session_id': scoped.storedSessionId},
          where: 'operation_key = ?',
          whereArgs: [operation.value],
        );
      });
      for (final piece in pieces) {
        if (piece.state == AttachmentState.uploaded) {
          final rows = await database.query(
            'outbox_attachments',
            columns: [
              'connection_key',
              'profile_key',
              'stored_session_id',
              'reference',
            ],
            where: 'attachment_key = ?',
            whereArgs: [piece.key],
          );
          if (rows.length != 1 ||
              rows.single['connection_key'] != draft.connection.value ||
              rows.single['profile_key'] != draft.profile.value ||
              rows.single['stored_session_id'] != scoped.storedSessionId ||
              rows.single['reference'] != piece.reference) {
            throw const AppError('attachment.scope_changed');
          }
        }
      }
      final transport = AttachmentTransport(g, timeout);
      for (final piece in pieces) {
        if (piece.state == AttachmentState.uploaded) continue;
        await database.rawUpdate(
          'UPDATE outbox_attachments SET state = ?, stored_session_id = ?, '
          'error_code = NULL, attempts = attempts + 1 '
          'WHERE attachment_key = ? AND operation_key = ?',
          [
            AttachmentState.uploading.name,
            scoped.storedSessionId,
            piece.key,
            operation.value,
          ],
        );
        await database.update(
          'outbox_operation_attachments',
          {'state': AttachmentState.uploading.name},
          where: 'operation_key = ? AND attachment_key = ?',
          whereArgs: [operation.value, piece.key],
        );
        if (!_changes.isClosed) _changes.add(key);
        _assertAttachmentScope(draft, generation);
        final result = await transport.upload(piece, draft.profile, runtime);
        final state = switch (result.outcome) {
          AttachOutcome.uploaded => AttachmentState.uploaded,
          AttachOutcome.refused => AttachmentState.failed,
          AttachOutcome.uncertain => AttachmentState.uncertain,
        };
        await database.update(
          'outbox_attachments',
          {
            'state': state.name,
            'reference': result.reference,
            'error_code': result.errorCode,
          },
          where: 'attachment_key = ? AND operation_key = ?',
          whereArgs: [piece.key, operation.value],
        );
        await database.update(
          'outbox_operation_attachments',
          {
            'state': state.name,
            'reference': result.reference,
            'error_code': result.errorCode,
          },
          where: 'operation_key = ? AND attachment_key = ?',
          whereArgs: [operation.value, piece.key],
        );
        if (!_changes.isClosed) _changes.add(key);
        if (state != AttachmentState.uploaded) {
          await _finish(
            key,
            operation,
            state == AttachmentState.uncertain
                ? OperationState.unknown
                : OperationState.failed,
            result.errorCode ?? 'attachment.unknown',
            false,
          );
          return;
        }
      }
      onStep?.call('notificationTracking'); // Epic 5, non bloquant
      if (status(key).turnActive) {
        // Session reprise en plein tour : rien n'est soumis.
        await _finish(
          key,
          operation,
          OperationState.failed,
          'send.turn_active',
          true,
        );
        return;
      }
      // Repère du rapprochement si la réponse se perd : lignes déjà connues.
      final watermark = await conversation?.maxUserRow(
        TimelineKey(draft.connection, draft.profile, _storedIds[key]!),
      );
      await _persist(
        operation,
        OperationState.sending,
        rowWatermark: watermark,
      );
      sentPieces = (await attachments(key))
          .where((a) => pieces.any((p) => p.key == a.key))
          .toList();
      prompt = [
        for (final piece in sentPieces) piece.reference!,
        if (draft.body.trim().isNotEmpty) draft.body,
      ].join('\n');
    } catch (error) {
      // A write may have reached Hermes before local persistence failed.
      var inFlight = 0;
      try {
        inFlight = await database.update(
          'outbox_attachments',
          {
            'state': AttachmentState.uncertain.name,
            'error_code': 'attachment.unknown',
          },
          where: 'operation_key = ? AND state = ?',
          whereArgs: [operation.value, AttachmentState.uploading.name],
        );
        await database.update(
          'outbox_operation_attachments',
          {
            'state': AttachmentState.uncertain.name,
            'error_code': 'attachment.unknown',
          },
          where: 'operation_key = ? AND state = ?',
          whereArgs: [operation.value, AttachmentState.uploading.name],
        );
      } catch (_) {
        inFlight = 1;
      }
      if (inFlight > 0 && !_changes.isClosed) _changes.add(key);
      await _finish(
        key,
        operation,
        inFlight > 0 ? OperationState.unknown : OperationState.failed,
        inFlight > 0 ? 'attachment.unknown' : _code(error),
        inFlight == 0,
      );
      return;
    }
    _set(key, const SendStatus(state: OperationState.sending));
    onStep?.call('submit');
    var recovered = false;
    while (true) {
      try {
        if (pieces.isNotEmpty) _assertAttachmentScope(draft, generation);
        final result = await g.call(
          'prompt.submit',
          HermesRpc.submitParams(runtime, prompt),
          timeout: timeout,
        );
        final accepted = HermesRpc.submitted(result);
        if (accepted == null) {
          await _finish(
            key,
            operation,
            OperationState.unknown,
            'send.unknown',
            false,
          );
        } else {
          await _accept(
            key,
            operation,
            draft,
            accepted.userRowId,
            attachments: sentPieces,
            runtime: runtime,
            submittedPrompt: prompt,
          );
        }
        return;
      } on RpcError catch (error) {
        if (error.code == HermesRpc.runtimeLost && !recovered) {
          // Refus certain : un seul nouvel essai après reprise de la session.
          recovered = true;
          _runtime.remove(key);
          try {
            runtime = await ensureSession(key);
            generation = _runtime[key]!.generation;
            continue;
          } catch (error) {
            await _finish(
              key,
              operation,
              OperationState.failed,
              _code(error),
              true,
            );
            return;
          }
        }
        await _finish(
          key,
          operation,
          OperationState.failed,
          'rpc.${error.code}',
          true,
        );
        return;
      } on AppError catch (error) {
        final uncertain = error.code == 'rpc.uncertain';
        await _finish(
          key,
          operation,
          uncertain ? OperationState.unknown : OperationState.failed,
          uncertain ? 'send.unknown' : error.code,
          !uncertain,
        );
        return;
      } catch (_) {
        // Erreur inattendue après écriture possible : on ne renvoie pas.
        await _finish(
          key,
          operation,
          OperationState.unknown,
          'send.unknown',
          false,
        );
        return;
      }
    }
  }

  static String _code(Object error) => switch (error) {
    RpcError() => 'rpc.${error.code}',
    AppError(code: 'rpc.uncertain') => 'transport.unreachable',
    AppError() => error.code,
    _ => 'storage.unavailable',
  };

  Future<void> _persist(
    OperationKey operation,
    OperationState state, {
    String? errorCode,
    int? userRowId,
    int? rowWatermark,
  }) => database.update(
    'outbox_operations',
    {
      'state': state.name,
      'error_code': errorCode,
      'user_row_id': ?userRowId,
      'row_watermark': ?rowWatermark,
      'updated_at': _now().toIso8601String(),
    },
    where: 'operation_key = ?',
    whereArgs: [operation.value],
  );

  Future<void> _finish(
    DraftKey key,
    OperationKey operation,
    OperationState state,
    String code,
    bool retryable,
  ) async {
    try {
      await _persist(operation, state, errorCode: code);
    } catch (_) {
      /* l'état affiché prime ; le brouillon reste intact */
    }
    _set(key, SendStatus(state: state, errorCode: code, retryable: retryable));
  }

  Future<void> _accept(
    DraftKey key,
    OperationKey operation,
    Draft draft,
    int? userRowId, {
    List<Attachment> attachments = const [],
    String? runtime,
    String? submittedPrompt,
  }) async {
    try {
      await _commitAccepted(
        key,
        operation,
        userRowId,
        clearRevision: draft.revision,
      );
    } catch (_) {
      await _finish(
        key,
        operation,
        OperationState.unknown,
        'send.unknown',
        false,
      );
      return;
    }
    // Après la base : la bulle n'apparaît que pour une demande réellement acceptée.
    await conversation?.accepted(
      TimelineKey(draft.connection, draft.profile, _storedIds[key]!),
      operation,
      draft.body,
      userRowId: userRowId,
    );
    if (attachments.isNotEmpty && runtime != null && submittedPrompt != null) {
      await _confirmReceipts(
        key,
        operation,
        attachments,
        runtime,
        userRowId,
        submittedPrompt,
      );
    }
    _set(key, const SendStatus(state: OperationState.accepted));
  }

  Future<void> _confirmReceipts(
    DraftKey key,
    OperationKey operation,
    List<Attachment> pieces,
    String runtime,
    int? userRowId,
    String submittedPrompt,
  ) async {
    try {
      final scope = await draft(key);
      final cached = _runtime[key];
      if (scope == null || cached == null || cached.id != runtime) return;
      _assertAttachmentScope(scope, cached.generation);
      final history = await gateway.call(
        'session.history',
        HermesRpc.historyParams(runtime),
        timeout: timeout,
      );
      _assertAttachmentScope(scope, cached.generation);
      final messages = history['messages'];
      if (messages is! List) return;
      final operationRows = await database.query(
        'outbox_operations',
        where: 'operation_key = ? AND draft_key = ? AND state = ? AND connection_key = ? AND profile_key = ? AND stored_session_id = ?',
        whereArgs: [
          operation.value,
          key.value,
          OperationState.accepted.name,
          scope.connection.value,
          scope.profile.value,
          scope.storedSessionId,
        ],
      );
      if (operationRows.length != 1) return;
      final watermark = operationRows.singleOrNull?['row_watermark'] as int?;
      final candidates = <Map>[];
      for (final message in messages) {
        if (message is! Map ||
            message['role'] != 'user' ||
            message['row_id'] is! int ||
            (userRowId != null
                ? message['row_id'] != userRowId
                : watermark == null ||
                      message['row_id'] is! int ||
                      (message['row_id'] as int) <= watermark)) {
          continue;
        }
        candidates.add(message);
      }
      if (candidates.length != 1) return;
      final rowId = candidates.single['row_id'] as int;
      final collisions = await database.query(
        'outbox_operations',
        columns: ['operation_key'],
        where: 'operation_key <> ? AND connection_key = ? AND profile_key = ? AND stored_session_id = ? AND user_row_id = ?',
        whereArgs: [
          operation.value,
          scope.connection.value,
          scope.profile.value,
          scope.storedSessionId,
          rowId,
        ],
      );
      if (collisions.isNotEmpty) return;
      final snapshots = await database.query(
        'outbox_operation_attachments',
        columns: ['reference'],
        where: 'operation_key = ?',
        whereArgs: [operation.value],
      );
      for (final message in candidates) {
        final raw = message['content'] ?? message['text'];
        if (raw is! String) continue;
        final promptAt = raw.indexOf(submittedPrompt);
        if (promptAt < 0) continue;
        // References in the submitted prompt are echoes, never receipt proof.
        final serverOnly = raw.replaceAll(submittedPrompt, '');
        for (final piece in pieces) {
          final reference = piece.reference;
          if (reference == null ||
              snapshots.where((s) => s['reference'] == reference).length != 1) {
            continue;
          }
          final evidence = piece.isImage
              ? RegExp(r'@image:[^\s]+')
                    .allMatches(serverOnly)
                    .any((m) => m.group(0) == reference)
              : serverOnly.contains('--- Attached Context ---') &&
                    RegExp(
                      '(^|[\\s\\[(])${RegExp.escape(reference)}'
                      r'($|[\s\])])',
                    ).hasMatch(
                      serverOnly.substring(
                        serverOnly.indexOf('--- Attached Context ---'),
                      ),
                    );
          if (evidence) {
            _assertAttachmentScope(scope, cached.generation);
            await database.transaction((t) async {
              await t.update(
                'outbox_operations',
                {'user_row_id': rowId},
                where: 'operation_key = ? AND state = ?',
                whereArgs: [operation.value, OperationState.accepted.name],
              );
              await t.update(
                'outbox_attachments',
                {'state': AttachmentState.received.name},
                where: 'attachment_key = ? AND draft_key = ? AND operation_key = ? AND sent = 1',
                whereArgs: [piece.key, key.value, operation.value],
              );
              await t.update(
                'outbox_operation_attachments',
                {
                  'state': AttachmentState.received.name,
                  'receipt_row_id': rowId,
                },
                where: 'attachment_key = ? AND operation_key = ?',
                whereArgs: [piece.key, operation.value],
              );
            });
            // Receipt and exact row are durable before the private bytes go.
            await _cleanupReceived(key, operation);
          }
        }
      }
      if (!_changes.isClosed) _changes.add(key);
      _refreshAttachmentTimeline(scope);
    } catch (_) {
      // No history proof: retain the truthful uploaded/unverified state.
    }
  }

  void _refreshAttachmentTimeline(Draft scope) {
    if (scope.storedSessionId != null) {
      conversation?.refreshAttachments(
        TimelineKey(scope.connection, scope.profile, scope.storedSessionId!),
      );
    }
  }

  Future<void> _cleanupReceived(DraftKey key, OperationKey operation) async {
    final rows = await database.rawQuery(
      'SELECT a.attachment_key FROM outbox_attachments a '
      'JOIN outbox_operation_attachments s ON s.attachment_key = a.attachment_key AND s.operation_key = a.operation_key '
      'JOIN outbox_operations o ON o.operation_key = s.operation_key '
      'WHERE a.draft_key = ? AND o.draft_key = a.draft_key AND o.operation_key = ? '
      'AND o.state = ? AND o.user_row_id IS NOT NULL AND a.sent = 1 AND a.cleaned = 0 '
      'AND s.receipt_row_id = o.user_row_id '
      'AND s.reference IS NOT NULL AND NOT EXISTS (SELECT 1 FROM outbox_operation_attachments shared '
      'WHERE shared.operation_key = s.operation_key AND shared.attachment_key <> s.attachment_key AND shared.reference = s.reference) '
      'AND NOT EXISTS (SELECT 1 FROM outbox_operations other WHERE other.operation_key <> o.operation_key '
      'AND other.connection_key = o.connection_key AND other.profile_key = o.profile_key '
      'AND other.stored_session_id = o.stored_session_id AND other.user_row_id = o.user_row_id) '
      'AND a.state = ? AND s.state = ? '
      'AND a.connection_key = o.connection_key AND a.profile_key = o.profile_key '
      'AND a.stored_session_id = o.stored_session_id '
      'AND s.connection_key = o.connection_key AND s.profile_key = o.profile_key AND s.stored_session_id = o.stored_session_id',
      [
        key.value,
        operation.value,
        OperationState.accepted.name,
        AttachmentState.received.name,
        AttachmentState.received.name,
      ],
    );
    for (final row in rows) {
      try {
        await _attachmentFiles.remove(key, row['attachment_key'] as String);
        await database.update(
          'outbox_attachments',
          {'cleaned': 1},
          where: 'draft_key = ? AND attachment_key = ? AND operation_key = ? AND sent = 1',
          whereArgs: [key.value, row['attachment_key'], operation.value],
        );
      } catch (_) {
        /* durable received state allows an idempotent retry */
      }
    }
  }

  Future<void> _checkPendingReceipts(DraftKey key, String runtime) =>
      _receiptChecks[key] ??= _readPendingReceipts(key, runtime).whenComplete(
        () {
          _receiptChecks.remove(key);
        },
      );

  Future<void> _readPendingReceipts(DraftKey key, String runtime) async {
    try {
      final pending = await database.query(
        'outbox_operations',
        where: 'draft_key = ? AND state = ?',
        whereArgs: [key.value, OperationState.accepted.name],
      );
      for (final op in pending) {
        final operation = OperationKey(op['operation_key'] as String);
        await _cleanupReceived(key, operation);
        final local = await attachments(key);
        final snapshots = await database.query(
          'outbox_operation_attachments',
          where: 'operation_key = ?',
          whereArgs: [operation.value],
          orderBy: 'position',
        );
        final keys = snapshots.map((r) => r['attachment_key']).toSet();
        final pieces = local
            .where((a) => a.sent && keys.contains(a.key))
            .toList();
        if (!pieces.any(
          (a) =>
              !a.cleaned &&
              (a.state == AttachmentState.uploaded ||
                  a.state == AttachmentState.received),
        )) {
          continue;
        }
        final body = op['body'] as String;
        final prompt = [
          for (final row in snapshots) row['reference'] as String,
          if (body.trim().isNotEmpty) body,
        ].join('\n');
        await _confirmReceipts(
          key,
          operation,
          pieces,
          runtime,
          op['user_row_id'] as int?,
          prompt,
        );
      }
      if (conversation != null) {
        final scope = await draft(key);
        if (scope != null) _refreshAttachmentTimeline(scope);
      }
    } catch (_) {
      // Les preuves manquantes restent en attente, sans répétition d'envoi.
    }
  }

  Future<void> _commitAccepted(
    DraftKey key,
    OperationKey operation,
    int? userRowId, {
    int? clearRevision,
  }) => database.transaction((t) async {
    await t.update(
      'outbox_operations',
      {
        'state': OperationState.accepted.name,
        'user_row_id': userRowId,
        'updated_at': _now().toIso8601String(),
      },
      where: 'operation_key = ?',
      whereArgs: [operation.value],
    );
    await t.update(
      'outbox_attachments',
      {'sent': 1},
      where: 'draft_key = ? AND operation_key = ?',
      whereArgs: [key.value, operation.value],
    );
    // Seule la version envoyée est retirée ; une saisie plus récente reste.
    // Un rapprochement ne prouve pas l'envoi : le texte reste alors en place.
    if (clearRevision == null) return;
    await t.update(
      'outbox_drafts',
      {'body': ''},
      where: 'draft_key = ? AND revision = ?',
      whereArgs: [key.value, clearRevision],
    );
  });

  /// Reprise d'une session déjà connue (jamais de création) : lie le runtime à
  /// la projection et rend le travail en cours.
  @override
  Future<Resumed> resume(TimelineKey key) async {
    // Lue avant l'appel : une reconnexion pendant l'attente rend l'id périmé.
    final generation = gateway.socketGeneration;
    final resumed = HermesRpc.resumed(
      await gateway.call(
        'session.resume',
        HermesRpc.resumeParams(key.session, key.profile),
        timeout: timeout,
      ),
    ).at(generation);
    for (final draft in await _draftsOf(key)) {
      _runtime[draft] = (id: resumed.runtime, generation: generation);
      _storedIds[draft] = key.session;
      _timelineKeys[draft] = key;
      if (resumed.running) {
        _turns[draft] = generation;
      } else {
        _turns.remove(draft);
      }
      if (!_changes.isClosed) _changes.add(draft);
    }
    conversation?.bind(key, resumed.runtime, generation);
    return resumed;
  }

  Future<List<DraftKey>> _draftsOf(TimelineKey key) async => [
    for (final row in await database.query(
      'outbox_drafts',
      columns: ['draft_key'],
      where: 'connection_key = ? AND profile_key = ? AND stored_session_id = ?',
      whereArgs: [key.connection.value, key.profile.value, key.session],
    ))
      DraftKey(row['draft_key'] as String),
  ];

  Future<List<Map<String, Object?>>> _unknownOperations(
    TimelineKey key, {
    bool marked = false,
  }) => database.rawQuery(
    'SELECT o.operation_key, o.draft_key, o.revision, o.row_watermark '
    'FROM outbox_operations o JOIN outbox_drafts d '
    'ON d.draft_key = o.draft_key '
    'WHERE o.state = ? AND d.connection_key = ? AND d.profile_key = ? '
    'AND d.stored_session_id = ? '
    '${marked ? 'AND o.row_watermark IS NOT NULL ' : ''}'
    'ORDER BY o.created_at, o.rowid',
    [
      OperationState.unknown.name,
      key.connection.value,
      key.profile.value,
      key.session,
    ],
  );

  /// Sans repère, une opération reste affichée « incertaine » sans forcer de snapshot.
  @override
  Future<bool> hasUnknown(TimelineKey key) async =>
      (await _unknownOperations(key, marked: true)).isNotEmpty;

  /// Une opération `unknown` devient `accepted` seulement si le rapprochement
  /// est sans ambiguïté : elle est la seule incertaine de la session et une
  /// seule ligne utilisateur libre dépasse son repère. `failed` (renvoi
  /// manuel possible) si rien n'est arrivé ni en cours. Sinon elle reste
  /// `unknown`. Jamais de renvoi, de comparaison de texte, ni d'effacement du
  /// brouillon (seule une acceptation directe le retire).
  @override
  Future<void> reconcile(
    TimelineKey key,
    Resumed state,
    List<int> userRows,
  ) async {
    for (final draft in await _draftsOf(key)) {
      await _checkPendingReceipts(draft, state.runtime);
    }
    final ops = await _unknownOperations(key);
    if (ops.length != 1) return;
    final op = ops.single;
    try {
      final watermark = op['row_watermark'] as int?;
      if (watermark == null) return;
      final operation = OperationKey(op['operation_key'] as String);
      final draft = DraftKey(op['draft_key'] as String);
      final taken = {
        for (final row in await database.rawQuery(
          'SELECT o.user_row_id FROM outbox_operations o JOIN outbox_drafts d '
          'ON d.draft_key = o.draft_key WHERE o.operation_key <> ? '
          'AND o.user_row_id IS NOT NULL AND d.connection_key = ? '
          'AND d.profile_key = ? AND d.stored_session_id = ?',
          [
            operation.value,
            key.connection.value,
            key.profile.value,
            key.session,
          ],
        ))
          row['user_row_id'] as int,
      };
      final fresh = userRows
          .where((r) => r > watermark && !taken.contains(r))
          .toList();
      if (fresh.length == 1) {
        await _commitAccepted(draft, operation, fresh.single);
        await _checkPendingReceipts(draft, state.runtime);
        _set(draft, const SendStatus(state: OperationState.accepted));
      } else if (fresh.isEmpty &&
          !state.running &&
          !state.inflight &&
          !state.queued) {
        await _finish(
          draft,
          operation,
          OperationState.failed,
          'send.not_received',
          true,
        );
      }
    } catch (_) {
      /* l'opération reste incertaine */
    }
  }

  @override
  Future<void> dispose() async {
    await _events?.cancel();
    await Future.wait(_receiptChecks.values);
    await Future.wait(_stopping.values);
    await Future.wait(_writes.values.map((w) => w.catchError((_) {})));
    await Future.wait(
      _attachmentWrites.values.map((w) => w.catchError((_) {})),
    );
    await _changes.close();
  }

  static Draft _draft(Map<String, Object?> row) => Draft(
    key: DraftKey(row['draft_key'] as String),
    connection: ConnectionKey(row['connection_key'] as String),
    profile: ProfileKey(row['profile_key'] as String),
    body: row['body'] as String,
    revision: row['revision'] as int,
    storedSessionId: row['stored_session_id'] as String?,
  );
}
