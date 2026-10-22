import 'package:flutter/material.dart';

import '../../models/timeline.dart';
import '../content.dart';
import '../tokens.dart';
import 'activity_details.dart';

/// Ligne d'activité générique : jamais de détail inventé sur ce que fait Hermes.
class ActivityLine extends StatelessWidget {
  const ActivityLine({
    super.key,
    required this.kind,
    this.completed = false,
    this.details = const {},
    this.expanded = false,
    this.onChanged,
  });

  /// Famille issue du mapping (`tool`, `unknown`).
  final ActivityKind kind;
  final bool completed;
  final Map<String, Object?> details;
  final bool expanded;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final label = Content.activity(kind == ActivityKind.tool);
    final scheme = Theme.of(context).colorScheme;
    final heading = Semantics(
      container: true,
      label: completed ? '$label, ${Content.activityEndAccessible}' : label,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ActivityTokens.illustration,
            height: ActivityTokens.illustration,
            child: Icon(
              kind == ActivityKind.tool
                  ? Icons.build_outlined
                  : Icons.circle_outlined,
              size: IconSizes.sm,
              color: scheme.content,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                if (completed)
                  Row(
                    children: [
                      Icon(
                        Icons.horizontal_rule,
                        size: IconSizes.sm,
                        color: scheme.content,
                      ),
                      const SizedBox(width: Spacing.xs),
                      const Flexible(child: Text(Content.activityEnd)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onChanged == null || ActivityDetails.sections(details).isEmpty) {
      return heading;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: completed ? '$label, ${Content.activityEndAccessible}' : label,
          expanded: expanded,
          hint: expanded ? Content.collapseDetails : Content.expandDetails,
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(
                ActivityTokens.command,
                ActivityTokens.command,
              ),
              alignment: Alignment.centerLeft,
            ),
            onPressed: () => onChanged!(!expanded),
            child: Row(
              children: [
                Expanded(child: ExcludeSemantics(child: heading)),
                ExcludeSemantics(
                  child: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: IconSizes.md,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded) ActivityDetails(details: details),
      ],
    );
  }
}
