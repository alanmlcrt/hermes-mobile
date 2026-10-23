// Captures synthétiques locales : flutter test test/support/activity_catalog_capture.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/gallery.dart';
import 'package:hermes_mobile/ui/theme.dart';

void main() {
  testWidgets('catalogue comparatif synthétique, petit écran et texte 200 %', (
    tester,
  ) async {
    for (final entry in {
      'ActivityCapture': 'C:/Windows/Fonts/segoeui.ttf',
      'MaterialIcons': 'C:/Users/alanc/fvm/versions/3.47.7/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(File(entry.value).readAsBytesSync()),
            ),
          ))
          .load();
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.reset);
    final directory = Directory(
      '_bmad-output/implementation-artifacts/story-3-4-verification/captures',
    )..createSync(recursive: true);
    for (final (name, brightness, scale, reduced) in [
      ('light', Brightness.light, 1.0, false),
      ('dark', Brightness.dark, 1.0, false),
      ('large-text', Brightness.light, 2.0, false),
      ('reduced-motion', Brightness.light, 1.0, true),
      ('dark-large-reduced', Brightness.dark, 2.0, true),
    ]) {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(null, brightness).copyWith(
            textTheme: buildTheme(
              null,
              brightness,
            ).textTheme.apply(fontFamily: 'ActivityCapture'),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduced,
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: const Scaffold(
              body: SingleChildScrollView(child: ActivityPreview()),
            ),
          ),
        ),
      );
      await tester.pump();
      Future<void> capture(String suffix) async {
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${directory.path}/$name-$suffix.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('controls');
      for (final kind in ActivityKind.values) {
        final row = find.byKey(ValueKey('catalogue-${kind.name}'));
        await Scrollable.ensureVisible(tester.element(row), alignment: 0);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump(const Duration(milliseconds: 200));
        expect(row, findsOneWidget);
        if (scale == 2 ||
            [
              ActivityKind.tool,
              ActivityKind.fileRead,
              ActivityKind.imageCreate,
              ActivityKind.skill,
              ActivityKind.unknown,
            ].contains(kind)) {
          await capture(kind.name);
        }
      }
      await tester.ensureVisible(find.text(GalleryContent.pauseActivities));
      await tester.tap(find.text(GalleryContent.pauseActivities));
      await tester.pumpAndSettle();
      expect(find.text(GalleryContent.resumeActivities), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
