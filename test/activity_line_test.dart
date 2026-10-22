import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/activity_catalog.dart';
import 'package:hermes_mobile/ui/components/activity_group.dart';
import 'package:hermes_mobile/ui/components/activity_line.dart';
import 'package:hermes_mobile/ui/components/activity_details.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/gallery.dart';
import 'package:hermes_mobile/ui/theme.dart';
import 'package:hermes_mobile/ui/tokens.dart';

void main() {
  testWidgets('sortie longue : deux axes, texte intégral et corps sans repli', (
    tester,
  ) async {
    final values = [
      for (var i = 0; i < 60; i++) 'Ligne $i ${'code ' * 30}',
      '[truncated]',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivityLine(
            kind: ActivityKind.tool,
            expanded: true,
            details: {'result': values},
            onChanged: (_) => fail('Le corps ne replie pas la ligne'),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(
      find
          .descendant(
            of: find.byType(SelectionArea),
            matching: find.byType(Text),
          )
          .first,
    );
    expect(text.data, contains('Ligne 59'));
    expect(text.data, contains('[truncated]'));
    final scrolls = find.descendant(
      of: find.byType(ActivityDetails),
      matching: find.byType(Scrollable),
    );
    final vertical = tester
        .stateList<ScrollableState>(scrolls)
        .firstWhere((s) => s.axisDirection == AxisDirection.down);
    final horizontal = tester
        .stateList<ScrollableState>(scrolls)
        .firstWhere((s) => s.axisDirection == AxisDirection.right);
    expect(vertical.position.maxScrollExtent, greaterThan(0));
    expect(horizontal.position.maxScrollExtent, greaterThan(0));
    vertical.position.jumpTo(vertical.position.maxScrollExtent);
    horizontal.position.jumpTo(horizontal.position.maxScrollExtent);
    await tester.pump();
    expect(find.byType(ActivityDetails), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('aucun contenu utilisable : ligne statique sans faux contrôle', (
    tester,
  ) async {
    final details = ActivityDetailFields.decode({
      'name': null,
      'context': [],
      'result': null,
      'inline_diff': false,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivityLine(
            kind: ActivityKind.tool,
            details: details,
            onChanged: (_) => fail('Statique'),
          ),
        ),
      ),
    );
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(ActivityDetails), findsNothing);
    expect(find.text(Content.activityTool), findsOneWidget);
  });
  testWidgets(
    'détails : clavier, état annoncé, sélection et données sans exécution',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var expanded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => ActivityLine(
                kind: ActivityKind.tool,
                details: const {
                  'args': false,
                  'args_text': 'fallback masqué',
                  'result': {'error': 'reçu', 'exit_code': 1},
                  'inline_diff': '- a\n+ b',
                },
                expanded: expanded,
                onChanged: (v) => update(() => expanded = v),
              ),
            ),
          ),
        ),
      );
      final button = find.byType(TextButton);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      final focus = Focus.of(tester.element(find.text(Content.activityTool)));
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(expanded, isTrue);
      expect(focus.hasFocus, isTrue);
      expect(find.text('false'), findsOneWidget);
      expect(find.text('fallback masqué'), findsNothing);
      expect(find.text(Content.detailError), findsOneWidget);
      expect(find.byType(SelectionArea), findsNWidgets(4));
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(Content.activityTool))
            .flagsCollection
            .isExpanded,
        ui.Tristate.isTrue,
      );
      await tester.tap(find.text('false'));
      await tester.pump();
      expect(find.byType(ActivityDetails), findsOneWidget);
      semantics.dispose();
    },
  );

  test(
    'sections : aucune erreur déduite, valeurs et secours présents seulement',
    () {
      expect(
        ActivityDetails.sections({
          'result': {'error': false, 'exit_code': 1},
        }).containsKey(Content.detailError),
        isFalse,
      );
      expect(ActivityDetails.sections({'args': [], 'result': 0}), {
        Content.detailArguments: [],
        Content.detailOutput: 0,
      });
      expect(
        ActivityDetails.sections({
          'args_text': 'reçu',
          'result_text': '[truncated]',
        }),
        {Content.detailArguments: 'reçu', Content.detailOutput: '[truncated]'},
      );
      expect(ActivityDetails.sections({'name': '', 'args': null}), isEmpty);
    },
  );
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
                  '_bmad-output/implementation-artifacts/story-3-3-verification/captures',
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
              GalleryContent.activityCode,
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

  testWidgets(
    'catalogue par ActivityKind : repli générique et isolation de details[name] / emoji',
    (tester) async {
      final fallbackOnly = ActivityCatalog(entries: const {});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const ActivityLine(
                  kind: ActivityKind.tool,
                  details: {'name': 'write_file 💻', 'context': 'code'},
                ),
                const ActivityLine(kind: ActivityKind.code),
                const ActivityLine(kind: ActivityKind.unknown),
                ActivityLine(kind: ActivityKind.code, catalog: fallbackOnly),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final paints = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(ActivityIllustration),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((p) => p.painter)
          .toList();
      expect(paints[0], isA<ToolActivityPainter>());
      expect(paints[1], isA<CodeActivityPainter>());
      expect(paints[2], isA<UnknownActivityPainter>());
      expect(paints[3], isA<UnknownActivityPainter>());
      expect(ActivityKind.decode('tool'), ActivityKind.tool);
      expect(ActivityKind.decode('code'), ActivityKind.code);
      expect(ActivityKind.decode('unexpected_family'), ActivityKind.unknown);
      expect(ActivityKind.decode(null), ActivityKind.unknown);
    },
  );

  testWidgets(
    'illustration code (UX-DR14), tool et unknown : châssis fixe aux traits épais, lignes/curseur mobiles, clé/signal mobiles et 3 points en rotation',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ActivityLine(kind: ActivityKind.code),
                ActivityLine(kind: ActivityKind.tool),
                ActivityLine(kind: ActivityKind.unknown),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      CodeActivityPainter codePainter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<CodeActivityPainter>()
          .single;
      ToolActivityPainter toolPainter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<ToolActivityPainter>()
          .single;
      UnknownActivityPainter unknownPainter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<UnknownActivityPainter>()
          .single;

      final initialChassis = codePainter().chassisBounds;
      final initialLines = codePainter().lineLengths;
      final initialCursor = codePainter().cursorOffset;
      final initialDots = unknownPainter().dotCenters;
      expect(codePainter().stationary, isTrue);
      expect(toolPainter().stationary, isTrue);
      expect(toolPainter().wrenchAngle, 0);
      expect(toolPainter().signalX, ActivityTokens.toolSignalStartX);
      expect(unknownPainter().stationary, isTrue);
      expect(initialDots, hasLength(3));

      await tester.pump(ActivityTokens.rest);
      await tester.pump(const Duration(milliseconds: 200));
      expect(codePainter().stationary, isFalse);
      expect(codePainter().chassisBounds, initialChassis);
      expect(codePainter().lineLengths, isNot(equals(initialLines)));
      expect(codePainter().cursorOffset, isNot(equals(initialCursor)));

      expect(toolPainter().stationary, isFalse);
      expect(toolPainter().wrenchAngle, isNot(0));
      expect(
        toolPainter().signalX,
        greaterThan(ActivityTokens.toolSignalStartX),
      );

      expect(unknownPainter().stationary, isFalse);
      expect(unknownPainter().rotationAngle, greaterThan(0));
      expect(unknownPainter().dotCenters, isNot(equals(initialDots)));

      await tester.pump(ActivityTokens.cycle);
      expect(codePainter().stationary, isTrue);
      expect(codePainter().chassisBounds, initialChassis);
      expect(codePainter().lineLengths, initialLines);
      expect(codePainter().cursorOffset, initialCursor);
      expect(toolPainter().stationary, isTrue);
      expect(toolPainter().wrenchAngle, 0);
      expect(toolPainter().signalX, ActivityTokens.toolSignalStartX);
      expect(unknownPainter().stationary, isTrue);
    },
  );

  testWidgets(
    'suspension immédiate : mouvement réduit, pause, completed, Offstage, hors viewport et arrière-plan',
    (tester) async {
      var paused = false;
      var completed = false;
      var offstage = false;
      var disableAnimations = false;
      final scroll = ScrollController();
      addTearDown(scroll.dispose);

      Widget buildHarness() => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(375, 400),
            disableAnimations: disableAnimations,
          ),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, _) => SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    Offstage(
                      offstage: offstage,
                      child: ActivityLine(
                        kind: ActivityKind.code,
                        paused: paused,
                        completed: completed,
                      ),
                    ),
                    const SizedBox(height: 1200),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      CodeActivityPainter current() => tester
          .widgetList<CustomPaint>(
            find.byType(CustomPaint, skipOffstage: false),
          )
          .map((p) => p.painter)
          .whereType<CodeActivityPainter>()
          .single;

      await tester.pumpWidget(buildHarness());
      await tester.pump();
      await tester.pump(ActivityTokens.rest);
      await tester.pump(const Duration(milliseconds: 200));
      expect(current().stationary, isFalse);

      // 1. Mouvement réduit en cours de cycle -> arrêt immédiat.
      disableAnimations = true;
      await tester.pumpWidget(buildHarness());
      await tester.pump();
      expect(current().stationary, isTrue);
      expect(tester.binding.transientCallbackCount, 0);

      // Reprise normale.
      disableAnimations = false;
      await tester.pumpWidget(buildHarness());
      await tester.pump();
      await tester.pump(ActivityTokens.rest);
      await tester.pump(const Duration(milliseconds: 200));
      expect(current().stationary, isFalse);

      // 2. Pause de la page -> variante immobile immédiate, zéro callback.
      paused = true;
      await tester.pumpWidget(buildHarness());
      await tester.pump();
      expect(current().stationary, isTrue);
      expect(tester.binding.transientCallbackCount, 0);

      paused = false;
      await tester.pumpWidget(buildHarness());
      await tester.pump();
      await tester.pump(ActivityTokens.rest);
      await tester.pump(const Duration(milliseconds: 200));
      expect(current().stationary, isFalse);

      // 3. Fin d'action (completed: true) -> variante immobile immédiate.
      completed = true;
      await tester.pumpWidget(buildHarness());
      await tester.pump();
      expect(current().stationary, isTrue);
      expect(tester.binding.transientCallbackCount, 0);

      completed = false;
      await tester.pumpWidget(buildHarness());
      await tester.pump();
      await tester.pump(ActivityTokens.rest);
      await tester.pump(const Duration(milliseconds: 200));
      expect(current().stationary, isFalse);

      // 4. Offstage -> suspension immédiate.
      offstage = true;
      await tester.pumpWidget(buildHarness());
      await tester.pump();
      expect(current().stationary, isTrue);
      expect(tester.binding.transientCallbackCount, 0);

      offstage = false;
      await tester.pumpWidget(buildHarness());
      await tester.pump();
      await tester.pump(ActivityTokens.rest);
      await tester.pump(const Duration(milliseconds: 200));
      expect(current().stationary, isFalse);

      // 5. Défilement hors du viewport -> suspension immédiate.
      scroll.jumpTo(800);
      await tester.pump();
      await tester.pump();
      expect(current().stationary, isTrue);
      await tester.pump(ActivityTokens.rest + ActivityTokens.cycle);
      expect(current().stationary, isTrue);
      expect(tester.binding.transientCallbackCount, 0);

      scroll.jumpTo(0);
      await tester.pump();
      await tester.pump();
      await tester.pump(ActivityTokens.rest);
      await tester.pump(const Duration(milliseconds: 200));
      expect(current().stationary, isFalse);

      // 6. Passage en arrière-plan -> suspension immédiate, reprise au retour.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(current().stationary, isTrue);
      expect(tester.binding.transientCallbackCount, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(ActivityTokens.rest);
      await tester.pump(const Duration(milliseconds: 200));
      expect(current().stationary, isFalse);

      // 7. Route couverte -> suspension immédiate, reprise au retour.
      final navigator = Navigator.of(
        tester.element(find.byType(ActivityIllustration)),
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Route couverte')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(ActivityTokens.rest + ActivityTokens.cycle);
      expect(tester.binding.transientCallbackCount, 0);
      navigator.pop();
      await tester.pumpAndSettle();
      await tester.pump(ActivityTokens.rest);
      await tester.pump(const Duration(milliseconds: 200));
      expect(current().stationary, isFalse);

      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'remplacement d’une entrée dans ActivityCatalog sans toucher au décodage ni au transport',
    (tester) async {
      final replaced = ActivityCatalog.standard.copyWithEntry(
        ActivityKind.tool,
        const ActivityCatalogEntry(painter: _ReplacementPainter.build),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityLine(kind: ActivityKind.tool, catalog: replaced),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is _ReplacementPainter,
        ),
        findsOneWidget,
      );
    },
  );
}

class _ReplacementPainter extends CustomPainter {
  const _ReplacementPainter({
    required this.color,
    required this.progress,
    required this.stationary,
  });

  static CustomPainter build({
    required Color color,
    required double progress,
    required bool stationary,
  }) => _ReplacementPainter(
    color: color,
    progress: progress,
    stationary: stationary,
  );

  final Color color;
  final double progress;
  final bool stationary;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ReplacementPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.stationary != stationary;
}
