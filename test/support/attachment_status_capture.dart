// Captures de vérification de la story 4.3, exécutées explicitement.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/attachment.dart';
import 'package:hermes_mobile/ui/components/attachment_list.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';
import 'package:hermes_mobile/ui/tokens.dart';

void main() {
  testWidgets('états des pièces, clair/sombre et texte à 200 %', (
    tester,
  ) async {
    await (FontLoader('Inter')..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/inter-400.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);
    final output = Directory(
      '_bmad-output/implementation-artifacts/story-4-3-verification/captures',
    )..createSync(recursive: true);
    const pieces = [
      Attachment(
        key: 'failed',
        name: 'Rapport trimestriel.pdf',
        mediaType: 'application/pdf',
        bytes: 5242996,
        localPath: '',
        state: AttachmentState.failed,
        errorCode: 'attachment.refused',
      ),
      Attachment(
        key: 'uploaded',
        name: 'Annexe.pdf',
        mediaType: 'application/pdf',
        bytes: 1048708,
        localPath: '',
        state: AttachmentState.uploaded,
      ),
      Attachment(
        key: 'received',
        name: 'Document reçu.pdf',
        mediaType: 'application/pdf',
        bytes: 7278,
        localPath: '',
        state: AttachmentState.received,
        sent: true,
      ),
    ];
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(null, brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text(Content.attachments)),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: AttachmentList(
                    attachments: scale == 1 ? pieces : [pieces.first],
                    onRetry: (_) {},
                    onRemove: (_) {},
                  ),
                ),
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
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            '${output.path}/etats-${brightness.name}-${scale.toInt()}x.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
    }
  });
}
