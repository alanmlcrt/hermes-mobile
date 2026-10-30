import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hermes_mobile/data/notification_repository.dart';
import 'package:hermes_mobile/data/firebase_notification_client.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/data/storage/migrations.dart';
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
  int permissionRequests = 0;
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
    if (requestPermission) permissionRequests++;
    return acquire == null ? value : await acquire!();
  }

  @override
  Future<void> dispose() async {
    // Sans attente : un écouteur posé dans la zone d'un testWidgets ne
    // reçoit sa fin qu'au prochain pump, jamais pendant un tearDown.
    unawaited(changes.close());
    unawaited(taps.close());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const connection = ConnectionKey('c-1');
  const profile = ProfileKey('default');
  const stored = TimelineKey(connection, profile, '<SYNTHETIC_STORED_SESSION>');
  late Database db;
  late Directory directory;
  late Harness h;
  late Device device;
  late NotificationRepository notifications;
  late ConversationRepository conversation;
  late OutboxRepository outbox;
  Future<Database> open() => openConnectionDatabase(
    factory: databaseFactoryFfi,
    path: '${directory.path}/db',
  );
  Future<void> wire() async {
    device = Device();
    notifications = NotificationRepository(db, device);
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

  Future<void> close() async {
    await outbox.dispose();
    await conversation.dispose();
    await notifications.dispose();
    await db.close();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('notification-');
    db = await open();
    h = Harness();
    await h.connect();
    await wire();
  });
  tearDown(() async {
    await close();
    await h.repository.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue);
  }

  bool unfollowed() =>
      conversation
          .projection(stored)
          .items
          .whereType<UserItem>()
          .singleOrNull
          ?.notificationUnfollowed ??
      false;

  test('Firebase absent : pas de faux token', () async {
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
      final draft = await sendWith(() => {'type': 'plugin', 'output': 'ok'});
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

    test('plugin absent (4018) : tour marqué « non suivi », relu après réouverture', () async {
      final draft = await sendWith(() => const RpcFail(4018));
      expect(outbox.status(draft.key).state, OperationState.accepted);
      await until(unfollowed);
      expect(
        (await db.query('outbox_operations')).single['notification_unfollowed'],
        1,
      );
      await close();
      db = await open();
      await wire();
      final restored = await conversation.load(stored);
      expect(
        restored.items.whereType<UserItem>().single.notificationUnfollowed,
        isTrue,
      );
    });

    for (final (label, answer) in <(String, Object?)>[
      ('plugin présent', {'type': 'plugin', 'output': 'ok'}),
      ('autre erreur', const RpcFail(5000)),
      ('délai dépassé', null),
    ]) {
      test('$label : aucune marque « non suivie »', () async {
        final draft = await sendWith(() => answer);
        expect(outbox.status(draft.key).state, OperationState.accepted);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await pumpEventQueue();
        expect(
          (await db.query('outbox_operations'))
              .single['notification_unfollowed'],
          0,
        );
        expect(unfollowed(), isFalse);
      });
    }

    test('jeton absent : aucune marque « non suivie »', () async {
      device.value = null;
      final draft = await sendWith(() => fail('aucun appel attendu'));
      expect(outbox.status(draft.key).state, OperationState.accepted);
      expect(
        (await db.query('outbox_operations')).single['notification_unfollowed'],
        0,
      );
    });
  });

  group('NotificationRepository.target', () {
    test(
      'session connue par sa timeline ou son brouillon, sinon null',
      () async {
        final now = DateTime.utc(2026, 10, 29).toIso8601String();
        await db.insert('conversation_timelines', {
          'connection_key': 'c-1',
          'profile_key': 'travail',
          'stored_session_id': '20261029_101500_a1b2c3',
          'projection': '{}',
          'updated_at': now,
        });
        // Même session en timeline et en brouillon : une seule cible.
        for (final (key, session) in [
          ('d-1', '20261029_101500_a1b2c3'),
          ('d-2', 'draft-only.session:1'),
        ]) {
          await db.insert('outbox_drafts', {
            'draft_key': key,
            'connection_key': 'c-1',
            'profile_key': 'travail',
            'body': '',
            'updated_at': now,
            'stored_session_id': session,
          });
        }
        // Même id sur deux profils : ambigu, donc aucune cible.
        for (final p in ['a', 'b']) {
          await db.insert('conversation_timelines', {
            'connection_key': 'c-1',
            'profile_key': p,
            'stored_session_id': 'shared',
            'projection': '{}',
            'updated_at': now,
          });
        }
        final timeline = await notifications.target('20261029_101500_a1b2c3');
        expect(timeline?.connection, const ConnectionKey('c-1'));
        expect(timeline?.profile, const ProfileKey('travail'));
        expect(timeline?.session, '20261029_101500_a1b2c3');
        expect(
          (await notifications.target('draft-only.session:1'))?.session,
          'draft-only.session:1',
        );
        expect(await notifications.target('inconnue'), isNull);
        expect(await notifications.target('20261029_101500_A1B2C3'), isNull);
        expect(await notifications.target('shared'), isNull);
        expect(await notifications.target("x' OR 1=1 --"), isNull);
        expect(await notifications.target(''), isNull);
      },
    );
  });

  group('migration de purge de l’observateur', () {
    late List<List<ConnectionKey>> purged;
    late Future<void> Function(List<ConnectionKey>) original;
    setUp(() {
      original = purgeObserverBearer;
      purged = [];
    });
    tearDown(() => purgeObserverBearer = original);

    Future<Database> legacy(String path) async {
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          // v15 : dernière version avant la migration de purge 5.7 (v16).
          version: 15,
          onCreate: (db, version) async {
            for (var i = 0; i < version; i++) {
              await connectionMigrations[i](db);
            }
          },
        ),
      );
      for (final key in ['c-1', 'c-2']) {
        await old.insert('notification_settings', {
          'connection_key': key,
          'origin': 'https://legacy.test',
          'enabled': 1,
        });
      }
      await old.insert('notification_subscriptions', {
        'subscription_id': 'a' * 22,
        'operation_key': 'op',
        'connection_key': 'c-1',
        'profile_key': 'default',
        'state': 'attached',
        'created_at': DateTime.utc(2026, 10, 27).toIso8601String(),
      });
      await old.close();
      return openConnectionDatabase(factory: databaseFactoryFfi, path: path);
    }

    Future<List<String>> tables(Database db) async => [
      for (final row in await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
        row['name'] as String,
    ];

    test('tables supprimées, bearer purgé pour chaque connexion', () async {
      purgeObserverBearer = (keys) async => purged.add(keys);
      final migrated = await legacy('${directory.path}/legacy');
      expect(await migrated.getVersion(), connectionMigrations.length);
      final names = await tables(migrated);
      expect(names, isNot(contains('notification_settings')));
      expect(names, isNot(contains('notification_subscriptions')));
      expect(names, contains('outbox_operations'));
      expect(purged, [
        [const ConnectionKey('c-1'), const ConnectionKey('c-2')],
      ]);
      await migrated.close();
    });

    test('échec du stockage sécurisé : la migration aboutit', () async {
      purgeObserverBearer = (keys) async => throw StateError('keystore');
      final migrated = await legacy('${directory.path}/failing');
      expect(await migrated.getVersion(), connectionMigrations.length);
      expect(await tables(migrated), isNot(contains('notification_settings')));
      await migrated.close();
    });

    test(
      'purge par défaut : un échec du stockage sécurisé est ignoré',
      () async {
        const storage = MethodChannel(
          'plugins.it_nomads.com/flutter_secure_storage',
        );
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(storage, (call) async {
          calls.add(call);
          throw PlatformException(code: 'keystore');
        });
        addTearDown(() => messenger.setMockMethodCallHandler(storage, null));
        await original([
          const ConnectionKey('c-1'),
          const ConnectionKey('c-2'),
        ]);
        expect(calls.map((c) => c.method), ['delete', 'delete']);
        expect(calls.map((c) => (c.arguments as Map)['key']), [
          'c-1/observerBearer',
          'c-2/observerBearer',
        ]);
      },
    );
  });
}
