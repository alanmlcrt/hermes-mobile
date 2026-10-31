import 'package:flutter/material.dart';

import '../../models/result.dart';
import '../../models/timeline.dart';
import '../content.dart';
import '../tokens.dart';
import 'activity_catalog.dart';
import 'activity_details.dart';

/// Ligne d'activité générique : jamais de détail inventé sur ce que fait Hermes.
class ActivityLine extends StatelessWidget {
  const ActivityLine({
    super.key,
    required this.kind,
    this.completed = false,
    this.paused = false,
    this.showIllustration = true,
    this.catalog = ActivityCatalog.standard,
    this.details = const {},
    this.expanded = false,
    this.onChanged,
    this.resultProduced = false,
  });

  /// Famille issue du mapping (`tool`, `code`, `unknown`).
  final ActivityKind kind;
  final bool completed;
  final bool paused;

  /// Petit dessin animé de l'activité en cours (catalogue des familles).
  final bool showIllustration;
  final ActivityCatalog catalog;
  final Map<String, Object?> details;
  final bool expanded;
  final ValueChanged<bool>? onChanged;

  /// L'activité a produit une carte résultat : la mention « non récupérable »
  /// ne s'applique alors pas.
  final bool resultProduced;

  /// Capsule d'activité (style AI SDK Elements `<Tool>` compact) : bordure fine
  /// 1px, forme pilule, libellé et badge d'état.
  Widget _pill(BuildContext context, String label) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelMedium;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: scheme.bubbleSurface,
          shape: StadiumBorder(side: BorderSide(color: scheme.line)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm + Spacing.xs,
            vertical: Spacing.xs + Spacing.xxs,
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Spacing.xs,
            children: [
              if (showIllustration)
                ActivityIllustration(
                  kind: kind,
                  completed: completed,
                  paused: paused,
                  catalog: catalog,
                ),
              Text(label, style: style?.copyWith(fontWeight: FontWeight.w500)),
              if (completed) ...[
                Icon(Icons.check, size: IconSizes.sm, color: scheme.content),
                Text(
                  Content.activityEnd,
                  style: style?.copyWith(color: scheme.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Carte d'outil (style AI SDK Elements `<ToolHeader>` + `<ToolContent>`) :
  /// en-tête structuré avec nom de l'outil, résumé en chasse fixe, badge d'état
  /// et chevron de repli.
  Widget _card(
    BuildContext context,
    String label,
    String? summary,
    String? mention,
    bool expandable,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelLarge;
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showIllustration) ...[
          ActivityIllustration(
            kind: kind,
            completed: completed,
            paused: paused,
            catalog: catalog,
          ),
          const SizedBox(width: Spacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Spacing.xs,
                children: [
                  Text(
                    label,
                    style: style?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (completed)
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: scheme.chip,
                        shape: StadiumBorder(
                          side: BorderSide(color: scheme.line),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.xs,
                          vertical: Spacing.xxs,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check,
                              size: IconSizes.sm,
                              color: scheme.content,
                            ),
                            const SizedBox(width: Spacing.xxs),
                            Text(
                              Content.activityEnd,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (summary != null) ...[
                const SizedBox(height: Spacing.xs),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.codeSurface,
                    borderRadius: BorderRadius.circular(Radii.xs),
                    border: Border.all(color: scheme.line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.xs + Spacing.xxs,
                      vertical: Spacing.xxs,
                    ),
                    child: Text(
                      kind == ActivityKind.command ? '\$ $summary' : summary,
                      maxLines: expanded ? null : 1,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: ActivityTokens.detailFont,
                        color: scheme.muted,
                      ),
                    ),
                  ),
                ),
              ],
              if (mention != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  mention,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (expandable)
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: IconSizes.sm,
            color: scheme.muted,
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm + Spacing.xs,
        vertical: Spacing.sm,
      ),
      child: header,
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = Content.activityLabel(kind);
    final scheme = Theme.of(context).colorScheme;
    final summary = ActivityDetails.summary(details);
    // Un chemin absolu affiché par une activité qui n'a rien produit reste
    // sur Hermes ; jamais pour une commande, une URL ou le texte d'une réponse.
    final mention =
        !resultProduced &&
            kind != ActivityKind.command &&
            summary != null &&
            ResultPaths.isAbsolute(summary)
        ? Content.activityPathUnavailable
        : null;
    final expandable =
        onChanged != null && ActivityDetails.sections(details).isNotEmpty;
    final spoken = completed
        ? '$label, ${Content.activityEndAccessible}'
        : label;
    final spokenValue = [summary, mention].nonNulls.join('\n');
    if (summary == null && !expandable) {
      return Semantics(
        container: true,
        label: spoken,
        excludeSemantics: true,
        child: _pill(context, label),
      );
    }
    final card = ExcludeSemantics(
      child: _card(context, label, summary, mention, expandable),
    );
    // Sans AnimatedSize : à durée nulle il se redessine pendant sa mise en page.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: scheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: spoken,
            value: spokenValue.isEmpty ? null : spokenValue,
            expanded: expandable ? expanded : null,
            hint: !expandable
                ? null
                : expanded
                ? Content.collapseDetails
                : Content.expandDetails,
            child: expandable
                ? TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: scheme.content,
                      alignment: AlignmentDirectional.centerStart,
                      minimumSize: const Size(
                        ActivityTokens.command,
                        ActivityTokens.command,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.lg),
                      ),
                    ),
                    onPressed: () => onChanged!(!expanded),
                    child: card,
                  )
                : card,
          ),
          if (expandable && expanded) ...[
            Divider(color: scheme.line),
            ActivityDetails(details: details),
          ],
        ],
      ),
    );
  }
}
