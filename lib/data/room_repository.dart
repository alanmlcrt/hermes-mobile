import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/app_error.dart';
import '../models/connection.dart';
import '../models/connection_gateway.dart';
import '../models/profile.dart';
import '../models/room.dart';
import 'hermes_adapter.dart';

/// Un seul accès aux salons ; le dialecte reste dans HermesRpc.
class RoomRepository implements RoomGateway {
  RoomRepository({
    required this.gateway,
    this.database,
    this.timeout = rpcTimeout,
  });
  final Database? database;
  final ConnectionGateway gateway;
  final Duration timeout;
  final _busy = <RoomKey>{};
  final _missing = <(ConnectionKey, ProfileKey, int, String)>{};
  static const whereRoom =
      'connection_key = ? AND profile_key = ? AND room_id = ?';

  @override
  Future<RoomSnapshot> load(RoomKey key) async {
    final state = await call(key, HermesRpc.groupsState);
    final events = <Map<String, dynamic>>[];
    var cursor = 0;
    while (true) {
      final page = HermesRpc.roomLogPage(
        await call(key, HermesRpc.groupsLog, {'since_seq': cursor}),
      );
      events.addAll(page.events);
      if (page.cursor < cursor || (page.more && page.cursor <= cursor)) {
        throw const AppError('room.history');
      }
      cursor = page.cursor;
      if (!page.more) break;
    }
    final snapshot = HermesRpc.roomSnapshot(state, events);
    check(key);
    final db = database;
    if (db != null) {
      await db.transaction((tx) async {
        final old = await tx.query(
          'room_snapshots',
          columns: ['seen_seq'],
          where: whereRoom,
          whereArgs: key.args,
        );
        await tx.insert('room_snapshots', {
          'connection_key': key.connection.value,
          'profile_key': key.profile.value,
          'room_id': key.room,
          'state_json': jsonEncode(state),
          'events_json': jsonEncode(events),
          'seen_seq': old.isEmpty ? 0 : old.single['seen_seq'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    }
    return snapshot;
  }

  @override
  Future<RoomSnapshot?> cached(RoomKey key) async {
    final rows = await database?.query(
      'room_snapshots',
      where: whereRoom,
      whereArgs: key.args,
    );
    if (rows == null || rows.isEmpty) return null;
    return HermesRpc.roomSnapshot(
      jsonDecode(rows.single['state_json'] as String) as Map,
      (jsonDecode(rows.single['events_json'] as String) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  @override
  String newId() => randomUuid();

  @override
  Future<RoomSummary> find(RoomKey key) async =>
      HermesRpc.room((await call(key, HermesRpc.groupsState))['room'] as Map);

  @override
  Future<RoomSummary> create(
    RoomKey key,
    String name,
    Set<ProfileKey> members,
  ) => mutate(key, () async {
    if (name.trim().isEmpty || members.length < 2 || members.length > 6) {
      throw const AppError('room.invalid');
    }
    final caps = await capabilities(key.connection, key.profile);
    if (!caps.driver || !members.every(caps.profiles.contains)) {
      throw const AppError('room.bot_mode');
    }
    if (!caps.methods.contains(HermesRpc.groupsCreate)) {
      throw const AppError('room.missing');
    }
    final result = await call(
      key,
      HermesRpc.groupsCreate,
      HermesRpc.roomCreate(name.trim(), members),
    );
    try {
      final room = HermesRpc.room(result['room'] as Map);
      if (room.id != key.room) throw const AppError('rpc.uncertain');
      return room;
    } catch (_) {
      throw const AppError('rpc.uncertain');
    }
  });

  void check(RoomKey key) {
    if (gateway.snapshot.connection?.key != key.connection ||
        !gateway.snapshot.profiles.any((p) => p.key == key.profile)) {
      throw const AppError('connection.mismatch');
    }
  }

  Future<Map<String, dynamic>> call(
    RoomKey key,
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    check(key);
    final generation = gateway.socketGeneration;
    final missing = (key.connection, key.profile, generation, method);
    if (_missing.contains(missing)) throw const AppError('room.missing');
    try {
      final result = await gateway.call(
        method,
        HermesRpc.roomParams(key, params),
        timeout: timeout,
      );
      check(key);
      if (generation != gateway.socketGeneration) {
        throw const AppError('rpc.uncertain');
      }
      return result;
    } on RpcError catch (e) {
      if (e.code == HermesRpc.methodNotFound) {
        _missing.add(missing);
        throw const AppError('room.missing');
      }
      throw const AppError('room.refused');
    }
  }

  Future<T> mutate<T>(RoomKey key, Future<T> Function() action) async {
    check(key);
    if (!_busy.add(key)) throw const AppError('room.busy');
    try {
      return await action();
    } finally {
      _busy.remove(key);
    }
  }

  @override
  Future<RoomCapabilities> capabilities(
    ConnectionKey connection,
    ProfileKey profile,
  ) async => HermesRpc.roomCapabilities(
    await call(RoomKey(connection, profile, ''), HermesRpc.groupsCapabilities),
  );

  @override
  Future<List<RoomSummary>> list(
    ConnectionKey connection,
    ProfileKey profile,
  ) async {
    final caps = await capabilities(connection, profile);
    if (!caps.driver) throw const AppError('room.bot_mode');
    if (!caps.methods.contains(HermesRpc.groupsList)) {
      throw const AppError('room.missing');
    }
    final key = RoomKey(connection, profile, '');
    final rooms = <RoomSummary>[];
    int? offset;
    final seen = <int>{};
    do {
      final page = await call(key, HermesRpc.groupsList, {'offset': ?offset});
      rooms.addAll(HermesRpc.rooms(page));
      offset = page['next_offset'] as int?;
      if (offset != null && !seen.add(offset)) {
        throw const AppError('contract.invalid_response');
      }
    } while (offset != null);
    return [
      for (final room in rooms)
        await _summary(RoomKey(connection, profile, room.id), room, caps),
    ];
  }

  Future<RoomSummary> _summary(
    RoomKey key,
    RoomSummary room,
    RoomCapabilities caps,
  ) async {
    if (database != null &&
        caps.methods.contains(HermesRpc.groupsState) &&
        caps.methods.contains(HermesRpc.groupsLog)) {
      final snapshot = await load(key);
      return RoomSummary(
        id: room.id,
        name: room.name,
        members: room.members,
        updatedAt: room.updatedAt,
        preview: snapshot.entries
            .where((e) => e.text.isNotEmpty)
            .lastOrNull
            ?.text,
        working: snapshot.working,
      );
    }
    final state = caps.methods.contains(HermesRpc.groupsState)
        ? await call(key, HermesRpc.groupsState)
        : <String, dynamic>{};
    final status = HermesRpc.roomStatus(state);
    final messages = caps.methods.contains(HermesRpc.groupsLog)
        ? HermesRpc.roomMessages(
            await call(key, HermesRpc.groupsLog, {'since_seq': 0}),
          )
        : <String>[];
    return RoomSummary(
      id: room.id,
      name: room.name,
      members: room.members,
      updatedAt: room.updatedAt,
      preview: messages.lastOrNull,
      working: status.working,
    );
  }
}
