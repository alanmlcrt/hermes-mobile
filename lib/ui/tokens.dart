// Source unique des valeurs visuelles (UX-DR : tokens).
// Les littéraux visuels ne sont autorisés qu'ici et dans `theme.dart`
// (contrôlé par test/visual_literals_test.dart).
import 'package:flutter/material.dart';

import '../models/profile_accent.dart';

/// Neutres de l'app (refonte 2026-10-23, DESIGN.md) : fond gris-bleu très
/// clair, cartes blanches, encre quasi noire ; inversés en sombre. La seule
/// couleur vive est l'accent du profil ([AccentTokens]).
abstract final class Palette {
  static const Color bgLight = Color(0xFFF7F8FA);
  static const Color bgDark = Color(0xFF0E1013);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF171A1F);
  static const Color bubbleLight = Color(0xFFEDEFF2);
  static const Color bubbleDark = Color(0xFF1C2026);
  static const Color chipLight = Color(0xFFEDEFF2);
  static const Color chipDark = Color(0xFF22262C);
  static const Color codeLight = Color(0xFFE3E6EA);
  static const Color codeDark = Color(0xFF2A2F36);
  static const Color lineLight = Color(0xFFE3E6EA);
  static const Color lineDark = Color(0xFF2A2F36);
  static const Color outlineLight = Color(0xFFC9CED6);
  static const Color outlineDark = Color(0xFF3A4049);
  static const Color inkLight = Color(0xFF111418);
  static const Color inkDark = Color(0xFFEEF0F3);
  static const Color mutedLight = Color(0xFF5B6470);
  static const Color mutedDark = Color(0xFF9AA3AE);
  static const Color errorLight = Color(0xFFC62828);
  static const Color errorDark = Color(0xFFFF8A80);

  /// Voile derrière une feuille du bas.
  static const Color scrim = Color(0x73080A0E);

  /// Opacité de la teinte d'accent (ligne surlignée).
  static const double accentTint = .14;
}

/// Couleur d'un profil : avatar, bouton d'envoi, repères. Texte blanc
/// lisible dessus (contraste ≥ 4,5:1) dans les deux thèmes.
abstract final class AccentTokens {
  static const Color onAccent = Color(0xFFFFFFFF);
  static Color of(ProfileAccent accent) => switch (accent) {
    ProfileAccent.indigo => const Color(0xFF4F57E8),
    ProfileAccent.blue => const Color(0xFF1D6FD1),
    ProfileAccent.violet => const Color(0xFF7152E8),
    ProfileAccent.teal => const Color(0xFF00796B),
    ProfileAccent.orange => const Color(0xFFC2410C),
    ProfileAccent.raspberry => const Color(0xFFC2306A),
  };
}

/// Police de l'app (assets/fonts, OFL).
abstract final class Fonts {
  static const String family = 'Inter';
}

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
  static const double xl = 24;
  static const double pill = 28;

  /// Bulles de message.
  static const double bubble = 22;
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
  static const Color successDark = Color(0xFF34D399);
  static const Color successLight = Color(0xFF059669);
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

  /// Cycle des points « Hermes travaille ».
  static const Duration typing = Duration(milliseconds: 1200);
}

/// Hauteur visible du champ de saisie, en lignes ; au-delà il défile.
abstract final class ComposerLines {
  static const int min = 1;
  static const int max = 8;
}

/// Police à chasse fixe des blocs de code.
abstract final class CodeStyle {
  static const String family = 'monospace';
}

/// Échelles de texte de référence (galerie : texte agrandi 200 %).
/// Proportions de mise en page.
abstract final class Layout {
  /// Largeur max d'une bulle, en fraction de l'écran.
  static const double bubbleMaxWidth = .85;

  /// Diamètre du bouton d'envoi rond.
  static const double sendButton = 40;
  static const double stopButton = 48;
  static const double threadMinHeight = 96;

  /// Marge haute de l'accueil d'un brouillon vide, en fraction du fil.
  static const double welcomeTop = .18;

  /// Avatars de profil : liste d'accueil, pastille d'en-tête, feuille
  /// d'historique, accueil d'un brouillon, réglages du profil.
  static const double avatar = 52;
  static const double avatarSmall = 34;
  static const double avatarSheet = 44;
  static const double avatarWelcome = 64;
  static const double avatarLarge = 88;

  /// Initiale dans l'avatar, en fraction du diamètre.
  static const double avatarLetter = .4;

  /// Bouton rond d'en-tête (cible tactile).
  static const double headerButton = 44;

  /// Pastille de palette (cible tactile) et son disque visible.
  static const double swatch = 56;
  static const double swatchDot = 30;
  static const double swatchBorder = 1;
  static const double swatchSelected = 3;

  /// Points animés « Hermes travaille ».
  static const double typingDot = 7;
  static const double typingLift = 3;

  /// Poignée de la feuille du bas.
  static const double sheetHandleWidth = 36;
  static const double sheetHandleHeight = 4;

  /// Hauteur max de la feuille d'historique, en fraction de l'écran.
  static const double sheetMax = .85;

  /// Glissement d'arrivée d'un élément du fil, en fraction de sa hauteur.
  static const double appearShift = .15;

