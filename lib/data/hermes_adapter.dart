import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/app_error.dart';
import '../models/profile.dart';

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
