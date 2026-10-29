import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hermes_mobile/data/notification_repository.dart';
import 'package:hermes_mobile/data/firebase_notification_client.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/models/notifications.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';

import 'support/connection_fakes.dart';

class Device implements NotificationClient {
  String? value = 'synthetic-device';
  Future<String?> Function()? acquire;
  int reads = 0;
  final changes = StreamController<String>.broadcast();
  @override
  NotificationAvailability get availability => value == null
      ? NotificationAvailability.denied
      : NotificationAvailability.ready;
  @override
  Stream<String> get rotations => changes.stream;
  final taps = StreamController<String>.broadcast();
  String? launch;
  @override
  Stream<String> get opened => taps.stream;
  @override
  Future<String?> takeOpened() async {
    final id = launch;
    launch = null;
    return id;
  }
  @override
  Future<String?> token({bool requestPermission = false}) async {
    reads++;
    return acquire == null ? value : await acquire!();
  }

  @override
  Future<void> dispose() async {
    await changes.close();
    await taps.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const connection = ConnectionKey('c-1');
  const profile = ProfileKey('default');
  late Database db;
  late Directory directory;
  late Harness h;
  late Device device;
  late MemorySecrets secrets;
  late NotificationRepository notifications;
  late ConversationRepository conversation;
  late OutboxRepository outbox;
  late List<http.Request> requests;
  bool stalled = false;
  bool registerCompleted = false;
  Future<http.Response?> Function(http.Request)? respond;
  int status = 200;
  Future<Database> open() => openConnectionDatabase(
    factory: databaseFactoryFfi,
    path: '${directory.path}/db',
  );
  Future<void> wire() async {
    device = Device();
    notifications = NotificationRepository(
      db,
      secrets,
      device,
      client: MockClient((request) async {
        requests.add(request);
        final override = await respond?.call(request);
        if (override != null) return override;
        if (stalled) return Completer<http.Response>().future;
        if (request.method == 'POST' &&
            request.url.path == '/v1/subscriptions') {
          expect(
            (await db.query('notification_subscriptions')).any(
              (row) =>
                  row['subscription_id'] ==
                  jsonDecode(request.body)['subscriptionId'],
            ),
            isTrue,
          );
        }
        if (request.url.path == '/v1/subscriptions' && status == 200) {
          registerCompleted = true;
        }
        return http.Response('{}', status);
      }),
    );
    conversation = ConversationRepository(
      db,
      gateway: h.repository,
      mapping: await EventMapping.load(),
    );
    outbox = OutboxRepository(
      db,
      gateway: h.repository,
      conversation: conversation,
      notifications: notifications,
      timeout: const Duration(milliseconds: 50),
    );
  }

  Future<void> configure() async {
    await notifications.configure(
      connection,
      Uri.parse('https://observer.test'),
      'observer-secret',
    );
    expect(await notifications.enable(connection), isTrue);
  }

  Future<Draft> send({
    bool lost = false,
    bool verifyRegistration = false,
  }) async {
    final draft = await outbox.openNewDraft(connection, profile);
    await outbox.saveText(draft.key, 'private prompt');
    h.transport.rpc = (method, params) {
      if (method == 'prompt.submit' && verifyRegistration) {
        expect(registerCompleted, isTrue);
      }
      return switch (method) {
        'session.create' => Map<String, dynamic>.from(
          fixture('session-create')['result'],
        ),
        'prompt.submit' =>
          lost
              ? const RpcDrop()
              : Map<String, dynamic>.from(fixture('prompt-submit')['result']),
        _ => null,
      };
    };
    await outbox.send(draft.key);
    return draft;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('notification-');
    db = await open();
    h = Harness();
    await h.connect();
    secrets = MemorySecrets();
    requests = [];
    status = 200;
    stalled = false;
    respond = null;
    registerCompleted = false;
    await wire();
  });
  tearDown(() async {
    await outbox.dispose();
    await conversation.dispose();
    await notifications.dispose();
    await h.repository.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  test('register précède submit ; attach utilise la session stockée et la ligne confirmée', () async {
    await configure();
    final draft = await send(verifyRegistration: true);
    expect(outbox.status(draft.key).state, OperationState.accepted);
    final sub = (await db.query('notification_subscriptions')).single;
    expect(sub['state'], 'attached');
    expect(sub['stored_session_id'], '<SYNTHETIC_STORED_SESSION>');
    expect(jsonDecode(requests.last.body), {
      // Essai 5.5 : Hermes ne reprend que l'id stocké (4007 pour le runtime).
      'sessionId': '<SYNTHETIC_STORED_SESSION>',
      'profile': 'default',
      'executionId': base64Url
          .encode(utf8.encode('<SYNTHETIC_STORED_SESSION>:42'))
          .replaceAll('=', ''),
    });
    expect(
      requests.every(
        (r) => r.headers['Authorization'] == 'Bearer observer-secret',
      ),
      isTrue,
    );
    expect(secrets.values.values, contains('observer-secret'));
    expect(
      jsonEncode(await db.query('notification_settings')),
      isNot(contains('observer-secret')),
    );
  });

  test(
    'observateur en panne : envoi accepté, tour non suivi après réouverture',
    () async {
      await configure();
      status = 401;
      final draft = await send();
      expect(outbox.status(draft.key).state, OperationState.accepted);
      final key = TimelineKey(
        connection,
        profile,
        '<SYNTHETIC_STORED_SESSION>',
      );
      expect(
        conversation
            .projection(key)
            .items
            .whereType<UserItem>()
            .single
            .notificationUnfollowed,
        isTrue,
      );
      expect(
        (await db.query('notification_subscriptions')).single['state'],
        'unfollowed',
      );
      await outbox.dispose();
      await conversation.dispose();
      await notifications.dispose();
      await db.close();
      db = await open();
      await wire();
      final restored = await conversation.load(key);
      expect(
        restored.items.whereType<UserItem>().single.notificationUnfollowed,
        isTrue,
      );
      expect((await outbox.draft(draft.key))!.body, isEmpty);
    },
  );

  test('réponse perdue : aucune attache avant rapprochement certain, aucun nouvel envoi', () async {
    await configure();
    final draft = await send(lost: true);
    expect(outbox.status(draft.key).state, OperationState.unknown);
    expect(requests.where((r) => r.url.path.endsWith('/attach')), isEmpty);
    final key = TimelineKey(connection, profile, '<SYNTHETIC_STORED_SESSION>');
    await outbox.reconcile(
      key,
      const Resumed(runtime: 'new-runtime-after-reconnect', running: false),
      [42],
    );
    expect(
      (await db.query('notification_subscriptions')).single['state'],
      'attached',
    );
    expect(
      jsonDecode(requests.last.body)['sessionId'],
      '<SYNTHETIC_STORED_SESSION>',
    );
    expect(
      h.transport.frames.where((f) => f['method'] == 'prompt.submit'),
      hasLength(1),
    );
  });

  test('redémarrage après commit accepted : attache réparée, rotation et révocation reprises', () async {
    await configure();
    await send();
    await db.update('notification_subscriptions', {
      'execution_id': null,
      'state': 'registered',
    });
    await outbox.dispose();
    await conversation.dispose();
    await notifications.dispose();
    await db.close();
    db = await open();
    await wire();
    device.value = 'rotated-device';
    requests.clear();
    await notifications.resume();
    expect(
      (await db.query('notification_subscriptions')).single['state'],
      'attached',
    );
    expect(jsonDecode(requests.first.body)['fcmToken'], 'rotated-device');
    status = 401;
    await notifications.disable(connection);
    expect(
      (await db.query('notification_subscriptions')).single['state'],
      'revokePending',
    );
    await outbox.dispose();
    await conversation.dispose();
    await notifications.dispose();
    await db.close();
    db = await open();
    await wire();
    status = 404;
    await notifications.resume();
    expect(
      (await db.query('notification_subscriptions')).single['state'],
      'revoked',
    );
    expect(requests.last.method, 'DELETE');
  });

  test('deadline réseau : une panne ne bloque pas la soumission', () async {
    await configure();
    stalled = true;
    final clock = Stopwatch()..start();
    final draft = await send();
    expect(outbox.status(draft.key).state, OperationState.accepted);
    expect(clock.elapsed, lessThan(const Duration(seconds: 10)));
    expect(requests.length, lessThanOrEqualTo(2));
    expect(requests.where((r) => r.url.path.endsWith('/attach')), isEmpty);
  });

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue);
  }

