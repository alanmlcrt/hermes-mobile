import 'package:flutter/material.dart';

import '../content.dart';
import '../tokens.dart';

/// En-tête de raisonnement / groupe d'étapes (style AI SDK Elements
/// `<ChainOfThought>` / `<Reasoning>`) : bouton encadré repliable listant le
/// nombre d'étapes d'outil exécutées ou en cours.
class ActivityGroup extends StatelessWidget {
  const ActivityGroup({
    super.key,
    required this.count,
    required this.pending,
    required this.expanded,
    required this.onChanged,
  });
  final int count;
  final int pending;
  final bool expanded;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      expanded: expanded,
      hint: expanded ? Content.collapseActivities : Content.expandActivities,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(
              ActivityTokens.command,
              ActivityTokens.command,
            ),
            foregroundColor: scheme.content,
            backgroundColor: scheme.bubbleSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md),
              side: BorderSide(color: scheme.line),
            ),
            padding: const EdgeInsetsDirectional.only(
              start: Spacing.sm + Spacing.xs,
              end: Spacing.sm + Spacing.xs,
            ),
          ),
          onPressed: () => onChanged(!expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  pending == 0 ? Icons.check : Icons.auto_awesome_outlined,
                  size: IconSizes.sm,
                  color: scheme.muted,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Flexible(
                child: Text(
                  Content.activitySummary(count, pending),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.content,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.xs),
              ExcludeSemantics(
                child: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: IconSizes.sm,
                  color: scheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
