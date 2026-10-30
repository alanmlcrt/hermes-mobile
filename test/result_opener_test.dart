import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/result_opener.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:open_filex/open_filex.dart';

void main() {
  test('ouverture réussie : chemin et type transmis, aucune erreur', () async {
    final calls = <({String path, String? mediaType})>[];
    final opener = DeviceResultOpener((path, mediaType) async {
      calls.add((path: path, mediaType: mediaType));
      return ResultType.done;
    });

    await opener.open('/tmp/x.pdf', 'application/pdf');
    expect(calls.single, (path: '/tmp/x.pdf', mediaType: 'application/pdf'));

    await opener.open('/tmp/x.pdf', '');
    expect(calls.last.mediaType, isNull);
  });

  test('fichier absent ou refus de permission : copie illisible', () async {
    for (final type in [ResultType.fileNotFound, ResultType.permissionDenied]) {
      await expectLater(
        DeviceResultOpener((_, _) async => type).open('/tmp/x.pdf', null),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'result.unreadable',
          ),
        ),
      );
    }
  });

  test('aucune application ou erreur plateforme : result.open', () async {
    for (final type in [ResultType.noAppToOpen, ResultType.error]) {
      await expectLater(
        DeviceResultOpener((_, _) async => type).open('/tmp/x.pdf', null),
        throwsA(
          isA<AppError>().having((error) => error.code, 'code', 'result.open'),
        ),
      );
    }
    await expectLater(
      DeviceResultOpener((_, _) async => throw StateError('canal absent'))
          .open('/tmp/x.pdf', null),
      throwsA(
        isA<AppError>().having((error) => error.code, 'code', 'result.open'),
      ),
    );
  });
}
