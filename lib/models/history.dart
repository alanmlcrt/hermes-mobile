/// Limite de `session.list` : au-delà, seules les plus récentes sont listées.
const sessionListLimit = 200;

/// Ligne de `session.list` : une conversation d'un profil.
class SessionSummary {
  const SessionSummary({
    required this.id,
    this.title,
    this.preview,
    this.startedAt,
    this.messageCount = 0,
  });

  /// Clé durable (`stored_session_id`), opaque et sensible à la casse.
  final String id;
  final String? title;
  final String? preview;
  final DateTime? startedAt;
  final int messageCount;
}
