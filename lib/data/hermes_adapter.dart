import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/app_error.dart';
import '../models/connection_gateway.dart';
import '../models/history.dart';
import '../models/profile.dart';
import '../models/result.dart';
import '../models/room.dart';
import '../models/timeline.dart';

const networkTimeout = Duration(seconds: 15);

class TransportResponse {
  const TransportResponse(this.status, this.body, {this.cookies = const []});
  final int status;
  final Map<String, dynamic> body;
  final List<String> cookies;
}

abstract interface class GatewaySocket {
  Stream<Object?> get messages;
  void send(Map<String, dynamic> message);
  Future<void> close();
}

abstract interface class HermesTransport {
  Future<TransportResponse> request(
    Uri uri, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? bearer,
  });

  /// Flux binaire authentifié : écrit dans `targetPath.part` puis renomme.
  Future<DownloadedFile> download(Uri uri, String targetPath, {String? bearer});
  Future<GatewaySocket> openSocket(Uri origin, String ticket);
  void close();
}

/// Aucun suivi de redirection, y compris pendant l'upgrade authentifié.
class IoHermesTransport implements HermesTransport {
  IoHermesTransport({HttpClient? client}) : _client = client ?? HttpClient();
  final HttpClient _client;

  Future<HttpClientRequest> _open(String method, Uri uri) {
    var expired = false;
    final opening = _client.openUrl(method, uri);
    unawaited(
      opening.then((request) {
        if (expired) request.abort();
      }, onError: (Object _, StackTrace _) {}),
    );
    return opening.timeout(
      networkTimeout,
      onTimeout: () {
        expired = true;
        throw TimeoutException('transport.timeout');
      },
    );
  }

  Future<HttpClientResponse> _send(HttpClientRequest request) =>
      request.close().timeout(
        networkTimeout,
        onTimeout: () {
          request.abort();
          throw TimeoutException('transport.timeout');
        },
      );

