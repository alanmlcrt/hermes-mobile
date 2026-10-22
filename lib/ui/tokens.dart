// Source unique des valeurs visuelles (UX-DR : tokens).
// Les littéraux visuels ne sont autorisés qu'ici et dans `theme.dart`
// (contrôlé par test/visual_literals_test.dart).
import 'package:flutter/material.dart';

/// Espacements (marges, écarts entre éléments).
abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Rayons d'arrondi.
abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}

/// Élévations.
abstract final class Elevations {
  static const double flat = 0;
  static const double card = 1;
}

/// Tailles d'icônes.
abstract final class IconSizes {
  static const double sm = 18;
  static const double md = 24;
  static const double lg = 32;
}

/// Durées de mouvement. À lire via `motionDuration` (theme.dart), qui
/// respecte la préférence « mouvement réduit » du système.
abstract final class Motion {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
}

/// Hauteur visible du champ de saisie, en lignes ; au-delà il défile.
abstract final class ComposerLines {
  static const int min = 3;
  static const int max = 8;
}

/// Police à chasse fixe des blocs de code.
abstract final class CodeStyle {
  static const String family = 'monospace';
}

/// Échelles de texte de référence (galerie : texte agrandi 200 %).
abstract final class TextScales {
  static const double large = 2.0;
}

/// Réglages locaux du compagnon, sans modifier la palette de l'application.
abstract final class RabbitTokens {
  static const double large = 180;
  static const double compact = 64;
  static const double minimum = 48;
  static const double stroke = 1.2;
  static const double faceStroke = 2.8;
  static const double minimumOutline = .65;
  static const double minimumFaceStroke = 1;
  static const double headForeshortening = .065;
  static const double faceForeshortening = .14;
  static const double focusStroke = 3;
  static const double focusHalo = 1.5;
  static const double wiggleCycles = 4;
  static const double viewWidth = 200;
  static const double viewHeight = 240;
  static const double gazeDistance = 8;
  static const double turnDistance = 5;
  static const double earWiggle = .095;
  static const double headTilt = .06;
  static const Duration rest = Duration(seconds: 6);
  static const Duration travel = Duration(milliseconds: 300);
  static const Duration hold = Duration(milliseconds: 700);
  static const Duration tickle = Duration(milliseconds: 1100);
  static final Duration glance = travel + hold + travel;
  static const Color coat = Color(0xFFFFFFFF);
  static const Color innerEar = Color(0xFFD9D9D9);
  static const Color ink = Color(0xFF000000);
  static const Color outline = Color(0xFF68616F);
  static const LinearGradient backdrop = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE6DFF5), Color(0xFFF5DFD3)],
  );

  // Anatomie v5 dans un repère fixe ; jamais de miroir global.
  static const Offset leftPivot = Offset(82, 133);
  static const Offset rightPivot = Offset(119, 133);
  static const Offset headPivot = Offset(100, 177);
  static const Rect head = Rect.fromLTWH(54, 119, 94, 113);
  static const Rect leftEye = Rect.fromLTWH(67, 165, 8, 13);
  static const Rect rightEye = Rect.fromLTWH(127, 165, 8, 13);
  static Path get leftEar => Path()
    ..moveTo(80, 136)
    ..cubicTo(49, 104, 43, 48, 53, 22)
    ..cubicTo(66, -8, 103, 54, 96, 126)
    ..close();
  static Path get leftInner => Path()
    ..moveTo(83, 126)
    ..cubicTo(65, 90, 57, 45, 62, 30)
    ..cubicTo(72, 26, 94, 77, 89, 125)
    ..close();
  static Path get rightEar => Path()
    ..moveTo(109, 126)
    ..cubicTo(123, 85, 158, 39, 176, 35)
    ..cubicTo(208, 29, 181, 83, 125, 139)
    ..close();
  static Path get rightInner => Path()
    ..moveTo(120, 127)
    ..cubicTo(139, 87, 166, 51, 178, 47)
    ..cubicTo(190, 46, 166, 88, 128, 131)
    ..close();
  static Path get nose => Path()
    ..moveTo(93, 187)
    ..quadraticBezierTo(101, 184, 109, 187)
    ..quadraticBezierTo(112, 189, 103, 198)
    ..quadraticBezierTo(101, 200, 99, 198)
    ..quadraticBezierTo(90, 190, 93, 187)
    ..close();
  static Path get mouth => Path()
    ..moveTo(101, 197)
    ..lineTo(101, 203)
    ..cubicTo(100, 213, 90, 214, 85, 206)
    ..moveTo(101, 203)
    ..cubicTo(102, 213, 112, 214, 117, 206);
  static Path get happyEyes => Path()
    ..moveTo(66, 173)
    ..cubicTo(70, 166, 77, 166, 81, 173)
    ..moveTo(124, 173)
    ..cubicTo(128, 166, 135, 166, 139, 173);
}

/// Rôles de couleur résolus à l'exécution (DESIGN.md, runtime-role-bindings).
/// Les composants lisent ces noms, jamais une valeur hexadécimale.
extension ColorRoles on ColorScheme {
  Color get canvas => surface;
  Color get content => onSurface;
  Color get emphasis => primary;
  Color get emphasisContent => onPrimary;
  Color get codeSurface => surfaceContainerHighest;
  Color get bubbleSurface => secondaryContainer;
  Color get bubbleContent => onSecondaryContainer;
}
