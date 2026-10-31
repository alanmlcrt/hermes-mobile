import 'dart:convert';

import 'connection.dart';
import 'profile.dart';

enum NotificationAvailability { unconfigured, denied, unavailable, ready }

/// Seul format accepté pour un `sessionId` (id stocké Hermes, borné à 256
/// comme le plugin `hermes-mobile-notify`).
bool isSessionId(Object? value) =>
    value is String && RegExp(r'^[A-Za-z0-9_.:-]{1,256}$').hasMatch(value);

bool isRoomId(Object? value) =>
    value is String &&
    value.isNotEmpty &&
    value.length <= 256 &&
    !value.contains(RegExp(r'[\x00-\x1f]'));

/// Transport interne du toucher, distinct de tout identifiant de session.
String roomNotification(String room, String outcome) =>
    jsonEncode({'roomId': room, 'outcome': outcome});
String? notificationRoom(Object? value) {
  if (value is! String) return null;
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map &&
        decoded.length == 2 &&
        isRoomId(decoded['roomId']) &&
        const {'needs_user', 'approval'}.contains(decoded['outcome'])) {
      return decoded['roomId'] as String;
    }
  } catch (_) {
    /* Une session n'est pas une enveloppe de salon. */
  }
  return null;
}

bool isNotificationTarget(Object? value) =>
    isSessionId(value) || notificationRoom(value) != null;

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
