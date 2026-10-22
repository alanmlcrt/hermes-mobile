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
  Widget build(BuildContext context) => Semantics(
    expanded: expanded,
    hint: expanded ? Content.collapseActivities : Content.expandActivities,
    child: TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(ActivityTokens.command, ActivityTokens.command),
        alignment: Alignment.centerLeft,
      ),
      onPressed: () => onChanged(!expanded),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: IconSizes.md,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(child: Text(Content.activitySummary(count, pending))),
        ],
      ),
    ),
  );
}
