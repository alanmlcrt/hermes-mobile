import 'package:flutter/material.dart';

import '../content.dart';
import '../tokens.dart';
import 'rabbit_companion.dart';
import '../../models/companion_background.dart';
import 'companion_backdrop.dart';

/// Présentation locale, indépendante du libellé et du contrat serveur du profil.
class ProfileCompanionPanel extends StatefulWidget {
  const ProfileCompanionPanel({
    super.key,
    this.name = Content.companionName,
    this.active = true,
    this.palette = CompanionPalette.lavenderPeach,
    this.onBackground,
    this.backgroundLoading = false,
    this.backgroundError = false,
    this.onRetryBackground,
  });

  final String? name;
  final bool active;
  final CompanionPalette palette;
  final VoidCallback? onBackground;
  final bool backgroundLoading;
  final bool backgroundError;
  final VoidCallback? onRetryBackground;

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
    // En-tête de profil (style Grok) : compagnon centré, nom, actions en pilules.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CompanionBackdrop(
              palette: widget.palette,
              child: RabbitCompanion(
                name: displayName,
                size: RabbitTokens.preview,
                active: widget.active,
                paused: _paused,
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          if (widget.backgroundLoading)
            Semantics(
              container: true,
              liveRegion: true,
              child: const Text(Content.backgroundLoading),
            ),
          if (widget.backgroundError) ...[
            Semantics(
              liveRegion: true,
              child: const Text(Content.backgroundReadError),
            ),
            TextButton(
              onPressed: widget.onRetryBackground,
              child: const Text(Content.backgroundRetry),
            ),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              if (widget.onBackground != null ||
                  widget.backgroundLoading ||
                  widget.backgroundError)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, RabbitTokens.minimum),
                  ),
                  onPressed: widget.backgroundLoading || widget.backgroundError
                      ? null
                      : widget.onBackground,
                  child: const Text(Content.backgroundTitle),
                ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, RabbitTokens.minimum),
                ),
                onPressed: () => setState(() => _paused = !_paused),
                child: Text(
                  _paused ? Content.resumeCompanion : Content.pauseCompanion,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
