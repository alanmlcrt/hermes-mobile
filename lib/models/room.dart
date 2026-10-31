import 'connection.dart';
import 'profile.dart';

abstract interface class RoomGateway {
  String newId();
  Future<RoomSummary> create(RoomKey key, String name, Set<ProfileKey> members);
  Future<RoomSummary> find(RoomKey key);
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

class RoomCapabilities {
  const RoomCapabilities(this.driver, this.methods, this.profiles);
  final bool driver;
  final Set<String> methods;
  final Set<ProfileKey> profiles;
}
