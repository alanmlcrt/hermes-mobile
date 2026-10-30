import 'package:flutter/material.dart';

import '../../models/profile_accent.dart';
import '../tokens.dart';

/// Disque à la couleur du profil, initiale du nom en blanc. Décoratif : le
/// nom est toujours écrit à côté.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.label,
    required this.size,
    this.accent,
  });
  final String label;
  final double size;

  /// Nul : l'accent du thème (AccentScope).
  final ProfileAccent? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = label.trim();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent == null ? scheme.accent : AccentTokens.of(accent!),
        ),
        child: Text(
          trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
          // L'initiale suit le diamètre, pas la taille de texte système.
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: AccentTokens.onAccent,
            fontSize: size * Layout.avatarLetter,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Donne l'accent [accent] à tout ce qui est dessous (`scheme.accent`).
class AccentScope extends StatelessWidget {
  const AccentScope({super.key, required this.accent, required this.child});
  final ProfileAccent accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          secondary: AccentTokens.of(accent),
          onSecondary: AccentTokens.onAccent,
        ),
      ),
      child: child,
    );
  }
}
