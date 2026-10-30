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
    this.cleaned = false,
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

  /// Receipt metadata survives removal of the private copy.
  final bool cleaned;
  bool get isImage => mediaType == 'image/png' || mediaType == 'image/jpeg';

  Map<String, Object?> toJson() => {
    'key': key,
    'name': name,
    'mediaType': mediaType,
    'bytes': bytes,
    'state': state.name,
    'sent': sent,
    'cleaned': cleaned,
  };

  // Paths and server references are deliberately never restored from JSON.
  factory Attachment.fromJson(Map<String, Object?> json) => Attachment(
    key: json['key'] as String,
    name: json['name'] as String,
    mediaType: json['mediaType'] as String,
    bytes: json['bytes'] as int,
    localPath: '',
    missing: true,
    state: AttachmentState.values.byName(json['state'] as String),
    sent: json['sent'] == true,
    cleaned: json['cleaned'] == true,
  );
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
