import 'companion_background.dart';
import 'profile.dart';

/// Couleur d'un profil, choisie dans ses réglages ; locale à l'appareil.
enum ProfileAccent {
  indigo('indigo'),
  blue('blue'),
  sky('sky'),
  teal('teal'),
  mint('mint'),
  emerald('emerald'),
  amber('amber'),
  orange('orange'),
  peach('peach'),
  rose('rose'),
  raspberry('raspberry'),
  violet('violet');

  const ProfileAccent(this.id);
  final String id;

  static ProfileAccent? fromId(String? id) =>
      values.where((a) => a.id == id).firstOrNull;

  /// Couleur stable tant qu'aucune n'est choisie : deux profils voisins ont
  /// rarement la même.
  static ProfileAccent defaultFor(ProfileKey profile) =>
      values[profile.value.codeUnits.fold(0, (a, b) => a + b) % values.length];
}

/// Même identité que l'arrière-plan du compagnon : origine, connexion, profil.
typedef ProfileIdentity = CompanionBackgroundIdentity;

abstract interface class ProfileAccentStore {
  /// `null` : aucune couleur choisie.
  Future<ProfileAccent?> read(ProfileIdentity identity);
  Future<void> save(ProfileIdentity identity, ProfileAccent accent);
}

/// Sans stockage injecté (tests, galerie) : en mémoire seulement.
class MemoryProfileAccentStore implements ProfileAccentStore {
  final values = <ProfileIdentity, ProfileAccent>{};
  @override
  Future<ProfileAccent?> read(ProfileIdentity identity) async =>
      values[identity];
  @override
  Future<void> save(ProfileIdentity identity, ProfileAccent accent) async =>
      values[identity] = accent;
}
