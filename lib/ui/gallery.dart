// Galerie de composants (UX-DR23), build de développement uniquement :
// lancée par lib/main_gallery.dart, jamais importée par lib/main.dart.
import 'package:flutter/material.dart';

import 'components/activity_line.dart';
import 'components/composer.dart';
import 'components/history_row.dart';
import 'components/message_bubble.dart';
import 'components/work_state_label.dart';
import 'components/section_card.dart';
import 'components/status_label.dart';
import 'components/profile_choice.dart';
import 'components/rabbit_companion.dart';
import '../models/history.dart';
import '../models/profile.dart';
import '../models/timeline.dart';
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

  static Widget _messages() => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MessageBubble(text: GalleryContent.sampleRequest, fromUser: true),
      SizedBox(height: Spacing.sm),
      MessageBubble(text: GalleryContent.sampleReply),
    ],
  );

  static Widget _activityLines() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ActivityLine(kind: 'tool'),
      SizedBox(height: Spacing.sm),
      ActivityLine(kind: 'unknown'),
    ],
  );

  static Widget _workStates() => Wrap(
    spacing: Spacing.md,
    runSpacing: Spacing.sm,
    children: [for (final s in WorkState.values) WorkStateLabel(state: s)],
  );

  static Widget _history() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const HistoryNotice(
        icon: Icons.hourglass_empty,
        message: Content.historyLoading,
      ),
      const HistoryNotice(
        icon: Icons.inbox_outlined,
        message: Content.historyEmpty,
      ),
      HistoryNotice(
        icon: Icons.error_outline,
        message: Content.historyError,
        actionLabel: Content.retryList,
        onAction: () {},
      ),
      HistoryRow(
        session: SessionSummary(
          id: 'a',
          title: GalleryContent.sampleSessionTitle,
          startedAt: DateTime.utc(2026, 10, 21, 9, 30),
          messageCount: 4,
        ),
        onTap: () {},
      ),
      const HistoryRow(
        session: SessionSummary(
          id: 'b',
          preview: GalleryContent.sampleSessionPreview,
          messageCount: 1,
        ),
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
      (GalleryContent.rabbitSection, () => const _RabbitPreview()),
      (GalleryContent.statusLabelSection, _statusLabels),
      (GalleryContent.sectionCardSection, _sectionCard),
      (
        GalleryContent.composerSection,
        () => const Composer(disabledReason: Content.sendEmpty),
      ),
      (GalleryContent.messageSection, _messages),
      (GalleryContent.activitySection, _activityLines),
      (GalleryContent.workStateSection, _workStates),
      (GalleryContent.historySection, _history),
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

class _RabbitPreview extends StatefulWidget {
  const _RabbitPreview();

  @override
  State<_RabbitPreview> createState() => _RabbitPreviewState();
}

class _RabbitPreviewState extends State<_RabbitPreview> {
  bool _paused = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        GalleryContent.rabbitName,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: Spacing.sm),
      Wrap(
        spacing: Spacing.md,
        runSpacing: Spacing.md,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          for (final (size, label) in [
            (RabbitTokens.large, GalleryContent.rabbitLarge),
            (RabbitTokens.compact, GalleryContent.rabbitCompact),
            (RabbitTokens.minimum, GalleryContent.rabbitMinimum),
          ])
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RabbitTokens.backdrop,
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  child: RabbitCompanion(
                    name: GalleryContent.rabbitName,
                    size: size,
                    paused: _paused,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(label),
              ],
            ),
        ],
      ),
      const SizedBox(height: Spacing.sm),
      TextButton(
        onPressed: () => setState(() => _paused = !_paused),
        child: Text(
          _paused ? GalleryContent.resumeRabbit : GalleryContent.pauseRabbit,
        ),
      ),
    ],
  );
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
