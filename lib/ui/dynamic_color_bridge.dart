// Pont entre dynamic_color 2.1.0 et le thème de l'app.
//
// dynamic_color 2.1.0 fournit des `ColorScheme` du paquet `material_ui`
// (bibliothèque Material découplée du SDK), alors que l'app et
// flutter_markdown_plus utilisent `package:flutter/material.dart`. Les deux
// types sont distincts : on recopie ici chaque rôle, sans transformation.
import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as mui;

/// Convertit un schéma `material_ui` (ou `null`) en schéma Flutter.
ColorScheme? fromDynamicScheme(mui.ColorScheme? s) {
  if (s == null) return null;
  return ColorScheme(
    brightness: s.brightness,
    primary: s.primary,
    onPrimary: s.onPrimary,
    primaryContainer: s.primaryContainer,
    onPrimaryContainer: s.onPrimaryContainer,
    primaryFixed: s.primaryFixed,
    primaryFixedDim: s.primaryFixedDim,
    onPrimaryFixed: s.onPrimaryFixed,
    onPrimaryFixedVariant: s.onPrimaryFixedVariant,
    secondary: s.secondary,
    onSecondary: s.onSecondary,
    secondaryContainer: s.secondaryContainer,
    onSecondaryContainer: s.onSecondaryContainer,
    secondaryFixed: s.secondaryFixed,
    secondaryFixedDim: s.secondaryFixedDim,
    onSecondaryFixed: s.onSecondaryFixed,
    onSecondaryFixedVariant: s.onSecondaryFixedVariant,
    tertiary: s.tertiary,
    onTertiary: s.onTertiary,
    tertiaryContainer: s.tertiaryContainer,
    onTertiaryContainer: s.onTertiaryContainer,
    tertiaryFixed: s.tertiaryFixed,
    tertiaryFixedDim: s.tertiaryFixedDim,
    onTertiaryFixed: s.onTertiaryFixed,
    onTertiaryFixedVariant: s.onTertiaryFixedVariant,
    error: s.error,
    onError: s.onError,
    errorContainer: s.errorContainer,
    onErrorContainer: s.onErrorContainer,
    surface: s.surface,
    onSurface: s.onSurface,
    surfaceDim: s.surfaceDim,
    surfaceBright: s.surfaceBright,
    surfaceContainerLowest: s.surfaceContainerLowest,
    surfaceContainerLow: s.surfaceContainerLow,
    surfaceContainer: s.surfaceContainer,
    surfaceContainerHigh: s.surfaceContainerHigh,
    surfaceContainerHighest: s.surfaceContainerHighest,
    onSurfaceVariant: s.onSurfaceVariant,
    outline: s.outline,
    outlineVariant: s.outlineVariant,
    shadow: s.shadow,
    scrim: s.scrim,
    inverseSurface: s.inverseSurface,
    onInverseSurface: s.onInverseSurface,
    inversePrimary: s.inversePrimary,
    surfaceTint: s.surfaceTint,
  );
}
