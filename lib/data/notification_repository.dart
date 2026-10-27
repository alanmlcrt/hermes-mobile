import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../models/connection.dart';
import '../models/draft.dart';
import '../models/notifications.dart';
import 'storage/secret_store.dart';

/// Associations conservées pour la résolution d'ouverture (5.4).
/// L'outbox crée et attache ; la reprise ne soumet jamais de travail.
class NotificationRepository implements NotificationGateway {
  NotificationRepository(
    this.database,
    this.secrets,
    this.device, {
    http.Client? client,
  }) : _http = client ?? http.Client() {
    _rotations = device.rotations.listen((_) {
      _rotationPending = true;
      _resumeAfterRow = 0;
      unawaited(resume());
    });
  }
  final Database database;
  final SecretStore secrets;
  @override
  final NotificationClient device;
  final http.Client _http;
  late final StreamSubscription<String> _rotations;
  Future<void>? _resuming;
  bool _rotationPending = false;
  bool _batchPending = false;
  bool _disposed = false;
  int _resumeAfterRow = 0;
  Timer? _resumeAgain;
  final _tracking = <Future<void>>{};
  Future<T> _track<T>(Future<T> Function() work) {
    final future = work();
    final done = future.then<void>((_) {}, onError: (Object _) {});
    _tracking.add(done);
    done.whenComplete(() => _tracking.remove(done));
    return future;
  }

  @override
  Future<ObserverSettings?> settings(ConnectionKey key) async {
    final rows = await database.query(
      'notification_settings',
      where: 'connection_key = ?',
      whereArgs: [key.value],
    );
    if (rows.isEmpty) return null;
    return ObserverSettings(
      key,
      Uri.parse(rows.single['origin'] as String),
      rows.single['enabled'] == 1,
    );
  }