  @override
  Future<TransportResponse> request(
    Uri uri, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? bearer,
  }) async {
    final request = await _open(method, uri);
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    if (bearer != null) request.headers.set('Authorization', 'Bearer $bearer');
    if (body != null) request.write(jsonEncode(body));
    final response = await _send(request);
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(
          networkTimeout,
          onTimeout: () {
            request.abort();
            throw TimeoutException('transport.timeout');
          },
        );
    // Les corps d'erreur ne sont jamais interprétés, affichés ou conservés.
    final decoded = response.statusCode == 200
        ? jsonDecode(text)
        : <String, dynamic>{};
    if (decoded is! Map<String, dynamic>) {
      throw const AppError('contract.invalid_response');
    }
    return TransportResponse(
      response.statusCode,
      decoded,
      cookies: response.headers['set-cookie'] ?? const [],
    );
  }

  @override
  Future<DownloadedFile> download(
    Uri uri,
    String targetPath, {
    String? bearer,
  }) async {
    final target = File(targetPath);
    final part = File('$targetPath.part');
    HttpClientRequest? request;
    Future<void> discardPart() async {
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {
        /* copie partielle déjà illisible */
      }
    }

    try {
      await target.parent.create(recursive: true);
      request = await _open('GET', uri);
      request.followRedirects = false;
      if (bearer != null) {
        request.headers.set('Authorization', 'Bearer $bearer');
      }
      final response = await _send(request);
      final status = response.statusCode;
      if (status != 200) {
        try {
          await response.drain<void>().timeout(networkTimeout);
        } catch (_) {
          /* corps d'erreur ignoré */
        }
        if (status >= 300 && status < 400) {
          throw const AppError('transport.redirect');
        }
        if (status == 401) throw const AppError('auth.refused');
        if (status == 403) throw const AppError('result.refused');
        if (status == 404) throw const AppError('result.missing');
        throw AppError(
          'transport.server',
          retryable: status == 429 || status >= 500,
        );
      }
      if (await part.exists()) await part.delete();
      final sink = part.openWrite();
      try {
        // `networkTimeout` borne l'inactivité du flux, pas sa durée totale.
        await for (final chunk in response.timeout(networkTimeout)) {
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();
      } catch (_) {
        try {
          await sink.close();
        } catch (_) {
          /* flux déjà rompu */
        }
        rethrow;
      }
      if (await target.exists()) await target.delete();
      await part.rename(targetPath);
      // La carte n'affiche une taille que si le serveur l'a annoncée.
      final length = response.contentLength;
      return DownloadedFile(
        length < 0 ? null : length,
        mediaType: response.headers.contentType?.mimeType,
      );
    } on AppError {
      await discardPart();
      rethrow;
    } on TimeoutException {
      request?.abort();
      await discardPart();
      throw const AppError('transport.unreachable', retryable: true);
    } on FileSystemException {
      await discardPart();
      throw const AppError('result.write');
    } catch (_) {
      request?.abort();
      await discardPart();
      throw const AppError('transport.unreachable', retryable: true);
    }
  }

  @override
  Future<GatewaySocket> openSocket(Uri origin, String ticket) async {
    final nonce = base64Encode(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final request = await _open('GET', origin.resolve('/api/ws'));
    request.followRedirects = false;
    request.headers
      ..set('Connection', 'Upgrade')
      ..set('Upgrade', 'websocket')
      ..set('Sec-WebSocket-Key', nonce)
      ..set('Sec-WebSocket-Version', '13')
      ..set(
        'Sec-WebSocket-Protocol',
        'hermes-gateway-v1, hermes-gateway-ticket.$ticket',
      );
    final response = await _send(request);
    final expected = base64Encode(
      sha1
          .convert(utf8.encode('${nonce}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
          .bytes,
    );
    if (response.statusCode != 101 ||
        response.headers.value('sec-websocket-accept') != expected ||
        response.headers.value('sec-websocket-protocol') !=
            'hermes-gateway-v1' ||
        response.headers.value('upgrade')?.toLowerCase() != 'websocket') {
      (await response.detachSocket()).destroy();
      if (response.statusCode >= 300 && response.statusCode < 400) {
        throw const AppError('transport.redirect');
      }
      if ([404, 405, 501].contains(response.statusCode)) {
        throw const AppError('contract.method_missing');
      }
      throw AppError(
        response.statusCode == 401 || response.statusCode == 403
            ? 'auth.refused'
            : 'transport.websocket',
        retryable: response.statusCode >= 500,
      );
    }
    final socket = await response.detachSocket();
    return _IoGatewaySocket(
      WebSocket.fromUpgradedSocket(
        socket,
        serverSide: false,
        protocol: 'hermes-gateway-v1',
      )..pingInterval = networkTimeout,
    );
  }

  @override
  void close() => _client.close(force: true);
}

class _IoGatewaySocket implements GatewaySocket {
  _IoGatewaySocket(this.socket);
  final WebSocket socket;
  @override
  Stream<Object?> get messages => socket;
  @override
  void send(Map<String, dynamic> message) => socket.add(jsonEncode(message));
  @override
  Future<void> close() async {
    await socket.close();
  }
}

class AuthTokens {
  const AuthTokens(this.access, this.refresh);
  final String access;
  final String? refresh;
}

class HermesAdapter {
  HermesAdapter(this.transport);
  final HermesTransport transport;
  Future<Map<String, dynamic>> _request(
    Uri origin,
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? bearer,
  }) async {
    final response = await _response(
      origin,
      path,
      method: method,
      body: body,
      bearer: bearer,
    );
    return response.body;
  }

  Future<TransportResponse> _response(
    Uri origin,
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? bearer,
  }) async {
    try {
      final response = await transport
          .request(
            origin.resolve(path),
            method: method,
            body: body,
            bearer: bearer,
          )
          .timeout(networkTimeout);
      final status = response.status;
      if (status == 200) return response;
      if (status >= 300 && status < 400) {
        throw const AppError('transport.redirect');
      }
      if (status == 401 || status == 403) throw const AppError('auth.refused');
      if (status == 404 || status == 405 || status == 501) {
        throw const AppError('contract.method_missing');
      }
      throw AppError(
        'transport.server',
        retryable: status == 429 || status >= 500,
      );
    } on AppError {
      rethrow;
    } on FormatException {
      throw const AppError('contract.invalid_response');
    } catch (_) {
      throw const AppError('transport.unreachable', retryable: true);
    }
  }

  Future<AuthTokens> login(Uri origin, String password) async {
    final response = await _response(
      origin,
      '/auth/password-login',
      method: 'POST',
      body: {
        'provider': 'basic',
        'username': 'hermes',
        'password': password,
        'next': '',
      },
    );
    final cookies = <String, String>{};
    try {
      for (final header in response.cookies) {
        final cookie = Cookie.fromSetCookieValue(header);
        cookies[cookie.name.replaceFirst(RegExp(r'^__(Host|Secure)-'), '')] =
            cookie.value;
      }
    } catch (_) {
      throw const AppError('auth.invalid_session');
    }
    final access = cookies['hermes_session_at'];
    if (response.body['ok'] != true || access == null || access.isEmpty) {
      throw const AppError('auth.invalid_session');
    }
    final refresh = cookies['hermes_session_rt'];
    return AuthTokens(
      access,
      refresh == null || refresh.isEmpty ? null : refresh,
    );
  }

  Future<AuthTokens> refresh(Uri origin, String refresh) async {
    final body = await _request(
      origin,
      '/auth/native/refresh',
      method: 'POST',
      body: {'provider': 'basic', 'refresh_token': refresh},
    );
    final access = body['access_token'];
    final token = body['refresh_token'];
    if (access is! String ||
        access.isEmpty ||
        (token != null && (token is! String || token.isEmpty))) {
      throw const AppError('auth.invalid_session');
    }
    return AuthTokens(access, token as String? ?? refresh);
  }

  Future<List<Profile>> profiles(Uri origin, String bearer) async {
    final body = await _request(origin, '/api/profiles', bearer: bearer);
    final profiles = body['profiles'];
    if (profiles is! List) throw const AppError('contract.invalid_response');
    final keys = <String>{};
    return profiles
        .map((entry) {
          if (entry is! Map ||
              entry['name'] is! String ||
              (entry['name'] as String).isEmpty ||
              entry['is_default'] is! bool ||
              !keys.add(entry['name'] as String)) {
            throw const AppError('contract.invalid_response');
          }
          final key = entry['name'] as String;
          final label = entry['display_name'];
          return Profile(
            key: ProfileKey(key),
            label: label is String && label.isNotEmpty ? label : key,
            isDefault: entry['is_default'] as bool,
          );
        })
        .toList(growable: false);
  }

  /// Fichier déjà écrit côté Hermes : `GET /api/fs/download` avec le profil
  /// et la session du fil, jamais de redirection.
  Future<DownloadedFile> download(
    Uri origin, {
    required String path,
    required ProfileKey profile,
    required String session,
    required String targetPath,
    required String bearer,
  }) => transport.download(
    origin
        .resolve('/api/fs/download')
        .replace(
          queryParameters: {
            'path': path,
            'profile': profile.value,
            'session_id': session,
          },
        ),
    targetPath,
    bearer: bearer,
  );

  Future<GatewaySocket> socket(Uri origin, String bearer) async {
    final body = await _request(
      origin,
      '/api/auth/ws-ticket',
      method: 'POST',
      bearer: bearer,
    );
    final ticket = body['ticket'];
    if (ticket is! String || ticket.isEmpty) {
      throw const AppError('contract.invalid_response');
    }
    var expired = false;
    final opening = transport.openSocket(origin, ticket);
    unawaited(
      opening.then((socket) {
        if (expired) unawaited(socket.close());
      }, onError: (Object _, StackTrace _) {}),
    );
    try {
      return await opening.timeout(
        networkTimeout,
        onTimeout: () {
          expired = true;
          throw const AppError('transport.websocket', retryable: true);
        },
      );
    } on AppError {
      rethrow;
    } catch (_) {
      throw const AppError('transport.websocket', retryable: true);
    }
  }
}

/// Dialecte legacy du contrat 9e01b44 : seul endroit qui connaît ces formats.
abstract final class HermesRpc {
  static const groupsCapabilities = 'groups.capabilities';
  static const groupsList = 'groups.list';
  static const groupsCreate = 'groups.create';
  static const groupsSend = 'groups.send';
  static const groupsState = 'groups.state';
  static const groupsLog = 'groups.log';
  static const groupsStop = 'groups.stop';
  static const groupsRetry = 'groups.retry';
  static const groupsDiscard = 'groups.discard';
  static const groupsApprove = 'groups.approve';
  static ({bool working, bool blocked}) roomStatus(Map r) {
    final status = r['driver_status'];
    return (
      working: status is Map && status['working'] == true,
      blocked: status is Map && status['blocked'] == true,
    );
  }

  static List<String> roomMessages(Map r) => [
    for (final event in r['events'] as List? ?? const [])
      if (event is Map &&
          event['kind'] is String &&
          (event['kind'] as String).startsWith('message.') &&
          event['payload'] is Map)
        if ((event['payload'] as Map)['text'] is String)
          (event['payload'] as Map)['text'] as String,
  ];

  static Map<String, dynamic> roomParams(
    RoomKey key,
    Map<String, dynamic> params,
  ) => {
    'profile': key.profile.value,
    if (key.room.isNotEmpty) 'room_id': key.room,
    ...params,
  };

  static RoomCapabilities roomCapabilities(Map<String, dynamic> r) {
    if (r['driver'] is! bool || r['methods'] is! List) {
      throw const AppError('contract.invalid_response');
    }
    return RoomCapabilities(
      r['driver'] == true,
      (r['methods'] as List).cast<String>().toSet(),
      {
        for (final p in (r['seatable_profiles'] as List? ?? const []))
          ProfileKey(p as String),
      },
    );
  }

  static RoomSummary room(Map r) {
    if (r['room_id'] is! String ||
        r['name'] is! String ||
        r['members'] is! List) {
      throw const AppError('contract.invalid_response');
    }
    return RoomSummary(
      id: r['room_id'] as String,
      name: r['name'] as String,
      members: [
        for (final raw in r['members'] as List)
          if (raw is Map)
            RoomMember(
              raw['member_id'] as String? ?? raw['profile'] as String? ?? '',
              ProfileKey(raw['profile'] as String? ?? ''),
              raw['display_name'] as String? ?? raw['profile'] as String? ?? '',
              raw['handle'] as String? ?? raw['profile'] as String? ?? '',
            ),
      ],
      updatedAt: r['updated_at'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              ((r['updated_at'] as num) * 1000).round(),
              isUtc: true,
            )
          : null,
    );
  }

  static List<RoomSummary> rooms(Map<String, dynamic> r) {
    if (r['rooms'] is! List) throw const AppError('contract.invalid_response');
    return [for (final value in r['rooms'] as List) room(value as Map)];
  }

  static Map<String, dynamic> interruptParams(
    String runtime,
    ProfileKey profile,
  ) => {'session_id': runtime, 'profile': profile.value};

  /// Le résultat RPC ne constitue jamais une preuve terminale.
  static bool interrupted(Map<String, dynamic> result) {
    if (!{'interrupted', 'not_interrupted'}.contains(result['status']) ||
        (result['interrupted'] != null && result['interrupted'] is! bool) ||
        (result['turn_isolation'] != null &&
            result['turn_isolation'] is! bool)) {
      throw const AppError('contract.invalid_response');
    }
    return result['status'] == 'interrupted';
  }

  static const runtimeLost = 4001;
  static const turnStart = 'message.start';
  static const turnEnd = 'message.complete';
  static const sessionError = 'error';
  static const _accepted = {'streaming', 'queued', 'steered', 'redirected'};

  /// Le dialecte canonique (`session_authority`) n'est pas pris en charge.
  static bool conversationSupported(Map payload) =>
      payload['session_authority'] != true;

  static Map<String, dynamic> createParams(ProfileKey profile, String key) => {
    'profile': profile.value,
    'close_on_disconnect': false,
    'idempotency_key': key,
  };

  static ({String runtime, String stored}) created(Map<String, dynamic> r) {
    final runtime = r['session_id'];
    final stored = r['stored_session_id'];
    if (runtime is! String ||
        runtime.isEmpty ||
        stored is! String ||
        stored.isEmpty) {
      throw const AppError('contract.invalid_response');
    }
    return (runtime: runtime, stored: stored);
  }

  static Map<String, dynamic> resumeParams(String stored, ProfileKey profile) =>
      {'session_id': stored, 'profile': profile.value};

  static Resumed resumed(Map<String, dynamic> r) {
    final runtime = r['session_id'];
    if (runtime is! String || runtime.isEmpty) {
      throw const AppError('contract.invalid_response');
    }
    final inflight = r['inflight'];
    final partial = inflight is Map ? inflight['assistant'] : null;
    return Resumed(
      runtime: runtime,
      running: r['running'] == true,
      inflight: _filled(inflight),
      partial: partial is String && partial.isNotEmpty ? partial : null,
      queued: _filled(r['queued']),
      openRequests: openRequests(r),
    );
  }

  /// Entrées `open_requests` (`OpenRequestEntry {id, method, params}`) ;
  /// `null` si le champ est absent ou mal formé.
  static List<Map<String, Object?>>? openRequests(Map<String, dynamic> r) {
    final raw = r['open_requests'];
    if (raw is! List) return null;
    return [
      for (final e in raw)
        if (e is Map && e['id'] is String && e['method'] is String)
          Map<String, Object?>.from(e),
    ];
  }

  /// Déclaration des requêtes serveur, une fois par socket.
  static const clientCapabilities = 'client.capabilities';
  static const clientCapabilitiesParams = {'server_requests': true};

  /// Requêtes serveur prises en charge (6.2, 6.3) ; types synthétiques internes.
  static const clarify = 'clarify';
  static const clarifyEvent = 'server.clarify';
  static const approval = 'approval';
  static const approvalEvent = 'server.approval';
  static const requestCancel = 'request.cancel';
  static const methodNotFound = -32601;

  /// Mode d'autorisation d'un profil : `config.get` / `config.set` avec
  /// `profile` (mesuré sans effet sur les autres profils).
  static const configGet = 'config.get';
  static const configSet = 'config.set';
  static const approvalsMode = 'approvals.mode';

  /// Requête serveur `clarify` ou `approval` (directe ou `open_requests`)
  /// rendue comme un événement de session ; `null` si elle n'est pas prise
  /// en charge ou pas exploitable.
  static GatewayEvent? serverRequest(
    Map<Object?, Object?> request, {
    String? runtime,
    required int generation,
    required String? replayEpoch,
  }) {
    final id = request['id'];
    final params = request['params'];
    final method = request['method'];
    if (id is! String || params is! Map) return null;
    final session = runtime ?? params['session_id'];
    if (session is! String || session.isEmpty) return null;
    final Map<String, Object?> payload;
    final String type;
    if (method == clarify) {
      final questions = params['questions'];
      if (questions is! List) return null;
      type = clarifyEvent;
      payload = {'id': id, 'questions': questions};
    } else if (method == approval) {
      final command = params['command'];
      final description = params['description'];
      if (command is! String) return null;
      final choices = params['choices'];
      type = approvalEvent;
      payload = {
        'id': id,
        'description': description is String ? description : '',
        'command': command,
        'choices': [
          if (choices is List)
            for (final c in choices)
              if (c is String) c,
        ],
        'allow_session': params['allow_session'] == true,
        'allow_permanent': params['allow_permanent'] == true,
      };
    } else {
      return null;
    }
    return GatewayEvent(
      sessionId: session,
      type: type,
      payload: payload,
      generation: generation,
      replayEpoch: replayEpoch,
    );
  }

  /// Réponse soumise : `{answers: {qid: texte}, outcome: "submitted"}`.
  static Map<String, dynamic> clarifyAnswer(Map<String, String> answers) => {
    'answers': answers,
    'outcome': 'submitted',
  };

  /// Décision d'autorisation : `{choice}` (`once` ou `deny` seulement).
  static Map<String, dynamic> approvalAnswer(String choice) => {
    'choice': choice,
  };

  /// `config.get` du mode d'autorisation de [profile].
  static Map<String, dynamic> approvalModeGet(String profile) => {
    'key': approvalsMode,
    'profile': profile,
  };

  /// `config.set` du mode d'autorisation de [profile].
  static Map<String, dynamic> approvalModeSet(String profile, String mode) => {
    'key': approvalsMode,
    'value': mode,
    'profile': profile,
  };

  /// Valeur relue par `config.get` (`{value}`), `null` si absente.
  static String? configValue(Map<String, dynamic> r) {
    final value = r['value'];
    return value is String ? value : null;
  }

  /// Refus immédiat d'une requête serveur non prise en charge.
  static Map<String, dynamic> unsupportedRequest() => {
    'code': methodNotFound,
    'message': 'method not supported by client',
  };

  static bool _filled(Object? value) => switch (value) {
    Map() => value.isNotEmpty,
    List() => value.isNotEmpty,
    String() => value.isNotEmpty,
    bool() => value,
    null => false,
    _ => true,
  };

  /// Limite par défaut du serveur : pas de pagination au-delà.
  static const listLimit = sessionListLimit;

  static Map<String, dynamic> listParams(
    ProfileKey profile, {
    bool includeHidden = false,
  }) => {
    'profile': profile.value,
    'limit': listLimit,
    if (includeHidden) 'include_hidden': true,
  };

  /// Lignes de `session.list` dans l'ordre du serveur ; une ligne sans `id` est écartée.
  static List<SessionSummary> sessions(Map<String, dynamic> r) {
    final raw = r['sessions'];
    if (raw is! List) throw const AppError('contract.invalid_response');
    String? text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
    return [
      for (final s in raw)
        if (s is Map && s['id'] is String && (s['id'] as String).isNotEmpty)
          SessionSummary(
            id: s['id'] as String,
            title: text(s['title']),
            preview: text(s['preview']),
            startedAt: _date(s['started_at']),
            messageCount: _count(s['message_count']),
          ),
    ];
  }

  /// Secondes epoch ; hors plage ou non finies : pas de date.
  static DateTime? _date(Object? seconds) {
    if (seconds is! num || !seconds.isFinite || seconds <= 0) return null;
    final ms = seconds * 1000;
    return ms > 8.64e15
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms.round(), isUtc: true);
  }

  static int _count(Object? n) =>
      n is num && n.isFinite ? n.toInt().clamp(0, 1 << 31) : 0;

  /// `session.title` (contrat documentaire, non qualifié sur installation) :
  /// identifiant runtime, profil et titre déjà normalisé.
  static const sessionTitle = 'session.title';
  static const sessionSetHidden = 'session.set_hidden';
  static const sessionDelete = 'session.delete';

  /// `session.set_hidden` vise l'ID stocké (contrat documentaire, non
  /// qualifié sur installation).
  static Map<String, dynamic> hiddenParams(
    String stored,
    ProfileKey profile,
    bool hidden,
  ) => {'session_id': stored, 'hidden': hidden, 'profile': profile.value};

  static bool hiddenResult(Map<String, dynamic> r) {
    final hidden = r['hidden'];
    if (hidden is! bool) throw const AppError('contract.invalid_response');
    return hidden;
  }

  static Map<String, dynamic> deleteParams(String stored, ProfileKey profile) =>
      {'session_id': stored, 'profile': profile.value};

  /// `{deleted: <id stocké>}` : seule une réponse visant [stored] confirme.
  static bool deleted(Map<String, dynamic> r, String stored) {
    final id = r['deleted'];
    if (id is! String) throw const AppError('contract.invalid_response');
    return id == stored;
  }

  static Map<String, dynamic> titleParams(
    String runtime,
    ProfileKey profile,
    String title,
  ) => {'session_id': runtime, 'profile': profile.value, 'title': title};

  /// `SessionTitleResult {title, session_key?, pending?}` ; `pending: true` :
  /// titre en file, non confirmé.
  static ({String title, bool pending}) titled(Map<String, dynamic> r) {
    final title = r['title'];
    final pending = r['pending'];
    final key = r['session_key'];
    if (title is! String ||
        title.trim().isEmpty ||
        (pending != null && pending is! bool) ||
        (key != null && key is! String)) {
      throw const AppError('contract.invalid_response');
    }
    return (title: title, pending: pending == true);
  }

  static Map<String, dynamic> historyParams(String runtime) => {
    'session_id': runtime,
  };

  /// Lignes utilisateur/assistant affichables de `session.history`, dans l'ordre.
  static List<({int row, bool user, String text})> history(
    Map<String, dynamic> r,
  ) {
    final messages = r['messages'];
    if (messages is! List) throw const AppError('contract.invalid_response');
    final rows = <({int row, bool user, String text})>[];
    for (final m in messages) {
      final kind = m is Map ? m['display_kind'] : null;
      if (m is! Map || (kind != null && kind != 'text')) continue;
      final role = m['role'];
      final text = m['text'] ?? m['content'];
      final row = m['row_id'];
      if ((role != 'user' && role != 'assistant') ||
          row is! int ||
          text is! String ||
          text.isEmpty) {
        continue;
      }
      rows.add((row: row, user: role == 'user', text: text));
    }
    return rows;
  }

  static Map<String, dynamic> sinceParams(String runtime, int lastSeen) => {
    'session_id': runtime,
    'last_seen': lastSeen,
  };

  /// Événements rejoués (`seq` inclus) rendus comme s'ils étaient arrivés en direct.
  static ({
    List<GatewayEvent> events,
    int? latest,
    bool truncated,
    String? epoch,
    List<Map<String, Object?>>? openRequests,
  })
  since(
    Map<String, dynamic> r, {
    required String runtime,
    required int generation,
    required String? replayEpoch,
  }) {
    final raw = r['events'];
    if (raw is! List) throw const AppError('contract.invalid_response');
    final events = <GatewayEvent>[];
    for (final e in raw) {
      if (e is! Map || e['type'] is! String || e['seq'] is! int) continue;
      final payload = e['payload'];
      events.add(
        GatewayEvent(
          sessionId: runtime,
          type: e['type'] as String,
          payload: payload is Map
              ? Map<String, dynamic>.from(payload)
              : const {},
          seq: e['seq'] as int,
          generation: generation,
          replayEpoch: replayEpoch,
        ),
      );
    }
    final latest = r['latest_seq'];
    final epoch = r['epoch'];
    return (
      events: events,
      latest: latest is int ? latest : null,
      truncated: r['truncated'] != false,
      epoch: epoch is String ? epoch : null,
      openRequests: openRequests(r),
    );
  }

  static Map<String, dynamic> submitParams(String runtime, String text) => {
    'session_id': runtime,
    'text': text,
  };

  /// Commande de plugin Hermes (`command.dispatch`), hors session.
  static Map<String, dynamic> dispatchParams(String name, String arg) => {
    'name': name,
    'arg': arg,
  };

  /// `null` si la réponse n'est pas une acceptation connue.
  static ({int? userRowId})? submitted(Map<String, dynamic> r) {
    if (!_accepted.contains(r['status'])) return null;
    final row = r['user_row_id'];
    return (userRowId: row is int ? row : null);
  }

  /// Texte non vide d'un `message.delta` / `message.complete` ; `null` sinon.
  static String? eventText(Map<String, dynamic> payload) {
    final text = payload['text'];
    return text is String && text.isNotEmpty ? text : null;
  }

  /// Commentaire `message.interim` à ajouter (rien s'il a déjà été diffusé).
  static String? interimText(Map<String, dynamic> payload) =>
      payload['already_streamed'] == true ? null : eventText(payload);

  /// Lignes utilisateur validées d'un tour (`persisted_turn`), dans l'ordre.
  static List<int> persistedUserRows(Map<String, dynamic> payload) {
    final turn = payload['persisted_turn'];
    if (turn is! Map) return const [];
    final many = turn['user_row_ids'];
    if (many is List) {
      return [
        for (final r in many)
          if (r is int) r,
      ];
    }
    final one = turn['user_row_id'];
    return one is int ? [one] : const [];
  }

  /// Le serveur signale une erreur de tour dans la charge utile.
  static bool hasTurnError(Map<String, dynamic> payload) =>
      payload['error'] != null || payload['error_surface'] != null;
}
