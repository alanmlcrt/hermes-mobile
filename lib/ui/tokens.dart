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

abstract final class ActivityTokens {
  // Motifs vectoriels sur 32 unités, affichés dans le slot commun de 24 px.
  // Les contours fixes restent séparés des pièces mobiles.
  static Path _lines(List<List<double>> lines) {
    final path = Path();
    for (final line in lines) {
      path.moveTo(line[0], line[1]);
      for (var i = 2; i < line.length; i += 2) {
        path.lineTo(line[i], line[i + 1]);
      }
    }
    return path;
  }

  static Path _box(double x, double y, double w, double h) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        const Radius.circular(2),
      ),
    );
  static Path _circle(double x, double y, double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
  static Path get _paper => _lines([
    [7, 3, 20, 3, 26, 9, 26, 29, 7, 29, 7, 3],
    [20, 3, 20, 9, 26, 9],
  ]);
  static Path get _textLines => _lines([
    [11, 13, 22, 13],
    [11, 18, 20, 18],
    [11, 23, 22, 23],
  ]);
  static Path get _browser => _box(3, 5, 26, 23)
    ..addPath(
      _lines([
        [3, 11, 29, 11],
        [7, 8, 8, 8],
        [12, 8, 13, 8],
      ]),
      Offset.zero,
    );
  static Path get _lens => _circle(21, 20, 5)
    ..addPath(
      _lines([
        [25, 24, 29, 28],
      ]),
      Offset.zero,
    );
  static Path get _picture => _box(4, 4, 24, 24);
  static Path get _landscape => _circle(22, 10, 2)
    ..addPath(
      _lines([
        [7, 25, 13, 17, 18, 22, 22, 18, 26, 24],
      ]),
      Offset.zero,
    );
  static final familyDrawings = <String, ActivityFamilyDrawing>{
    'fileCreate': ActivityFamilyDrawing(
      fixed: _paper,
      moving: _textLines,
      reveal: true,
    ),
    'fileEdit': ActivityFamilyDrawing(
      fixed: _paper
        ..addPath(
          _lines([
            [11, 14, 19, 14],
            [11, 23, 18, 23],
          ]),
          Offset.zero,
        ),
      moving: _lines([
        [17, 19, 26, 10, 29, 13, 20, 22, 16, 23, 17, 19],
        [25, 11, 28, 14],
      ]),
      travel: const Offset(1, -2),
    ),
    'webSearch': ActivityFamilyDrawing(
      fixed: _browser
        ..addPath(
          _lines([
            [7, 15, 17, 15],
            [7, 20, 13, 20],
            [7, 24, 14, 24],
          ]),
          Offset.zero,
        ),
      moving: _lens,
      travel: const Offset(-1, -1),
    ),
    'webBrowse': ActivityFamilyDrawing(
      fixed: _browser
        ..addPath(
          _lines([
            [7, 16, 23, 16],
            [7, 21, 16, 21],
            [7, 25, 14, 25],
          ]),
          Offset.zero,
        ),
      moving: _lines([
        [19, 18, 21, 28, 23, 24, 28, 23, 19, 18],
      ]),
      travel: const Offset(1, -1),
    ),
    'fileRead': ActivityFamilyDrawing(
      fixed: _paper..addPath(_textLines, Offset.zero),
      moving: _lines([
        [10, 17, 23, 17],
      ]),
      travel: const Offset(0, 6),
    ),
    'command': ActivityFamilyDrawing(
      fixed: _browser
        ..addPath(
          _lines([
            [7, 15, 10, 18, 7, 21],
            [13, 18, 22, 18],
          ]),
          Offset.zero,
        ),
      moving: _lines([
        [7, 24, 19, 24],
        [25, 16, 25, 20],
      ]),
      reveal: true,
    ),
    'fileSearch': ActivityFamilyDrawing(
      fixed: _lines([
        [3, 11, 3, 27, 27, 27, 29, 15, 3, 15],
        [3, 11, 12, 11, 15, 15],
      ]),
      moving: _box(10, 5, 10, 16)..addPath(_lens, Offset.zero),
      travel: const Offset(0, -2),
    ),
    'imageCreate': ActivityFamilyDrawing(
      fixed: _picture..addPath(_landscape, Offset.zero),
      moving:
          _lines([
            [13, 17, 23, 6, 26, 9, 16, 20, 13, 17],
          ])..addPath(
            Path()
              ..moveTo(13, 17)
              ..cubicTo(7, 17, 12, 23, 6, 25)
              ..cubicTo(12, 28, 18, 25, 16, 20)
              ..close(),
            Offset.zero,
          ),
      travel: const Offset(2, 2),
    ),
    'imageAnalyze': ActivityFamilyDrawing(
      fixed: _picture..addPath(_landscape, Offset.zero),
      moving: _lines([
        [9, 14, 9, 10, 13, 10],
        [17, 10, 21, 10, 21, 14],
        [9, 18, 9, 22, 13, 22],
        [17, 22, 21, 22, 21, 18],
      ])..addPath(_circle(15, 16, 1), Offset.zero),
      travel: const Offset(3, 2),
    ),
    'memory': ActivityFamilyDrawing(
      fixed: _box(7, 8, 19, 21)
        ..addPath(
          _lines([
            [11, 8, 11, 29],
            [4, 12, 9, 12],
            [4, 18, 9, 18],
            [4, 24, 9, 24],
          ]),
          Offset.zero,
        ),
      moving: _box(15, 3, 10, 14)
        ..addPath(
          _lines([
            [18, 7, 22, 7],
            [18, 11, 22, 11],
          ]),
          Offset.zero,
        ),
      travel: const Offset(0, 1),
    ),
    'delegate': ActivityFamilyDrawing(
      fixed: _box(11, 3, 10, 8)
        ..addPath(
          _lines([
            [16, 11, 16, 16, 7, 16, 7, 21],
            [16, 16, 25, 16, 25, 21],
          ]),
          Offset.zero,
        )
        ..addPath(_box(2, 21, 10, 8), Offset.zero)
        ..addPath(_box(20, 21, 10, 8), Offset.zero),
      moving: _circle(7, 17, 1.8)..addPath(_circle(25, 17, 1.8), Offset.zero),
      travel: const Offset(0, 3),
      filled: true,
    ),
    'organize': ActivityFamilyDrawing(
      fixed: _paper,
      moving: _box(11, 12, 3, 3)
        ..addPath(_box(11, 18, 3, 3), Offset.zero)
        ..addPath(_box(11, 24, 3, 3), Offset.zero)
        ..addPath(
          _lines([
            [18, 14, 23, 14],
            [18, 20, 22, 20],
            [18, 26, 23, 26],
          ]),
          Offset.zero,
        ),
      reveal: true,
    ),
    'skill': ActivityFamilyDrawing(
      fixed: _lines([
        [
          16,
          8,
          9,
          5,
          3,
          6,
          3,
          25,
          9,
          24,
          16,
          28,
          23,
          24,
          29,
          25,
          29,
          6,
          23,
          5,
          16,
          8,
          16,
          28,
        ],
        [7, 11, 12, 13],
        [7, 17, 12, 19],
      ]),
      moving: _lines([
        [16, 8, 24, 6, 24, 24, 16, 28],
        [19, 13, 22, 12],
        [19, 19, 22, 18],
      ]),
      travel: const Offset(-3, 0),
    ),
    'schedule': ActivityFamilyDrawing(
      fixed: _box(4, 6, 20, 22)
        ..addPath(
          _lines([
            [4, 12, 24, 12],
            [9, 3, 9, 8],
            [19, 3, 19, 8],
            [8, 17, 14, 17],
            [8, 22, 12, 22],
          ]),
          Offset.zero,
        )
        ..addPath(_circle(23, 23, 7), Offset.zero)
        ..addPath(
          _lines([
            [23, 23, 26, 25],
          ]),
          Offset.zero,
        ),
      moving: _lines([
        [23, 23, 23, 18],
      ]),
      pivot: const Offset(23, 23),
      rotation: 1,
    ),
    'preparation': ActivityFamilyDrawing(
      fixed: Path(),
      moving: _circle(16, 8.8, 2.7)
        ..addPath(_circle(22.24, 19.6, 2.7), Offset.zero)
        ..addPath(_circle(9.76, 19.6, 2.7), Offset.zero),
      pivot: const Offset(16, 16),
      rotation: 1,
      filled: true,
    ),
  };
  static const double detailHeight = 240;
  static const String detailFont = 'monospace';
  static const double illustration = 24;
  static const double command = 48;
  static const double viewSize = 32;
  static const double strokeWidth = 3.2;
  static const double lineStrokeWidth = 2.6;
  static const Duration cycle = Duration(milliseconds: 800);
  static const Duration rest = Duration(milliseconds: 600);

  // Géométrie de l'illustration « code » (châssis d'ordinateur fixe, UX-DR14).
  static final RRect codeMonitor = RRect.fromRectAndRadius(
    const Rect.fromLTWH(3, 4, 26, 18),
    const Radius.circular(3.5),
  );
  static const Offset codeNeckTop = Offset(16, 22);
  static const Offset codeNeckBottom = Offset(16, 27);
  static const Offset codeBaseStart = Offset(9.5, 27);
  static const Offset codeBaseEnd = Offset(22.5, 27);
  static const double codeLineStartX = 7.5;
  static const double codeLine1Y = 9.5;
  static const double codeLine1MaxWidth = 11.0;
  static const double codeLine1End = 0.3;
  static const double codeLine2Y = 14.0;
  static const double codeLine2MaxWidth = 14.0;
  static const double codeLine2End = 0.65;
  static const double codeLine3Y = 18.0;
  static const double codeLine3MaxWidth = 8.0;
  static const double codeLine3End = 0.95;
  static const double codeCursorGap = 2.2;
  static const double codeCursorHalfHeight = 1.6;

  // Géométrie de l'illustration « tool » (boîtier d'outil + clé + impulsion).
  static final RRect toolChassis = RRect.fromRectAndRadius(
    const Rect.fromLTWH(3.5, 9, 13, 14),
    const Radius.circular(3),
  );
  static const Offset toolPortCenter = Offset(10, 16);
  static const double toolPortRadius = 2.2;
  static const Offset toolPivot = Offset(22, 16);
  static const double toolWrenchAngle = 0.28;
  static const Offset toolShaftStart = Offset(16.5, 16);
  static const Offset toolShaftEnd = Offset(22.5, 16);
  static const Rect toolJawArc = Rect.fromLTWH(22.5, 12, 6, 8);
  static const double toolJawStartFactor = 0.35;
  static const double toolJawSweepFactor = 1.3;
  static const double toolSignalStartX = 15.0;
  static const double toolSignalTravel = 5.5;
  static const double toolSignalY = 8.0;
  static const double toolSignalRadius = 1.8;

  // Géométrie de l'illustration « unknown » (trois petits points en rotation, UX-DR13).
  static const Offset unknownCenter = Offset(16, 16);
  static const double unknownOrbitRadius = 7.2;
  static const double unknownDotRadius = 2.7;
}

/// Géométrie et mouvement d’un motif du catalogue, indépendants des événements.
class ActivityFamilyDrawing {
  const ActivityFamilyDrawing({
    required this.fixed,
    required this.moving,
    this.travel = Offset.zero,
    this.pivot = Offset.zero,
    this.rotation = 0,
    this.reveal = false,
    this.filled = false,
  });
  final Path fixed;
  final Path moving;
  final Offset travel;
  final Offset pivot;
  final double rotation;
  final bool reveal;
  final bool filled;
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
  static const double frostSigma = 12;
  static const Color frost = Color(0x33FFFFFF);
  static const LinearGradient mintSky = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD9F0E6), Color(0xFFDCEAF8)],
  );
  static const LinearGradient roseLilac = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5DDE8), Color(0xFFE7DFF5)],
  );
  static const double large = 180;
  static const double compact = 64;
  static const double conversationSideWidth = 360;
  static const double conversationTextLimit = 1.5;
  static const double concentrationEyeScale = .65;
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
