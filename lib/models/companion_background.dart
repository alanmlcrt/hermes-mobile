import 'connection.dart';
import 'profile.dart';

enum CompanionPalette {
  lavenderPeach('lavender_peach'),
  mintSky('mint_sky'),
  roseLilac('rose_lilac'),
  peachSun('peach_sun'),
  oceanMist('ocean_mist'),
  sageSand('sage_sand'),
  coralRose('coral_rose'),
  pearl('pearl');

  const CompanionPalette(this.id);
  final String id;
  static CompanionPalette fromId(String? id) => values.firstWhere(
    (palette) => palette.id == id,
    orElse: () => lavenderPeach,
  );
}

/// L'origine fait partie de l'identité : une connexion peut changer de serveur.
class CompanionBackgroundIdentity {
  CompanionBackgroundIdentity(Uri origin, this.connection, this.profile)
    : origin = parseOrigin(origin.toString()).toString();
  final String origin;
  final ConnectionKey connection;
  final ProfileKey profile;
  @override
  bool operator ==(Object other) =>
      other is CompanionBackgroundIdentity &&
      origin == other.origin &&
      connection == other.connection &&
      profile == other.profile;
  @override
  int get hashCode => Object.hash(origin, connection, profile);
}

abstract interface class CompanionBackgroundStore {
  Future<CompanionPalette> read(CompanionBackgroundIdentity identity);
  Future<void> save(
    CompanionBackgroundIdentity identity,
    CompanionPalette palette,
  );
}

/// Compatibilité des appelants sans stockage injecté ; aucun état persistant.
class DefaultCompanionBackgroundStore implements CompanionBackgroundStore {
  const DefaultCompanionBackgroundStore();
  @override
  Future<CompanionPalette> read(CompanionBackgroundIdentity identity) async =>
      CompanionPalette.lavenderPeach;
  @override
  Future<void> save(
    CompanionBackgroundIdentity identity,
    CompanionPalette palette,
  ) async => throw StateError('Background storage unavailable');
}
