import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/timeline.dart';
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
        expect(find.byType(RabbitCompanion), findsNWidgets(12));
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
      // Une fois par composant (9 sections).
      expect(find.text(variant), findsNWidgets(9), reason: variant);
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
    expect(find.byType(RabbitCompanion), findsNWidgets(4 * 3));
    expect(find.text(GalleryContent.pauseRabbit), findsNWidgets(4));
    expect(find.byType(Composer), findsNWidgets(4));
    // Trois états de connexion, deux lignes d'activité, six états du travail.
    expect(find.byType(StatusLabel), findsNWidgets(4 * (3 + 2 + 6)));
    expect(find.byType(MessageBubble), findsNWidgets(4 * 2));
    expect(find.byType(ActivityLine), findsNWidgets(4 * 2));
    for (final state in WorkState.values) {
      expect(
        find.text(WorkStateLabel.label(state)),
        findsNWidgets(4),
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
