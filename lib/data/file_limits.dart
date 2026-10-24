import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/attachment.dart';

/// Seuls les types observés sont vérifiés ; JPEG est une exception locale.
class FileLimits {
  FileLimits.fromJson(Map<String, dynamic> json)
    : limits = [
        for (final e in (json['limits'] as Map<String, dynamic>).entries)
          AttachmentLimit(
            AttachmentCategory.values.byName(e.key),
            (e.value as Map)['maxBytes'] as int,
            List<String>.from(
              (e.value['observed'] as Map)['mediaTypes'] as List,
            ),
            maxCount: e.value['maxCount'] as int?,
          ),
      ];
  final List<AttachmentLimit> limits;
  static Future<FileLimits> load() async => FileLimits.fromJson(
    jsonDecode(await rootBundle.loadString('contracts/file-limits.json'))
        as Map<String, dynamic>,
  );
  AttachmentCategory? categoryOf(String type) => type == 'image/jpeg'
      ? AttachmentCategory.image
      : limits.where((l) => l.mediaTypes.contains(type)).firstOrNull?.category;
  int? maxBytesFor(String type) =>
      limits.where((l) => l.category == categoryOf(type)).firstOrNull?.maxBytes;
  String? refusal(String type, int bytes) {
    final maximum = maxBytesFor(type);
    if (maximum == null) return 'attachment.type';
    return bytes > maximum ? 'attachment.size' : null;
  }
}
