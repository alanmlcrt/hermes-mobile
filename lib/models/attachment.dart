import 'dart:typed_data';

enum AttachmentState {
  selected,
  uploading,
  uploaded,
  received,
  failed,
  uncertain,
}

enum AttachmentCategory { text, image, pdf, office }

enum AttachmentSource { photos, files }

class Attachment {
  const Attachment({
    required this.key,
    required this.name,
    required this.mediaType,
    required this.bytes,
    required this.localPath,
    this.missing = false,
    this.state = AttachmentState.selected,
    this.reference,
    this.errorCode,
    this.sent = false,
  });
  final String key;
  final String name;
  final String mediaType;
  final int bytes;
  final String localPath;
  final bool missing;
  final AttachmentState state;
  final String? reference;
  final String? errorCode;
  final bool sent;
  bool get isImage => mediaType == 'image/png' || mediaType == 'image/jpeg';
}

class PickedFile {
  const PickedFile({
    required this.name,
    required this.mediaType,
    this.path,
    this.data,
  });
  final String name;
  final String mediaType;
  final String? path;
  final Uint8List? data;
}

class AttachmentLimit {
  const AttachmentLimit(
    this.category,
    this.maxBytes,
    this.mediaTypes, {
    this.maxCount,
  });
  final AttachmentCategory category;
  final int maxBytes;
  final List<String> mediaTypes;
  final int? maxCount;
}

abstract interface class AttachmentPicker {
  Future<List<PickedFile>> pick(AttachmentSource source);
}
