import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../models/app_error.dart';
import '../models/connection.dart';
import '../models/connection_gateway.dart';
import '../models/draft.dart';
import '../models/profile.dart';
import 'hermes_adapter.dart';

/// Seul auteur des brouillons et des opérations (`outbox_*`). Ne ferme pas la
/// base partagée.
class OutboxRepository implements OutboxGateway {
  OutboxRepository(
    this.database, {
    required this.gateway,
    DateTime Function()? now,
    this.timeout = rpcTimeout,
    this.onStep,
  }) : _now = now ?? (() => DateTime.now().toUtc()) {
    _events = gateway.events.listen(_onEvent);
  }
  final Database database;
  final ConnectionGateway gateway;
  final DateTime Function() _now;
  final Duration timeout;

  /// Observateur du pipeline nommé (tests, diagnostic) ; jamais de contenu.
  final void Function(String step)? onStep;
  final _writes = <DraftKey, Future<void>>{};
  final _recovered = <DraftKey>{};
  final _status = <DraftKey, SendStatus>{};
  final _runtime = <DraftKey, ({String id, int generation})>{};
  final _turns = <DraftKey, int>{};
  final _ensuring = <DraftKey, Future<String>>{};
  final _changes = StreamController<DraftKey>.broadcast(sync: true);
  StreamSubscription<GatewayEvent>? _events;

  @override
  Stream<DraftKey> get changes => _changes.stream;

  @override
  Future<Draft> openNewDraft(
    ConnectionKey connection,
    ProfileKey profile,
  ) async {
    // Un brouillon non vide garde son texte même s'il a déjà une session.
    Future<List<Map<String, Object?>>> reusable() => database.query(
      'outbox_drafts',
      where:
          'connection_key = ? AND profile_key = ? '
          "AND (stored_session_id IS NULL OR body <> '')",
      whereArgs: [connection.value, profile.value],
      orderBy: "(body <> '') DESC, updated_at DESC",
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
  Future<Draft?> draft(DraftKey key) async {
    await _recover(key);
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
    final turn =
        _turns[key] != null && _turns[key] == gateway.socketGeneration;
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
      } else {
        continue;
      }
      if (!_changes.isClosed) _changes.add(entry.key);
    }
  }

  /// Création ou reprise de la session, sérialisée par brouillon : deux appels
  /// concurrents partagent le même vol et une seule `session.create` part.
  Future<String> ensureSession(DraftKey key) => _ensuring[key] ??= _ensure(
    key,
  ).whenComplete(() {
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
    } else {
      final result = await g.call(
        'session.resume',
        HermesRpc.resumeParams(draft.storedSessionId!, draft.profile),
        timeout: timeout,
      );
      final resumed = HermesRpc.resumed(result);
      runtime = resumed.runtime;
      running = resumed.running;
    }
    _runtime[key] = (id: runtime, generation: generation);
    if (running) {
      _turns[key] = generation;
      if (!_changes.isClosed) _changes.add(key);
    }
    return runtime;
  }

  static String _idempotencyKey(Draft draft) =>
      '${draft.profile.value}/${draft.key.value}';

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
    try {
      // Les saisies en vol sont écrites avant de figer le texte envoyé.
      await (_writes[key] ?? Future.value()).catchError((_) {});
      final found = await this.draft(key);
      if (found == null || found.body.trim().isEmpty) {
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
    try {
      runtime = await ensureSession(key);
      onStep?.call('attachments'); // Epic 4
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
      await _persist(operation, OperationState.sending);
    } catch (error) {
      // Rien n'a été soumis : l'échec est certain, un renvoi manuel est permis.
      await _finish(key, operation, OperationState.failed, _code(error), true);
      return;
    }
    _set(key, const SendStatus(state: OperationState.sending));
    onStep?.call('submit');
    var recovered = false;
    while (true) {
      try {
        final result = await g.call(
          'prompt.submit',
          HermesRpc.submitParams(runtime, draft.body),
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
          await _accept(key, operation, draft, accepted.userRowId);
        }
        return;
      } on RpcError catch (error) {
        if (error.code == HermesRpc.runtimeLost && !recovered) {
          // Refus certain : un seul nouvel essai après reprise de la session.
          recovered = true;
          _runtime.remove(key);
          try {
            runtime = await ensureSession(key);
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
  }) => database.update(
    'outbox_operations',
    {
      'state': state.name,
      'error_code': errorCode,
      'user_row_id': userRowId,
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
    int? userRowId,
  ) async {
    try {
      await database.transaction((t) async {
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
        // Seule la version envoyée est retirée ; une saisie plus récente reste.
        await t.update(
          'outbox_drafts',
          {'body': ''},
          where: 'draft_key = ? AND revision = ?',
          whereArgs: [key.value, draft.revision],
        );
      });
    } catch (_) {
      /* acceptée côté serveur : l'écran l'indique même si la base échoue */
    }
    _set(key, const SendStatus(state: OperationState.accepted));
  }

  @override
  Future<void> dispose() async {
    await _events?.cancel();
    await Future.wait(_writes.values.map((w) => w.catchError((_) {})));
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
