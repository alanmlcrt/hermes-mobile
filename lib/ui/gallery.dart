// Galerie de composants (UX-DR23), build de développement uniquement :
// lancée par lib/main_gallery.dart, jamais importée par lib/main.dart.
import 'package:flutter/material.dart';

import 'components/activity_catalog.dart';
import 'components/activity_line.dart';
import 'components/activity_group.dart';
import 'components/composer.dart';
import 'components/conversation_companion.dart';
import 'components/history_row.dart';
import 'components/message_bubble.dart';
import 'components/work_state_label.dart';
import 'components/section_card.dart';
import 'components/status_label.dart';
import 'components/profile_choice.dart';
import 'components/rabbit_companion.dart';
import 'components/companion_background_editor.dart';
import 'components/companion_backdrop.dart';
import '../models/companion_background.dart';
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

  static Widget _activityLines() => const ActivityPreview();

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
      (Content.backgroundTitle, () => const _BackgroundPreview()),
      (
        GalleryContent.conversationCompanionSection,
        () => const ConversationCompanionPreview(),
      ),
      (GalleryContent.statusLabelSection, _statusLabels),
      (GalleryContent.sectionCardSection, _sectionCard),
      (
        GalleryContent.composerSection,
        () => const Composer(disabledReason: Content.sendEmpty),
      ),
      (GalleryContent.messageSection, _messages),
      (GalleryContent.activitySection, _activityLines),
      (GalleryContent.workStateSection, _workStates),
      (
        Content.stopDemo,
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Composer(stopping: true, onStop: () {}),
            const Text(Content.stopReminder),
            const StatusLabel(
              icon: Icons.stop_circle_outlined,
              label: Content.stopRequested,
            ),
            const WorkStateLabel(state: WorkState.stopped),
            const Text(Content.stopUnknown),
          ],
        ),
      ),
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

/// Données synthétiques pilotables, indépendantes de tout transport.
class ActivityPreview extends StatefulWidget {
  const ActivityPreview({super.key});
  @override
  State<ActivityPreview> createState() => _ActivityPreviewState();
}

