// Captures locales, selon le mécanisme de activity_capture.dart :
// flutter test test/support/attachment_capture.dart
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/features/conversation/draft_view.dart';
import 'package:hermes_mobile/features/conversation/draft_view_model.dart';
import 'package:hermes_mobile/features/profiles/profile_accents.dart';
import 'package:hermes_mobile/models/attachment.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/ui/theme.dart';

import 'connection_fakes.dart';

class CapturePicker implements AttachmentPicker {
  @override
  Future<List<PickedFile>> pick(AttachmentSource source) async => const [];
}

void main() {
  testWidgets('captures du composer avec PNG et PDF, 375 px clair/sombre', (
    tester,
  ) async {
    final config = File('.dart_tool/package_config.json');
    final packages =
        (jsonDecode(config.readAsStringSync())
                as Map<String, dynamic>)['packages']
            as List;
    final flutterPackage = packages.cast<Map<String, dynamic>>().singleWhere(
      (p) => p['name'] == 'flutter',
    );
    final sdk = Directory.fromUri(
      config.absolute.uri.resolve(flutterPackage['rootUri'] as String),
    ).parent.parent;
    for (final entry in {
      'Inter': 'assets/fonts/inter-400.ttf',
      'MaterialIcons':
          '${sdk.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(File(entry.value).readAsBytesSync()),
            ),
          ))
          .load();
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);
    final output = Directory(
      '_bmad-output/implementation-artifacts/story-4-2-verification/captures',
    )..createSync(recursive: true);
    final temporary = Directory.systemTemp.createTempSync(
      'attachment-capture-',
    );
    final png = File('${temporary.path}/local-image');
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 96, 96),
        Paint()..color = const Color(0xFFBFE5F6),
      );
      canvas.drawCircle(
        const Offset(70, 25),
        12,
        Paint()..color = const Color(0xFFFFCF66),
      );
      canvas.drawPath(
        Path()
          ..moveTo(0, 96)
          ..lineTo(38, 35)
          ..lineTo(80, 96)
          ..close(),
        Paint()..color = const Color(0xFF278F7C),
      );
      final picture = recorder.endRecording();
      final fixture = await picture.toImage(96, 96);
      final bytes = await fixture.toByteData(format: ui.ImageByteFormat.png);
      await png.writeAsBytes(bytes!.buffer.asUint8List());
      fixture.dispose();
      picture.dispose();
    });
    // Charger l’image dans la boucle réelle avant le premier Image.file,
    // pour que la capture n’attende pas une lecture démarrée en temps simulé.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(
      () => precacheImage(
        ResizeImage(FileImage(png), width: 192),
        tester.element(find.byType(SizedBox).last),
      ),
    );
    for (final brightness in Brightness.values) {
      final h = Harness();
      final outbox = MemoryOutbox();
      final draft = await outbox.openNewDraft(
        const ConnectionKey('capture'),
        const ProfileKey('default'),
      );
      await outbox.saveText(draft.key, 'Peux-tu comparer ces deux fichiers ?');
      outbox.pieces[draft.key] = [
        Attachment(
          key: 'local-image',
          name: 'capture.png',
          mediaType: 'image/png',
          bytes: png.lengthSync(),
          localPath: png.path,
        ),
        const Attachment(
          key: 'local-pdf',
          name: 'rapport.pdf',
          mediaType: 'application/pdf',
          bytes: 5242996,
          localPath: 'synthetic-private-pdf',
        ),
      ];
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(null, brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: RepaintBoundary(key: boundary, child: child!),
          ),
          home: DraftView(
            accents: ProfileAccents(h.repository),
            create: () => DraftViewModel(
              outbox: outbox,
              gateway: h.repository,
              conversation: MemoryConversation(),
              key: draft.key,
              picker: CapturePicker(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final picture =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File('${output.path}/composer-${brightness.name}-375.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await h.repository.dispose();
    }
    PaintingBinding.instance.imageCache.clear();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await temporary.delete(recursive: true);
    });
  });
}
