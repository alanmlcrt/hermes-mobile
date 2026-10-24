import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hermes_mobile/data/connection_repository.dart';
import 'package:hermes_mobile/data/hermes_adapter.dart';
import 'package:hermes_mobile/data/storage/connection_store.dart';
import 'package:hermes_mobile/data/storage/secret_store.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/attachment.dart';
import 'package:hermes_mobile/models/history.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';

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

/// Réponse RPC scriptée : erreur JSON-RPC reçue.
class RpcFail {
  const RpcFail(this.code);
  final int code;
}

/// Réponse RPC scriptée : la socket tombe après réception de la trame.
class RpcDrop {
  const RpcDrop();
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
    owner.frames.add(message);
    if (message['method'] == owner.throwOnMethod) {
      throw StateError('synthetic write failure');
    }
    final script = owner.rpc;
    if (script != null && message['id'] != 'capabilities') {
      final outcome = script(
        message['method'] as String,
        Map<String, dynamic>.from(message['params'] as Map),
      );
      if (outcome is RpcDrop) {
        unawaited(close());
      } else if (outcome is RpcFail) {
        controller.add({
          'jsonrpc': '2.0',
          'id': message['id'],
          'error': {'code': outcome.code, 'message': 'SYNTHETIC'},
        });
      } else if (outcome is Map) {
        controller.add({
          'jsonrpc': '2.0',
          'id': message['id'],
          'result': outcome,
        });
      }
      return;
    }
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
  Map<String, dynamic> ready = fixture('gateway-ready-legacy');

  /// Trames écrites par l'app, dans l'ordre.
  final frames = <Map<String, dynamic>>[];

  /// Méthode dont l'écriture lève une erreur (trame peut-être partie).
  String? throwOnMethod;

  /// Script des appels hors `gateway.capabilities` : Map = résultat,
  /// [RpcFail] = erreur, [RpcDrop] = socket coupée, autre = silence.
  Object? Function(String method, Map<String, dynamic> params)? rpc;
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

class MemoryOutbox implements OutboxGateway {
  final pieces = <DraftKey, List<Attachment>>{};
  @override
  Future<List<AttachmentLimit>> attachmentLimits() async => const [];
  @override
  Future<List<Attachment>> attachments(DraftKey key) async =>
      pieces[key] ?? const [];
  @override
  Future<void> addAttachment(DraftKey key, PickedFile file) async {
    (pieces[key] ??= []).add(
      Attachment(
        key: 'piece-${pieces[key]?.length ?? 0}',
        name: file.name,
        mediaType: file.mediaType,
        bytes: file.data?.length ?? 0,
        localPath: file.path ?? 'synthetic',
      ),
    );
  }

  @override
  Future<void> removeAttachment(DraftKey key, String attachmentKey) async =>
      pieces[key]?.removeWhere((a) => a.key == attachmentKey);
  final drafts = <DraftKey, Draft>{};
  final statuses = <DraftKey, SendStatus>{};
  final sent = <DraftKey>[];
  final _changes = StreamController<DraftKey>.broadcast(sync: true);
  void setStatus(DraftKey key, SendStatus status) {
    statuses[key] = status;
    _changes.add(key);
  }

  @override
  Stream<DraftKey> get changes => _changes.stream;
  @override
  SendStatus status(DraftKey key) => statuses[key] ?? const SendStatus();
  @override
  Future<void> send(DraftKey key) async {
    if ((pieces[key] ?? const []).isNotEmpty) {
      setStatus(
        key,
        const SendStatus(
          state: OperationState.failed,
          errorCode: 'attachment.send_blocked',
        ),
      );
      return;
    }
    sent.add(key);
  }

  bool failSave = false;
  bool failOpen = false;
  bool failRead = false;
  @override
  Future<Draft> openNewDraft(
    ConnectionKey connection,
    ProfileKey profile,
  ) async {
    if (failOpen) throw StateError('synthetic storage failure');
    for (final d in drafts.values) {
      if (d.connection == connection &&
          d.profile == profile &&
          d.storedSessionId == null) {
        return d;
      }
    }
    final draft = Draft(
      key: DraftKey.create(),
      connection: connection,
      profile: profile,
      body: '',
    );
    return drafts[draft.key] = draft;
  }

