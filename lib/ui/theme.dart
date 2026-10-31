// Thème central (refonte 2026-10-23) : neutres gris-bleu, police Inter,
// accent du profil en `secondary` (AccentScope). Dynamic Color seulement si
// un schéma est fourni.
import 'package:flutter/material.dart';

import '../models/profile_accent.dart';
import 'tokens.dart';

/// Palette de l'app, claire/sombre (style monochrome shadcn/ui & AI Elements).
ColorScheme fallbackColorScheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ink = dark ? Palette.inkDark : Palette.inkLight;
  final bg = dark ? Palette.bgDark : Palette.bgLight;
  final chip = dark ? Palette.chipDark : Palette.chipLight;
  return ColorScheme.fromSeed(
    seedColor: AccentTokens.of(ProfileAccent.indigo),
    brightness: brightness,
  ).copyWith(
    primary: ink,
    onPrimary: bg,
    secondary: ink,
    onSecondary: bg,
    secondaryContainer: chip,
    onSecondaryContainer: ink,
    surface: bg,
    onSurface: ink,
    onSurfaceVariant: dark ? Palette.mutedDark : Palette.mutedLight,
    surfaceContainerLowest: dark ? Palette.bgDark : Palette.cardLight,
    surfaceContainerLow: dark ? Palette.cardDark : Palette.cardLight,
    surfaceContainer: dark ? Palette.bubbleDark : Palette.bubbleLight,
    surfaceContainerHigh: chip,
    surfaceContainerHighest: dark ? Palette.codeDark : Palette.codeLight,
    outline: dark ? Palette.outlineDark : Palette.outlineLight,
    outlineVariant: dark ? Palette.lineDark : Palette.lineLight,
    error: dark ? Palette.errorDark : Palette.errorLight,
    inverseSurface: ink,
    onInverseSurface: bg,
    scrim: Palette.scrim,
    surfaceTint: Colors.transparent,
  );
}

/// Construit le thème à partir du schéma dynamique [dynamicScheme] fourni par
/// `DynamicColorBuilder`, ou de la palette de l'app s'il est `null`.
ThemeData buildTheme(ColorScheme? dynamicScheme, Brightness brightness) {
  final scheme = dynamicScheme ?? fallbackColorScheme(brightness);
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.md),
  );
  final base = ThemeData(
    colorScheme: scheme,
    brightness: scheme.brightness,
    fontFamily: Fonts.family,
  );
  return base.copyWith(
    scaffoldBackgroundColor: scheme.canvas,
    // Transitions de page homogènes : fondu glissé (Android).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.canvas,
      foregroundColor: scheme.content,
      surfaceTintColor: Colors.transparent,
      elevation: Elevations.flat,
      scrolledUnderElevation: Elevations.flat,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleMedium?.copyWith(
        color: scheme.content,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: Elevations.flat,
      margin: EdgeInsets.zero,
      color: scheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: scheme.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.emphasis,
        foregroundColor: scheme.emphasisContent,
        elevation: Elevations.flat,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        shape: rounded,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.content,
        backgroundColor: scheme.card,
        side: BorderSide(color: scheme.line),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        shape: rounded,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.content,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm + Spacing.xs,
          vertical: Spacing.sm,
        ),
        shape: rounded,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm + Spacing.xs,
        vertical: Spacing.sm + Spacing.xs,
      ),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: scheme.outline),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: rounded,
      iconColor: scheme.onSurfaceVariant,
      selectedColor: scheme.content,
      selectedTileColor: scheme.surfaceContainerHigh,
      subtitleTextStyle: base.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.line,
      dragHandleSize: const Size(
        Layout.sheetHandleWidth,
        Layout.sheetHandleHeight,
      ),
      modalBarrierColor: scheme.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.xl),
        ),
        side: BorderSide(color: scheme.line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
        side: BorderSide(color: scheme.line),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(Layout.headerButton),
        shape: rounded,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.card,
      selectedColor: scheme.surfaceContainerHigh,
      side: BorderSide(color: scheme.line),
      shape: rounded,
    ),
    dividerTheme: DividerThemeData(color: scheme.line, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.emphasis),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      behavior: SnackBarBehavior.floating,
      shape: rounded,
    ),
    iconTheme: IconThemeData(color: scheme.content, size: IconSizes.md),
  );
}

/// Durée de mouvement effective : nulle si le système demande de réduire
/// les animations.
Duration motionDuration(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
