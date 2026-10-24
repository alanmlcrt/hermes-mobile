import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/attachment_picker.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/attachment.dart';

/// Remplace uniquement la frontière native utilisée par FilePicker.pickFiles.
class PickerPlatform extends FilePickerPlatform {
  PlatformException? error;
  FileType? requestedType;
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    requestedType = type;
    if (error != null) throw error!;
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FilePickerPlatform previous;
  late PickerPlatform platform;
  setUp(() {
    previous = FilePickerPlatform.instance;
    FilePickerPlatform.instance = platform = PickerPlatform();
  });
  tearDown(() {
    FilePickerPlatform.instance = previous;
  });
  test('permission native refusée traduite en AppError', () async {
    platform.error = PlatformException(code: 'photo_access_denied');
    await expectLater(
      const DeviceAttachmentPicker().pick(AttachmentSource.photos),
      throwsA(
        isA<AppError>().having((e) => e.code, 'code', 'attachment.permission'),
      ),
    );
    expect(platform.requestedType, FileType.image);
  });
  test('annulation native : liste vide', () async {
    expect(
      await const DeviceAttachmentPicker().pick(AttachmentSource.files),
      isEmpty,
    );
    expect(platform.requestedType, FileType.any);
  });
}
