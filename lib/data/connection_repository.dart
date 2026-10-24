import 'dart:async';
import 'dart:convert';

import '../models/app_error.dart';
import '../models/connection.dart';
import '../models/connection_gateway.dart';
import '../models/profile.dart';
import 'hermes_adapter.dart';
import 'storage/connection_store.dart';
import 'storage/secret_store.dart';

typedef RetryDelay = Future<void> Function(Duration duration);

/// Seul auteur des snapshots et de l'unique socket. Les mutations sont sérialisées.
class ConnectionRepository implements ConnectionGateway {
  ConnectionRepository({
    required this.adapter,
    required this.store,
    required this.secrets,
    RetryDelay? delay,
    DateTime Function()? now,
    this.closeStorage,
  }) : _delay = delay ?? Future<void>.delayed,
       _now = now ?? (() => DateTime.now().toUtc());
  final HermesAdapter adapter;
  final ConnectionStore store;
  final SecretStore secrets;
  final RetryDelay _delay;
  final DateTime Function() _now;
  Timer? _capabilitiesDeadline;
  Future<void> _closingSocket = Future.value();
  final Future<void> Function()? closeStorage;
  final _changes = StreamController<ConnectionSnapshot>.broadcast(sync: true);
  final _events = StreamController<GatewayEvent>.broadcast(sync: true);
  final _calls = <String, Completer<Map<String, dynamic>>>{};
  int _rpcSeq = 0;
  int _generation = 0;
  String? _replayEpoch;
  ConnectionSnapshot _snapshot = ConnectionSnapshot(
    capabilities: _documentaryCapabilities,
  );
  Future<void> _pending = Future.value();
  GatewaySocket? _socket;
  StreamSubscription<Object?>? _subscription;
  bool _disposed = false;
  int _epoch = 0;
  int _attempts = 0;
  bool _retryScheduled = false;
  DateTime? _connectedAt;

  static const _documentaryCapabilities = [
    Capability('profiles', CapabilityState.unverified, required: true),
    Capability('websocket', CapabilityState.unverified, required: true),
    Capability('replay_epoch', CapabilityState.unverified, required: true),
    Capability('conversation', CapabilityState.unverified, required: true),
    Capability('change_events', CapabilityState.unverified),
    Capability('heartbeat', CapabilityState.unverified),
    Capability('per_session_exclusive_submit', CapabilityState.unverified),
    Capability('session.events.since', CapabilityState.unverified),
    Capability('session.create.idempotency_key', CapabilityState.unverified),
    Capability('file.attach', CapabilityState.unverified),
    Capability('session.interrupt', CapabilityState.unverified),
  ];
  @override
  ConnectionSnapshot get snapshot => _snapshot;
  @override
  Stream<ConnectionSnapshot> get snapshots => _changes.stream;
  @override
  Stream<GatewayEvent> get events => _events.stream;
  @override
  int get socketGeneration => _generation;
  @override
  String? get replayEpoch => _replayEpoch;

