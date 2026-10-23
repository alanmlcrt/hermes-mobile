import 'package:flutter/material.dart';

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
  });

  /// Famille issue du mapping (`tool`, `code`, `unknown`).
  final ActivityKind kind;
  final bool completed;
  final bool paused;

  /// Désactivé dans la conversation, où Otc porte seul la présence animée.
  final bool showIllustration;
  final ActivityCatalog catalog;
  final Map<String, Object?> details;
  final bool expanded;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final label = Content.activityLabel(kind);
    final scheme = Theme.of(context).colorScheme;
    final heading = Semantics(
      container: true,
      label: completed ? '$label, ${Content.activityEndAccessible}' : label,
      excludeSemantics: true,
      child: Row(
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
