import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/hermes_adapter.dart';
import 'package:hermes_mobile/models/app_error.dart';

void main() {
  test(
    'pair local sans pong : perte détectée par pingInterval borné',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final received = Completer<void>();
      Socket? peerSocket;
      server.listen((request) async {
        final nonce = request.headers.value('sec-websocket-key')!;
        request.response.statusCode = 101;
        request.response.headers
          ..set('Connection', 'Upgrade')
          ..set('Upgrade', 'websocket')
          ..set('Sec-WebSocket-Protocol', 'hermes-gateway-v1')
          ..set(
            'Sec-WebSocket-Accept',
            base64Encode(
              sha1
                  .convert(
                    utf8.encode('${nonce}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'),
                  )
                  .bytes,
            ),
          );
        final peer = await request.response.detachSocket(writeHeaders: true);
        peerSocket = peer;
        addTearDown(peer.destroy);
        // Le pair lit les trames mais ne répond jamais au ping.
        peer.listen((data) {
          if ((data.first & 15) == 9 && !received.isCompleted) {
            received.complete();
          }
        });
      });
      final transport = IoHermesTransport();
      addTearDown(transport.close);
      final socket = await runZoned(
        () => transport.openSocket(
          Uri.parse('http://127.0.0.1:${server.port}'),
          'SYNTHETIC_TICKET',
        ),
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) =>
              parent.createTimer(
                zone,
                duration == networkTimeout
                    ? const Duration(milliseconds: 500)
                    : duration,
                callback,
              ),
        ),
      );
      final ended = socket.messages.drain<void>();
      await received.future.timeout(const Duration(seconds: 18));
      await ended.timeout(const Duration(seconds: 18));
      peerSocket!.destroy();
      await socket.close();
    },
  );
  test(
    'login HTTP réel : JSON, cookies explicites puis bearer sur profils',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final paths = <String>[];
      server.listen((request) async {
        paths.add(request.uri.path);
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/auth/password-login') {
          expect(request.method, 'POST');
          expect(request.headers.contentType!.mimeType, 'application/json');
          expect(request.headers.value('authorization'), isNull);
          expect(jsonDecode(await utf8.decoder.bind(request).join()), {
            'provider': 'basic',
            'username': 'hermes',
            'password': '<SYNTHETIC_PASSWORD>',
            'next': '',
          });
          request.response.headers.add(
            'Set-Cookie',
            'hermes_session_at=SYNTHETIC_ACCESS; HttpOnly; Path=/',
          );
          request.response.headers.add(
            'Set-Cookie',
            'hermes_session_rt=SYNTHETIC_REFRESH; HttpOnly; Path=/',
          );
          request.response.write(jsonEncode({'ok': true, 'next': '/'}));
        } else {
          expect(request.uri.path, '/api/profiles');
          expect(request.method, 'GET');
          expect(
            request.headers.value('authorization'),
            'Bearer SYNTHETIC_ACCESS',
          );
          expect(request.headers.value('cookie'), isNull);
          request.response.write(
            jsonEncode({
              'profiles': [
                {
                  'name': 'default',
                  'is_default': true,
                  'display_name': 'Principal',
                },
              ],
            }),
          );
        }
        await request.response.close();
      });
      final transport = IoHermesTransport();
      addTearDown(transport.close);
      final adapter = HermesAdapter(transport);
      final origin = Uri.parse('http://127.0.0.1:${server.port}');
      final tokens = await adapter.login(origin, '<SYNTHETIC_PASSWORD>');
      expect(tokens.access, 'SYNTHETIC_ACCESS');
      expect(tokens.refresh, 'SYNTHETIC_REFRESH');
      expect(
        (await adapter.profiles(origin, tokens.access)).single.key.value,
        'default',
      );
      expect(paths, ['/auth/password-login', '/api/profiles']);
    },
  );
  test('JSON 200 malformé est une erreur de contrat non retryable', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response.write('{invalid JSON');
      request.response.close();
    });
    final transport = IoHermesTransport();
    addTearDown(transport.close);
    await expectLater(
      HermesAdapter(transport).profiles(
        Uri.parse('http://127.0.0.1:${server.port}'),
        'SYNTHETIC_ACCESS',
      ),
      throwsA(
        isA<AppError>()
            .having((error) => error.code, 'code', 'contract.invalid_response')
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  }, timeout: const Timeout(Duration(seconds: 45)));
  test(
    'REST et upgrade WS ne transmettent aucun secret à une redirection externe',
    () async {
      final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final external = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => source.close(force: true));
      addTearDown(() => external.close(force: true));
      var leakedRequests = 0;
      external.listen((request) {
        leakedRequests++;
        request.response.close();
      });
      source.listen((request) {
        request.response.statusCode = 302;
        request.response.headers.set(
          'Location',
          'http://127.0.0.1:${external.port}/leak',
        );
        request.response.close();
      });
      final transport = IoHermesTransport();
      addTearDown(transport.close);
      final origin = Uri.parse('http://127.0.0.1:${source.port}');
      final response = await transport.request(
        origin,
        bearer: '<SYNTHETIC_ACCESS>',
      );
      expect(response.status, 302);
      await expectLater(
        transport.openSocket(origin, '<SYNTHETIC_TICKET>'),
        throwsA(isA<AppError>()),
      );
      expect(leakedRequests, 0);
    },
  );
  test(
    'vrai upgrade WS utilise sous-protocoles, jamais query de secret',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        expect(request.uri.path, '/api/ws');
        expect(request.uri.hasQuery, isFalse);
        expect(
          request.headers.value('sec-websocket-protocol'),
          contains('hermes-gateway-ticket.SYNTHETIC_TICKET'),
        );
        final ws = await WebSocketTransformer.upgrade(
          request,
          protocolSelector: (protocols) =>
              protocols.contains('hermes-gateway-v1')
              ? 'hermes-gateway-v1'
              : null,
        );
        ws.add(
          jsonEncode({
            'method': 'event',
            'params': {'type': 'gateway.ready', 'payload': {}},
          }),
        );
        ws.listen((_) {});
      });
      final transport = IoHermesTransport();
      addTearDown(transport.close);
      final socket = await transport.openSocket(
        Uri.parse('http://127.0.0.1:${server.port}'),
        'SYNTHETIC_TICKET',
      );
      expect(
        jsonDecode(await socket.messages.first as String)['method'],
        'event',
      );
      await socket.close();
    },
  );
}
