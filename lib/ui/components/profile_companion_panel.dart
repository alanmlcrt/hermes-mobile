import 'package:flutter/material.dart';

import '../content.dart';
import '../tokens.dart';
import 'rabbit_companion.dart';

/// Présentation locale, indépendante du libellé et du contrat serveur du profil.
class ProfileCompanionPanel extends StatefulWidget {
  const ProfileCompanionPanel({
    super.key,
    this.name = Content.companionName,
    this.active = true,
  });

  final String? name;
  final bool active;

  @override
  State<ProfileCompanionPanel> createState() => _ProfileCompanionPanelState();
}

class _ProfileCompanionPanelState extends State<ProfileCompanionPanel> {
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.name?.trim();
    final displayName = name == null || name.isEmpty
        ? Content.companionFallback
        : name;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              displayName,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RabbitTokens.backdrop,
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: RabbitCompanion(
                  name: displayName,
                  active: widget.active,
                  paused: _paused,
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            TextButton(
              onPressed: () => setState(() => _paused = !_paused),
              child: Text(
                _paused ? Content.resumeCompanion : Content.pauseCompanion,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