  /// Saisie : hauteur minimale de la pilule.
  static const double composerMinHeight = 52;
}

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
  static const LinearGradient peachSun = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8D9C4), Color(0xFFFCEFC2)],
  );
  static const LinearGradient oceanMist = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFCFE3F7), Color(0xFFD9F2F2)],
  );
  static const LinearGradient sageSand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDDE8D3), Color(0xFFF1E7D2)],
  );
  static const LinearGradient coralRose = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF9D3CC), Color(0xFFF6D9E8)],
  );
  static const LinearGradient pearl = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE9E9EE), Color(0xFFF6F4F0)],
  );
  static const LinearGradient roseLilac = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5DDE8), Color(0xFFE7DFF5)],
  );
  static const double large = 180;
  static const double compact = 64;

  /// Lapin des écrans profil et arrière-plan, plus discret que [large].
  static const double preview = 112;
  static const double conversationSideWidth = 360;
  static const double conversationTextLimit = 1.5;
  static const double concentrationEyeScale = .65;
  static const double minimum = 48;
  static const double stroke = 1.2;
  static const double faceStroke = 2.8;
  static const double minimumOutline = .65;
  static const double minimumFaceStroke = 1;
  // Volume : la tête est un ellipsoïde éclairé en haut à gauche ; le visage
  // et les oreilles tournent à sa surface (lacet), la lumière reste fixe.
  static const double maxYaw = .55;
  static const double maxPitch = .15;
  static const double earLongitude = .42;
  // Faible glissement latéral : l'oreille pivote sur place plutôt que de
  // filer le long du contour (qui, lui, ne bouge pas).
  static const double earRadius = .4;
  static const Offset light = Offset(-.38, -.45);
  static const double lightReach = 1.15;
  static const Color coatShade = Color(0xFFE4DFEC);
  static const Color coatDeep = Color(0xFFBDB4CC);
  static const Color innerEarDeep = Color(0xFFC2B6C9);
  static const Color shadow = Color(0x553A2F4A);
  static const Color shadowClear = Color(0x003A2F4A);
  static const Rect groundShadow = Rect.fromLTWH(58, 227, 86, 11);
  static const double shadowShrink = .045;
  // Aspect peluche : œuf bosselé, grain de feutre, coutures.
  static const double eggTaper = .07;
  static const double headLumps = .012;
  static const double headRoll = .05;
  static const double earDelay = .07;
  static const int grainSeed = 7;
  static const int grainCount = 340;
  static const double grainSize = 1.4;
  static const Color grainDark = Color(0x33685E78);
  static const Color grainLight = Color(0x99FFFFFF);
  static const Color seam = Color(0x33968CA6);
  static const double seamStroke = 1.2;
  static Path get seams => Path()
    ..moveTo(101, 124)
    ..cubicTo(97, 142, 104, 162, 101, 183)
    ..moveTo(60, 162)
    ..cubicTo(74, 146, 128, 146, 142, 162);
  static const double focusStroke = 3;
  static const double focusHalo = 1.5;
  static const double wiggleCycles = 4;
  static const double viewWidth = 200;
  static const double viewHeight = 240;
  static const double earWiggle = .095;
  static const double headTilt = .06;
  // Vie des gestes (inspirée du Grok orb) : clignement piqué, étirement
  // pendant la rotation, oreilles qui traînent puis rebondissent, saut.
  static const double blinkClosure = .9;
  static const double turnStretch = .03;
  static const double earFollow = .05;
  static const double earDrag = .16;
  static const double earFlop = .14;
  static const double hopHeight = 10;
  static const double hopSquash = .07;
  static const double hopStretch = .05;
  static const double wobbleDamping = 6;
  static const double wobbleFrequency = 2.4;
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
  // Racines enfoncées dans la tête : jamais de jour entre oreille et crâne.
  static const Offset leftPivot = Offset(85, 152);
  static const Offset rightPivot = Offset(116, 152);
  // Comme la peluche : la gauche presque droite, la droite penchée dehors
  // et un peu plus évasée.
  static const double leftEarAngle = -.12;
  static const double rightEarAngle = .7;
  static const double rightEarFlare = 1.12;
  static const Offset headPivot = Offset(100, 177);
  static const Offset groundPivot = Offset(100, 232);
  static const Rect head = Rect.fromLTWH(54, 119, 94, 113);
  static const Rect leftEye = Rect.fromLTWH(67, 165, 8, 13);
  static const Rect rightEye = Rect.fromLTWH(127, 165, 8, 13);

  /// Oreille locale, base à l'origine et pointe vers le haut, aux
  /// proportions de la peluche : presque la hauteur de la tête, en feuille,
  /// pincée à la racine et la plus large aux deux tiers.
  static const double earLength = 120;
  static const double wrapStep = 1.5;
  static Path get ear => Path()
    ..moveTo(-9, 18)
    ..cubicTo(-26, -40, -22, -earLength + 6, 0, -earLength)
    ..cubicTo(22, -earLength + 6, 26, -40, 9, 18)
    ..close();
  static Path get earInside => Path()
    ..moveTo(-4, -4)
    ..cubicTo(-19, -44, -16, -earLength + 16, 0, -earLength + 9)
    ..cubicTo(16, -earLength + 16, 19, -44, 4, -4)
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
  Color get bubbleSurface => surfaceContainer;
  Color get bubbleContent => onSurface;

  /// Carte posée sur le fond (réglages, feuille, saisie).
  Color get card => surfaceContainerLow;

  /// Fond des boutons ronds et des pastilles.
  Color get chip => surfaceContainerHigh;
  Color get line => outlineVariant;
  Color get muted => onSurfaceVariant;

  /// Accent du profil courant (AccentScope), sinon l'accent par défaut.
  Color get accent => secondary;
  Color get onAccent => onSecondary;

  /// Fin d'activité confirmée (coche des pilules), lisible sur les deux thèmes.
  Color get success => brightness == Brightness.dark
      ? ActivityTokens.successDark
      : ActivityTokens.successLight;
}
