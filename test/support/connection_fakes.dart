import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hermes_mobile/data/connection_repository.dart';
import 'package:hermes_mobile/data/hermes_adapter.dart';
import 'package:hermes_mobile/data/storage/connection_store.dart';
import 'package:hermes_mobile/data/storage/secret_store.dart';
import 'package:hermes_mobile/models/connection.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('contracts/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;

class MemoryConnections implements ConnectionStore {
  Connection? value;
  int writes = 0;
  bool failSave = false;
  Completer<Connection?>? delayedRead;
  @override
  Future<Connection?> read() async =>
      delayedRead == null ? value : await delayedRead!.future;
  @override
  Future<void> save(Connection connection) async {
    if (failSave) throw StateError('synthetic storage failure');
    value = connection;
    writes++;
  }
}

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  final operations = <String>[];
  bool failClear = false;
  @override
  Future<String?> read(ConnectionKey key, SecretUsage usage) async =>
      values['${key.value}/${usage.name}'];
  @override
  Future<void> write(ConnectionKey key, SecretUsage usage, String value) async {
    values['${key.value}/${usage.name}'] = value;
  }

  @override
  Future<void> delete(ConnectionKey key, SecretUsage usage) async {
    values.remove('${key.value}/${usage.name}');
  }

  @override
  Future<void> clear(ConnectionKey key) async {
    if (failClear) throw StateError('synthetic secret failure');
    operations.add('clear');
    values.removeWhere((name, _) => name.startsWith('${key.value}/'));
  }
}

class FakeSocket implements GatewaySocket {
  FakeSocket(this.owner) {
    owner.active++;
    if (owner.active > owner.maximumActive) owner.maximumActive = owner.active;
    controller = StreamController<Object?>(
      onListen: () {
        scheduleMicrotask(() {
          if (!closed) controller.add(owner.ready);
        });
      },
    );
  }
  final FakeTransport owner;
  late final StreamController<Object?> controller;
  bool closed = false;
  @override
  Stream<Object?> get messages => controller.stream;
  @override
  void send(Map<String, dynamic> message) {
    if (owner.silentRpc) return;
    controller.add({
      'jsonrpc': '2.0',
      'id': message['id'],
      if (owner.missingRpc || owner.rpcError != null)
        'error': {'code': owner.rpcError ?? -32601, 'message': 'SYNTHETIC'},
      if (!owner.missingRpc && owner.rpcError == null)
        'result': owner.rpcResult,
    });
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    owner.active--;
    unawaited(controller.close());
  }

  Future<void> drop() => close();
}

class FakeTransport implements HermesTransport {
  final requests =
      <
        ({Uri uri, String method, Map<String, dynamic>? body, String? bearer})
      >[];
  Map<String, dynamic> profiles = fixture('profiles');
  Map<String, dynamic> ready = fixture('gateway-ready');
  int loginStatus = 200;
  List<String>? loginCookies;
  int refreshStatus = 200;
  int profilesStatus = 200;
  int ticketStatus = 200;
  bool unreachable = false;
  bool missingRpc = false;
  bool silentRpc = false;
  int? rpcError;
  Map<String, dynamic> rpcResult = {'per_session_exclusive_submit': true};
  int active = 0;
  int maximumActive = 0;
  int ticketCount = 0;
  final sockets = <FakeSocket>[];
  void Function()? beforeRequest;
  @override
  Future<TransportResponse> request(
    Uri uri, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? bearer,
  }) async {
    beforeRequest?.call();
    requests.add((uri: uri, method: method, body: body, bearer: bearer));
    if (unreachable) {
      throw const SocketException('SYNTHETIC_PASSWORD_MUST_NOT_ESCAPE');
    }
    switch (uri.path) {
      case '/auth/password-login':
        final login = fixture('login');
        return TransportResponse(
          loginStatus,
          Map<String, dynamic>.from(login['body'] as Map),
          cookies: loginCookies ?? List<String>.from(login['cookies'] as List),
        );
      case '/auth/native/refresh':
        return TransportResponse(refreshStatus, {
          'access_token': '<SYNTHETIC_ACCESS>',
          'refresh_token': '<SYNTHETIC_REFRESH>',
        });
      case '/api/profiles':
        return TransportResponse(profilesStatus, profiles);
      case '/api/auth/ws-ticket':
        ticketCount++;
        return TransportResponse(ticketStatus, {
          'ticket': '<SYNTHETIC_TICKET_$ticketCount>',
          'ttl_seconds': 30,
        });
      default:
        throw StateError('Route inattendue');
    }
  }

  @override
  Future<GatewaySocket> openSocket(Uri origin, String ticket) async {
    final socket = FakeSocket(this);
    sockets.add(socket);
    return socket;
  }

  @override
  void close() {}
}

class Harness {
  Harness() {
    repository = ConnectionRepository(
      adapter: HermesAdapter(transport),
      store: store,
      secrets: secrets,
      now: () => DateTime.utc(2026, 10, 21),
      delay: (duration) {
        final pending = Completer<void>();
        delays.add(pending);
        return pending.future;
      },
    );
  }
  final transport = FakeTransport();
  final store = MemoryConnections();
  final secrets = MemorySecrets();
  final delays = <Completer<void>>[];
  late final ConnectionRepository repository;
  Future<void> connect() async {
    await repository.confirmOrigin(
      parseOrigin('http://desktop.example.ts.net:9119'),
    );
    await repository.authenticate('<SYNTHETIC_PASSWORD>');
  }
}
