import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/ui/components/rabbit_companion.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/tokens.dart';

RabbitPainter pose(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((widget) => widget.painter)
    .whereType<RabbitPainter>()
    .single;

Widget host({
  bool reduced = false,
  bool active = true,
  bool paused = false,
  bool ticker = true,
  double size = RabbitTokens.large,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      disableAnimations: reduced,
    ),
    child: TickerMode(
      enabled: ticker,
      child: Center(
        child: RabbitCompanion(
          name: 'Otc',
          size: size,
          active: active,
          paused: paused,
        ),
      ),
    ),
  ),
);

Future<void> settleMount(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump();
}

void main() {
  testWidgets('pose de travail courante après suspension et chatouille fixe', (
    tester,
  ) async {
    var current = RabbitPose.concentrating;
    var active = true;
    var reduced = false;
    late StateSetter update;
    await settleMount(
      tester,
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQueryData(
                size: const Size(800, 600),
                disableAnimations: reduced,
              ),
              child: Center(
                child: RabbitCompanion(
                  pose: current,
                  autonomous: false,
                  active: active,
                ),
              ),
            );
          },
        ),
      ),
    );
    expect(pose(tester).concentrating, isTrue);
    await tester.tap(find.byType(RabbitCompanion));
    await tester.pump();
    update(() {
      active = false;
      current = RabbitPose.reading;
    });
    await tester.pump();
    expect(pose(tester).tickled, isFalse);
    await tester.pump(const Duration(seconds: 20));
    expect(tester.binding.transientCallbackCount, 0);
    update(() {
      active = true;
      reduced = true;
    });
    await tester.pump();
    await tester.pump();
    expect(pose(tester).gaze, 1);
    await tester.tap(find.byType(RabbitCompanion));
    await tester.pump();
    expect(pose(tester).tickled, isTrue);
    expect(pose(tester).wiggle, 0);
    update(() => current = RabbitPose.concentrating);
    await tester.pump();
    await tester.pump(RabbitTokens.tickle);
    expect(pose(tester).concentrating, isTrue);
    expect(pose(tester).tickled, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('limites transformées du lapin et du viewport près du bord', (
    tester,
  ) async {
    for (final scaleViewport in [false, true]) {
      final scroll = ScrollController(
        initialScrollOffset: scaleViewport ? 0 : 100,
      );
      await settleMount(
        tester,
        MaterialApp(
          home: Stack(
            children: [
              Positioned(
                top: 100,
                left: 0,
                child: Transform.scale(
                  scale: scaleViewport ? .5 : 1,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: SingleChildScrollView(
                      controller: scroll,
                      child: Column(
                        children: [
                          if (scaleViewport) const SizedBox(height: 250),
                          Transform.scale(
                            scale: scaleViewport ? 1 : .25,
                            alignment: Alignment.topLeft,
                            child: const RabbitCompanion(),
                          ),
                          const SizedBox(height: 600),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump(RabbitTokens.rest);
      await tester.pump(RabbitTokens.travel);
      expect(
        pose(tester).gaze,
        0,
        reason: 'painted outside viewport; scaled viewport=$scaleViewport',
      );
      scroll.jumpTo(scaleViewport ? 200 : 0);
      await tester.pump();
      await tester.pump();
      await tester.pump(RabbitTokens.rest);
      await tester.pump(RabbitTokens.travel);
      expect(pose(tester).gaze.abs(), closeTo(1, .001));
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
    }
  });

  testWidgets(
    'surface inactive sans activation ni focus et sémantique désactivée',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await settleMount(tester, host(active: false));
      final button = find.bySemanticsLabel('Chatouiller Otc');
      expect(
        tester.getSemantics(button),
        matchesSemantics(
          label: 'Chatouiller Otc',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      final ink = tester.widget<InkWell>(find.byType(InkWell));
      expect(ink.onTap, isNull);
      expect(ink.canRequestFocus, isFalse);
      await tester.tap(find.byType(RabbitCompanion));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(ink.focusNode!.hasFocus, isFalse);
      expect(pose(tester).tickled, isFalse);
      await settleMount(tester, host());
      expect(
        tester
            .getSemantics(button)
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      await tester.tap(find.byType(RabbitCompanion));
      await tester.pump();
      expect(pose(tester).tickled, isTrue);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );
  testWidgets('un ancêtre déplace un enfant constant sans cycle hors écran', (
    tester,
  ) async {
    final top = ValueNotifier<double>(0);
    addTearDown(top.dispose);
    await settleMount(
      tester,
      MaterialApp(
        home: ValueListenableBuilder<double>(
          valueListenable: top,
          child: const RabbitCompanion(),
          builder: (_, y, child) => Stack(
            children: [Positioned(top: y, left: 0, child: child!)],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(RabbitCompanion));
    await tester.pump();
    top.value = 900;
    await tester.pump();
    await tester.pump();
    expect(pose(tester).tickled, isFalse);
    await tester.pump(const Duration(seconds: 20));
    expect(pose(tester).gaze, 0);
    expect(tester.binding.transientCallbackCount, 0);
    top.value = 0;
    await tester.pump();
    await tester.pump();
    await tester.pump(RabbitTokens.rest);
    await tester.pump(RabbitTokens.travel);
    expect(pose(tester).gaze.abs(), closeTo(1, .001));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'remplacement du contrôleur avec enfant constant suit la nouvelle position',
    (tester) async {
      final first = ScrollController();
      final second = ScrollController();
      final controller = ValueNotifier(first);
      addTearDown(() {
        controller.dispose();
        first.dispose();
        second.dispose();
      });
      await settleMount(
        tester,
        MaterialApp(
          home: ValueListenableBuilder<ScrollController>(
            valueListenable: controller,
            child: const Column(
              children: [RabbitCompanion(), SizedBox(height: 1800)],
            ),
            builder: (_, value, child) =>
                SingleChildScrollView(controller: value, child: child),
          ),
        ),
      );
      controller.value = second;
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byType(RabbitCompanion));
      await tester.pump();
      second.jumpTo(900);
      await tester.pump();
      await tester.pump();
      expect(pose(tester).tickled, isFalse);
      await tester.pump(const Duration(seconds: 20));
      expect(pose(tester).gaze, 0);
      second.jumpTo(0);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byType(RabbitCompanion));
      await tester.pump();
      expect(pose(tester).tickled, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('un changement de thème conserve la réaction fixe et son délai', (
    tester,
  ) async {
    final dark = ValueNotifier(false);
    addTearDown(dark.dispose);
    await settleMount(
      tester,
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            disableAnimations: true,
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: dark,
            child: const Center(child: RabbitCompanion()),
            builder: (_, value, child) => Theme(
              data: value ? ThemeData.dark() : ThemeData.light(),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(RabbitCompanion));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    dark.value = true;
    await tester.pump();
    expect(pose(tester).tickled, isTrue);
    expect(pose(tester).wiggle, 0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(pose(tester).tickled, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('focus en anneau sur pastel conserve le centre transparent', (
    tester,
  ) async {
    const key = Key('focus-pastel');
    await settleMount(
      tester,
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: RabbitTokens.backdrop),
              child: const RabbitCompanion(paused: true),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/rabbit_focus.png'),
    );
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(key))
          .toImage();
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final corner = (90 * image.width + 20) * 4;
      expect(
        pixels.getUint8(corner),
        lessThan(250),
      ); // Pastel, not an opaque white fill.
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });

  test('enveloppe peinte aux amplitudes extrêmes à 48/64/180 px', () async {
    for (final size in [48, 64, 180]) {
      for (final gaze in [-1.0, 0.0, 1.0]) {
        for (final wiggle in [-1.0, 0.0, 1.0]) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..translate(16, 16);
          RabbitPainter(
            gaze: gaze,
            wiggle: wiggle,
            tickled: wiggle != 0,
          ).paint(canvas, Size.square(size.toDouble()));
          final picture = recorder.endRecording();
          final image = await picture.toImage(size + 32, size + 32);
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              if (x < 16 || x >= size + 16 || y < 16 || y >= size + 16) {
                expect(
                  pixels.getUint8((y * image.width + x) * 4 + 3),
                  0,
                  reason: '$size gaze=$gaze wiggle=$wiggle at $x,$y',
                );
              }
            }
          }
          image.dispose();
          picture.dispose();
        }
      }
    }
  });
  testWidgets('une route qui masque la surface suspend la réaction', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await settleMount(
      tester,
      MaterialApp(
        navigatorKey: navigator,
        home: const Center(child: RabbitCompanion()),
      ),
    );
    await tester.tap(find.byType(RabbitCompanion));
    await tester.pump();
    expect(pose(tester).tickled, isTrue);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Surface masquée')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(pose(tester).tickled, isFalse);
    expect(pose(tester).gaze, 0);
    await tester.tap(find.byType(RabbitCompanion));
    await tester.pump();
    expect(pose(tester).tickled, isTrue);
    await tester.pump(RabbitTokens.tickle);
    await tester.pump(const Duration(milliseconds: 10));
    expect(pose(tester).tickled, isFalse);
    await tester.pump(RabbitTokens.rest - const Duration(milliseconds: 1));
    expect(pose(tester).gaze, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(RabbitTokens.travel);
    expect(pose(tester).gaze.abs(), closeTo(1, .001));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('regards espacés alternés avec retour face et enveloppe stable', (
    tester,
  ) async {
    await settleMount(tester, host());
    final before = tester.getRect(find.byType(RabbitCompanion));
    expect(pose(tester).gaze, 0);
    await tester.pump(RabbitTokens.rest);
    await tester.pump(RabbitTokens.travel);
    expect(pose(tester).gaze, closeTo(-1, .001));
    await tester.pump(
      RabbitTokens.hold +
          RabbitTokens.travel +
          const Duration(milliseconds: 10),
    );
    expect(pose(tester).gaze, 0);
    await tester.pump(RabbitTokens.rest);
    await tester.pump(RabbitTokens.travel);
    expect(pose(tester).gaze, closeTo(1, .001));
    expect(tester.getRect(find.byType(RabbitCompanion)), before);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'touches supplémentaires ignorées ; annulation et glissement ne réagissent pas',
    (tester) async {
      await settleMount(tester, host());
      final rabbit = find.byType(RabbitCompanion);
      var gesture = await tester.startGesture(tester.getCenter(rabbit));
      await gesture.cancel();
      await tester.pump();
      expect(pose(tester).tickled, isFalse);
      await tester.drag(rabbit, const Offset(0, -100));
      await tester.pump();
      expect(pose(tester).tickled, isFalse);
      await tester.tap(rabbit);
      await tester.pump();
      expect(pose(tester).tickled, isTrue);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(rabbit);
      await tester.pump(const Duration(milliseconds: 510));
      expect(pose(tester).tickled, isFalse);
      await tester.tap(rabbit);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clavier et action sémantique équivalents au toucher', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await settleMount(tester, host());
    final button = find.bySemanticsLabel('Chatouiller Otc');
    expect(
      tester.getSemantics(button),
      matchesSemantics(
        label: 'Chatouiller Otc',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(pose(tester).tickled, isTrue);
    await tester.pump(RabbitTokens.tickle);
    await tester.pump(const Duration(milliseconds: 10));
    expect(pose(tester).tickled, isFalse);
    tester
        .getSemantics(button)
        .owner!
        .performAction(tester.getSemantics(button).id, SemanticsAction.tap);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(pose(tester).tickled, isTrue);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets(
    'mouvement réduit interrompt immédiatement et propose une pose fixe',
    (tester) async {
      await settleMount(tester, host());
      await tester.tap(find.byType(RabbitCompanion));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(pose(tester).wiggle, isNot(0));
      await settleMount(tester, host(reduced: true));
      expect(pose(tester).tickled, isFalse);
      expect(pose(tester).gaze, 0);
      expect(pose(tester).wiggle, 0);
      await tester.pump(const Duration(seconds: 20));
      expect(pose(tester).gaze, 0);
      await tester.tap(find.byType(RabbitCompanion));
      await tester.pump();
      expect(pose(tester).tickled, isTrue);
      expect(pose(tester).wiggle, 0);
      final fixed = pose(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(pose(tester).shouldRepaint(fixed), isFalse);
      await tester.pump(const Duration(milliseconds: 600));
      expect(pose(tester).tickled, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pause, surface masquée et TickerMode reprennent depuis le repos',
    (tester) async {
      for (final hidden in [
        host(paused: true),
        host(active: false),
        host(ticker: false),
      ]) {
        await settleMount(tester, host());
        await tester.tap(find.byType(RabbitCompanion));
        await tester.pump();
        await settleMount(tester, hidden);
        expect(pose(tester).tickled, isFalse);
        await tester.pump(const Duration(seconds: 20));
        expect(pose(tester).gaze, 0);
        await settleMount(tester, host());
        expect(pose(tester).gaze, 0);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('arrière-plan et viewport suspendent, sans rejouer au retour', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await settleMount(
      tester,
      MaterialApp(
        home: SingleChildScrollView(
          controller: scroll,
          child: const Column(
            children: [RabbitCompanion(), SizedBox(height: 1800)],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(RabbitCompanion));
    await tester.pump();
    scroll.jumpTo(900);
    await tester.pump();
    await tester.pump();
    expect(pose(tester).tickled, isFalse);
    await tester.pump(const Duration(seconds: 20));
    expect(pose(tester).gaze, 0);
    scroll.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(pose(tester).gaze, 0);
    await tester.tap(find.byType(RabbitCompanion));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(pose(tester).tickled, isFalse);
    await tester.pump(const Duration(seconds: 20));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(pose(tester).gaze, 0);
    await tester.tap(find.byType(RabbitCompanion));
    await tester.pump();
    expect(pose(tester).tickled, isTrue);
    await tester.pump(RabbitTokens.tickle);
    await tester.pump(const Duration(milliseconds: 10));
    expect(pose(tester).tickled, isFalse);
    await tester.pump(RabbitTokens.rest - const Duration(milliseconds: 1));
    expect(pose(tester).gaze, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(RabbitTokens.travel);
    expect(pose(tester).gaze.abs(), closeTo(1, .001));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tailles minimales et nom de secours', (tester) async {
    for (final size in [
      RabbitTokens.large,
      RabbitTokens.compact,
      RabbitTokens.minimum,
    ]) {
      await settleMount(tester, host(size: size));
      expect(tester.getSize(find.byType(RabbitCompanion)), Size.square(size));
      await tester.tap(find.byType(RabbitCompanion));
      await tester.pump();
      expect(tester.getSize(find.byType(RabbitCompanion)), Size.square(size));
    }
    await settleMount(
      tester,
      const MaterialApp(home: RabbitCompanion(name: ' ')),
    );
    expect(
      find.bySemanticsLabel(Content.tickleCompanion(Content.companionFallback)),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('poses de travail à 48 et 64 px — référence raster', (
    tester,
  ) async {
    const sheet = Key('rabbit-work-poses');
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: sheet,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final size in [48.0, 64.0])
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final painter in const [
                            RabbitPainter(),
                            RabbitPainter(concentrating: true),
                            RabbitPainter(gaze: 1),
                            RabbitPainter(gazeDown: 1),
                          ])
                            CustomPaint(
                              size: Size.square(size),
                              painter: painter,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(sheet),
      matchesGoldenFile('goldens/rabbit_work_poses.png'),
    );
  });

  testWidgets(
    'planche vectorielle v5 — face, gauche, droite, chatouilles et compacts',
    (tester) async {
      const sheet = Key('rabbit-sheet');
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: sheet,
              child: Container(
                color: RabbitTokens.backdrop.colors.first,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          size: Size.square(180),
                          painter: RabbitPainter(),
                        ),
                        CustomPaint(
                          size: Size.square(180),
                          painter: RabbitPainter(gaze: -1),
                        ),
                        CustomPaint(
                          size: Size.square(180),
                          painter: RabbitPainter(gaze: 1),
                        ),
                        CustomPaint(
                          size: Size.square(180),
                          painter: RabbitPainter(
                            gaze: 1,
                            wiggle: 1,
                            tickled: true,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final size in [64.0, 48.0])
                          for (final painter in [
                            RabbitPainter(),
                            RabbitPainter(gaze: -1),
                            RabbitPainter(gaze: 1),
                            RabbitPainter(gaze: 1, wiggle: 1, tickled: true),
                            RabbitPainter(gaze: -1, wiggle: -1, tickled: true),
                          ])
                            CustomPaint(
                              size: Size.square(size),
                              painter: painter,
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(sheet),
        matchesGoldenFile('goldens/rabbit_companion.png'),
      );
    },
  );
}
