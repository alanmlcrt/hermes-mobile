import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../models/app_error.dart';
import '../models/attachment.dart';

class DeviceAttachmentPicker implements AttachmentPicker {
  const DeviceAttachmentPicker();
  @override
  Future<List<PickedFile>> pick(AttachmentSource source) async {
    try {
      final result = await FilePicker.pickFiles(
        // La photothèque native est distincte du sélecteur de fichiers.
        // Le repository refuse toujours les formats d’image non mesurés.
        type: source == AttachmentSource.photos ? FileType.image : FileType.any,
        darwinOptions: const DarwinOptions(
          assetRepresentationMode: DarwinAssetRepresentationMode.current,
        ),
      );
      return [
        for (final f in result)
          PickedFile(
            name: f.name,
            mediaType: mediaType(f.extension),
            path: f.path,
          ),
      ];
    } on PlatformException catch (e) {
      throw AppError(
        e.code.toLowerCase().contains('permission') ||
                e.code.toLowerCase().contains('denied')
            ? 'attachment.permission'
            : 'attachment.selection',
      );
    } catch (_) {
      throw const AppError('attachment.selection');
    }
  }

  static String mediaType(String? extension) => switch (extension
      ?.toLowerCase()) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    _ => 'application/octet-stream',
  };
}
