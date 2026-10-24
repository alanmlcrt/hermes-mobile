import 'package:flutter/material.dart';

import '../content.dart';
import '../tokens.dart';

/// Commande seule : les lignes restent des blocs paresseux du fil.
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
            backgroundColor: scheme.card,
            shape: StadiumBorder(side: BorderSide(color: scheme.line)),
            padding: const EdgeInsetsDirectional.only(
              start: Spacing.sm + Spacing.xs,
              end: Spacing.md,
            ),
          ),
          onPressed: () => onChanged(!expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  pending == 0 ? Icons.check : Icons.more_horiz,
                  size: IconSizes.sm,
                  color: scheme.accent,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Flexible(
                child: Text(
                  Content.activitySummary(count, pending),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
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
