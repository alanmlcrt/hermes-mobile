import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/app/routes.dart';
import 'package:hermes_mobile/data/room_repository.dart';
import 'package:hermes_mobile/features/rooms/rooms_view_model.dart';
import 'package:hermes_mobile/features/rooms/rooms_view.dart';
import 'package:hermes_mobile/features/profiles/profile_accents.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/room.dart';

import 'support/connection_fakes.dart';

const roomProfile = ProfileKey('default');
Map<String, dynamic> roomCaps() => {
  'driver': true,
  'methods': [
    'groups.list',
    'groups.create',
    'groups.state',
    'groups.log',
    'groups.send',
    'groups.stop',
    'groups.retry',
    'groups.discard',
    'groups.approve',
  ],
  'seatable_profiles': ['default', 'Second'],
};
Map<String, dynamic> roomData([String id = 'Room_A']) => {
  'room_id': id,
  'name': 'Salon',
  'members': [
    {
      'member_id': 'm1',
      'profile': 'default',
      'display_name': 'Premier',
      'handle': 'premier',
    },
    {
      'member_id': 'm2',
      'profile': 'Second',
      'display_name': 'Second',
      'handle': 'second',
    },
  ],
  'updated_at': 123.0,
};
Matcher roomCode(String code) =>
    isA<AppError>().having((e) => e.code, 'code', code);

