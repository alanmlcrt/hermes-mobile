// Thème central (refonte 2026-10-23) : neutres gris-bleu, police Inter,
// accent du profil en `secondary` (AccentScope). Dynamic Color seulement si
// un schéma est fourni.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PredictiveBackEvent;

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
    borderRadius: BorderRadius.circular(Radii.lg),
  );
  final base = ThemeData(
    colorScheme: scheme,
    brightness: scheme.brightness,
    fontFamily: Fonts.family,
  );
  return base.copyWith(
    scaffoldBackgroundColor: scheme.canvas,
    // Transitions de page homogènes sur toutes les plateformes : axe Z.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomFadePageTransitionsBuilder(),
        TargetPlatform.iOS: ZoomFadePageTransitionsBuilder(),
        TargetPlatform.windows: ZoomFadePageTransitionsBuilder(),
        TargetPlatform.linux: ZoomFadePageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomFadePageTransitionsBuilder(),
      },
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
        borderRadius: BorderRadius.circular(Radii.xl),
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
        shape: const StadiumBorder(),
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
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.content,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm + Spacing.xs,
          vertical: Spacing.sm,
        ),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm + Spacing.xs,
      ),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
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
          top: Radius.circular(Radii.pill),
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
        shape: const StadiumBorder(),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.card,
      selectedColor: scheme.surfaceContainerHigh,
      side: BorderSide(color: scheme.line),
      shape: const StadiumBorder(),
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

/// Transition de page « axe Z » (Material shared axis) : la page sortante
/// s'efface en grossissant à peine, l'entrante émerge d'un zoom léger. Sans
/// direction, elle convient aussi aux remplacements (`go`). Immobile sous
/// mouvement réduit.
class ZoomFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const ZoomFadePageTransitionsBuilder();

  @override
  Duration get transitionDuration => Motion.page;

  @override
  Duration get reverseTransitionDuration => Motion.pageReverse;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    // Une seule arborescence (paramètres variables) : basculer en geste ne
    // reconstruit jamais la page.
    final gesture = route.navigator?.userGestureInProgress ?? false;
    final shrinking = gesture && animation.value < 1;
    const split = Layout.pageFadeSplit;
    const opaque = AlwaysStoppedAnimation<double>(1);
    return _BackGesture(
      route: route,
      child: FadeTransition(
        // Geste : la page du dessous reste visible derrière le doigt.
        opacity: gesture
            ? opaque
            : secondaryAnimation.drive(
                Tween<double>(
                  begin: 1,
                  end: 0,
                ).chain(CurveTween(curve: const Interval(0, split))),
              ),
        child: ScaleTransition(
          scale: secondaryAnimation.drive(
            Tween(begin: Layout.normalScale, end: Layout.pageExitScale).chain(
              CurveTween(curve: gesture ? Curves.linear : Motion.emphasized),
            ),
          ),
          child: FadeTransition(
            opacity: gesture
                ? opaque
                : animation.drive(
                    CurveTween(
                      curve: const Interval(split, 1, curve: Motion.enter),
                    ),
                  ),
            child: ScaleTransition(
              // Geste : la page suit le doigt en rétrécissant, coins arrondis.
              scale: animation.drive(
                gesture
                    ? Tween(
                        begin: Layout.backGestureScale,
                        end: Layout.normalScale,
                      )
                    : Tween(
                        begin: Layout.pageEnterScale,
                        end: Layout.normalScale,
                      ).chain(CurveTween(curve: Motion.emphasized)),
              ),
              child: ClipRRect(
                clipBehavior: shrinking ? Clip.antiAlias : Clip.none,
                borderRadius: BorderRadius.circular(shrinking ? Radii.xl : 0),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Relie le geste de retour prédictif d'Android (14+) à la route courante :
/// sa progression pilote l'animation de la page.
class _BackGesture extends StatefulWidget {
  const _BackGesture({required this.route, required this.child});
  final PageRoute<Object?> route;
  final Widget child;

  @override
  State<_BackGesture> createState() => _BackGestureState();
}

class _BackGestureState extends State<_BackGesture>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final route = widget.route;
    if (backEvent.isButtonEvent ||
        !route.isCurrent ||
        !route.popGestureEnabled) {
      return false;
    }
    route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) => widget
      .route
      .handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);

  @override
  void handleCancelBackGesture() => widget.route.handleCancelBackGesture();

  @override
  void handleCommitBackGesture() => widget.route.handleCommitBackGesture();

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Feuille du bas : montée amortie, descente plus vive.
const sheetAnimation = AnimationStyle(
  duration: Motion.sheet,
  reverseDuration: Motion.sheetReverse,
  curve: Motion.emphasized,
);

/// Durée de mouvement effective : nulle si le système demande de réduire
/// les animations.
Duration motionDuration(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
