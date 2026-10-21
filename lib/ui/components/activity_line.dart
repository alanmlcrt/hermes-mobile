import 'package:flutter/material.dart';

import '../content.dart';
import 'status_label.dart';

/// Ligne d'activité générique : jamais de détail inventé sur ce que fait Hermes.
class ActivityLine extends StatelessWidget {
  const ActivityLine({super.key, required this.kind});

  /// Famille issue du mapping (`tool`, `unknown`).
  final String kind;

  @override
  Widget build(BuildContext context) => StatusLabel(
    icon: kind == 'tool' ? Icons.build_outlined : Icons.more_horiz,
    label: Content.activity(kind),
  );
}