void main() {
  test('8.2 liste optionnelle absente : lire les salons et vérifier les marqueurs des seuls profils locaux', () async {
    final h = Harness();
    h.transport.profiles = {
      'profiles': [
        {'name': 'default', 'is_default': true},
        {'name': 'Finance', 'is_default': false},
        {'name': 'Other', 'is_default': false},
      ],
    };
    await h.connect();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final connection = h.repository.snapshot.connection!.key;
    final repo = RoomRepository(
      gateway: h.repository,
      timeout: const Duration(milliseconds: 50),
    );
    final vm = RoomsViewModel(repo, connection, roomProfile);
    var caps = {...roomCaps()}..remove('seatable_profiles');
    h.transport.rpc = (m, p) => switch (m) {
      'groups.capabilities' => caps,
      'profiles.list' => {
        'profiles': [
          {
            'name': 'default',
            'ui_meta': {'hermes-bots': <String, dynamic>{}},
          },
          {
            'name': 'Finance',
            'ui_meta': {
              'hermes-bots': {'title': 'Finance'},
            },
          },
          {
            'name': 'Other',
            'ui_meta': {'hermes-bots': true},
          },
          {
            'name': 'finance',
            'ui_meta': {'hermes-bots': <String, dynamic>{}},
          },
          {
            'name': 'Foreign',
            'ui_meta': {'hermes-bots': <String, dynamic>{}},
          },
        ],
      },
      'groups.list' => {'rooms': []},
      'groups.create' => {
        'room': {...roomData(p['room_id'] as String), 'members': p['members']},
      },
      _ => null,
    };
    await vm.refresh();
    expect(vm.error, isNull);
    expect(vm.canOfferCreate, isTrue);
    expect(vm.diagnostic!.profilesAnnounced, isFalse);
    expect(vm.diagnostic!.rosterChecked, isTrue);
    expect(vm.diagnostic!.profiles, {roomProfile, const ProfileKey('Finance')});
    expect(
      h.transport.frames.lastWhere(
        (f) => f['method'] == 'profiles.list',
      )['params'],
      {'profile': 'default', 'include_sessions': false},
    );
    await vm.prepareCreate();
    vm.setName('Recherche');
    vm.select(roomProfile, true);
    vm.select(const ProfileKey('Finance'), true);
    expect(await vm.create(), isNotNull);
    final before = h.transport.frames
        .where((f) => f['method'] == 'profiles.list')
        .length;
    caps = {...roomCaps(), 'seatable_profiles': <String>[]};
    await vm.refresh();
    expect(
      vm.error,
      isNull,
      reason: 'L’éligibilité ne bloque jamais la lecture',
    );
    expect(vm.canOfferCreate, isFalse);
    expect(
      h.transport.frames.where((f) => f['method'] == 'profiles.list').length,
      before,
      reason: 'Ne jamais contourner une liste explicitement vide',
    );
    vm.dispose();
    await h.repository.dispose();
  });
  test('8.2 métadonnées absentes ou méthode profiles.list absente : lecture seule, aucune création supposée', () async {
    final h = Harness();
    await h.connect();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final connection = h.repository.snapshot.connection!.key;
    final repo = RoomRepository(
      gateway: h.repository,
      timeout: const Duration(milliseconds: 50),
    );
    final vm = RoomsViewModel(repo, connection, roomProfile);
    var absent = false;
    h.transport.rpc = (m, p) => switch (m) {
      'groups.capabilities' => {...roomCaps()}..remove('seatable_profiles'),
      'profiles.list' =>
        absent
            ? const RpcFail(-32601)
            : {
                'profiles': [
                  {'name': 'default'},
                ],
              },
      'groups.list' => {'rooms': []},
      _ => null,
    };
    await vm.refresh();
    expect(vm.error, isNull);
    expect(vm.creationProblem, 'room.eligibility_unknown');
    expect(vm.canOfferCreate, isFalse);
    absent = true;
    await vm.refresh();
    expect(vm.error, isNull);
    expect(vm.canOfferCreate, isFalse);
    final before = h.transport.frames
        .where((f) => f['method'] == 'profiles.list')
        .length;
    await vm.refresh();
    expect(
      h.transport.frames.where((f) => f['method'] == 'profiles.list').length,
      before,
    );
    expect(
      h.transport.frames.where((f) => f['method'] == 'groups.create'),
      isEmpty,
    );
    vm.dispose();
    await h.repository.dispose();
  });
  test(
    '8.2 ne déduit pas Bot Mode de la disponibilité du pilote ou des profils',
    () async {
      final h = Harness();
      await h.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final connection = h.repository.snapshot.connection!.key;
      final repo = RoomRepository(
        gateway: h.repository,
        timeout: const Duration(milliseconds: 50),
      );
      final vm = RoomsViewModel(repo, connection, roomProfile);
      Map<String, dynamic>? reply;
      h.transport.rpc = (m, p) =>
          m == 'groups.capabilities' ? reply : {'rooms': []};
      reply = {
        ...roomCaps(),
        'driver': false,
        'protocol_version': 2,
        'persistent_process': true,
      };
      await vm.refresh();
      expect(vm.error, 'room.driver_missing');
      expect(vm.diagnostic!.driver, isFalse);
      expect(vm.diagnostic!.protocolVersion, 2);
      expect(
        Content.roomCapabilityDetails(vm.diagnostic!),
        contains('Pilote salons : non'),
      );
      expect(
        h.transport.frames.where((f) => f['method'] == 'groups.list'),
        isEmpty,
      );
      expect(
        repo.knownCapabilities(connection, const ProfileKey('Other')),
        isNull,
      );
      expect(
        repo.knownCapabilities(const ConnectionKey('Other'), roomProfile),
        isNull,
      );
      reply = {...roomCaps()}..remove('seatable_profiles');
      await vm.refresh();
      expect(vm.error, isNull);
      expect(vm.creationProblem, 'room.eligibility_unknown');
      expect(vm.diagnostic!.profilesAnnounced, isFalse);
      reply = {...roomCaps(), 'seatable_profiles': <String>[]};
      await vm.refresh();
      expect(vm.error, isNull);
      expect(vm.creationProblem, 'room.no_eligible');
      expect(vm.diagnostic!.profilesAnnounced, isTrue);
      reply = null;
      await vm.refresh();
      expect(vm.error, 'rpc.uncertain');
      expect(
        vm.diagnostic,
        isNull,
        reason: 'Ne pas afficher une ancienne réponse après une coupure',
      );
      reply = roomCaps();
      await vm.refresh();
      expect(vm.error, isNull);
      expect(vm.rooms, isEmpty);
      vm.dispose();
      await h.repository.dispose();
    },
  );
  testWidgets(
    '8.2 diagnostic lisible à 200 %, création masquée et actualisation disponible',
    (tester) async {
      final h = Harness();
      await tester.runAsync(() async {
        await h.connect();
        await Future<void>.delayed(const Duration(milliseconds: 5));
      });
      final connection = h.repository.snapshot.connection!.key;
      h.transport.rpc = (m, p) => {...roomCaps(), 'driver': false};
      final vm = RoomsViewModel(
        RoomRepository(gateway: h.repository),
        connection,
        roomProfile,
      );
      final accents = ProfileAccents(h.repository);
      await tester.runAsync(
        () => tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: RoomsView(
                create: () => vm,
                accents: accents,
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(find.text(Content.newRoom), findsNothing);
      expect(find.textContaining('Pilote salons : non'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(Content.retryList),
        150,
        scrollable: find
            .descendant(
              of: find.byType(RoomsView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text(Content.retryList), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      accents.dispose();
      await tester.runAsync(h.repository.dispose);
    },
  );
  test(
    '8.2 liste, vide, refus, absent, timeout, isolation et route opaque',
    () async {
      final h = Harness();
      await h.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final connection = h.repository.snapshot.connection!.key;
      final repo = RoomRepository(
        gateway: h.repository,
        timeout: const Duration(milliseconds: 50),
      );
      final vm = RoomsViewModel(repo, connection, roomProfile);
      h.transport.rpc = (m, p) => m == 'groups.capabilities'
          ? roomCaps()
          : {
              'rooms': [roomData()],
            };
      await vm.refresh();
      expect(vm.rooms.single.id, 'Room_A');
      expect(vm.rooms.single.members.first.name, 'Premier');
      h.transport.rpc = (m, p) =>
          m == 'groups.capabilities' ? roomCaps() : {'rooms': []};
      await vm.refresh();
      expect(vm.rooms, isEmpty);
      h.transport.rpc = (m, p) => const RpcFail(403);
      await vm.refresh();
      expect(vm.error, 'room.refused');
      h.transport.rpc = (m, p) => null;
      await vm.refresh();
      expect(vm.error, 'rpc.uncertain');
      h.transport.rpc = (m, p) => const RpcFail(-32601);
      await vm.refresh();
      expect(vm.error, 'room.missing');
      await expectLater(
        repo.list(const ConnectionKey('other'), roomProfile),
        throwsA(roomCode('connection.mismatch')),
      );
      final key = RoomKey(connection, roomProfile, 'Room/A?');
      final uri = Uri.parse(roomPath(key));
      expect(uri.pathSegments.last, key.room);
      expect(uri.queryParameters['profile'], 'default');
      expect(RoomKey(connection, roomProfile, 'room/A?'), isNot(key));
      vm.dispose();
      await h.repository.dispose();
    },
  );
}