  @override
  Future<void> configure(ConnectionKey key, Uri origin, String bearer) async {
    if (origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path != '' && origin.path != '/') ||
        bearer.trim().isEmpty) {
      throw const FormatException('notification.configuration');
    }
    final old = await settings(key);
    if (old != null) {
      await disable(key);
      final pending = await database.query(
        'notification_subscriptions',
        where: 'connection_key = ? AND state = ?',
        whereArgs: [key.value, 'revokePending'],
      );
      if (pending.isNotEmpty && old.origin != origin) {
        throw const FormatException('notification.revocation_pending');
      }
    }
    await secrets.write(key, SecretUsage.observerBearer, bearer.trim());
    await database.insert('notification_settings', {
      'connection_key': key.value,
      'origin': origin.toString(),
      'enabled': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (old != null && old.origin == origin) await resume();
  }

  @override
  Future<bool> enable(ConnectionKey key) async {
    if (await settings(key) == null) return false;
    final token = await device
        .token(requestPermission: true)
        .timeout(const Duration(seconds: 3), onTimeout: () => null);
    if (token == null) return false;
    await database.update(
      'notification_settings',
      {'enabled': 1},
      where: 'connection_key = ?',
      whereArgs: [key.value],
    );
    await resume();
    return true;
  }

  @override
  Future<void> disable(ConnectionKey key) async {
    await database.update(
      'notification_settings',
      {'enabled': 0},
      where: 'connection_key = ?',
      whereArgs: [key.value],
    );
    await Future.wait(_tracking.toList());
    await _resuming;
    await database.update(
      'notification_subscriptions',
      {'state': 'revokePending'},
      where: 'connection_key = ? AND state <> ?',
      whereArgs: [key.value, 'revoked'],
    );
    await resume();
  }

  Future<String?> prepare(
    OperationKey operation,
    Draft draft, {
    required String session,
  }) => _track(() => _prepare(operation, draft, session: session));

  Future<String?> _prepare(
    OperationKey operation,
    Draft draft, {
    required String session,
  }) async {
    final deadline = Stopwatch()..start();
    final config = await settings(draft.connection);
    if (config == null || !config.enabled) return null;
    final random = Random.secure();
    final id = base64Url
        .encode(List.generate(24, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    await database.insert('notification_subscriptions', {
      'subscription_id': id,
      'operation_key': operation.value,
      'connection_key': draft.connection.value,
      'profile_key': draft.profile.value,
      'session_id': session,
      'stored_session_id': draft.storedSessionId,
      'state': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    final token = await device.token().timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );
    final ok =
        token != null &&
        deadline.elapsed < const Duration(seconds: 4) &&
        await _request(config, 'POST', '/v1/subscriptions', {
          'subscriptionId': id,
          'fcmToken': token,
        }, budget: const Duration(seconds: 4) - deadline.elapsed);
    await database.update(
      'notification_subscriptions',
      {'state': ok ? 'registered' : 'unfollowed'},
      where: 'subscription_id = ? AND state = ?',
      whereArgs: [id, 'pending'],
    );
    return id;
  }

  Future<void> submitting(OperationKey operation, String runtime) =>
      database.update(
        'notification_subscriptions',
        {'session_id': runtime},
        where: 'operation_key = ? AND execution_id IS NULL',
        whereArgs: [operation.value],
      );

  Future<String?> submittedSession(OperationKey operation) async {
    final rows = await database.query(
      'notification_subscriptions',
      columns: ['session_id'],
      where: 'operation_key = ?',
      whereArgs: [operation.value],
    );
    return rows.singleOrNull?['session_id'] as String?;
  }

  Future<void> attach(OperationKey operation, String session, int? row) =>
      _track(() => _attach(operation, session, row));

  Future<void> _attach(
    OperationKey operation,
    String session,
    int? row, {
    Duration budget = const Duration(seconds: 4),
    String? deviceToken,
  }) async {
    final deadline = Stopwatch()..start();
    final rows = await database.query(
      'notification_subscriptions',
      where: 'operation_key = ?',
      whereArgs: [operation.value],
    );
    if (rows.isEmpty) return;
    final sub = rows.single;
    if (sub['state'] == 'revoked' || sub['state'] == 'revokePending') return;
    final id = sub['subscription_id'] as String;
    final execution = row == null || session.isEmpty
        ? null
        : base64Url.encode(utf8.encode('$session:$row')).replaceAll('=', '');
    await database.update(
      'notification_subscriptions',
      {'session_id': session, 'execution_id': execution},
      where: 'subscription_id = ?',
      whereArgs: [id],
    );
    if (execution == null) {
      await _state(id, 'unfollowed');
      return;
    }
    final config = await settings(
      ConnectionKey(sub['connection_key'] as String),
    );
    if (config == null || !config.enabled) return;
    // Un register peut être repris, toujours avant l'attache.
    final token =
        deviceToken ??
        await device.token().timeout(
          budget < const Duration(seconds: 3)
              ? budget
              : const Duration(seconds: 3),
          onTimeout: () => null,
        );
    final registered =
        token != null &&
        deadline.elapsed < budget &&
        await _request(config, 'POST', '/v1/subscriptions', {
          'subscriptionId': id,
          'fcmToken': token,
        }, budget: budget - deadline.elapsed);
    final ok =
        registered &&
        deadline.elapsed < budget &&
        await _request(config, 'POST', '/v1/subscriptions/$id/attach', {
          'sessionId': session,
          'profile': sub['profile_key'],
          'executionId': execution,
        }, budget: budget - deadline.elapsed);
    await _state(id, ok ? 'attached' : 'unfollowed');
    if (ok) {
      await database.update(
        'outbox_operations',
        {'notification_unfollowed': 0},
        where: 'operation_key = ?',
        whereArgs: [operation.value],
      );
    }
  }

  Future<void> _state(String id, String state) => database.rawUpdate(
    'UPDATE notification_subscriptions SET state = ?, '
    'attached_at = CASE WHEN ? = ? THEN COALESCE(attached_at, ?) ELSE attached_at END '
    'WHERE subscription_id = ? AND state NOT IN (?, ?)',
    [
      state,
      state,
      'attached',
      DateTime.now().toUtc().toIso8601String(),
      id,
      'revoked',
      'revokePending',
    ],
  );

  Future<void> resume() =>
      _resuming ??= _resume().catchError((_) {}).whenComplete(() {
        _resuming = null;
        if ((_rotationPending || _batchPending) && !_disposed) {
          if (_rotationPending) _resumeAfterRow = 0;
          _resumeAgain?.cancel();
          _resumeAgain = Timer(
            const Duration(milliseconds: 50),
            () => unawaited(resume()),
          );
        }
      });
  Future<void> _resume() async {
    _rotationPending = false;
    _batchPending = false;
    final deadline = Stopwatch()..start();
    // Relire la permission même sans abonnement ; aucune demande interactive.
    final token = await device.token().timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 7))
        .toIso8601String();
    await database.update(
      'notification_subscriptions',
      {'state': 'expired'},
      where: 'COALESCE(attached_at, created_at) < ? AND state NOT IN (?, ?)',
      whereArgs: [cutoff, 'revoked', 'revokePending'],
    );
    final rows = await database.query(
      'notification_subscriptions',
      columns: ['rowid', '*'],
      where: 'state NOT IN (?, ?, ?) AND rowid > ?',
      whereArgs: ['revoked', 'expired', 'notified', _resumeAfterRow],
      orderBy: 'rowid',
      limit: 16,
    );
    if (rows.isEmpty) {
      _resumeAfterRow = 0;
      return;
    }
    var completedBatch = true;
    for (final sub in rows) {
      final remaining = const Duration(seconds: 8) - deadline.elapsed;
      if (remaining <= Duration.zero || _disposed) {
        completedBatch = false;
        break;
      }
      _resumeAfterRow = sub['rowid'] as int;
      final config = await settings(
        ConnectionKey(sub['connection_key'] as String),
      );
      if (config == null) continue;
      final id = sub['subscription_id'] as String;
      if (sub['state'] == 'revokePending') {
        if (await _request(
          config,
          'DELETE',
          '/v1/subscriptions/$id',
          null,
          budget: remaining < const Duration(seconds: 4)
              ? remaining
              : const Duration(seconds: 4),
        )) {
          await database.update(
            'notification_subscriptions',
            {'state': 'revoked'},
            where: 'subscription_id = ?',
            whereArgs: [id],
          );
        }
      } else if (config.enabled && token != null) {
        final op = OperationKey(sub['operation_key'] as String);
        final operations = await database.query(
          'outbox_operations',
          where: 'operation_key = ? AND state = ?',
          whereArgs: [op.value, 'accepted'],
        );
        if (operations.isNotEmpty && sub['session_id'] != null) {
          await _attach(
            op,
            sub['session_id'] as String,
            operations.single['user_row_id'] as int?,
            budget: remaining < const Duration(seconds: 4)
                ? remaining
                : const Duration(seconds: 4),
            deviceToken: token,
          );
        } else {
          {
            await _request(
              config,
              'POST',
              '/v1/subscriptions',
              {'subscriptionId': id, 'fcmToken': token},
              budget: remaining < const Duration(seconds: 4)
                  ? remaining
                  : const Duration(seconds: 4),
            );
          }
        }
      }
    }
    _batchPending = !completedBatch || rows.length == 16;
    if (!_batchPending) _resumeAfterRow = 0;
  }

  @override
  Future<String> health(ConnectionKey key) async {
    final config = await settings(key);
    if (config == null) return 'unconfigured';
    String state = 'unavailable';
    await _request(
      config,
      'GET',
      '/v1/health',
      null,
      health: (data) {
        if (data['state'] == 'ok' || data['state'] == 'degraded') {
          state = data['state'] as String;
        }
      },
    );
    return state;
  }

  Future<bool> _request(
    ObserverSettings config,
    String method,
    String path,
    Map<String, Object?>? body, {
    void Function(Map<String, dynamic>)? health,
    Duration budget = const Duration(seconds: 4),
  }) async {
    final clock = Stopwatch()..start();
    try {
      final bearer = await secrets
          .read(config.connection, SecretUsage.observerBearer)
          .timeout(budget);
      if (bearer == null) return false;
      for (var attempt = 0; attempt < (health == null ? 3 : 1); attempt++) {
        final remaining = budget - clock.elapsed;
        if (remaining <= Duration.zero) return false;
        final abort = Completer<void>();
        final timer = Timer(remaining, () {
          if (!abort.isCompleted) abort.complete();
        });
        final request = http.AbortableRequest(
          method,
          config.origin.resolve(path),
          abortTrigger: abort.future,
        );
        request.followRedirects = false;
        request.headers.addAll({
          'Authorization': 'Bearer $bearer',
          'Content-Type': 'application/json',
        });
        if (body != null) request.body = jsonEncode(body);
        int status;
        try {
          final response = await _http.send(request).timeout(remaining);
          status = response.statusCode;
          if (health != null && status == 200) {
            final bytes = await response.stream
                .fold<List<int>>(<int>[], (all, chunk) {
                  if (all.length + chunk.length > 16384) {
                    throw const FormatException('notification.health');
                  }
                  return all..addAll(chunk);
                })
                .timeout(
                  budget - clock.elapsed > Duration.zero
                      ? budget - clock.elapsed
                      : const Duration(milliseconds: 1),
                );
            if (bytes.length <= 16384) {
              health(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
            }
          } else {
            await response.stream.listen(null).cancel();
          }
          if ([200, 201, 202, 204].contains(status) ||
              (method == 'DELETE' && status == 404)) {
            return true;
          }
          if (![429, 500, 502, 503, 504].contains(status)) return false;
        } catch (_) {
          /* Reprise bornée, sans exposer la réponse du fournisseur. */
        } finally {
          timer.cancel();
          if (!abort.isCompleted) abort.complete();
        }
        if (attempt < 2) {
          final delay = Duration(
            milliseconds: (attempt == 0 ? 250 : 750) + Random().nextInt(100),
          );
          if (clock.elapsed + delay >= budget) return false;
          await Future<void>.delayed(delay);
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  Future<void> dispose() async {
    _disposed = true;
    _resumeAgain?.cancel();
    await _rotations.cancel();
    await Future.wait(_tracking.toList());
    await _resuming;
    _http.close();
    await device.dispose();
  }
}
