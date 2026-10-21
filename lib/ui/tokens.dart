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

/// Échelles de texte de référence (galerie : texte agrandi 200 %).
abstract final class TextScales {
  static const double large = 2.0;
}

/// Rôles de couleur résolus à l'exécution (DESIGN.md, runtime-role-bindings).
/// Les composants lisent ces noms, jamais une valeur hexadécimale.
extension ColorRoles on ColorScheme {
  Color get canvas => surface;
  Color get content => onSurface;
  Color get emphasis => primary;
  Color get emphasisContent => onPrimary;
}
