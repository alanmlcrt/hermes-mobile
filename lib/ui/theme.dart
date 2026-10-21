// Thème central : Dynamic Color si disponible, palette de secours sinon.
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Graine neutre de la palette de secours (sans couleur de marque).
/// Valeur provisoire jusqu'à G4.
const Color _fallbackSeed = Color(0xFF808080);

/// Palette de secours claire/sombre, utilisée quand le système ne fournit
/// pas de couleurs dynamiques (Android < 12).
ColorScheme fallbackColorScheme(Brightness brightness) => ColorScheme.fromSeed(
      seedColor: _fallbackSeed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    );

/// Construit le thème à partir du schéma dynamique [dynamicScheme] fourni par
/// `DynamicColorBuilder`, ou de la palette de secours s'il est `null`.
ThemeData buildTheme(ColorScheme? dynamicScheme, Brightness brightness) {
  final scheme = dynamicScheme ?? fallbackColorScheme(brightness);
  return ThemeData(
    colorScheme: scheme,
    brightness: scheme.brightness,
    scaffoldBackgroundColor: scheme.canvas,
    cardTheme: CardThemeData(
      elevation: Elevations.card,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
    ),
    iconTheme: IconThemeData(color: scheme.content, size: IconSizes.md),
  );
}

/// Durée de mouvement effective : nulle si le système demande de réduire
/// les animations.
Duration motionDuration(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
