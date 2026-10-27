import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes_mobile/app/routes.dart';
import 'package:hermes_mobile/data/notification_repository.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/main.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/notifications.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'notification_repository_test.dart' show Device;
import 'support/connection_fakes.dart';

const _default = ProfileKey('default');
const _travail = ProfileKey('travail');
const _known = 'subscription-known-000000000';
const _otherConnection = 'subscription-other-connection';
const _noSession = 'subscription-no-session-00000';
const _goneProfile = 'subscription-gone-profile-000';
const _unknown = 'subscription-unknown-00000000';

/// Base jamais touchée : seules les associations de [_Targets] répondent.
class _NoDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('database');
}

/// Associations conservées par 5.3, sans SQLite dans les tests de widgets.
class _Targets extends NotificationRepository {
  _Targets(Device device) : super(_NoDatabase(), MemorySecrets(), device);
  final targets = <String, NotificationTarget>{};
  final lookups = <String>[];
  Completer<void>? gate;
  @override
  Future<NotificationTarget?> target(String subscriptionId) async {
    lookups.add(subscriptionId);
    await gate?.future;
    return targets[subscriptionId];
  }
}

void main() {
  sqfliteFfiInit();

  group('ouverture depuis une notification', () {
    late Harness h;
    late Device device;
    late _Targets notifications;
    late MemoryConversation memory;
    late ConnectionKey connection;

    Future<void> launched() async {
      final previous = Harness();
      await previous.connect();
      h = Harness();
      h.store.value = previous.store.value;
      h.secrets.values.addAll(previous.secrets.values);
      connection = h.store.value!.key;
      device = Device();
      notifications = _Targets(device);
      notifications.targets.addAll({
        _known: (connection: connection, profile: _travail, session: 'abc'),
        _otherConnection: (
          connection: const ConnectionKey('autre'),
          profile: _travail,
          session: 'abc',
        ),
        _noSession: (connection: connection, profile: _travail, session: null),
        _goneProfile: (
          connection: connection,
          profile: const ProfileKey('disparu'),
          session: 'abc',
        ),
      });
      memory = MemoryConversation();
    }

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        MainApp(
          gateway: h.repository,
          outbox: MemoryOutbox(),
          conversation: memory,
          notifications: notifications,
        ),
      );
      await tester.pumpAndSettle();
    }

    GoRouter router(WidgetTester tester) =>
        GoRouter.of(tester.element(find.byType(Scaffold).first));
    String location(WidgetTester tester) =>
        router(tester).routerDelegate.currentConfiguration.uri.toString();
    Future<void> tap(WidgetTester tester, String id) async {
      device.taps.add(id);
      await tester.pumpAndSettle();
    }

    tearDown(() async {
      await device.dispose();
    });

    testWidgets(
      'à chaud depuis un autre fil : la cible remplace le fil, rechargée via Hermes',
      (tester) async {
        await launched();
        await pumpApp(tester);
        router(tester).go(conversationPath(connection, _default, 'courant'));
        await tester.pumpAndSettle();
        await tap(tester, _known);
        expect(location(tester), conversationPath(connection, _travail, 'abc'));
        expect(memory.loaded.last, TimelineKey(connection, _travail, 'abc'));
        expect(find.text(Content.notificationTargetMissing), findsNothing);
        // Le même toucher ne rouvre rien une fois consommé.
        router(tester).go('/');
        await tester.pumpAndSettle();
        unawaited(h.repository.refreshProfiles());
        await tester.pumpAndSettle();
        expect(Uri.parse(location(tester)).path, '/');
        expect(notifications.lookups, [_known]);
      },
    );

    testWidgets(
      'à froid, restauration échouée : la cible attend la reconnexion puis s\'ouvre une fois',
      (tester) async {
        await launched();
        h.transport.refreshStatus = 401;
        h.transport.loginStatus = 401;
        device.launch = _known;
        await pumpApp(tester);
        expect(h.repository.snapshot.authenticated, isFalse);
        expect(find.text(Content.connectTitle), findsOne);
        expect(notifications.lookups, isEmpty);
        h.transport.refreshStatus = 200;
        h.transport.loginStatus = 200;
        unawaited(h.repository.authenticate('<SYNTHETIC_PASSWORD>'));
        await tester.pumpAndSettle();
        expect(location(tester), conversationPath(connection, _travail, 'abc'));
        expect(memory.loaded, [TimelineKey(connection, _travail, 'abc')]);
        // Retour d'authentification ultérieur : aucune seconde ouverture.
        router(tester).go('/');
        await tester.pumpAndSettle();
        unawaited(h.repository.authenticate('<SYNTHETIC_PASSWORD>'));
        await tester.pumpAndSettle();
        expect(Uri.parse(location(tester)).path, '/');
        expect(notifications.lookups, [_known]);
        expect(device.launch, isNull);
      },
    );

    testWidgets(
      'profils en échec : la cible attend, un chargement réussi l’ouvre une fois',
      (tester) async {
        await launched();
        h.transport.profilesStatus = 500;
        await pumpApp(tester);
        expect(h.repository.snapshot.authenticated, isTrue);
        expect(h.repository.snapshot.profilesState, ProfilesState.error);
        await tap(tester, _known);
        expect(notifications.lookups, isEmpty);
        expect(find.text(Content.notificationTargetMissing), findsNothing);
        h.transport.profilesStatus = 200;
        unawaited(h.repository.refreshProfiles());
        await tester.pumpAndSettle();
        expect(location(tester), conversationPath(connection, _travail, 'abc'));
        expect(notifications.lookups, [_known]);
        router(tester).go('/');
        await tester.pumpAndSettle();
        unawaited(h.repository.refreshProfiles());
        await tester.pumpAndSettle();
        expect(Uri.parse(location(tester)).path, '/');
        expect(notifications.lookups, [_known]);
      },
    );

    testWidgets(
      'authentification perdue pendant la résolution : la cible attend puis s’ouvre une fois',
      (tester) async {
        await launched();
        // Sans socket, la session reste interruptible par un refus d'auth.
        h.transport.ticketStatus = 500;
        await pumpApp(tester);
        final gate = notifications.gate = Completer<void>();
        await tap(tester, _known);
        expect(notifications.lookups, [_known]);
        h.transport.profilesStatus = 401;
        h.transport.refreshStatus = 401;
        h.transport.loginStatus = 401;
        unawaited(h.repository.refreshProfiles());
        await tester.pumpAndSettle();
        expect(h.repository.snapshot.authenticated, isFalse);
        notifications.gate = null;
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text(Content.connectTitle), findsOne);
        expect(find.text(Content.notificationTargetMissing), findsNothing);
        h.transport.profilesStatus = 200;
        h.transport.refreshStatus = 200;
        h.transport.loginStatus = 200;
        unawaited(h.repository.authenticate('<SYNTHETIC_PASSWORD>'));
        await tester.pumpAndSettle();
        expect(location(tester), conversationPath(connection, _travail, 'abc'));
        expect(memory.loaded, [TimelineKey(connection, _travail, 'abc')]);
        expect(notifications.lookups, [_known, _known]);
        router(tester).go('/');
        await tester.pumpAndSettle();
        unawaited(h.repository.authenticate('<SYNTHETIC_PASSWORD>'));
        await tester.pumpAndSettle();
        expect(Uri.parse(location(tester)).path, '/');
        expect(notifications.lookups, [_known, _known]);
      },
    );

    testWidgets('à froid, app restaurée : la cible s\'ouvre directement', (
      tester,
    ) async {
      await launched();
      device.launch = _known;
      await pumpApp(tester);
      expect(location(tester), conversationPath(connection, _travail, 'abc'));
    });

    for (final (cause, id) in [
      ('id inconnu', _unknown),
      ('autre connexion', _otherConnection),
      ('session nulle', _noSession),
      ('profil disparu', _goneProfile),
    ]) {
      testWidgets(
        'cible absente ($cause) : message annoncé, l\'accueil remplace le fil',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await launched();
          await pumpApp(tester);
          router(tester).go(conversationPath(connection, _default, 'courant'));
          await tester.pumpAndSettle();
          final before = memory.loaded.length;
          device.taps.add(id);
          await tester.pump();
          await tester.pump();
          expect(find.text(Content.notificationTargetMissing), findsOne);
          expect(
            find.ancestor(
              of: find.text(Content.notificationTargetMissing),
              matching: find.byWidgetPredicate(
                (w) => w is Semantics && (w.properties.liveRegion ?? false),
              ),
            ),
            findsWidgets,
          );
          await tester.pumpAndSettle();
          expect(Uri.parse(location(tester)).path, '/');
          expect(memory.loaded.length, before);
          semantics.dispose();
        },
      );
    }

    testWidgets('id invalide ou absent : ignoré, lancement habituel', (
      tester,
    ) async {
      await launched();
      device.launch = 'court';
      await pumpApp(tester);
      expect(Uri.parse(location(tester)).path, '/');
      final current = conversationPath(connection, _default, 'courant');
      router(tester).go(current);
      await tester.pumpAndSettle();
      for (final id in ['', 'invalide avec espaces', 'a' * 129, '../../x']) {
        await tap(tester, id);
      }
      expect(location(tester), current);
      expect(notifications.lookups, isEmpty);
      expect(find.text(Content.notificationTargetMissing), findsNothing);
    });
  });

  group('resolveLaunchTarget', () {
    test('sans authentification, la cible attend (null, aucun message)', () async {
      final h = Harness();
      var explained = 0;
      final path = await resolveLaunchTarget(
        h.repository,
        MemoryOutbox(),
        notification: Future.value((
          connection: const ConnectionKey('c'),
          profile: _default,
          session: 'abc',
        )),
        onMissingTarget: () => explained++,
      );
      expect(path, isNull);
      expect(explained, 0);
    });
  });

  group('NotificationRepository.target sur SQLite en mémoire', () {
    late Database db;
    late NotificationRepository repository;
    late Device device;
    setUp(() async {
      db = await openConnectionDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      device = Device();
      repository = NotificationRepository(db, MemorySecrets(), device);
      var n = 0;
      for (final (id, stored, state) in [
        (_known, 'Abc', 'attached'),
        (_noSession, null, 'unfollowed'),
        (_goneProfile, 'abc', 'expired'),
        (_otherConnection, 'abc', 'revoked'),
      ]) {
        await db.insert('notification_subscriptions', {
          'subscription_id': id,
          'operation_key': 'operation-${n++}',
          'connection_key': 'c-1',
          'profile_key': 'travail',
          'session_id': 'runtime-must-not-route',
          'stored_session_id': stored,
          'state': state,
          'created_at': DateTime.utc(2026, 10, 27).toIso8601String(),
        });
      }
    });
    tearDown(() async {
      await repository.dispose();
      await db.close();
    });

    test('connexion, profil et session stockée ; jamais l\'id runtime', () async {
      final target = await repository.target(_known);
      expect(target?.connection, const ConnectionKey('c-1'));
      expect(target?.profile, _travail);
      expect(target?.session, 'Abc');
      expect((await repository.target(_noSession))?.session, isNull);
    });

    test('états expired et revoked restent des indices valides', () async {
      expect((await repository.target(_goneProfile))?.session, 'abc');
      expect((await repository.target(_otherConnection))?.session, 'abc');
    });

    test('inconnu, casse différente ou invalide : null', () async {
      expect(await repository.target(_unknown), isNull);
      expect(await repository.target(_known.toUpperCase()), isNull);
      expect(await repository.target("x' OR 1=1 --"), isNull);
      expect(await repository.target(''), isNull);
    });
  });
}
