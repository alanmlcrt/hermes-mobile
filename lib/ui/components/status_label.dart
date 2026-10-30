import 'package:flutter/material.dart';

import '../tokens.dart';

/// Indicateur d'état : icône + libellé, jamais la couleur seule.
/// Le libellé sert aussi de nom accessible ; l'icône est décorative.
class StatusLabel extends StatelessWidget {
  const StatusLabel({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: IconSizes.sm, color: scheme.emphasis),
          const SizedBox(width: Spacing.xs),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: scheme.content),
            ),
          ),
        ],
      ),
    );
  }
}
