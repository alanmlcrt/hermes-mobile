import 'connection.dart';
import 'profile.dart';
import 'timeline.dart';

const roomPollInterval = Duration(seconds: 3);

abstract interface class RoomGateway {
  String newId();
  Future<RoomSummary> create(RoomKey key, String name, Set<ProfileKey> members);
  Future<RoomSummary> find(RoomKey key);
  Future<RoomSnapshot> load(RoomKey key);
  Future<RoomSnapshot?> cached(RoomKey key);
  Future<RoomCapabilities> capabilities(
    ConnectionKey connection,
    ProfileKey profile,
  );
  Future<List<RoomSummary>> list(ConnectionKey connection, ProfileKey profile);
}

/// Identité complète, opaque et sensible à la casse ; distincte d'une session.
class RoomKey {
  const RoomKey(this.connection, this.profile, this.room);
  final ConnectionKey connection;
  final ProfileKey profile;
  final String room;
  List<String> get args => [connection.value, profile.value, room];
  @override
  bool operator ==(Object other) =>
      other is RoomKey &&
      other.connection == connection &&
      other.profile == profile &&
      other.room == room;
  @override
  int get hashCode => Object.hash(connection, profile, room);
}

class RoomMember {
  const RoomMember(this.id, this.profile, this.name, this.handle);
  final String id;
  final ProfileKey profile;
  final String name;
  final String handle;
}

class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.name,
    this.members = const [],
    this.updatedAt,
    this.preview,
    this.working = false,
  });
  final String id;
  final String name;
  final List<RoomMember> members;
  final DateTime? updatedAt;
  final String? preview;
  final bool working;
}

enum RoomFeature { create, send, stop, retry, discard, approve }

class RoomCapabilities {
  const RoomCapabilities(
    this.driver,
    this.methods,
    this.profiles, [
    this.available = const {},
  ]);
  final bool driver;
  final Set<String> methods;
  final Set<ProfileKey> profiles;
  final Set<RoomFeature> available;
}

class RoomEntry {
  const RoomEntry({
    required this.id,
    required this.seq,
    required this.member,
    this.text = '',
    this.fromUser = false,
    this.activity,
    this.completed = false,
    this.details = const {},
    this.needsUser = false,
  });
  final String id;
  final int seq;
  final String member;
  final String text;
  final bool fromUser;
  final ActivityKind? activity;
  final bool completed;
  final Map<String, Object?> details;
  final bool needsUser;
}

class RoomSnapshot {
  const RoomSnapshot(
    this.room,
    this.entries, {
    this.working = false,
    this.waiting = false,
  });
  final RoomSummary room;
  final List<RoomEntry> entries;
  final bool working;
  final bool waiting;
}

class RoomSend {
  const RoomSend(this.eventId, this.text, this.state);
  final String eventId;
  final String text;
  final String state;
}

abstract interface class RoomOutbox {
  Future<void> reconcileRoom(RoomKey key, Set<String> eventIds);
  Future<String> roomText(RoomKey key);
  Future<void> saveRoomText(RoomKey key, String text);
  Future<List<RoomSend>> roomSends(RoomKey key);
  Future<void> sendRoom(RoomKey key, String text);
}
