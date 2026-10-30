import 'package:open_filex/open_filex.dart';

import '../models/app_error.dart';
import '../models/result.dart';

/// Ouvre la copie locale avec l'application système adaptée au type.
/// Aucun refus de la plateforme n'est présenté comme une réussite.
class DeviceResultOpener implements ResultOpener {
  /// [open] permet de vérifier la traduction des issues sans plateforme.
  const DeviceResultOpener([this._open]);

  final Future<ResultType> Function(String path, String? mediaType)? _open;

  @override
  Future<void> open(String path, String? mediaType) async {
    final type = mediaType == null || mediaType.isEmpty ? null : mediaType;
    ResultType result;
    try {
      result = _open == null
          ? (await OpenFilex.open(path, type: type)).type
          : await _open(path, type);
    } catch (_) {
      throw const AppError('result.open');
    }
    switch (result) {
      case ResultType.done:
        return;
      case ResultType.fileNotFound || ResultType.permissionDenied:
        throw const AppError('result.unreadable');
      case ResultType.noAppToOpen || ResultType.error:
        throw const AppError('result.open');
    }
  }
}
