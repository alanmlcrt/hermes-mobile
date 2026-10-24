import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/file_limits.dart';
import 'package:hermes_mobile/data/attachment_picker.dart';
import 'package:hermes_mobile/models/attachment.dart';

void main() {
  final limits = FileLimits.fromJson(
    jsonDecode(File('contracts/file-limits.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  test('exact contract boundaries and no count cap', () {
    for (final limit in limits.limits) {
      expect(limit.maxCount, isNull);
      for (final type in limit.mediaTypes) {
        expect(limits.refusal(type, limit.maxBytes), isNull);
        expect(limits.refusal(type, limit.maxBytes + 1), 'attachment.size');
        expect(limits.categoryOf(type), limit.category);
      }
    }
  });
  test('JPEG local exception does not mutate observed formats', () {
    expect(limits.categoryOf('image/jpeg'), AttachmentCategory.image);
    expect(limits.maxBytesFor('image/jpeg'), limits.maxBytesFor('image/png'));
    expect(
      limits.limits
          .singleWhere((l) => l.category == AttachmentCategory.image)
          .mediaTypes,
      ['image/png'],
    );
    for (final extension in ['jpg', 'jpeg', 'JPG']) {
      expect(DeviceAttachmentPicker.mediaType(extension), 'image/jpeg');
    }
    for (final type in [
      'image/heic',
      'image/gif',
      'application/zip',
      'image/*',
    ]) {
      expect(limits.refusal(type, 1), 'attachment.type');
    }
  });
}
