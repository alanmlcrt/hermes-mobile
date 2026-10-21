import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/ui/components/section_card.dart';
import 'package:hermes_mobile/ui/components/status_label.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/gallery.dart';
import 'package:hermes_mobile/ui/theme.dart';
import 'package:hermes_mobile/ui/tokens.dart';

void main() {
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
      // Une fois par composant (3 composants).
      expect(find.text(variant), findsNWidgets(3), reason: variant);
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
    // Trois états par variante.
    expect(find.byType(StatusLabel), findsNWidgets(4 * 3));
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
