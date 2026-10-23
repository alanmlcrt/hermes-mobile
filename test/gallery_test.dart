import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/activity_catalog.dart';
import 'package:hermes_mobile/ui/components/activity_line.dart';
import 'package:hermes_mobile/ui/components/composer.dart';
import 'package:hermes_mobile/ui/components/message_bubble.dart';
import 'package:hermes_mobile/ui/components/work_state_label.dart';
import 'package:hermes_mobile/ui/components/section_card.dart';
import 'package:hermes_mobile/ui/components/status_label.dart';
import 'package:hermes_mobile/ui/components/rabbit_companion.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/gallery.dart';
import 'package:hermes_mobile/ui/theme.dart';
import 'package:hermes_mobile/ui/tokens.dart';

void main() {
  testWidgets('18 entrées comparables et pause commune atteignable à 200 %', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: ActivityPreview()),
        ),
      ),
    );
    await tester.pump();
    for (final kind in ActivityKind.values) {
      final row = find.byKey(ValueKey('catalogue-${kind.name}'));
      await tester.ensureVisible(row);
      await tester.pump();
      final examples = tester
          .widgetList<ActivityIllustration>(
            find.descendant(
              of: row,
              matching: find.byType(ActivityIllustration),
            ),
          )
          .toList();
      expect(examples.map((w) => w.kind), [kind, kind]);
      expect(examples.map((w) => w.paused), [false, true]);
      expect(
        find.text(GalleryContent.activityCatalogItem(kind)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.ensureVisible(find.text(GalleryContent.pauseActivities));
    await tester.tap(find.text(GalleryContent.pauseActivities));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(
            find.widgetWithText(TextButton, GalleryContent.resumeActivities),
          )
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .widgetList<ActivityIllustration>(find.byType(ActivityIllustration))
          .every((w) => w.paused),
      isTrue,
    );
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('activité : détails conservés après fin et repli du groupe', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ActivityPreview())),
      ),
    );
    await tester.tap(find.text(Content.activityTool));
    await tester.pump();
    expect(find.text(Content.detailArguments), findsOneWidget);
    await tester.tap(find.text(GalleryContent.activityComplete));
    await tester.pump();
    expect(find.text(Content.detailError), findsOneWidget);
    await tester.ensureVisible(find.text(GalleryContent.activitySecond));
    await tester.tap(find.text(GalleryContent.activitySecond));
    await tester.pump();
    await tester.ensureVisible(find.text(GalleryContent.activityReply));
    await tester.tap(find.text(GalleryContent.activityReply));
    await tester.pump();
    expect(find.text(Content.detailArguments), findsOneWidget);
    await tester.ensureVisible(find.text(Content.activitySummary(2, 1)));
    await tester.tap(find.text(Content.activitySummary(2, 1)));
    await tester.pump();
    expect(find.text(Content.detailArguments), findsNothing);
    await tester.ensureVisible(find.text(Content.activitySummary(2, 1)));
    await tester.tap(find.text(Content.activitySummary(2, 1)));
    await tester.pump();
    expect(find.text(Content.detailArguments), findsOneWidget);
  });

  testWidgets(
    'activité : ajout code, pause/reprise des illustrations et réinitialisation',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ActivityPreview())),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(GalleryContent.activityCode));
      await tester.pump();
      expect(find.byType(ActivityLine), findsNWidgets(2));
      expect(find.text(Content.activityCode), findsOneWidget);

      await tester.pump(ActivityTokens.rest);
      await tester.pump(const Duration(milliseconds: 200));
      CodeActivityPainter codeLinePainter() => tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(ActivityLine),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((p) => p.painter)
          .whereType<CodeActivityPainter>()
          .single;
      expect(codeLinePainter().stationary, isFalse);

      await tester.tap(find.text(GalleryContent.pauseActivities));
      await tester.pumpAndSettle();
      expect(find.text(GalleryContent.resumeActivities), findsOneWidget);
      for (final illustration in tester.widgetList<ActivityIllustration>(
        find.byType(ActivityIllustration),
      )) {
        expect(illustration.paused, isTrue);
      }
      expect(codeLinePainter().stationary, isTrue);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.tap(find.text(GalleryContent.resumeActivities));
      await tester.pumpAndSettle();
      expect(find.text(GalleryContent.pauseActivities), findsOneWidget);
      await tester.pump(ActivityTokens.rest);
      await tester.pump(const Duration(milliseconds: 200));
      expect(codeLinePainter().stationary, isFalse);

      await tester.tap(find.text(GalleryContent.pauseActivities));
      await tester.pump();
      await tester.tap(find.text(GalleryContent.activityReset));
      await tester.pump();
      expect(find.byType(ActivityLine), findsOneWidget);
      expect(find.text(GalleryContent.pauseActivities), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'scénario conversation piloté : texte, terminal pendant chatouille, reprise',
    (tester) async {
      tester.view.physicalSize = const Size(812, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(null, Brightness.light),
          home: const Scaffold(body: ConversationCompanionPreview()),
        ),
      );
      await tester.pump();
      RabbitPainter current() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<RabbitPainter>()
          .single;
      await tester.tap(find.text(GalleryContent.companionStart));
      await tester.pump();
      expect(current().concentrating, isTrue);
      await tester.tap(find.text(GalleryContent.companionText));
      await tester.pump();
      expect(current().gaze, 1);
      final firstText = tester
          .widget<MessageBubble>(find.byType(MessageBubble))
          .text;
      await tester.tap(find.text(GalleryContent.companionText));
      await tester.pump();
      final received = tester
          .widget<MessageBubble>(find.byType(MessageBubble))
          .text;
      expect(received.length, greaterThan(firstText.length));
      await tester.tap(find.byType(RabbitCompanion));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, Content.workStopped));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(WorkStateLabel),
          matching: find.text(Content.workStopped),
        ),
        findsOneWidget,
      );
      expect(current().tickled, isTrue);
      expect(
        tester.widget<MessageBubble>(find.byType(MessageBubble)).text,
        received,
      );
      await tester.pump(RabbitTokens.tickle);
      await tester.pump(const Duration(milliseconds: 1));
      expect(current().gaze, 0);
      expect(current().tickled, isFalse);
      await tester.tap(find.widgetWithText(TextButton, Content.workUnknown));
      await tester.pump();
      expect(
        tester.widget<MessageBubble>(find.byType(MessageBubble)).text,
        received,
      );
      await tester.tap(find.byType(RabbitCompanion));
      await tester.pump();
      expect(current().tickled, isTrue);
      await tester.tap(find.text(GalleryContent.companionRestore));
      await tester.pump();
      await tester.pump();
      expect(current().gaze, 1);
      expect(current().tickled, isFalse);
      expect(
        tester.widget<MessageBubble>(find.byType(MessageBubble)).text,
        received,
      );
      await tester.tap(find.text(GalleryContent.companionSuspend));
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.tap(find.text(GalleryContent.companionShow));
      await tester.pump();
      expect(current().gaze, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'éditeur galerie suit le mouvement réduit système pendant son ouverture',
    (tester) async {
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      for (final variant in [0, 3]) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: false);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(null, Brightness.light),
            home: const ComponentGallery(),
          ),
        );
        await tester.pumpAndSettle();
        final action = find
            .widgetWithText(OutlinedButton, Content.backgroundTitle)
            .at(variant);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        bool reduced() => MediaQuery.disableAnimationsOf(
          tester.element(find.byType(RabbitCompanion).last),
        );
        expect(reduced(), variant == 3);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        await tester.pump();
        expect(reduced(), isTrue);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: false);
        await tester.pump();
        expect(reduced(), variant == 3);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets('éditeur galerie : erreur simulée, retry puis succès local', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(null, Brightness.light),
        home: const ComponentGallery(),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.text(GalleryContent.backgroundFailure).first;
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text(Content.mintSky));
    await tester.tap(find.text(Content.backgroundApply));
    await tester.pumpAndSettle();
    expect(find.text(Content.backgroundSaveError), findsOneWidget);
    await tester.tap(find.text(Content.backgroundRetry));
    await tester.pumpAndSettle();
    expect(find.text(Content.backgroundSaveError), findsNothing);
    expect(find.text(Content.mintSky), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('chaque aperçu visible applique Pause et Reprendre au lapin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(null, Brightness.light),
        home: const ComponentGallery(),
      ),
    );
    await tester.pumpAndSettle();
    for (var variant = 0; variant < 4; variant++) {
      final rabbit = find.byType(RabbitCompanion).at(variant * 3 + 2);
      final pause = find.text(GalleryContent.pauseRabbit).at(variant);
      await tester.ensureVisible(pause);
      await tester.pumpAndSettle();
      await tester.ensureVisible(rabbit);
      await tester.pumpAndSettle();
      RabbitPainter current() => tester
          .widgetList<CustomPaint>(
            find.descendant(of: rabbit, matching: find.byType(CustomPaint)),
          )
          .map((paint) => paint.painter)
          .whereType<RabbitPainter>()
          .single;
      await tester.tap(pause);
      await tester.pumpAndSettle();
      expect(tester.widget<RabbitCompanion>(rabbit).paused, isTrue);
      await tester.pump(RabbitTokens.rest + RabbitTokens.travel);
      expect(current().gaze, 0);
      await tester.tap(rabbit);
      await tester.pump();
      expect(current().tickled, isTrue);
      expect(current().wiggle, 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(current().wiggle, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(current().tickled, isFalse);
      await tester.tap(find.text(GalleryContent.resumeRabbit));
      await tester.pumpAndSettle();
      expect(tester.widget<RabbitCompanion>(rabbit).paused, isFalse);
      await tester.pump(RabbitTokens.rest);
      await tester.pump(RabbitTokens.travel);
      expect(current().gaze.abs(), variant == 3 ? 0 : closeTo(1, .001));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'lapin : pause utilisable, paysage et texte 200 % sans débordement',
    (tester) async {
      addTearDown(tester.view.reset);
      for (final size in [const Size(375, 812), const Size(812, 375)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(null, Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const ComponentGallery(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(GalleryContent.pauseRabbit).first);
        await tester.tap(find.text(GalleryContent.pauseRabbit).first);
        await tester.pumpAndSettle();
        expect(find.text(GalleryContent.resumeRabbit), findsOneWidget);
        // Toutes les variantes existent, dont sombre avec texte système à 200 %.
        expect(find.byType(RabbitCompanion), findsNWidgets(20));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('chaque composant rendu dans les quatre variantes', (
    tester,
  ) async {
    // Écran de téléphone étroit pour éprouver le texte à 200 %.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(null, Brightness.light),
        home: const ComponentGallery(),
      ),
    );
    await tester.pumpAndSettle();

    // Aucune exception, débordement de mise en page compris.
    expect(tester.takeException(), isNull);

    for (final variant in [
      GalleryContent.variantLight,
      GalleryContent.variantDark,
      GalleryContent.variantLargeText,
      GalleryContent.variantReducedMotion,
    ]) {
      // Une fois par composant, dont le scénario conversation pilotable.
      expect(find.text(variant), findsNWidgets(11), reason: variant);
    }

    // Les surcharges de chaque variante s'appliquent à son contenu.
    void expectVariant(
      String variant, {
      required Brightness brightness,
      double textScale = 1,
      bool disableAnimations = false,
    }) {
      for (final element in find.text(variant).evaluate()) {
        expect(Theme.of(element).brightness, brightness, reason: variant);
        expect(
          MediaQuery.textScalerOf(element).scale(1),
          textScale,
          reason: variant,
        );
        expect(
          MediaQuery.disableAnimationsOf(element),
          disableAnimations,
          reason: variant,
        );
      }
    }

    expectVariant(GalleryContent.variantLight, brightness: Brightness.light);
    expectVariant(GalleryContent.variantDark, brightness: Brightness.dark);
    expectVariant(
      GalleryContent.variantLargeText,
      brightness: Brightness.light,
      textScale: TextScales.large,
    );
    expectVariant(
      GalleryContent.variantReducedMotion,
      brightness: Brightness.light,
      disableAnimations: true,
    );

    expect(find.byType(SectionCard), findsNWidgets(4));
    expect(find.byType(RabbitCompanion), findsNWidgets(4 * 5));
    expect(find.text(GalleryContent.pauseRabbit), findsNWidgets(8));
    expect(find.byType(Composer), findsNWidgets(4));
    // Trois états de connexion et sept occurrences d'état de travail.
    expect(find.byType(StatusLabel), findsNWidgets(4 * (3 + 7)));
    expect(find.byType(MessageBubble), findsNWidgets(4 * 2));
    expect(find.byType(ActivityLine), findsNWidgets(4 * 2));
    expect(
      find.byType(ActivityIllustration),
      findsNWidgets(4 * (2 * ActivityKind.values.length + 2)),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CodeActivityPainter,
      ),
      findsNWidgets(8),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ToolActivityPainter,
      ),
      findsNWidgets(4 * 4),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is UnknownActivityPainter,
      ),
      findsNWidgets(8),
    );
    for (final state in WorkState.values) {
      expect(
        find.descendant(
          of: find.byType(WorkStateLabel),
          matching: find.text(WorkStateLabel.label(state)),
        ),
        findsNWidgets(state == WorkState.sending ? 8 : 4),
        reason: state.name,
      );
    }
    for (final label in [
      ConnectionLabels.connected,
      ConnectionLabels.resyncing,
      ConnectionLabels.offline,
    ]) {
      expect(find.text(label), findsNWidgets(4), reason: label);
    }
  });

  testWidgets('SectionCard respecte le mouvement réduit', (tester) async {
    Future<Duration> durationWith({required bool disableAnimations}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: disableAnimations),
              child: const SectionCard(
                title: GalleryContent.sampleCardTitle,
                child: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      return tester.widget<AnimatedSize>(find.byType(AnimatedSize)).duration;
    }

    expect(await durationWith(disableAnimations: true), Duration.zero);
    expect(await durationWith(disableAnimations: false), Motion.medium);
  });

  testWidgets('StatusLabel annonce son libellé', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StatusLabel(
          icon: Icons.cloud_off_outlined,
          label: ConnectionLabels.offline,
        ),
      ),
    );
    expect(find.bySemanticsLabel(ConnectionLabels.offline), findsOneWidget);
  });
}