  @override
  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = rpcTimeout,
  }) async {
    final socket = _socket;
    if (socket == null || _snapshot.link != LinkState.connected) {
      throw const AppError('transport.offline', retryable: true);
    }
    final id = 'r${++_rpcSeq}';
    final done = Completer<Map<String, dynamic>>();
    _calls[id] = done;
    try {
      socket.send({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      });
    } catch (_) {
      // Écriture peut-être partielle : on ne sait pas si Hermes a reçu la trame.
      _calls.remove(id);
      throw const AppError('rpc.uncertain');
    }
    try {
      return await done.future.timeout(timeout);
    } on TimeoutException {
      throw const AppError('rpc.uncertain');
    } finally {
      _calls.remove(id);
    }
  }
  void _emit(ConnectionSnapshot value) {
    if (_disposed) return;
    _snapshot = value;
    _changes.add(value);
  }

  Future<void> _run(Future<void> Function() operation) {
    final next = _pending.then((_) async {
      if (_disposed) return;
      try {
        await operation();
      } on AppError catch (error) {
        _emit(_snapshot.copyWith(error: error, busy: false));
      } catch (_) {
        _emit(
          _snapshot.copyWith(
            error: const AppError('storage.unavailable', retryable: true),
            busy: false,
          ),
        );
      }
    });
    _pending = next;
    return next;
  }

  void _capability(String name, CapabilityState state) {
    _emit(
      _snapshot.copyWith(
        capabilities: [
          for (final capability in _snapshot.capabilities)
            capability.name == name
                ? Capability(name, state, required: capability.required)
                : capability,
        ],
      ),
    );
  }

  @override
  Future<void> restore() => _run(() async {
    final connection = await store.read();
    if (connection == null) return;
    _emit(
      ConnectionSnapshot(
        connection: connection,
        capabilities: _documentaryCapabilities,
      ),
    );
    await _connect();
  });

  @override
  Future<void> confirmOrigin(Uri origin) {
    // Validation avant toute mise en file ou écriture.
    final validated = parseOrigin(origin.toString());
    return _run(() async {
      final previous = _snapshot.connection;
      if (previous?.origin == validated) return;
      _epoch++;
      _attempts = 0;
      _retryScheduled = false;
      await _closeSocket();
      _emit(
        _snapshot.copyWith(
          link: LinkState.offline,
          authenticated: false,
          busy: false,
          capabilities: _documentaryCapabilities,
        ),
      );
      if (previous != null) await secrets.clear(previous.key);
      final connection = Connection(
        key: previous?.key ?? ConnectionKey.create(),
        origin: validated,
      );
      await store.save(connection);
      _emit(
        ConnectionSnapshot(
          connection: connection,
          capabilities: _documentaryCapabilities,
        ),
      );
    });
  }

  @override
  Future<void> authenticate(String password) => _run(() async {
    _epoch++;
    _retryScheduled = false;
    _attempts = 0;
    await _closeSocket();
    _emit(
      _snapshot.copyWith(
        authenticated: false,
        link: LinkState.offline,
        clearError: true,
        capabilities: _documentaryCapabilities,
      ),
    );
    final connection = _snapshot.connection;
    if (connection == null || password.isEmpty) {
      throw const AppError('auth.password_required');
    }
    _emit(_snapshot.copyWith(busy: true, clearError: true));
    final tokens = await adapter.login(connection.origin, password);
    await secrets.write(connection.key, SecretUsage.password, password);
    await _saveTokens(tokens);
    await _connect(access: tokens.access);
  });
  Future<void> _saveTokens(AuthTokens tokens) async {
    final key = _snapshot.connection!.key;
    await secrets.write(key, SecretUsage.accessToken, tokens.access);
    if (tokens.refresh != null) {
      await secrets.write(key, SecretUsage.refreshToken, tokens.refresh!);
    } else {
      await secrets.delete(key, SecretUsage.refreshToken);
    }
  }

  Future<String> _renew() async {
    final connection = _snapshot.connection!;
    final refresh = await secrets.read(
      connection.key,
      SecretUsage.refreshToken,
    );
    if (refresh != null) {
      try {
        final tokens = await adapter.refresh(connection.origin, refresh);
        await _saveTokens(tokens);
        return tokens.access;
      } on AppError catch (error) {
        if (error.code != 'auth.refused' &&
            error.code != 'contract.method_missing') {
          rethrow;
        }
      }
    }
    final password = await secrets.read(connection.key, SecretUsage.password);
    if (password == null) throw const AppError('auth.password_required');
    final tokens = await adapter.login(connection.origin, password);
    await _saveTokens(tokens);
    return tokens.access;
  }

  Future<T> _authorized<T>(Future<T> Function(String) operation) async {
    final key = _snapshot.connection!.key;
    final access =
        await secrets.read(key, SecretUsage.accessToken) ?? await _renew();
    try {
      return await operation(access);
    } on AppError catch (error) {
      if (error.code != 'auth.refused') rethrow;
      return operation(await _renew());
    }
  }

  Future<void> _connect({String? access}) async {
    if (_snapshot.connection == null) return;
    _emit(
      _snapshot.copyWith(
        busy: true,
        link: LinkState.resyncing,
        clearError: true,
        capabilities: _documentaryCapabilities,
      ),
    );
    await _closeSocket();
    try {
      final bearer = access ?? await _renew();
      _emit(_snapshot.copyWith(authenticated: true));
      await _loadProfiles();
      if (!_snapshot.authenticated) {
        _emit(_snapshot.copyWith(busy: false));
        return;
      }
      await _openSocket(bearer);
      if (_socket != null && _snapshot.link == LinkState.connected) {
        _connectedAt = _now();
      }
      _emit(_snapshot.copyWith(busy: false));
    } on AppError catch (error) {
      if (error.code == 'contract.method_missing') {
        _capability('websocket', CapabilityState.absent);
      }
      _emit(
        _snapshot.copyWith(
          busy: false,
          link: LinkState.offline,
          error: error,
          authenticated: error.code.startsWith('auth.') ? false : null,
        ),
      );
      if (error.retryable) _scheduleReconnect();
    }
  }

  Future<void> _openSocket(String bearer) async {
    final origin = _snapshot.connection!.origin;
    GatewaySocket socket;
    try {
      socket = await adapter.socket(origin, bearer);
    } on AppError catch (error) {
      if (error.code != 'auth.refused') rethrow;
      socket = await adapter.socket(origin, await _renew());
    }
    _socket = socket;
    final generation = ++_generation;
    final epoch = _epoch;
    final ready = Completer<void>();
    // Propre à cette socket : change à chaque redémarrage du processus Hermes.
    String? replayEpoch;
    _subscription = socket.messages.listen(
      (raw) {
        if (_disposed || _epoch != epoch || !identical(_socket, socket)) return;
        try {
          final message = raw is String ? jsonDecode(raw) : raw;
          if (message is! Map) return;
          final params = message['params'];
          if (message['method'] == 'event' &&
              params is Map &&
              params['type'] == 'gateway.ready') {
            final payload = params['payload'];
            if (payload is! Map) throw const FormatException();
            final epochValue = payload['replay_epoch'];
            replayEpoch = epochValue is String ? epochValue : null;
            _replayEpoch = replayEpoch;
            _capability('websocket', CapabilityState.present);
            _capability(
              'conversation',
              HermesRpc.conversationSupported(payload)
                  ? CapabilityState.present
                  : CapabilityState.absent,
            );
            for (final name in ['change_events', 'heartbeat', 'replay_epoch']) {
              final value = payload[name];
              _capability(
                name,
                (name == 'replay_epoch'
                        ? value is String && value.isNotEmpty
                        : value == true)
                    ? CapabilityState.present
                    : CapabilityState.absent,
              );
            }
            _emit(_snapshot.copyWith(link: LinkState.connected));
            _capabilitiesDeadline?.cancel();
            _capabilitiesDeadline = Timer(networkTimeout, () {
              if (_disposed || epoch != _epoch || !identical(_socket, socket)) {
                return;
              }
              _lostSocket(
                epoch,
                socket,
                error: const AppError(
                  'contract.capabilities_timeout',
                  retryable: true,
                ),
              );
            });
            socket.send({
              'jsonrpc': '2.0',
              'id': 'capabilities',
              'method': 'gateway.capabilities',
              'params': <String, dynamic>{},
            });
            if (!ready.isCompleted) ready.complete();
          } else if (message['method'] == 'event' &&
              params is Map &&
              params['session_id'] is String &&
              params['type'] is String) {
            final payload = params['payload'];
            final seq = params['seq'];
            _events.add(
              GatewayEvent(
                sessionId: params['session_id'] as String,
                type: params['type'] as String,
                payload: payload is Map
                    ? Map<String, dynamic>.from(payload)
                    : const {},
                seq: seq is int ? seq : null,
                generation: generation,
                replayEpoch: replayEpoch,
              ),
            );
          } else if (message['id'] is String &&
              _calls.containsKey(message['id'])) {
            final done = _calls.remove(message['id'])!;
            final result = message['result'];
            final error = message['error'];
            if (error is Map) {
              final code = error['code'];
              done.completeError(RpcError(code is int ? code : -1));
            } else if (result is Map) {
              done.complete(Map<String, dynamic>.from(result));
            } else {
              done.completeError(const AppError('rpc.uncertain'));
            }
          } else if (message['id'] == 'capabilities') {
            _capabilitiesDeadline?.cancel();
            _capabilitiesDeadline = null;
            final result = message['result'];
            final error = message['error'];
            if (error is Map) {
              if (error['code'] == -32601) {
                _capability(
                  'per_session_exclusive_submit',
                  CapabilityState.absent,
                );
                _emit(
                  _snapshot.copyWith(
                    error: const AppError('contract.method_missing'),
                  ),
                );
              } else if (error['code'] == 5035) {
                _lostSocket(epoch, socket);
              } else {
                _emit(
                  _snapshot.copyWith(
                    error: const AppError('contract.rpc_failed'),
                  ),
                );
              }
              return;
            }
            if (result is! Map ||
                result['per_session_exclusive_submit'] is! bool) {
              _capability(
                'per_session_exclusive_submit',
                CapabilityState.unverified,
              );
              _emit(
                _snapshot.copyWith(
                  error: const AppError('contract.invalid_response'),
                ),
              );
              return;
            }
            _capability(
              'per_session_exclusive_submit',
              result['per_session_exclusive_submit'] == true
                  ? CapabilityState.present
                  : CapabilityState.absent,
            );
          }
        } catch (_) {
          _emit(
            _snapshot.copyWith(
              error: const AppError('contract.invalid_response'),
            ),
          );
        }
      },
      onError: (Object error) {
        if (!ready.isCompleted) {
          ready.completeError(
            const AppError('transport.websocket', retryable: true),
          );
        }
        _lostSocket(epoch, socket);
      },
      onDone: () {
        if (!ready.isCompleted) {
          ready.completeError(
            const AppError('transport.websocket', retryable: true),
          );
        }
        _lostSocket(epoch, socket);
      },
    );
    try {
      await ready.future.timeout(networkTimeout);
    } catch (_) {
      await _closeSocket();
      throw const AppError('transport.websocket', retryable: true);
    }
  }

  void _lostSocket(int epoch, GatewaySocket socket, {AppError? error}) {
    if (_disposed || epoch != _epoch || !identical(socket, _socket)) return;
    // Retirer l'identité immédiatement empêche onError/onDone de compter deux pertes.
    unawaited(_closeSocket());
    final connectedAt = _connectedAt;
    if (connectedAt != null &&
        _now().difference(connectedAt) >= const Duration(seconds: 30)) {
      _attempts = 0;
    }
    _connectedAt = null;
    _emit(
      _snapshot.copyWith(
        link: LinkState.resyncing,
        error: error ?? const AppError('transport.websocket', retryable: true),
      ),
    );
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _retryScheduled) return;
    if (_attempts >= 3) {
      _emit(_snapshot.copyWith(link: LinkState.offline));
      return;
    }
    _retryScheduled = true;
    final epoch = _epoch;
    final wait = Duration(seconds: 1 << _attempts++);
    unawaited(
      _delay(wait).then(
        (_) => _run(() async {
          if (epoch != _epoch) return;
          _retryScheduled = false;
          await _connect();
        }),
      ),
    );
  }

  Future<void> _closeSocket() {
    // Trames déjà écrites : sans la socket, plus aucune réponse n'arrivera.
    final lost = _calls.values.toList();
    _calls.clear();
    for (final call in lost) {
      call.completeError(const AppError('rpc.uncertain'));
    }
    _capabilitiesDeadline?.cancel();
    _capabilitiesDeadline = null;
    final socket = _socket;
    _socket = null;
    _replayEpoch = null;
    final subscription = _subscription;
    _subscription = null;
    final previousClosing = _closingSocket;
    _closingSocket = () async {
      await previousClosing;
      await subscription?.cancel();
      if (socket != null) {
        try {
          await socket.close().timeout(networkTimeout);
        } catch (_) {
          /* fermeture locale */
        }
      }
    }();
    return _closingSocket;
  }

  @override
  Future<void> reconnect() => _run(() async {
    _epoch++;
    _retryScheduled = false;
    _attempts = 0;
    await _connect();
  });
  @override
  Future<void> refreshProfiles() => _run(() async {
    if (_snapshot.connection != null) await _loadProfiles();
  });
  Future<void> _loadProfiles() async {
    _emit(
      _snapshot.copyWith(
        clearError: true,
        profilesState: _snapshot.profiles.isEmpty
            ? ProfilesState.loading
            : ProfilesState.refreshing,
      ),
    );
    try {
      final profiles = await _authorized(
        (bearer) => adapter.profiles(_snapshot.connection!.origin, bearer),
      );
      final choice = _snapshot.connection!.selectedProfile;
      ProfileKey? selected;
      if (choice != null && profiles.any((p) => p.key == choice)) {
        selected = choice;
      } else {
        final defaults = profiles.where((p) => p.isDefault).toList();
        if (defaults.length == 1) selected = defaults.single.key;
      }
      _capability('profiles', CapabilityState.present);
      _emit(
        _snapshot.copyWith(
          profiles: profiles,
          profilesState: profiles.isEmpty
              ? ProfilesState.empty
              : ProfilesState.ready,
          selectedProfile: selected,
          clearSelection: selected == null,
        ),
      );
    } on AppError catch (error) {
      if (error.code.startsWith('auth.')) {
        _epoch++;
        _retryScheduled = false;
        await _closeSocket();
        _emit(
          _snapshot.copyWith(authenticated: false, link: LinkState.offline),
        );
      }
      if (error.code == 'contract.method_missing') {
        _capability('profiles', CapabilityState.absent);
      }
      _emit(
        _snapshot.copyWith(error: error, profilesState: ProfilesState.error),
      );
    }
  }

  @override
  Future<void> selectProfile(ProfileKey key) => _run(() async {
    if (!_snapshot.profiles.any((profile) => profile.key == key)) return;
    final current = _snapshot.connection!;
    final updated = Connection(
      key: current.key,
      origin: current.origin,
      selectedProfile: key,
    );
    await store.save(updated);
    _emit(_snapshot.copyWith(connection: updated, selectedProfile: key));
  });
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    await _pending;
    await _closeSocket();
    adapter.transport.close();
    await closeStorage?.call();
    await _changes.close();
    await _events.close();
  }
}
