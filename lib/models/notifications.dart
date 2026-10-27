import 'connection.dart';
import 'profile.dart';

enum NotificationAvailability { unconfigured, denied, unavailable, ready }

/// Seul format accepté pour un `subscriptionId` (le même que l'observateur).
bool isSubscriptionId(Object? value) =>
    value is String && RegExp(r'^[A-Za-z0-9_-]{22,128}$').hasMatch(value);

/// Association locale d'un suivi : un indice d'ouverture, jamais un état.
typedef NotificationTarget = ({
  ConnectionKey connection,
  ProfileKey profile,
  String? session,
});

abstract interface class NotificationClient {
  NotificationAvailability get availability;
  Future<String?> token({bool requestPermission = false});
  Stream<String> get rotations;

  /// `subscriptionId` d'une notification touchée pendant que l'app tourne.
  Stream<String> get opened;

  /// `subscriptionId` de la notification qui a lancé l'app, consommé une fois.
  Future<String?> takeOpened();
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
