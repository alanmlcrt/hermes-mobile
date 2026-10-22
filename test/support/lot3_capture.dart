// Capture reproductible : flutter test test/support/lot3_capture.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/companion_background.dart';
import 'package:hermes_mobile/ui/components/companion_background_editor.dart';
import 'package:hermes_mobile/ui/components/profile_companion_panel.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';

void main() {
  testWidgets('captures du lot 3', (tester) async {
    final textFont = FontLoader('Lot3Capture');
    textFont.addFont(
      Future.value(
        ByteData.sublistView(
          File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
        ),
      ),
    );
    await textFont.load();
    final iconFont = FontLoader('MaterialIcons');
    iconFont.addFont(
      Future.value(
        ByteData.sublistView(
          File(
            'C:/Users/alanc/fvm/versions/3.47.7/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    );
    await iconFont.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    Future<void> capture(String name) async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory(
          '_bmad-output/implementation-artifacts/lot3-visuals',
        );
        await dir.create(recursive: true);
        await File('${dir.path}/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = const Size(375, 812);
        Widget host(Widget child) => MaterialApp(
          theme: buildTheme(null, brightness).copyWith(
            textTheme: buildTheme(
              null,
              brightness,
            ).textTheme.apply(fontFamily: 'Lot3Capture'),
          ),
          builder: (context, route) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: RepaintBoundary(key: boundary, child: route!),
          ),
          home: child,
        );
        final name = '${brightness.name}-${scale == 2 ? '200' : '100'}';
        await tester.pumpWidget(
          host(
            CompanionBackgroundEditor(
              initialPalette: CompanionPalette.mintSky,
              onApply: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture('editor-$name-top');
        await tester.scrollUntilVisible(
          find.text(Content.backgroundApply),
          100,
        );
        await tester.pumpAndSettle();
        await capture('editor-$name-commands');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await capture('editor-$name-focus');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await capture('editor-$name-palette-focus');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          host(
            Scaffold(
              body: SafeArea(
                child: ListView(
                  children: [
                    ProfileCompanionPanel(
                      palette: CompanionPalette.roseLilac,
                      onBackground: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture('panel-$name');
        for (final palette in CompanionPalette.values) {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            host(
              Scaffold(
                body: SafeArea(
                  child: ListView(
                    children: [
                      ProfileCompanionPanel(
                        palette: palette,
                        onBackground: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await capture('palette-${palette.id}-$name');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
