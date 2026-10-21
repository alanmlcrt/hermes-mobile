import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/app_error.dart';
import '../models/connection_gateway.dart';
import '../models/history.dart';
import '../models/profile.dart';
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
    );
  }

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

  static Map<String, dynamic> listParams(ProfileKey profile) => {
    'profile': profile.value,
    'limit': listLimit,
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
  static ({List<GatewayEvent> events, int? latest, bool truncated, String? epoch})
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
          payload: payload is Map ? Map<String, dynamic>.from(payload) : const {},
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
    );
  }

  static Map<String, dynamic> submitParams(String runtime, String text) => {
    'session_id': runtime,
    'text': text,
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
    if (many is List) return [for (final r in many) if (r is int) r];
    final one = turn['user_row_id'];
    return one is int ? [one] : const [];
  }

  /// Le serveur signale une erreur de tour dans la charge utile.
  static bool hasTurnError(Map<String, dynamic> payload) =>
      payload['error'] != null || payload['error_surface'] != null;
}
