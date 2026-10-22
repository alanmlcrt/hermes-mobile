import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/activity_group.dart';
import 'package:hermes_mobile/ui/components/activity_line.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/gallery.dart';
import 'package:hermes_mobile/ui/theme.dart';

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('ACTIVITY_CAPTURES')) return;
    const fonts =
        'C:/Users/alanc/fvm/versions/3.47.7/bin/cache/artifacts/material_fonts';
    for (final entry in {
      'ActivityCapture': 'roboto-regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          File('$fonts/${entry.value}')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  testWidgets('fin neutre, libellé accessible et illustration 24 px', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const ActivityLine(kind: ActivityKind.tool, completed: true),
        ),
      ),
    );
    expect(find.text(Content.activityEnd), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '${Content.activityTool}, ${Content.activityEndAccessible}',
      ),
      findsOneWidget,
    );
    expect(find.text(Content.workSucceeded), findsNothing);
    expect(find.text('Appel d’outil'), findsOneWidget);
    expect(tester.getSize(find.byType(SizedBox).first), const Size(24, 24));
    semantics.dispose();
  });

  testWidgets('commande native 48 px, clavier et sémantique dépliée', (
    tester,
  ) async {
    var expanded = false;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => ActivityGroup(
              count: 2,
              pending: 1,
              expanded: expanded,
              onChanged: (value) => update(() => expanded = value),
            ),
          ),
        ),
      ),
    );
    final label = find.text(Content.activitySummary(2, 1));
    final node = Focus.of(tester.element(label));
    node.requestFocus();
    await tester.pump();
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSemantics(find.byType(ActivityGroup))
          .flagsCollection
          .isExpanded,
      ui.Tristate.isFalse,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(expanded, isTrue);
    expect(node.hasFocus, isTrue);
    expect(
      tester
          .getSemantics(find.byType(ActivityGroup))
          .flagsCollection
          .isExpanded,
      ui.Tristate.isTrue,
    );
    semantics.dispose();
  });

  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 740),
      const Size(375, 812),
      const Size(812, 375),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'galerie activités ${brightness.name} $size texte $scale clavier mouvement réduit',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final boundary = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                theme: buildTheme(null, brightness).copyWith(
                  textTheme: buildTheme(null, brightness).textTheme.apply(
                    fontFamily: const bool.fromEnvironment('ACTIVITY_CAPTURES')
                        ? 'ActivityCapture'
                        : null,
                  ),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                    viewInsets: EdgeInsets.only(bottom: size.height / 3),
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
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.text(GalleryContent.activitySecond),
            );
            await tester.tap(find.text(GalleryContent.activitySecond));
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.text(GalleryContent.activityComplete),
            );
            await tester.tap(find.text(GalleryContent.activityComplete));
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.text(GalleryContent.activityUnknown),
            );
            await tester.tap(find.text(GalleryContent.activityUnknown));
            await tester.pumpAndSettle();
            expect(find.byType(ActivityLine), findsNWidgets(3));
            expect(find.text(Content.activityEnd), findsOneWidget);
            expect(tester.takeException(), isNull);
            Future<void> capture(String phase) async {
              if (!const bool.fromEnvironment('ACTIVITY_CAPTURES')) return;
              await tester.ensureVisible(find.byType(ActivityGroup));
              await tester.pumpAndSettle();
              await tester.runAsync(() async {
                final image =
                    await (boundary.currentContext!.findRenderObject()!
                            as RenderRepaintBoundary)
                        .toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                image.dispose();
                final dir = Directory(
                  '_bmad-output/implementation-artifacts/story-3-1-verification/captures',
                );
                await dir.create(recursive: true);
                await File(
                  '${dir.path}/${brightness.name}-${size.width.toInt()}-${scale.toInt()}-$phase.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
              });
            }

            await capture('expanded');
            await tester.ensureVisible(find.text(GalleryContent.activityReply));
            await tester.tap(find.text(GalleryContent.activityReply));
            await tester.pumpAndSettle();
            expect(find.byType(ActivityLine), findsNothing);
            expect(find.text(Content.activitySummary(3, 2)), findsOneWidget);
            for (final label in [
              GalleryContent.activitySecond,
              GalleryContent.activityUnknown,
            ]) {
              expect(
                tester
                    .widget<TextButton>(find.widgetWithText(TextButton, label))
                    .onPressed,
                isNull,
              );
            }
            expect(tester.takeException(), isNull);
            await capture('collapsed');
          },
        );
      }
    }
  }
}
