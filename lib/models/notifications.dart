import 'connection.dart';
import 'profile.dart';

enum NotificationAvailability { unconfigured, denied, unavailable, ready }

/// Seul format accepté pour un `sessionId` (id stocké Hermes, borné à 256
/// comme le plugin `hermes-mobile-notify`).
bool isSessionId(Object? value) =>
    value is String && RegExp(r'^[A-Za-z0-9_.:-]{1,256}$').hasMatch(value);

/// Association locale d'une session touchée : un indice d'ouverture, jamais un état.
typedef NotificationTarget = ({
  ConnectionKey connection,
  ProfileKey profile,
  String? session,
});

abstract interface class NotificationClient {
  NotificationAvailability get availability;
  Future<String?> token({bool requestPermission = false});
  Stream<String> get rotations;

  /// `sessionId` d'une notification touchée pendant que l'app tourne.
  Stream<String> get opened;

  /// `sessionId` de la notification qui a lancé l'app, consommé une fois.
  Future<String?> takeOpened();
  Future<void> dispose();
}
