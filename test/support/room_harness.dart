import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/room_repository.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/models/room.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'connection_fakes.dart';
import '../rooms_list_test.dart' show roomCaps, roomData, roomProfile;

export '../rooms_list_test.dart' show roomCaps, roomData, roomProfile, roomCode;

class RoomHarness {
  final h = Harness();
  late Database db;
  late RoomRepository rooms;
  late OutboxRepository outbox;
  late RoomKey key;
  final events = <Map<String, dynamic>>[];
  Map<String, dynamic> driver = {
    'working': false,
    'blocked': false,
    'pending_actions': <Map<String, dynamic>>[],
  };
  Future<void> open() async {
    sqfliteFfiInit();
    db = await openConnectionDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await h.connect();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    key = RoomKey(h.repository.snapshot.connection!.key, roomProfile, 'Room_A');
    rooms = RoomRepository(
      gateway: h.repository,
      database: db,
      timeout: const Duration(milliseconds: 50),
    );
    outbox = OutboxRepository(db, gateway: h.repository)..rooms = rooms;
    h.transport.rpc = rpc;
  }

  Object? rpc(String method, Map<String, dynamic> params) => switch (method) {
    'groups.capabilities' => roomCaps(),
    'groups.list' => {'rooms': [roomData()]},
    'groups.state' => {'room': roomData(), 'driver_status': driver},
    'groups.log' => {
      'events': events
          .where((e) => (e['seq'] as int) > (params['since_seq'] as int))
          .toList(),
      'cursor': events.length,
      'latest_seq': events.length,
      'has_more': false,
    },
    _ => null,
  };
  Map<String, dynamic> event(
    int seq, {
    String text = 'Réponse',
    String kind = 'message.assistant',
    String actor = 'm1',
    String? id,
  }) => {
    'room_id': key.room,
    'seq': seq,
    'event_id': id ?? 'event-$seq',
    'kind': kind,
    'actor': {'kind': 'member', 'id': actor},
    'payload': {'text': text},
    'created_at': 123,
  };
  Future<void> close() async {
    await outbox.dispose();
    await h.repository.dispose();
    await db.close();
  }
}
