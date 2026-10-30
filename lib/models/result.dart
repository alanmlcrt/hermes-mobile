import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';

import 'timeline.dart';

/// Cycle local d'un fichier produit par Hermes : rien n'est récupéré tant
/// qu'Alanc ne le demande pas.
enum ResultState {
  available,
  downloading,
  downloaded,
  failed,
  interrupted;

  static ResultState decode(Object? value) =>
      values.asNameMap()[value] ?? ResultState.available;
}

/// Identité locale stable d'un résultat : jamais le chemin serveur.
abstract final class ResultKey {
  /// La clé vient de l'activité d'origine, pour qu'un rejeu ne crée pas
  /// une seconde carte.
  static String of(String eventKey) =>
      sha256.convert(utf8.encode('result:$eventKey')).toString();
}

/// Décisions permises sur un chemin reçu, sans toucher au texte des réponses.
abstract final class ResultPaths {
  static final _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]+://');
  static final _drive = RegExp(r'^[A-Za-z]:[\\/]');

  /// Absolu au sens de Hermes : `/…` ou `Lettre:\…` ; jamais une URL, un
  /// chemin relatif ni un partage UNC.
  static bool isAbsolute(String path) {
    final value = path.trim();
    if (value.isEmpty || _scheme.hasMatch(value)) return false;
    if (value.startsWith('/')) return !value.startsWith('//');
    return _drive.hasMatch(value);
  }

  /// Dernier segment du chemin, sans dossier ni séparateur final. Un lecteur
  /// seul (`C:\`) n'est pas un nom de fichier.
  static String? name(String path) {
    final value = path.trim();
    final parts = value.split(RegExp(r'[/\\]'));
    for (final part in parts.reversed) {
      final name = part.trim();
      if (name.isEmpty || name == '.' || name == '..') continue;
      if (RegExp(r'^[A-Za-z]:$').hasMatch(name)) return null;
      return name;
    }
    return null;
  }

  /// Type déduit du nom ; le `Content-Type` reçu prend le relais au
  /// téléchargement quand l'extension ne dit rien.
  static String mediaTypeFor(String name) => lookupMimeType(name) ?? '';
}

/// Copie locale obtenue du serveur, avec la taille annoncée par
/// `Content-Length` ; nulle quand le serveur ne l'a pas fournie.
class DownloadedFile {
  const DownloadedFile(this.bytes, {this.mediaType});
  final int? bytes;
  final String? mediaType;
}

/// Téléchargement authentifié d'un fichier déjà écrit par Hermes.
abstract interface class ResultDownloads {
  /// Écrit les octets dans [targetPath] et rend la taille et le type reçus.
  /// Lève `AppError` : `result.missing`, `result.refused`, `auth.refused`,
  /// `transport.server`…
  Future<DownloadedFile> download(
    TimelineKey key,
    String path,
    String targetPath,
  );
}

/// Ouverture par l'application système, jamais automatique.
abstract interface class ResultOpener {
  /// Lève `result.open` si aucune application ne peut ouvrir ce type.
  Future<void> open(String path, String? mediaType);
}
