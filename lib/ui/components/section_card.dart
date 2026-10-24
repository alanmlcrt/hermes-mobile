import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// Surface titrée regroupant un contenu (listes des stories 1.4 et 1.7).
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: AnimatedSize(
          duration: motionDuration(context, Motion.medium),
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: scheme.content),
                ),
              ),
              const SizedBox(height: Spacing.sm),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
