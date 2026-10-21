import 'connection.dart';
import 'profile.dart';

abstract interface class ConnectionGateway {
  ConnectionSnapshot get snapshot;
  Stream<ConnectionSnapshot> get snapshots;
  Future<void> restore();
  Future<void> confirmOrigin(Uri origin);
  Future<void> authenticate(String password);
  Future<void> refreshProfiles();
  Future<void> selectProfile(ProfileKey key);
  Future<void> reconnect();
  Future<void> dispose();
}