  test('nouveau bearer même origine récupère les révocations 401, autre origine protégée', () async {
    await configure();
    await send();
    status = 401;
    await notifications.disable(connection);
    await expectLater(
      notifications.configure(
        connection,
        Uri.parse('https://other.test'),
        'new',
      ),
      throwsFormatException,
    );
    respond = (request) async => http.Response(
      '{}',
      request.headers['Authorization'] == 'Bearer recovered' ? 200 : 401,
    );
    await notifications.configure(
      connection,
      Uri.parse('https://observer.test'),
      'recovered',
    );
    expect(
      (await db.query('notification_subscriptions')).single['state'],
      'revoked',
    );
    expect(requests.last.headers['Authorization'], 'Bearer recovered');
  });

  test('attache tardive : sept jours depuis première réussite, historique préservé', () async {
    await configure();
    final draft = await send(lost: true);
    final old = DateTime.now().toUtc().subtract(const Duration(days: 6));
    await db.update('notification_subscriptions', {
      'created_at': old.toIso8601String(),
    });
    final op = OperationKey(
      (await db.query('outbox_operations')).single['operation_key'] as String,
    );
    await db.update('outbox_operations', {
      'state': 'accepted',
      'user_row_id': 42,
    });
    await notifications.attach(op, 'a1b2c3d4', 42);
    final attached = (await db.query('notification_subscriptions'))
        .single['attached_at'];
    expect(attached, isNot(old.toIso8601String()));
    await notifications.resume();
    expect(
      (await db.query('notification_subscriptions')).single['attached_at'],
      attached,
    );
    expect(
      (await db.query('notification_subscriptions')).single['state'],
      'attached',
    );
    await db.update('notification_subscriptions', {
      'attached_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 8))
          .toIso8601String(),
    });
    await notifications.resume();
    expect(
      (await db.query('notification_subscriptions')).single['state'],
      'expired',
    );
    final key = TimelineKey(connection, profile, '<SYNTHETIC_STORED_SESSION>');
    await conversation.accepted(key, op, draft.body, userRowId: 42);
    expect(
      conversation
          .projection(key)
          .items
          .whereType<UserItem>()
          .single
          .notificationUnfollowed,
      isFalse,
    );
  });

