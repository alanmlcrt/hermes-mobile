// Galerie de composants (UX-DR23), build de développement uniquement :
// lancée par lib/main_gallery.dart, jamais importée par lib/main.dart.
import 'package:flutter/material.dart';

import 'components/section_card.dart';
import 'components/status_label.dart';
import 'components/profile_choice.dart';
import '../models/profile.dart';
import 'content.dart';
import 'theme.dart';
import 'tokens.dart';

/// Une variante d'affichage : thème + surcharges `MediaQuery`.
class _Variant {
  const _Variant(
    this.label,
    this.brightness, {
    this.textScale,
    this.disableAnimations = false,
  });

  final String label;
  final Brightness brightness;
  final double? textScale;
  final bool disableAnimations;
}

const _variants = [
  _Variant(GalleryContent.variantLight, Brightness.light),
  _Variant(GalleryContent.variantDark, Brightness.dark),
  _Variant(
    GalleryContent.variantLargeText,
    Brightness.light,
    textScale: TextScales.large,
  ),
  _Variant(
    GalleryContent.variantReducedMotion,
    Brightness.light,
    disableAnimations: true,
  ),
];

class ComponentGallery extends StatelessWidget {
  const ComponentGallery({super.key, this.lightScheme, this.darkScheme});

  /// Schémas dynamiques du système (`null` : palette de secours).
  final ColorScheme? lightScheme;
  final ColorScheme? darkScheme;

  static Widget _statusLabels() => const Wrap(
    spacing: Spacing.md,
    runSpacing: Spacing.sm,
    children: [
      StatusLabel(
        icon: Icons.cloud_done_outlined,
        label: ConnectionLabels.connected,
      ),
      StatusLabel(icon: Icons.sync, label: ConnectionLabels.resyncing),
      StatusLabel(
        icon: Icons.cloud_off_outlined,
        label: ConnectionLabels.offline,
      ),
    ],
  );

  static Widget _sectionCard() => SectionCard(
    title: GalleryContent.sampleCardTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final name in GalleryContent.sampleProfiles)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
            child: Text(name),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sections = <(String, Widget Function())>[
      (GalleryContent.statusLabelSection, _statusLabels),
      (GalleryContent.sectionCardSection, _sectionCard),
      (
        Content.profilesTitle,
        () => const ProfileChoice(
          profile: Profile(
            key: ProfileKey(Content.profileFixtureKey),
            label: Content.profileFixture,
          ),
          selected: true,
        ),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text(GalleryContent.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (title, builder) in sections) ...[
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              for (final v in _variants) ...[
                _VariantFrame(
                  variant: v,
                  scheme: v.brightness == Brightness.light
                      ? lightScheme
                      : darkScheme,
                  child: builder(),
                ),
                const SizedBox(height: Spacing.sm),
              ],
              const SizedBox(height: Spacing.lg),
            ],
          ],
        ),
      ),
    );
  }
}

class _VariantFrame extends StatelessWidget {
  const _VariantFrame({
    required this.variant,
    required this.scheme,
    required this.child,
  });

  final _Variant variant;
  final ColorScheme? scheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = buildTheme(scheme, variant.brightness);
    final mq = MediaQuery.of(context);
    final textScale = variant.textScale;
    return Theme(
      data: theme,
      child: MediaQuery(
        data: mq.copyWith(
          textScaler: textScale == null
              ? mq.textScaler
              : TextScaler.linear(textScale),
          disableAnimations: variant.disableAnimations || mq.disableAnimations,
        ),
        child: Material(
          color: theme.colorScheme.canvas,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  variant.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.content,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
