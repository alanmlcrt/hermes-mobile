// Capture manuelle : flutter test test/support/lot4_capture.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/conversation_companion.dart';
import 'package:hermes_mobile/ui/components/message_bubble.dart';
import 'package:hermes_mobile/ui/components/work_state_label.dart';
import 'package:hermes_mobile/ui/theme.dart';
import 'package:hermes_mobile/ui/gallery.dart';
import 'package:hermes_mobile/ui/content.dart';

void main() {
  testWidgets('captures lot 4', (tester) async {
    final font = FontLoader('Lot4Capture')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              'C:/Users/alanc/fvm/versions/3.47.7/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = Directory('_bmad-output/implementation-artifacts/lot4-visuals');
    dir.createSync(recursive: true);
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        for (final width in [320.0, 412.0]) {
          tester.view.physicalSize = Size(width, 812);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(null, brightness).copyWith(
                textTheme: buildTheme(
                  null,
                  brightness,
                ).textTheme.apply(fontFamily: 'Lot4Capture'),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(scale),
                ),
                child: RepaintBoundary(key: boundary, child: child!),
              ),
              home: Scaffold(
                appBar: AppBar(title: const Text('Conversation')),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final phase in CompanionPhase.values) ...[
                      ConversationCompanion(
                        phase: phase,
                        child: const MessageBubble(
                          text: 'Voici une réponse Hermes.\n\nLe texte reste lisible pendant le travail.',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const WorkStateLabel(state: WorkState.running),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final picture = await render.toImage();
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${dir.path}/${brightness.name}-${width.toInt()}-${(scale * 100).toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
    final previousHighlight = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlight,
    );
    for (final size in [const Size(375, 812), const Size(812, 375)]) {
      tester.view.physicalSize = size;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(null, Brightness.dark).copyWith(
            textTheme: buildTheme(
              null,
              Brightness.dark,
            ).textTheme.apply(fontFamily: 'Lot4Capture'),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(2),
            ),
            child: RepaintBoundary(key: boundary, child: child!),
          ),
          home: const Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: ConversationCompanionPreview(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text(Content.pauseCompanion)),
      );
      Focus.of(tester.element(find.text(Content.pauseCompanion)))
          .requestFocus();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await render.toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${dir.path}/controls-dark-${size.width.toInt()}-200-focus.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
  });
}