  test(
    'rotation stream automatique, y compris pendant une reprise active',
    () async {
      await configure();
      await send();
      requests.clear();
      final gate = Completer<http.Response>();
      bool waiting = false;
      respond = (request) async {
        if (!waiting && request.url.path == '/v1/subscriptions') {
          waiting = true;
          return gate.future;
        }
        return null;
      };
      device.value = 'rotation-one';
      device.changes.add(device.value!);
      await until(() => waiting);
      device.value = 'rotation-two';
      device.changes.add(device.value!);
      gate.complete(http.Response('{}', 200));
      await until(
        () => requests.any(
          (r) =>
              r.url.path == '/v1/subscriptions' &&
              jsonDecode(r.body)['fcmToken'] == 'rotation-two',
        ),
      );
    },
  );

  test(
    'reprise bornée même avec beaucoup de lignes et acquisition token muette',
    () async {
      await configure();
      await send();
      final seed = Map<String, Object?>.from(
        (await db.query('notification_subscriptions')).single,
      );
      for (var i = 0; i < 30; i++) {
        await db.insert('notification_subscriptions', {
          ...seed,
          'subscription_id': 'synthetic_subscription_number_$i',
          'operation_key': 'op-$i',
          'execution_id': null,
        });
      }
      requests.clear();
      await notifications.resume();
      expect(requests.length, lessThanOrEqualTo(17));
      final reads = device.reads;
      device.acquire = () => Completer<String?>().future;
      final clock = Stopwatch()..start();
      await notifications.resume();
      expect(device.reads, reads + 1);
      expect(clock.elapsed, lessThan(const Duration(seconds: 4)));
    },
  );

