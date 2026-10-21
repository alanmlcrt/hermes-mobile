import 'connection.dart';
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
  });
  final DraftKey key;
  final ConnectionKey connection;
  final ProfileKey profile;
  final String body;
}

/// Brouillons locaux ; aucun appel Hermes.
abstract interface class OutboxGateway {
  /// Brouillon « nouvelle conversation » du couple, créé s'il n'existe pas.
  Future<Draft> openNewDraft(ConnectionKey connection, ProfileKey profile);
  Future<Draft?> draft(DraftKey key);

  /// Écritures sérialisées par brouillon : la dernière saisie gagne.
  Future<void> saveText(DraftKey key, String body);
  Future<void> dispose();
}
