import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../models/timeline.dart';
import '../tokens.dart';
import 'activity_family_painters.dart';

typedef ActivityPainterBuilder = CustomPainter Function({
  required Color color,
  required double progress,
  required bool stationary,
});

/// Entrée du catalogue de présentation : dessin, variante immobile et rythme
/// issus de [ActivityTokens], sans dépendance au transport ni à la persistance.
class ActivityCatalogEntry {
  const ActivityCatalogEntry({
    required this.painter,
    this.cycle = ActivityTokens.cycle,
    this.rest = ActivityTokens.rest,
  });

  final ActivityPainterBuilder painter;
  final Duration cycle;
  final Duration rest;
}

/// Catalogue déclaratif indexé exclusivement par [ActivityKind] avec repli
/// générique sur [ActivityKind.unknown] (UX-DR12, UX-DR15).
class ActivityCatalog {
  const ActivityCatalog({
    Map<ActivityKind, ActivityCatalogEntry>? entries,
    this.fallback = unknownEntry,
  }) : _entries = entries ?? _defaultEntries;

  static const standard = ActivityCatalog();

  static const codeEntry = ActivityCatalogEntry(
    painter: CodeActivityPainter.build,
  );
  static const toolEntry = ActivityCatalogEntry(
    painter: ToolActivityPainter.build,
  );
  static const unknownEntry = ActivityCatalogEntry(
    painter: UnknownActivityPainter.build,
  );

  static const _defaultEntries = <ActivityKind, ActivityCatalogEntry>{
    ActivityKind.code: codeEntry,
    ActivityKind.tool: toolEntry,
    ActivityKind.fileCreate: ActivityCatalogEntry(
      painter: FamilyActivityPainter.fileCreate,
    ),
    ActivityKind.webSearch: ActivityCatalogEntry(
      painter: FamilyActivityPainter.webSearch,
    ),
    ActivityKind.fileRead: ActivityCatalogEntry(
      painter: FamilyActivityPainter.fileRead,
    ),
    ActivityKind.command: ActivityCatalogEntry(
      painter: FamilyActivityPainter.command,
    ),
    ActivityKind.webBrowse: ActivityCatalogEntry(
      painter: FamilyActivityPainter.webBrowse,
    ),
    ActivityKind.fileEdit: ActivityCatalogEntry(
      painter: FamilyActivityPainter.fileEdit,
    ),
    ActivityKind.fileSearch: ActivityCatalogEntry(
      painter: FamilyActivityPainter.fileSearch,
    ),
    ActivityKind.imageCreate: ActivityCatalogEntry(
      painter: FamilyActivityPainter.imageCreate,
    ),
    ActivityKind.memory: ActivityCatalogEntry(
      painter: FamilyActivityPainter.memory,
    ),
    ActivityKind.delegate: ActivityCatalogEntry(
      painter: FamilyActivityPainter.delegate,
    ),
    ActivityKind.organize: ActivityCatalogEntry(
      painter: FamilyActivityPainter.organize,
    ),
    ActivityKind.imageAnalyze: ActivityCatalogEntry(
      painter: FamilyActivityPainter.imageAnalyze,
    ),
    ActivityKind.skill: ActivityCatalogEntry(
      painter: FamilyActivityPainter.skill,
    ),
    ActivityKind.schedule: ActivityCatalogEntry(
      painter: FamilyActivityPainter.schedule,
    ),
    ActivityKind.preparation: ActivityCatalogEntry(
      painter: FamilyActivityPainter.preparation,
    ),
    ActivityKind.unknown: unknownEntry,
  };

  final Map<ActivityKind, ActivityCatalogEntry> _entries;
  final ActivityCatalogEntry fallback;

  ActivityCatalogEntry resolve(ActivityKind kind) => _entries[kind] ?? fallback;

  /// Retourne un nouveau catalogue remplaçant une entrée sans toucher au
  /// décodage serveur (`EventMapping`) ni aux appels Hermes.
  ActivityCatalog copyWithEntry(
    ActivityKind kind,
    ActivityCatalogEntry entry,
  ) => ActivityCatalog(entries: {..._entries, kind: entry}, fallback: fallback);
}

/// Illustration d'activité 24 × 24 px pilotée par [ActivityCatalog].
/// Suspend immédiatement ses cycles et timers sous mouvement réduit, pause,
/// action terminée (`completed: true`), hors viewport, `Offstage`, route
/// couverte ou passage en arrière-plan.
class ActivityIllustration extends StatefulWidget {
  const ActivityIllustration({
    super.key,
    required this.kind,
    this.completed = false,
    this.paused = false,
    this.catalog = ActivityCatalog.standard,
  });