  test('acceptation publiée avant réponse du réseau attach', () async {
    await configure();
    final gate = Completer<http.Response>();
    bool waiting = false;
    respond = (request) async {
      if (request.url.path.endsWith('/attach')) {
        waiting = true;
        return gate.future;
      }
      return null;
    };
    final draft = await outbox.openNewDraft(connection, profile);
    await outbox.saveText(draft.key, 'visible immédiatement');
    h.transport.rpc = (method, params) => switch (method) {
      'session.create' => Map<String, dynamic>.from(
        fixture('session-create')['result'],
      ),
      'prompt.submit' => Map<String, dynamic>.from(
        fixture('prompt-submit')['result'],
      ),
      _ => null,
    };
    final sending = outbox.send(draft.key);
    await until(() => waiting);
    expect(outbox.status(draft.key).state, OperationState.accepted);
    final key = TimelineKey(connection, profile, '<SYNTHETIC_STORED_SESSION>');
    expect(
      conversation.projection(key).items.whereType<UserItem>().single.text,
      'visible immédiatement',
    );
    gate.complete(http.Response('{}', 200));
    await sending;
  });

  test('permission relue sans abonnement à la reprise', () async {
    final reads = device.reads;
    device.value = null;
    await notifications.resume();
    expect(device.reads, reads + 1);
    expect(device.availability, NotificationAvailability.denied);
  });

  test('permission refusée et Firebase absent : pas de faux token ni de faux succès', () async {
    device.value = null;
    await notifications.configure(
      connection,
      Uri.parse('https://observer.test'),
      'observer-secret',
    );
    expect(await notifications.enable(connection), isFalse);
    expect(requests, isEmpty);
    final firebase = FirebaseNotificationClient();
    await firebase.initialize();
    expect(firebase.availability, NotificationAvailability.unconfigured);
    expect(await firebase.token(), isNull);
    await firebase.dispose();
  });

  group('jeton FCM pour le plugin de notifications Hermes', () {
    Future<Draft> sendWith(Object? Function() dispatch) async {
      final draft = await outbox.openNewDraft(connection, profile);
      await outbox.saveText(draft.key, 'private prompt');
      h.transport.rpc = (method, params) => switch (method) {
        'session.create' => Map<String, dynamic>.from(
          fixture('session-create')['result'],
        ),
        'command.dispatch' => dispatch(),
        'prompt.submit' => Map<String, dynamic>.from(
          fixture('prompt-submit')['result'],
        ),
        _ => null,
      };
      await outbox.send(draft.key);
      // Partage du jeton lancé sans attente : laisser sa trame partir.
      await pumpEventQueue();
      return draft;
    }

    List<String?> methods() => [
      for (final f in h.transport.frames) f['method'] as String?,
    ];

    test('command.dispatch porte le jeton', () async {
      final draft = await sendWith(
        () => {'type': 'plugin', 'output': 'ok'},
      );
      expect(outbox.status(draft.key).state, OperationState.accepted);
      final frame = h.transport.frames.singleWhere(
        (f) => f['method'] == 'command.dispatch',
      );
      expect(frame['params'], {
        'name': 'hermes-mobile-token',
        'arg': 'synthetic-device',
      });
    });

    for (final (label, answer) in [
      ('refus', const RpcFail(4018)),
      ('silence', null),
    ]) {
      test('$label de la commande : envoi accepté quand même', () async {
        final draft = await sendWith(() => answer);
        expect(outbox.status(draft.key).state, OperationState.accepted);
        expect(methods(), contains('command.dispatch'));
      });
    }

    test('jeton indisponible : aucune commande, envoi accepté', () async {
      device.value = null;
      final draft = await sendWith(() => fail('aucun appel attendu'));
      expect(outbox.status(draft.key).state, OperationState.accepted);
      expect(methods(), isNot(contains('command.dispatch')));
    });

    for (final (label, acquire) in <(String, Future<String?> Function())>[
      ('muet', () => Completer<String?>().future),
      ('en erreur', () => Future<String?>.error(StateError('synthetic'))),
    ]) {
      test('jeton $label : envoi accepté sans attendre', () async {
        device.acquire = acquire;
        final clock = Stopwatch()..start();
        final draft = await sendWith(() => fail('aucun appel attendu'));
        expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
        expect(outbox.status(draft.key).state, OperationState.accepted);
        expect(methods(), contains('prompt.submit'));
        expect(methods(), isNot(contains('command.dispatch')));
      });
    }
  });
}
