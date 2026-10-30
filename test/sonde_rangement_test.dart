import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/sonde_rangement.dart';

class FakeTransport implements ProbeTransport {
  final controller = StreamController<Object?>();
  final List<Map<String, Object?>> sent = [];
  bool closed = false;
  int opened = 0;
  Object? failure;
  void Function(Map<String, Object?>)? respond;
  @override
  Future<Object?> profiles() async {
    opened++;
    if (failure != null) throw failure!;
    return {
      'profiles': [
        {'name': 'dedicated-secret', 'token': 'TOKEN'},
      ],
    };
  }

  @override
  Future<void> connect() async {
    opened++;
  }

  @override
  Stream<Object?> get replies => controller.stream;
  @override
  void send(Map<String, Object?> request) {
    sent.add(request);
    if (respond != null) {
      respond!(request);
    } else {
      reply(request, {
        'sessions': [
          {
            'id': 'session-secret',
            'title': 'PRIVATE TITLE',
            'preview': 'PRIVATE CONTENT',
            'token': 'TOKEN',
            'hidden': false,
          },
          if ((request['params'] as Map)['include_hidden'] == true)
            {'id': 'hidden-session-secret', 'title': 'HIDDEN PRIVATE TITLE'},
        ],
        'title': 'PRIVATE TITLE',
      });
    }
  }

  void reply(Map<String, Object?> request, Object? result) =>
      controller.add({'jsonrpc': '2.0', 'id': request['id'], 'result': result});
  @override
  Future<void> close() async {
    closed = true;
    unawaited(controller.close());
  }
}

ProbeConfig config({
  bool authorized = false,
  bool lineage = false,
  Duration timeout = const Duration(milliseconds: 100),
  Uri? origin,
}) => ProbeConfig(
  origin: origin ?? Uri.parse('https://example.invalid'),
  profile: 'dedicated-secret',
  sessions: {'session-secret'},
  token: 'TOKEN',
  authorizedProfile: authorized ? 'dedicated-secret' : null,
  authorizedSessions: authorized ? {'session-secret'} : {},
  authorizedLineages: lineage ? {'session-secret'} : {},
  timeout: timeout,
);