  final ActivityKind kind;
  final bool completed;
  final bool paused;
  final ActivityCatalog catalog;

  @override
  State<ActivityIllustration> createState() => _ActivityIllustrationState();
}

class _ActivityIllustrationState extends State<ActivityIllustration>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  final _bounds = GlobalKey();
  final _scrollPositions = <ScrollPosition>{};
  Timer? _timer;
  bool _visible = false;
  bool _foreground = true;
  bool _surface = true;
  bool _reduced = false;
  bool _cycling = false;
  bool _visibilityQueued = false;

  ActivityCatalogEntry get _entry => widget.catalog.resolve(widget.kind);

  bool get _available => _surface && _foreground && _visible;

  bool get _animate =>
      _available && !widget.paused && !widget.completed && !_reduced;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _motion = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _cycling = false);
          _scheduleCycle();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasAnimate = _animate;
    final reduced = MediaQuery.disableAnimationsOf(context);
    _surface =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (reduced != _reduced) {
      _reduced = reduced;
      _cancel();
    }
    for (final position in _scrollPositions) {
      position.removeListener(_queueVisibility);
    }
    _scrollPositions.clear();
    BuildContext? scrollContext = context;
    while (scrollContext != null) {
      final scrollable = Scrollable.maybeOf(scrollContext);
      if (scrollable == null) break;
      _scrollPositions.add(scrollable.position);
      scrollContext = scrollable.context;
    }
    for (final position in _scrollPositions) {
      position.addListener(_queueVisibility);
    }
    if (wasAnimate != _animate) _cancel();
    _scheduleCycle();
    _queueVisibility();
  }

  @override
  void didUpdateWidget(ActivityIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.completed != widget.completed ||
        oldWidget.paused != widget.paused ||
        oldWidget.catalog != widget.catalog) {
      _cancel();
      _sync();
    }
    _queueVisibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    setState(_sync);
  }

  @override
  void didChangeMetrics() => _queueVisibility();

  void _queueVisibility() {
    if (_visibilityQueued || !mounted) return;
    _visibilityQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityQueued = false;
      if (!mounted) return;
      final box = _bounds.currentContext?.findRenderObject();
      var visible = box is RenderBox && box.attached && box.hasSize;
      if (visible) {
        var rect = MatrixUtils.transformRect(
          box.getTransformTo(null),
          Offset.zero & box.size,
        );
        rect = rect.intersect(Offset.zero & MediaQuery.sizeOf(context));
        context.visitAncestorElements((element) {
          final w = element.widget;
          if (w is Offstage && w.offstage) visible = false;
          final ancestor = element.findRenderObject();
          if (ancestor is RenderAbstractViewport && ancestor is RenderBox) {
            final viewport = ancestor as RenderBox;
            rect = rect.intersect(
              MatrixUtils.transformRect(
                viewport.getTransformTo(null),
                Offset.zero & viewport.size,
              ),
            );
          }
          return true;
        });
        visible = visible && !rect.isEmpty;
      }
      if (_visible != visible) {
        setState(() {
          _visible = visible;
          _sync();
        });
      }
    });
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _motion.stop();
    _motion.value = 0;
    _cycling = false;
  }

  void _sync() {
    if (!_animate) {
      _cancel();
    } else {
      _scheduleCycle();
    }
  }

  void _scheduleCycle() {
    if (!_animate || _cycling || _timer != null) return;
    final entry = _entry;
    _timer = Timer(entry.rest, () {
      _timer = null;
      if (!mounted || !_animate) return;
      setState(() => _cycling = true);
      _motion.duration = entry.cycle;
      _motion.forward(from: 0);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final position in _scrollPositions) {
      position.removeListener(_queueVisibility);
    }
    _timer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.content;
    final entry = _entry;
    final stationary = !_animate || !_cycling;
    return ExcludeSemantics(
      child: _ActivityPaintVisibility(
        onComposition: _queueVisibility,
        child: SizedBox.square(
          key: _bounds,
          dimension: ActivityTokens.illustration,
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) => CustomPaint(
              painter: entry.painter(
                color: color,
                progress: stationary ? 0 : _motion.value,
                stationary: stationary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityPaintVisibility extends SingleChildRenderObjectWidget {
  const _ActivityPaintVisibility({
    required this.onComposition,
    required super.child,
  });
  final VoidCallback onComposition;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderActivityPaintVisibility(onComposition);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderActivityPaintVisibility renderObject,
  ) {
    renderObject.onComposition = onComposition;
  }
}

class _RenderActivityPaintVisibility extends RenderProxyBox {
  _RenderActivityPaintVisibility(this.onComposition);
  VoidCallback onComposition;
  VoidCallback? _removeCompositionCallback;

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    _removeCompositionCallback?.call();
    _removeCompositionCallback = context.addCompositionCallback(
      (_) => onComposition(),
    );
    super.paint(context, offset);
    onComposition();
  }

  @override
  void detach() {
    _removeCompositionCallback?.call();
    _removeCompositionCallback = null;
    super.detach();
  }
}

/// Illustration « Écriture du code » (`UX-DR14`) : le châssis de l'ordinateur
/// reste strictement fixe avec des traits épais ; seuls les lignes de code et
/// le curseur bougent.
class CodeActivityPainter extends CustomPainter {
  const CodeActivityPainter({
    required this.color,
    this.progress = 0,
    this.stationary = true,
  });

  static CustomPainter build({
    required Color color,
    required double progress,
    required bool stationary,
  }) => CodeActivityPainter(
    color: color,
    progress: progress,
    stationary: stationary,
  );

  final Color color;
  final double progress;
  final bool stationary;

  /// Emprise du châssis fixe (inspectable en test pour vérifier son immobilité).
  Rect get chassisBounds => ActivityTokens.codeMonitor.outerRect;

  /// Longueurs courantes des trois lignes de code à l'intérieur de l'écran.
  List<double> get lineLengths {
    if (stationary) {
      return const [
        ActivityTokens.codeLine1MaxWidth,
        ActivityTokens.codeLine2MaxWidth,
        ActivityTokens.codeLine3MaxWidth,
      ];
    }
    double segment(double start, double end, double max) {
      if (progress <= start) return 0;
      if (progress >= end) return max;
      return Curves.easeOut.transform((progress - start) / (end - start)) * max;
    }

    return [
      segment(0, ActivityTokens.codeLine1End, ActivityTokens.codeLine1MaxWidth),
      segment(
        ActivityTokens.codeLine1End,
        ActivityTokens.codeLine2End,
        ActivityTokens.codeLine2MaxWidth,
      ),
      segment(
        ActivityTokens.codeLine2End,
        ActivityTokens.codeLine3End,
        ActivityTokens.codeLine3MaxWidth,
      ),
    ];
  }

  /// Position courante du curseur à l'intérieur de l'écran.
  Offset get cursorOffset {
    final lengths = lineLengths;
    if (stationary) {
      return Offset(
        ActivityTokens.codeLineStartX +
            lengths[2] +
            ActivityTokens.codeCursorGap,
        ActivityTokens.codeLine3Y,
      );
    }
    if (progress < ActivityTokens.codeLine1End) {
      return Offset(
        ActivityTokens.codeLineStartX +
            lengths[0] +
            ActivityTokens.codeCursorGap,
        ActivityTokens.codeLine1Y,
      );
    }
    if (progress < ActivityTokens.codeLine2End) {
      return Offset(
        ActivityTokens.codeLineStartX +
            lengths[1] +
            ActivityTokens.codeCursorGap,
        ActivityTokens.codeLine2Y,
      );
    }
    return Offset(
      ActivityTokens.codeLineStartX + lengths[2] + ActivityTokens.codeCursorGap,
      ActivityTokens.codeLine3Y,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / ActivityTokens.viewSize,
      size.height / ActivityTokens.viewSize,
    );
    canvas.save();
    canvas.translate(
      (size.width - ActivityTokens.viewSize * scale) / 2,
      (size.height - ActivityTokens.viewSize * scale) / 2,
    );
    canvas.scale(scale);

    // Châssis fixe aux traits épais (jamais translaté ni tourné).
    final chassisPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = ActivityTokens.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(ActivityTokens.codeMonitor, chassisPaint);
    canvas.drawLine(
      ActivityTokens.codeNeckTop,
      ActivityTokens.codeNeckBottom,
      chassisPaint,
    );
    canvas.drawLine(
      ActivityTokens.codeBaseStart,
      ActivityTokens.codeBaseEnd,
      chassisPaint,
    );

    // Lignes de code et curseur mobiles à l'intérieur de l'écran.
    final codePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = ActivityTokens.lineStrokeWidth
      ..strokeCap = StrokeCap.round;
    final lengths = lineLengths;
    final ys = const [
      ActivityTokens.codeLine1Y,
      ActivityTokens.codeLine2Y,
      ActivityTokens.codeLine3Y,
    ];
    for (var i = 0; i < ys.length; i++) {
      if (lengths[i] <= 0) continue;
      canvas.drawLine(
        Offset(ActivityTokens.codeLineStartX, ys[i]),
        Offset(ActivityTokens.codeLineStartX + lengths[i], ys[i]),
        codePaint,
      );
    }
    final cursor = cursorOffset;
    canvas.drawLine(
      Offset(cursor.dx, cursor.dy - ActivityTokens.codeCursorHalfHeight),
      Offset(cursor.dx, cursor.dy + ActivityTokens.codeCursorHalfHeight),
      codePaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CodeActivityPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.stationary != stationary;
}

/// Illustration « Appel d'outil » : boîtier machine aux traits épais, clé
/// oscillante et impulsion de signal.
class ToolActivityPainter extends CustomPainter {
  const ToolActivityPainter({
    required this.color,
    this.progress = 0,
    this.stationary = true,
  });

  static CustomPainter build({
    required Color color,
    required double progress,
    required bool stationary,
  }) => ToolActivityPainter(
    color: color,
    progress: progress,
    stationary: stationary,
  );

  final Color color;
  final double progress;
  final bool stationary;

  double get wrenchAngle => stationary
      ? 0
      : math.sin(progress * math.pi * 2) * ActivityTokens.toolWrenchAngle;

  double get signalX => stationary
      ? ActivityTokens.toolSignalStartX
      : ActivityTokens.toolSignalStartX +
            Curves.easeInOut.transform(progress) *
                ActivityTokens.toolSignalTravel;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / ActivityTokens.viewSize,
      size.height / ActivityTokens.viewSize,
    );
    canvas.save();
    canvas.translate(
      (size.width - ActivityTokens.viewSize * scale) / 2,
      (size.height - ActivityTokens.viewSize * scale) / 2,
    );
    canvas.scale(scale);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = ActivityTokens.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRRect(ActivityTokens.toolChassis, strokePaint);
    canvas.drawCircle(
      ActivityTokens.toolPortCenter,
      ActivityTokens.toolPortRadius,
      fillPaint,
    );

    canvas.save();
    canvas.translate(ActivityTokens.toolPivot.dx, ActivityTokens.toolPivot.dy);
    canvas.rotate(wrenchAngle);
    canvas.translate(
      -ActivityTokens.toolPivot.dx,
      -ActivityTokens.toolPivot.dy,
    );
    canvas.drawLine(
      ActivityTokens.toolShaftStart,
      ActivityTokens.toolShaftEnd,
      strokePaint,
    );
    canvas.drawArc(
      ActivityTokens.toolJawArc,
      math.pi * ActivityTokens.toolJawStartFactor,
      math.pi * ActivityTokens.toolJawSweepFactor,
      false,
      strokePaint,
    );
    canvas.restore();

    canvas.drawCircle(
      Offset(signalX, ActivityTokens.toolSignalY),
      ActivityTokens.toolSignalRadius,
      fillPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ToolActivityPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.stationary != stationary;
}

/// Illustration générique / `ActivityKind.unknown` (`UX-DR13` concilié avec le
/// lot 4 Otc) : trois petits points en rotation dans le slot 24 × 24 px, sans
/// bulle ni grand dessin, immobiles en variante fixe.
class UnknownActivityPainter extends CustomPainter {
  const UnknownActivityPainter({
    required this.color,
    this.progress = 0,
    this.stationary = true,
  });

  static CustomPainter build({
    required Color color,
    required double progress,
    required bool stationary,
  }) => UnknownActivityPainter(
    color: color,
    progress: progress,
    stationary: stationary,
  );

  final Color color;
  final double progress;
  final bool stationary;

  double get rotationAngle => stationary ? 0 : progress * math.pi * 2;

  List<Offset> get dotCenters {
    final baseAngle = -math.pi / 2 + rotationAngle;
    return [
      for (var i = 0; i < 3; i++)
        Offset(
          ActivityTokens.unknownCenter.dx +
              math.cos(baseAngle + i * (2 * math.pi / 3)) *
                  ActivityTokens.unknownOrbitRadius,
          ActivityTokens.unknownCenter.dy +
              math.sin(baseAngle + i * (2 * math.pi / 3)) *
                  ActivityTokens.unknownOrbitRadius,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / ActivityTokens.viewSize,
      size.height / ActivityTokens.viewSize,
    );
    canvas.save();
    canvas.translate(
      (size.width - ActivityTokens.viewSize * scale) / 2,
      (size.height - ActivityTokens.viewSize * scale) / 2,
    );
    canvas.scale(scale);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final center in dotCenters) {
      canvas.drawCircle(center, ActivityTokens.unknownDotRadius, fillPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(UnknownActivityPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.stationary != stationary;
}
