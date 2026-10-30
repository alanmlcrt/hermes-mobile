import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/app_error.dart';
import '../../models/timeline.dart';

/// Copies privées des fichiers résultats, séparées des pièces jointes.
/// Aucun segment ne vient tel quel d'un nom ou d'un chemin serveur.
class ResultFiles {
  ResultFiles({Future<Directory> Function()? root})
    : _root = root ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _root;
  static final _safe = RegExp(r'^[a-zA-Z0-9-]+$');

  /// Hache tout identifiant qui ne tient pas dans un seul segment sûr.
  static String segment(String value) => _safe.hasMatch(value)
      ? value
      : sha256.convert(utf8.encode(value)).toString();

  Future<File> file(TimelineKey key, String localKey) async {
    try {
      final connection = segment(key.connection.value);
      final profile = segment(key.profile.value);
      final session = segment(key.session);
      final local = segment(localKey);
      return File(
        '${(await _root()).path}/results/$connection/$profile/$session/$local',
      );
    } catch (_) {
      throw const AppError('storage.unavailable');
    }
  }

  Future<void> remove(TimelineKey key, String localKey) async {
    final target = await file(key, localKey);
    try {
      if (await target.exists()) await target.delete();
      final partial = File('${target.path}.part');
      if (await partial.exists()) await partial.delete();
    } catch (_) {
      throw const AppError('storage.unavailable');
    }
  }
}
