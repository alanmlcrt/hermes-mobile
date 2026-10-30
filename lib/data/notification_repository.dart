import 'package:sqflite/sqflite.dart';

import '../models/connection.dart';
import '../models/notifications.dart';
import '../models/profile.dart';

/// Résolution locale d'une notification du plugin vers sa conversation (5.4,
/// 5.7). Le plugin décide d'envoyer ; l'app ne garde aucun abonnement.
class NotificationRepository {
  NotificationRepository(this.database, this.device);
  final Database database;
  final NotificationClient device;

  /// Connexion et profil de la conversation dont l'id stocké est
  /// [sessionId] ; `null` si l'id est invalide, inconnu ou ambigu.
  Future<NotificationTarget?> target(String sessionId) async {
    if (!isSessionId(sessionId)) return null;
    final rows = await database.rawQuery(
      'SELECT connection_key, profile_key FROM conversation_timelines '
      'WHERE stored_session_id = ? '
      'UNION SELECT connection_key, profile_key FROM outbox_drafts '
      'WHERE stored_session_id = ?',
      [sessionId, sessionId],
    );
    if (rows.length != 1) return null;
    final row = rows.single;
    return (
      connection: ConnectionKey(row['connection_key'] as String),
      profile: ProfileKey(row['profile_key'] as String),
      session: sessionId,
    );
  }

  Future<void> dispose() => device.dispose();
}
