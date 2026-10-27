import 'connection.dart';

enum NotificationAvailability { unconfigured, denied, unavailable, ready }

abstract interface class NotificationClient {
  NotificationAvailability get availability;
  Future<String?> token({bool requestPermission = false});
  Stream<String> get rotations;
  Future<void> dispose();
}

class ObserverSettings {
  const ObserverSettings(this.connection, this.origin, this.enabled);
  final ConnectionKey connection;
  final Uri origin;
  final bool enabled;
}

abstract interface class NotificationGateway {
  NotificationClient get device;
  Future<ObserverSettings?> settings(ConnectionKey key);
  Future<void> configure(ConnectionKey key, Uri origin, String bearer);
  Future<bool> enable(ConnectionKey key);
  Future<void> disable(ConnectionKey key);
  Future<String> health(ConnectionKey key);
}
