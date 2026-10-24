import 'connection.dart';
import 'attachment.dart';
import 'profile.dart';

/// Identité locale d'un brouillon, distincte de toute session Hermes.
class DraftKey {
  const DraftKey(this.value);
  factory DraftKey.create() => DraftKey(randomUuid());
  final String value;
  @override
  bool operator ==(Object other) => other is DraftKey && value == other.value;
  @override
  int get hashCode => value.hashCode;
}

class Draft {
  const Draft({
    required this.key,
    required this.connection,
    required this.profile,
    required this.body,
    this.revision = 0,
    this.storedSessionId,
  });
  final DraftKey key;
  final ConnectionKey connection;
  final ProfileKey profile;
  final String body;

  /// Incrémentée à chaque saisie : seule la version envoyée est retirée.
  final int revision;

  /// Clé durable de la session Hermes, connue dès la première création.
  final String? storedSessionId;
}

/// Identité locale d'une tentative d'envoi, distincte de toute exécution Hermes.
class OperationKey {
  const OperationKey(this.value);
  factory OperationKey.create() => OperationKey(randomUuid());
  final String value;
  @override
  bool operator ==(Object other) =>
      other is OperationKey && value == other.value;
  @override
  int get hashCode => value.hashCode;
}

enum OperationState { preparing, sending, accepted, unknown, failed }

/// État d'envoi d'un brouillon ; [state] nul = aucune opération en cours.
class SendStatus {
  const SendStatus({
    this.state,
    this.errorCode,
    this.retryable = false,
    this.turnActive = false,
  });
  final OperationState? state;
  final String? errorCode;
  final bool retryable;

  /// Un tour est en cours sur la session (`message.start` sans fin).
  final bool turnActive;
  bool get busy =>
      state == OperationState.preparing || state == OperationState.sending;
}

enum StopState { preparing, requested, unknown, failed, stale }

/// Intention locale uniquement ; aucun de ces états n'est un terminal Hermes.
class StopStatus {
  const StopStatus(this.state, {this.errorCode});
  final StopState state;
  final String? errorCode;
}

abstract interface class StopGateway {
  bool canStop(DraftKey key);
  StopStatus? stopStatus(DraftKey key);
  Future<void> stop(DraftKey key);
}

/// Brouillons locaux ; aucun appel Hermes.
abstract interface class OutboxGateway {
  Future<List<AttachmentLimit>> attachmentLimits();
  Future<List<Attachment>> attachments(DraftKey key);
  Future<void> addAttachment(DraftKey key, PickedFile file);
  Future<void> removeAttachment(DraftKey key, String attachmentKey);

  /// Brouillon « nouvelle conversation » du couple, créé s'il n'existe pas.
  /// Ne rend jamais un brouillon qui a déjà une session.
  Future<Draft> openNewDraft(ConnectionKey connection, ProfileKey profile);

  /// Brouillon de suite de la conversation (connexion, profil, session
  /// durable), créé vide s'il n'existe pas ; aucune création de session.
  Future<Draft> openContinuation(
    ConnectionKey connection,
    ProfileKey profile,
    String storedSessionId,
  );
  Future<Draft?> draft(DraftKey key);

  /// Rattache le brouillon neuf [key] à [profile] (une transaction) : un
  /// brouillon neuf vide du profil est supprimé, un non vide échange son
  /// profil avec [key] ; aucun texte n'est perdu. Sans effet sur un brouillon
  /// qui a déjà une session.
  Future<void> reassignNewDraft(DraftKey key, ProfileKey profile);

  /// Écritures sérialisées par brouillon : la dernière saisie gagne.
  Future<void> saveText(DraftKey key, String body);

  SendStatus status(DraftKey key);

  /// Notifie la clé du brouillon dont [status] a changé.
  Stream<DraftKey> get changes;

  /// Persiste l'opération puis exécute le pipeline ; ne renvoie jamais seul.
  Future<void> send(DraftKey key);
  Future<void> dispose();
}
