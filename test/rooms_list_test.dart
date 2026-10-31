import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/app/routes.dart';
import 'package:hermes_mobile/data/room_repository.dart';
import 'package:hermes_mobile/features/rooms/rooms_view_model.dart';
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
