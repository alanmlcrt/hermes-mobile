import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/hermes_adapter.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/profile.dart';

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
    'téléchargement binaire : GET authentifié du fil, .part remplacé, type et '
    'octets reçus',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hermes-download-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final body = <int>[0, 1, 2, 254, 255];
      server.listen((request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/fs/download');
        expect(request.uri.queryParameters, {
          'path': '/home/u/rapport.pdf',
          'profile': 'default',
          'session_id': 'a1b2c3d4',
        });
        expect(
          request.headers.value('authorization'),
          'Bearer SYNTHETIC_ACCESS',
        );
        request.response.headers.contentType = ContentType(
          'application',
          'pdf',
        );
        request.response.contentLength = body.length;
        request.response.add(body);
        await request.response.close();
      });
      final target = '${directory.path}/results/cle';
      await File(target).parent.create(recursive: true);
      await File('$target.part').writeAsString('ancien partiel');

      final transport = IoHermesTransport();
      addTearDown(transport.close);
      final file = await HermesAdapter(transport).download(
        Uri.parse('http://127.0.0.1:${server.port}'),
        path: '/home/u/rapport.pdf',
        profile: const ProfileKey('default'),
        session: 'a1b2c3d4',
        targetPath: target,
        bearer: 'SYNTHETIC_ACCESS',
      );

      expect(file.bytes, body.length);
      expect(file.mediaType, 'application/pdf');
      expect(await File(target).readAsBytes(), body);
      expect(await File('$target.part').exists(), isFalse);
    },
  );

  test(
    'téléchargement sans Content-Length : taille inconnue, octets reçus',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hermes-download-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final body = <int>[4, 5, 6];
      server.listen((request) async {
        request.response.headers.contentType = ContentType.binary;
        request.response.add(body);
        await request.response.close();
      });
      final target = '${directory.path}/results/cle';
      final transport = IoHermesTransport();
      addTearDown(transport.close);

      final file = await HermesAdapter(transport).download(
        Uri.parse('http://127.0.0.1:${server.port}'),
        path: '/home/u/rapport.bin',
        profile: const ProfileKey('default'),
        session: 'a1b2c3d4',
        targetPath: target,
        bearer: 'SYNTHETIC_ACCESS',
      );

      expect(file.bytes, isNull);
      expect(await File(target).readAsBytes(), body);
    },
  );

  for (final (status, code, retryable) in const [
    (404, 'result.missing', false),
    (403, 'result.refused', false),
    (401, 'auth.refused', false),
    (429, 'transport.server', true),
    (500, 'transport.server', true),
    (503, 'transport.server', true),
  ]) {
    test('téléchargement HTTP $status → $code, aucun fichier', () async {
      final directory = await Directory.systemTemp.createTemp(
        'hermes-download-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.statusCode = status;
        request.response.write('corps ignoré');
        await request.response.close();
      });
      final target = '${directory.path}/results/cle';
      await File(target).parent.create(recursive: true);
      await File('$target.part').writeAsString('ancien partiel');

      final transport = IoHermesTransport();
      addTearDown(transport.close);
      await expectLater(
        HermesAdapter(transport).download(
          Uri.parse('http://127.0.0.1:${server.port}'),
          path: '/home/u/rapport.pdf',
          profile: const ProfileKey('default'),
          session: 'a1b2c3d4',
          targetPath: target,
          bearer: 'SYNTHETIC_ACCESS',
        ),
        throwsA(
          isA<AppError>()
              .having((error) => error.code, 'code', code)
              .having((error) => error.retryable, 'retryable', retryable),
        ),
      );
      expect(await File(target).exists(), isFalse);
      expect(await File('$target.part').exists(), isFalse);
    });
  }

  test(
    'redirection refusée : aucune credential ni fichier vers la cible',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hermes-download-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final external = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => source.close(force: true));
      addTearDown(() => external.close(force: true));
      var leaked = 0;
      external.listen((request) {
        leaked++;
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
      final target = '${directory.path}/results/cle';
      final transport = IoHermesTransport();
      addTearDown(transport.close);
      await expectLater(
        HermesAdapter(transport).download(
          Uri.parse('http://127.0.0.1:${source.port}'),
          path: '/home/u/rapport.pdf',
          profile: const ProfileKey('default'),
          session: 'a1b2c3d4',
          targetPath: target,
          bearer: 'SYNTHETIC_ACCESS',
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'transport.redirect',
          ),
        ),
      );
      expect(leaked, 0);
      expect(await File(target).exists(), isFalse);
      expect(await File('$target.part').exists(), isFalse);
    },
  );

  test(
    'flux inactif : délai d’inactivité, partiel supprimé, rien présenté comme '
    'reçu',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hermes-download-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final release = Completer<void>();
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await server.close(force: true);
      });
      server.listen((request) async {
        try {
          request.response.headers.contentType = ContentType.binary;
          request.response.contentLength = 100;
          request.response.add([1, 2, 3]);
          await request.response.flush();
          await release.future;
          await request.response.close();
        } catch (_) {
          /* client avorté après le délai */
        }
      });
      final target = '${directory.path}/results/cle';
      final transport = IoHermesTransport();
      addTearDown(transport.close);
      await expectLater(
        runZoned(
          () => HermesAdapter(transport).download(
            Uri.parse('http://127.0.0.1:${server.port}'),
            path: '/home/u/rapport.pdf',
            profile: const ProfileKey('default'),
            session: 'a1b2c3d4',
            targetPath: target,
            bearer: 'SYNTHETIC_ACCESS',
          ),
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) =>
                parent.createTimer(
                  zone,
                  duration == networkTimeout
                      ? const Duration(milliseconds: 300)
                      : duration,
                  callback,
                ),
          ),
        ),
        throwsA(
          isA<AppError>()
              .having((error) => error.code, 'code', 'transport.unreachable')
              .having((error) => error.retryable, 'retryable', isTrue),
        ),
      );
      expect(await File(target).exists(), isFalse);
      expect(await File('$target.part').exists(), isFalse);
      release.complete();
    },
  );
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