class _ActivityPreviewState extends State<ActivityPreview> {
  List<ActivityItem> _items = const [
    ActivityItem(
      1,
      ActivityKind.tool,
      toolId: 'SYNTHETIC_A',
      started: true,
      details: {
        'name': 'SYNTHETIC',
        'args': {'path': 'example.dart', 'dry_run': false},
      },
    ),
  ];
  final _detailsExpanded = <String?, bool>{};
  bool _reply = false;
  bool _paused = false;
  bool? _manual;
  @override
  Widget build(BuildContext context) {
    final expanded = _manual ?? (!_reply || _detailsExpanded.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(GalleryContent.activitySynthetic),
        const SizedBox(height: Spacing.xs),
        const Text(GalleryContent.activityRealContract),
        const SizedBox(height: Spacing.xs),
        if (_items.length >= 2)
          ActivityGroup(
            count: _items.length,
            pending: _items.where((a) => !a.completed).length,
            expanded: expanded,
            onChanged: (value) => setState(() => _manual = value),
          ),
        if (_items.length < 2 || expanded)
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: ActivityLine(
                kind: item.kind,
                completed: item.completed,
                paused: _paused,
                details: item.details,
                expanded: _detailsExpanded[item.toolId] ?? false,
                onChanged: (value) =>
                    setState(() => _detailsExpanded[item.toolId] = value),
              ),
            ),
        if (_reply) const MessageBubble(text: GalleryContent.activityReplyText),
        Wrap(
          spacing: Spacing.sm,
          children: [
            TextButton(
              onPressed: _reply
                  ? null
                  : () => setState(
                      () => _items = [
                        ..._items,
                        ActivityItem(
                          1,
                          ActivityKind.tool,
                          toolId: 'SYNTHETIC_${_items.length}',
                          started: true,
                        ),
                      ],
                    ),
              child: const Text(GalleryContent.activitySecond),
            ),
            TextButton(
              onPressed: () => setState(
                () => _items = [
                  _items.first.copyWith(
                    completed: true,
                    detailPatch: {
                      'result': {
                        'error': 'Exemple synthétique reçu',
                        'output': List.generate(
                          40,
                          (i) => 'Ligne $i : contenu reçu, sans coupe locale.',
                        ).join('\n'),
                      },
                      'inline_diff': '- avant\n+ après',
                    },
                  ),
                  ..._items.skip(1),
                ],
              ),
              child: const Text(GalleryContent.activityComplete),
            ),
            TextButton(
              onPressed: _reply
                  ? null
                  : () => setState(
                      () => _items = [
                        ..._items,
                        ActivityItem(
                          1,
                          ActivityKind.code,
                          toolId: 'SYNTHETIC_CODE_${_items.length}',
                          started: true,
                        ),
                      ],
                    ),
              child: const Text(GalleryContent.activityCode),
            ),
            TextButton(
              onPressed: _reply
                  ? null
                  : () => setState(
                      () => _items = [
                        ..._items,
                        const ActivityItem(1, ActivityKind.unknown),
                      ],
                    ),
              child: const Text(GalleryContent.activityUnknown),
            ),
            TextButton(
              onPressed: () => setState(() => _paused = !_paused),
              child: Text(
                _paused
                    ? GalleryContent.resumeActivities
                    : GalleryContent.pauseActivities,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _reply = true),
              child: const Text(GalleryContent.activityReply),
            ),
            TextButton(
              onPressed: () => setState(() {
                _reply = false;
                _paused = false;
                _manual = null;
                _detailsExpanded.clear();
                _items = const [
                  ActivityItem(
                    1,
                    ActivityKind.tool,
                    toolId: 'SYNTHETIC_A',
                    started: true,
                    details: {
                      'name': 'SYNTHETIC',
                      'args': {'path': 'example.dart', 'dry_run': false},
                    },
                  ),
                ];
              }),
              child: const Text(GalleryContent.activityReset),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        const Text(GalleryContent.activityCatalog),
        const Text(GalleryContent.activityDemonstration),
        const Text(GalleryContent.activityPreparationNote),
        for (final kind in ActivityKind.values)
          Padding(
            key: ValueKey('catalogue-${kind.name}'),
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(GalleryContent.activityCatalogItem(kind)),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.md,
                  runSpacing: Spacing.xs,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ActivityIllustration(kind: kind, paused: _paused),
                        const SizedBox(width: Spacing.xs),
                        const Text(GalleryContent.activityAnimated),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ActivityIllustration(kind: kind, paused: true),
                        const SizedBox(width: Spacing.xs),
                        const Text(GalleryContent.activityStationary),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ConversationCompanionPreview extends StatefulWidget {
  const ConversationCompanionPreview({super.key});
  @override
  State<ConversationCompanionPreview> createState() =>
      _ConversationPreviewState();
}

class _ConversationPreviewState extends State<ConversationCompanionPreview> {
  WorkState _work = WorkState.sending;
  CompanionPhase _phase = CompanionPhase.neutral;
  bool _paused = false;
  bool _active = true;
  int _textLength = 0;
  int _restoration = 0;

  void _change(
    WorkState work,
    CompanionPhase phase, {
    bool text = false,
    bool restore = false,
  }) {
    setState(() {
      _work = work;
      _phase = phase;
      if (work == WorkState.sending) _textLength = 0;
      if (text) {
        _textLength = (_textLength + 18).clamp(
          0,
          GalleryContent.sampleReply.length,
        );
      }
      // Une reprise reconstruit la pose courante et annule toute réaction locale.
      if (restore) _restoration++;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ConversationCompanion(
        key: ValueKey(_restoration),
        phase: _phase,
        paused: _paused,
        active: _active,
        resting:
            _work == WorkState.succeeded ||
            _work == WorkState.failed ||
            _work == WorkState.stopped,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_textLength > 0)
              MessageBubble(
                text: GalleryContent.sampleReply.substring(0, _textLength),
              ),
            ActivityLine(
              kind: ActivityKind.tool,
              showIllustration: false,
              paused: _paused || !_active,
            ),
            Semantics(liveRegion: true, child: WorkStateLabel(state: _work)),
          ],
        ),
      ),
      Wrap(
        spacing: Spacing.sm,
        children: [
          for (final state in WorkState.values)
            TextButton(
              onPressed: () => _change(
                state,
                state == WorkState.running
                    ? CompanionPhase.concentrating
                    : CompanionPhase.neutral,
              ),
              child: Text(WorkStateLabel.label(state)),
            ),
          TextButton(
            onPressed: () =>
                _change(WorkState.running, CompanionPhase.concentrating),
            child: const Text(GalleryContent.companionStart),
          ),
          TextButton(
            onPressed: () =>
                _change(WorkState.running, CompanionPhase.reading, text: true),
            child: const Text(GalleryContent.companionText),
          ),
          TextButton(
            onPressed: () => _change(
              WorkState.running,
              _textLength > 0
                  ? CompanionPhase.reading
                  : CompanionPhase.concentrating,
              restore: true,
            ),
            child: const Text(GalleryContent.companionRestore),
          ),
          TextButton(
            onPressed: () => setState(() => _paused = !_paused),
            child: Text(
              _paused ? Content.resumeCompanion : Content.pauseCompanion,
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _active = !_active),
            child: Text(
              _active
                  ? GalleryContent.companionSuspend
                  : GalleryContent.companionShow,
            ),
          ),
        ],
      ),
    ],
  );
}

class _BackgroundPreview extends StatefulWidget {
  const _BackgroundPreview();
  @override
  State<_BackgroundPreview> createState() => _BackgroundPreviewState();
}

class _BackgroundPreviewState extends State<_BackgroundPreview> {
  CompanionPalette _palette = CompanionPalette.lavenderPeach;
  Future<void> _open(bool fail) async {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final forcedMotion = context
        .getInheritedWidgetOfExactType<_GalleryMotion>()!
        .disabled;
    var failed = false;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => Theme(
          data: theme,
          child: MediaQuery(
            data: media.copyWith(
              disableAnimations:
                  forcedMotion || MediaQuery.disableAnimationsOf(routeContext),
            ),
            child: CompanionBackgroundEditor(
              initialPalette: _palette,
              onApply: (palette) async {
                await Future<void>.delayed(Motion.medium);
                if (fail && !failed) {
                  failed = true;
                  throw StateError('Gallery simulation');
                }
                if (mounted) setState(() => _palette = palette);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: CompanionBackdrop(
          palette: _palette,
          child: const RabbitCompanion(name: Content.companionName),
        ),
      ),
      Text(companionPaletteLabel(_palette)),
      OutlinedButton(
        onPressed: () => _open(false),
        child: const Text(Content.backgroundTitle),
      ),
      OutlinedButton(
        onPressed: () => _open(true),
        child: const Text(GalleryContent.backgroundFailure),
      ),
    ],
  );
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

class _GalleryMotion extends InheritedWidget {
  const _GalleryMotion({required this.disabled, required super.child});
  final bool disabled;
  @override
  bool updateShouldNotify(_GalleryMotion oldWidget) =>
      disabled != oldWidget.disabled;
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
                _GalleryMotion(
                  disabled: variant.disableAnimations,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