void main() {
  test(
    'transcript projection preserves anonymous text, rows and fixed roles',
    () {
      final projection = CaptureProjection();
      final before = projection.project({
        'messages': [
          {'text': 'PRIVATE ONE', 'role': 'user', 'row_id': 10},
        ],
      }) as Map;
      final same = projection.project({
        'messages': [
          {'text': 'PRIVATE ONE', 'role': 'user', 'row_id': 10},
        ],
      });
      final after = projection.project({
        'messages': [
          {'text': 'PRIVATE TWO', 'role': 'assistant', 'row_id': 20},
          {'text': 'PRIVATE THREE', 'role': 'TOKEN', 'row_id': 'SECRET ROW'},
        ],
      }) as Map;
      expect(before, same);
      expect((before['messages'] as List).first['role'], 'user');
      expect((after['messages'] as List).first['role'], 'assistant');
      expect((after['messages'] as List).last['role'], isNull);
      expect(
        (before['messages'] as List).first['text'],
        isNot((after['messages'] as List).first['text']),
      );
      expect(
        (before['messages'] as List).first['row_id'],
        isNot((after['messages'] as List).first['row_id']),
      );
      final encoded = jsonEncode([before, after]);
      for (final secret in ['PRIVATE', 'TOKEN', 'SECRET ROW']) {
        expect(encoded, isNot(contains(secret)));
      }
    },
  );

  for (final method in ['session.list', 'session.history']) {
    test(
      '$method baseline rejection prevents mutation but keeps read evidence',
      () async {
        for (final mutation in [null, 'session.delete']) {
          final transport = FakeTransport();
          transport.respond = (request) {
            if (request['method'] == method) {
              transport.controller.add({
                'jsonrpc': '2.0',
                'id': request['id'],
                'error': {'code': -32602, 'message': 'TOKEN'},
              });
            } else {
              transport.reply(request, {});
            }
          };
          final report = await ArrangementProbe(
            config(authorized: true),
            transport,
          ).run(mutation: mutation, session: 'session-secret');
          expect(
            transport.sent.where((r) => r['method'] == 'session.delete'),
            isEmpty,
          );
          expect(transport.sent.length, 5);
          expect(report['failure_category'], 'baseline_read_failed');
          expect(report['protocol_complete'], false);
        }
      },
    );
  }

  test(
    'optional runtime title rejection does not prevent stored deletion',
    () async {
      final transport = FakeTransport();
      transport.respond = (request) {
        if (request['method'] == 'session.title') {
          transport.controller.add({
            'jsonrpc': '2.0',
            'id': request['id'],
            'error': {'code': -32000},
          });
        } else {
          transport.reply(request, {});
        }
      };
      final report = await ArrangementProbe(
        config(authorized: true),
        transport,
      ).run(mutation: 'session.delete', session: 'session-secret');
      expect(
        transport.sent.where((r) => r['method'] == 'session.delete').length,
        1,
      );
      expect(report['protocol_complete'], true);
    },
  );

  test('malformed baseline result prevents mutation', () async {
    for (final result in [null, true, 42, 'TOKEN', <Object?>[]]) {
      final transport = FakeTransport();
      transport.respond = (request) => transport.reply(
        request,
        request['method'] == 'session.list' ? result : {},
      );
      final report = await ArrangementProbe(
        config(authorized: true),
        transport,
      ).run(mutation: 'session.delete', session: 'session-secret');
      expect(report['failure_category'], 'invalid_rpc_response');
      expect(
        transport.sent.where((r) => r['method'] == 'session.delete'),
        isEmpty,
      );
      expect(jsonEncode(report), isNot(contains('TOKEN')));
    }
  });

  test(
    'failed postcheck preserves conclusive mutation response or rejection',
    () async {
      for (final rejected in [false, true]) {
        final transport = FakeTransport();
        var answered = false;
        transport.respond = (request) {
          if (request['method'] == 'session.delete') {
            answered = true;
            if (rejected) {
              transport.controller.add({
                'jsonrpc': '2.0',
                'id': request['id'],
                'error': {'code': -32000},
              });
            } else {
              transport.reply(request, {'deleted': 'session-secret'});
            }
          } else if (!answered) {
            transport.reply(request, {});
          }
        };
        final report = await ArrangementProbe(
          config(authorized: true, timeout: const Duration(milliseconds: 20)),
          transport,
        ).run(mutation: 'session.delete', session: 'session-secret');
        final records = report['records'] as List;
        final mutation = records.singleWhere((r) => r['mutation'] == true);
        expect(
          mutation['outcome'],
          rejected ? 'rpc_error' : 'observed_response',
        );
        expect(report['failure_category'], 'postcheck_failed');
        expect(records.last['mutation_result'], 'response_received');
        expect(jsonEncode(report), isNot(contains('uncertain_do_not_replay')));
      }
    },
  );

  test(
    'actual guarded socket closes preserve authentication and access refusal',
    () async {
      for (final code in [4401, 4403]) {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final subscription = server.listen((request) async {
          if (request.uri.path == '/api/profiles') {
            request.response.write('{"profiles":[]}');
            await request.response.close();
          } else {
            final socket = await WebSocketTransformer.upgrade(request);
            await socket.close(code, 'TOKEN PRIVATE REASON');
          }
        });
        try {
          final settings = config(
            origin: Uri.parse('http://127.0.0.1:${server.port}'),
            timeout: const Duration(seconds: 2),
          );
          final report = await ArrangementProbe(
            settings,
            NetworkProbeTransport(settings),
          ).run();
          expect(
            report['failure_category'],
            code == 4401 ? 'authentication_refused' : 'access_refused',
          );
          expect(jsonEncode(report), isNot(contains('TOKEN')));
          expect(jsonEncode(report), isNot(contains('PRIVATE REASON')));
        } finally {
          await subscription.cancel();
          await server.close(force: true);
        }
      }
    },
  );

  test('CLI failures keep anonymous capture and fail without normal success', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'hermes-probe-cli-',
    );
    final packageFile = File('.dart_tool/package_config.json').absolute;
    final packages =
        jsonDecode(await packageFile.readAsString())['packages'] as List;
    final package = packages.singleWhere((p) => p['name'] == 'flutter_test');
    final sdkRoot = Directory.fromUri(
      packageFile.uri.resolve(package['rootUri'] as String),
    ).parent.parent.path;
    final dart =
        '$sdkRoot/bin/cache/dart-sdk/bin/${Platform.isWindows ? 'dart.exe' : 'dart'}';
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    var scenario = 'auth';
    final subscription = server.listen((request) async {
      requests++;
      if (scenario == 'auth') {
        request.response.statusCode = 401;
      } else if (request.uri.path == '/api/profiles') {
        request.response.write('{"profiles":[]}');
      } else if (scenario == 'protocol') {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((data) {
          final rpc = jsonDecode(data as String) as Map;
          socket.add(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': rpc['id'],
              'result': rpc['method'] == 'session.list' ? null : {},
            }),
          );
        });
        return;
      } else {
        request.response.statusCode = 500;
      }
      await request.response.close();
    });
    Future<ProcessResult> execute(String capture, {bool authorize = true}) =>
        Process.run(
          dart,
          [
            '--packages=.dart_tool/package_config.json',
            'tool/sonde_rangement.dart',
            'session.delete',
          ],
          includeParentEnvironment: false,
          environment: {
            for (final entry in Platform.environment.entries)
              if (!entry.key.startsWith('HERMES_')) entry.key: entry.value,
            'HERMES_ORIGIN': 'http://127.0.0.1:${server.port}',
            'HERMES_PROFILE': 'dedicated-secret',
            'HERMES_SESSIONS': 'session-secret',
            'HERMES_TARGET_SESSION': 'session-secret',
            'HERMES_TOKEN': 'TOKEN',
            'HERMES_CAPTURE': capture,
            if (authorize) 'HERMES_AUTHORIZE_PROFILE': 'dedicated-secret',
            if (authorize) 'HERMES_AUTHORIZE_SESSIONS': 'session-secret',
          },
        );
    try {
      final existing = File('${temporary.path}/existing.json');
      await existing.writeAsString('ORIGINAL BYTES');
      for (final destination in [
        existing.path,
        '${temporary.path}/absent/capture.json',
      ]) {
        final result = await execute(destination);
        expect(result.exitCode, isNot(0));
        expect(result.stdout, isNot(contains('Anonymized capture written')));
        expect(requests, 0);
        expect(await existing.readAsString(), 'ORIGINAL BYTES');
      }
      for (final kind in ['local', 'auth', 'transport', 'protocol']) {
        scenario = kind;
        final capture = '${temporary.path}/$kind.json';
        final result = await execute(capture, authorize: kind != 'local');
        expect(result.exitCode, isNot(0));
        expect(result.stdout, isNot(contains('Anonymized capture written')));
        final category = switch (kind) {
          'local' => 'local_authorization_refused',
          'auth' => 'authentication_refused',
          'protocol' => 'invalid_rpc_response',
          _ => 'connection_failure',
        };
        expect(result.stderr, contains(category));
        final contents = await File(capture).readAsString();
        expect(jsonDecode(contents)['protocol_complete'], false);
        expect(contents, isNot(contains('TOKEN')));
        expect(result.stderr, isNot(contains('TOKEN')));
        if (kind == 'local') expect(requests, 0);
      }
    } finally {
      await subscription.cancel();
      await server.close(force: true);
      await temporary.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
  test('malformed correlated mutation response remains uncertain', () async {
    final transport = FakeTransport();
    transport.respond = (request) {
      if (request['method'] == 'session.delete') {
        transport.controller.add({
          'jsonrpc': '2.0',
          'id': request['id'],
          'result': {},
          'error': {'code': -32601},
        });
      } else {
        transport.reply(request, {});
      }
    };
    final report = await ArrangementProbe(
      config(authorized: true),
      transport,
    ).run(mutation: 'session.delete', session: 'session-secret');
    expect(jsonEncode(report), contains('uncertain_do_not_replay'));
    expect(jsonEncode(report), isNot(contains('method_absent')));
    expect(transport.sent.length, 6);
  });

  test('network token routes and actual socket closure use the documented surfaces', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final closed = Completer<void>();
    WebSocket? peer;
    final subscription = server.listen((request) async {
      if (request.uri.path == '/api/profiles') {
        expect(request.headers.value('Authorization'), 'Bearer TOKEN');
        request.response.write('{"profiles":[]}');
        await request.response.close();
      } else {
        expect(request.uri.path, '/api/ws');
        expect(request.uri.queryParameters['token'], 'TOKEN');
        peer = await WebSocketTransformer.upgrade(request);
        peer!.listen(
          (data) {
            final request = jsonDecode(data as String) as Map;
            peer!.add(
              jsonEncode({'jsonrpc': '2.0', 'id': request['id'], 'result': {}}),
            );
          },
          onDone: () {
            if (!closed.isCompleted) closed.complete();
          },
        );
      }
    });
    try {
      final settings = config(
        origin: Uri.parse('http://127.0.0.1:${server.port}'),
        timeout: const Duration(seconds: 2),
      );
      final report = await ArrangementProbe(
        settings,
        NetworkProbeTransport(settings),
      ).run();
      expect(
        (report['records'] as List)
            .where((r) => r['outcome'] == 'observed_response')
            .length,
        5,
      );
      await closed.future.timeout(const Duration(seconds: 2));
    } finally {
      unawaited(peer?.close());
      await subscription.cancel();
      await server.close(force: true);
    }
  });

  test(
    'default is read-only and captures only anonymized fixed projections',
    () async {
      final transport = FakeTransport();
      final report = await ArrangementProbe(config(), transport).run();
      expect(transport.sent.length, 5);
      expect(
        transport.sent.where((r) => (r['params'] as Map).containsKey('title')),
        isEmpty,
      );
      expect(
        transport.sent.where((r) => r['method'] == 'session.list').length,
        2,
      );
      final encoded = jsonEncode(report);
      for (final secret in [
        'dedicated-secret',
        'session-secret',
        'TOKEN',
        'PRIVATE TITLE',
        'PRIVATE CONTENT',
      ]) {
        expect(encoded, isNot(contains(secret)));
      }
      expect(encoded, contains('id-'));
      expect(report['validated'], false);
      expect(transport.closed, true);
    },
  );

  test(
    'profile, target and entire lineage must be explicitly authorized',
    () async {
      for (final method in [
        'session.title',
        'session.delete',
        'session.set_hidden',
        'session.archive',
      ]) {
        final transport = FakeTransport();
        final report = await ArrangementProbe(config(), transport).run(
          mutation: method,
          session: 'session-secret',
          title: 'new',
          value: true,
        );
        expect(transport.opened, 0);
        expect(transport.sent, isEmpty);
        expect(jsonEncode(report), contains('local_authorization_refused'));
        expect(transport.closed, true);
      }
      for (final method in ['session.set_hidden', 'session.archive']) {
        final transport = FakeTransport();
        await ArrangementProbe(
          config(authorized: true),
          transport,
        ).run(mutation: method, session: 'session-secret', value: true);
        expect(transport.opened, 0);
      }
      final transport = FakeTransport();
      await ArrangementProbe(
        config(authorized: true, lineage: true),
        transport,
      ).run(mutation: 'session.delete', session: 'other-session');
      expect(transport.opened, 0);
    },
  );

  test(
    'observed transport does not validate build, other client or search',
    () async {
      final transport = FakeTransport();
      final report = await ArrangementProbe(config(), transport).run();
      expect(report['installed_build'], 'unverified');
      expect(report['other_client'], 'unverified');
      expect(report['search_coverage'], 'unverified');
      expect(report['validated'], false);
    },
  );

  for (final entry in <String, Map<String, Object?>>{
    'session.title': {'title': 'new synthetic title'},
    'session.set_hidden': {'hidden': false},
    'session.archive': {'archived': false},
    'session.delete': {},
  }.entries) {
    test(
      '${entry.key} maps its scoped parameters and has before/after reads',
      () async {
        final transport = FakeTransport();
        final report =
            await ArrangementProbe(
              config(authorized: true, lineage: true),
              transport,
            ).run(
              mutation: entry.key,
              session: 'session-secret',
              title: 'new synthetic title',
              value: false,
            );
        final records = report['records'] as List;
        final mutationRecords = records.where((r) => r['mutation'] == true);
        expect(mutationRecords.length, 1);
        expect(mutationRecords.single['method'], entry.key);
        expect(mutationRecords.single['outcome'], 'observed_response');
        final mutation = transport.sent.singleWhere(
          (r) => r['id'] == mutationRecords.single['request_id'],
        );
        expect(mutation['params'], {
          'profile': 'dedicated-secret',
          'session_id': 'session-secret',
          ...entry.value,
        });
        expect(records.where((r) => r['phase'] == 'before').length, 4);
        expect(records.where((r) => r['phase'] == 'after').length, 4);
        for (final phase in ['before', 'after']) {
          final lists = records
              .where(
                (r) => r['phase'] == phase && r['method'] == 'session.list',
              )
              .toList();
          expect(lists.map((r) => r['params']['include_hidden']).toList(), [
            false,
            true,
          ]);
          expect(
            lists
                .map((r) => (r['response']['sessions'] as List).length)
                .toList(),
            [1, 2],
          );
          expect(
            lists.first['response']['sessions'].first['id'],
            lists.last['response']['sessions'].first['id'],
          );
          expect(
            lists.last['response']['sessions'].last['id'],
            isNot(lists.first['response']['sessions'].first['id']),
          );
        }
        for (final request in transport.sent.where(
          (r) => r['method'] != 'gateway.capabilities',
        )) {
          expect((request['params'] as Map)['profile'], 'dedicated-secret');
        }
        expect(transport.sent.length, 10);
        expect(transport.closed, true);
      },
    );
  }

  test(
    'only explicit method-not-found proves absence, never raw diagnostics',
    () async {
      for (final code in [-32601, -32602, -32000]) {
        final transport = FakeTransport();
        transport.respond = (request) => transport.controller.add({
          'jsonrpc': '2.0',
          'id': request['id'],
          'error': {
            'code': code,
            'message': 'TOKEN PRIVATE CONTENT',
            'data': {'token': 'TOKEN'},
          },
        });
        final report = await ArrangementProbe(config(), transport).run();
        final encoded = jsonEncode(report);
        expect(encoded, isNot(contains('TOKEN')));
        expect(
          encoded,
          contains(
            code == -32601
                ? 'method_absent'
                : code == -32602
                ? 'invalid_parameters'
                : 'rpc_error',
          ),
        );
        if (code != -32601) expect(encoded, isNot(contains('method_absent')));
      }
    },
  );

  test('correlation ignores notifications and mismatched IDs', () async {
    final transport = FakeTransport();
    transport.respond = (request) {
      transport.controller.add({
        'jsonrpc': '2.0',
        'method': 'event',
        'params': 'TOKEN',
      });
      transport.controller.add({
        'jsonrpc': '2.0',
        'id': -1,
        'result': {'title': 'WRONG'},
      });
      transport.reply(request, {'pending': true});
    };
    final report = await ArrangementProbe(config(), transport).run();
    expect(jsonEncode(report), contains('"pending":true'));
    expect(jsonEncode(report), isNot(contains('WRONG')));
    expect(
      (report['records'] as List)
          .where((r) => r['outcome'] == 'observed_response')
          .length,
      5,
    );
  });

  test(
    'mutation timeout is uncertain, closes transport and never retries',
    () async {
      final transport = FakeTransport();
      transport.respond = (request) {
        if (request['method'] != 'session.delete') transport.reply(request, {});
      };
      final report = await ArrangementProbe(
        config(authorized: true, timeout: const Duration(milliseconds: 20)),
        transport,
      ).run(mutation: 'session.delete', session: 'session-secret');
      expect(
        transport.sent.where((r) => r['method'] == 'session.delete').length,
        1,
      );
      expect(transport.sent.length, 6);
      expect(jsonEncode(report), contains('uncertain_do_not_replay'));
      expect(transport.closed, true);
    },
  );

  test(
    'authentication refusal differs from transport failure and stops reads',
    () async {
      for (final kind in ['authentication_refused', 'redirect_refused']) {
        final transport = FakeTransport()..failure = ProbeFailure(kind);
        final report = await ArrangementProbe(config(), transport).run();
        expect(jsonEncode(report), contains(kind));
        expect(transport.sent, isEmpty);
        expect(transport.closed, true);
      }
    },
  );

  test(
    'network REST and WebSocket refuse redirects without contacting target',
    () async {
      final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var leaked = 0;
      final targetSub = target.listen((request) {
        leaked++;
        request.response.close();
      });
      final sourceSub = source.listen((request) {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          'location',
          'http://127.0.0.1:${target.port}/',
        );
        request.response.close();
      });
      final transport = NetworkProbeTransport(
        config(origin: Uri.parse('http://127.0.0.1:${source.port}')),
      );
      try {
        await expectLater(
          transport.profiles(),
          throwsA(
            isA<ProbeFailure>().having(
              (f) => f.kind,
              'kind',
              'redirect_refused',
            ),
          ),
        );
        await expectLater(
          transport.connect(),
          throwsA(
            isA<ProbeFailure>().having(
              (f) => f.kind,
              'kind',
              'redirect_refused',
            ),
          ),
        );
        expect(leaked, 0);
      } finally {
        await transport.close();
        await sourceSub.cancel();
        await targetSub.cancel();
        await source.close(force: true);
        await target.close(force: true);
      }
    },
  );

  test(
    'bounded deadline closes on read stall without sending a mutation',
    () async {
      final transport = FakeTransport()..respond = (_) {};
      final report = await ArrangementProbe(
        config(authorized: true, timeout: const Duration(milliseconds: 20)),
        transport,
      ).run(mutation: 'session.delete', session: 'session-secret');
      expect(transport.sent.length, 1);
      expect(transport.sent.single['method'], 'gateway.capabilities');
      expect(jsonEncode(report), contains('not_sent'));
      expect(transport.closed, true);
    },
  );

  test(
    'configuration rejects URL credentials, query, invalid identity and auth',
    () {
      for (final origin in [
        'https://user:secret@example.invalid',
        'https://example.invalid/?token=secret',
        'file:///tmp',
        'https://example.invalid/base',
      ]) {
        expect(
          () => config(origin: Uri.parse(origin)),
          throwsA(isA<ProbeFailure>()),
        );
      }
    },
  );
}
