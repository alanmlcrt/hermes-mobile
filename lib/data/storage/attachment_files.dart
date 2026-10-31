import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/app_error.dart';
import '../../models/attachment.dart';
import '../../models/draft.dart';

/// Octets privés, jamais nommés avec le nom fourni par le téléphone.
class AttachmentFiles {
  AttachmentFiles({Future<Directory> Function()? root})
    : _root = root ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _root;
  Future<File> file(DraftKey draft, String key) async {
    // Les clés sont des identifiants locaux, jamais des chemins du sélecteur.
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(draft.value) ||
        !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(key)) {
      throw const AppError('storage.unavailable');
    }
    return File('${(await _root()).path}/attachments/${draft.value}/$key');
  }

  Future<int> length(PickedFile picked) async =>
      picked.data?.length ??
      await File(picked.path ?? (throw const AppError('attachment.selection')))
          .length();
  Future<File> copy(
    DraftKey draft,
    String key,
    PickedFile picked,
    int maximum,
  ) async {
    if (await length(picked) > maximum) throw const AppError('attachment.size');
    final target = await file(draft, key);
    await target.parent.create(recursive: true);
    final sink = target.openWrite();
    try {
      var actual = 0;
      final input = picked.data == null
          ? File(picked.path!).openRead()
          : Stream<List<int>>.value(picked.data!);
      await for (final chunk in input) {
        actual += chunk.length;
        if (actual > maximum) throw const AppError('attachment.size');
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      return target;
    } catch (_) {
      try {
        await sink.close();
      } finally {
        if (await target.exists()) await target.delete();
      }
      rethrow;
    }
  }

  /// Toutes les copies privées d'un brouillon (conversation supprimée).
  Future<void> removeDraft(DraftKey draft) async {
    final dir = (await file(draft, 'x')).parent;
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> remove(DraftKey draft, String key) async {
    final target = await file(draft, key);
    if (await target.exists()) await target.delete();
  }
}
