import 'package:flutter/material.dart';

import '../../models/profile_accent.dart';
import '../tokens.dart';

/// Avatar style AI SDK Elements / shadcn (`<MessageAvatar>`) : carré aux coins
/// modérément arrondis (Radii.md), bordure fine 1px, initiale monochrome.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.label,
    required this.size,
    this.accent,
    this.heroTag,
  });
  final String label;
  final double size;

  /// Avatar partagé entre deux pages (accueil → conversation) : il vole de
  /// l'une à l'autre. Un seul porteur du même tag par page.
  final Object? heroTag;

  /// Nul : l'accent monochrome du thème (AccentScope).
  final ProfileAccent? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = label.trim();
    final bg = accent == null ? scheme.bubbleSurface : AccentTokens.of(accent!);
    final fg = accent == null ? scheme.content : AccentTokens.onAccent;
    final avatar = ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.line),
          color: bg,
        ),
        child: Text(
          trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
          // L'initiale suit le diamètre, pas la taille de texte système.
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: fg,
            fontSize: size * Layout.avatarLetter,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    if (heroTag == null) return avatar;
    return Hero(
      tag: heroTag!,
      // En vol : mis à l'échelle d'un bloc (initiale comprise), sur un
      // Material pour garder le style du texte.
      flightShuttleBuilder: (_, _, direction, from, to) => Material(
        type: MaterialType.transparency,
        child: FittedBox(
          child:
              ((direction == HeroFlightDirection.push ? to : from).widget
                      as Hero)
                  .child,
        ),
      ),
      child: avatar,
    );
  }
}

/// Conserve l'identité monochrome shadcn (`scheme.emphasis` / `scheme.emphasisContent`)
/// sur les éléments actifs tout en propageant le contexte du profil.
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
          secondary: theme.colorScheme.primary,
          onSecondary: theme.colorScheme.onPrimary,
        ),
      ),
      child: child,
    );
  }
}