  @override
  Future<Draft> openContinuation(
    ConnectionKey connection,
    ProfileKey profile,
    String storedSessionId,
  ) async {
    if (failOpen) throw StateError('synthetic storage failure');
    for (final d in drafts.values) {
      if (d.connection == connection &&
          d.profile == profile &&
          d.storedSessionId == storedSessionId) {
        return d;
      }
    }
    final draft = Draft(
      key: DraftKey.create(),
      connection: connection,
      profile: profile,
      body: '',
      storedSessionId: storedSessionId,
    );
    return drafts[draft.key] = draft;
  }

  @override
  Future<Draft?> draft(DraftKey key) async {
    if (failRead) throw StateError('synthetic storage failure');
    return drafts[key];
  }

  @override
  Future<void> reassignNewDraft(DraftKey key, ProfileKey profile) async {
    if (failSave) throw const AppError('storage.unavailable');
    final d = drafts[key];
    if (d == null) throw const AppError('draft.not_found');
    if (d.storedSessionId != null || d.profile == profile) return;
    Draft on(Draft x, ProfileKey p) => Draft(
      key: x.key,
      connection: x.connection,
      profile: p,
      body: x.body,
      revision: x.revision,
      storedSessionId: x.storedSessionId,
    );
    final target = drafts.values
        .where(
          (x) =>
              x.connection == d.connection &&
              x.profile == profile &&
              x.storedSessionId == null,
        )
        .firstOrNull;
    if (target != null) {
      if (status(target.key).busy || status(key).busy) {
        throw const AppError('draft.profile_busy');
      }
      if (target.body.isEmpty && (pieces[target.key] ?? const []).isEmpty) {
        drafts.remove(target.key);
      } else {
        drafts[target.key] = on(target, d.profile);
      }
    }
    drafts[key] = on(d, profile);
  }

  @override
  Future<void> saveText(DraftKey key, String body) async {
    if (failSave) throw StateError('synthetic storage failure');
    final d = drafts[key]!;
    drafts[key] = Draft(
      key: key,
      connection: d.connection,
      profile: d.profile,
      body: body,
      revision: d.revision + 1,
      storedSessionId: d.storedSessionId,
    );
  }

  @override
  Future<void> dispose() async {}
}

class MemoryConversation implements ConversationGateway {
  final projections = <TimelineKey, TimelineProjection>{};
  final loaded = <TimelineKey>[];
  final _changes = StreamController<TimelineKey>.broadcast(sync: true);
  void set(TimelineKey key, TimelineProjection projection) {
    projections[key] = projection;
    _changes.add(key);
  }

  @override
  Stream<TimelineKey> get changes => _changes.stream;
  @override
  Future<TimelineProjection> load(TimelineKey key) async {
    loaded.add(key);
    return projection(key);
  }

  @override
  TimelineProjection projection(TimelineKey key) =>
      projections[key] ?? const TimelineProjection();
  final resyncingKeys = <TimelineKey>{};
  @override
  bool resyncing(TimelineKey key) => resyncingKeys.contains(key);
  final failedKeys = <TimelineKey>{};
  @override
  bool resumeFailed(TimelineKey key) => failedKeys.contains(key);

  /// Listes par (connexion, profil) ; [listError] ou [listGate] pour les cas limites.
  final lists = <(ConnectionKey, ProfileKey), List<SessionSummary>>{};
  final listCalls = <(ConnectionKey, ProfileKey)>[];
  Object? listError;
  Completer<void>? listGate;
  @override
  Future<List<SessionSummary>> sessions(
    ConnectionKey connection,
    ProfileKey profile,
  ) async {
    listCalls.add((connection, profile));
    await listGate?.future;
    if (listError != null) throw listError!;
    return lists[(connection, profile)] ?? const [];
  }

  @override
  Future<void> dispose() async {}
}
