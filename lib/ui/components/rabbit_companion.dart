import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../content.dart';
import '../tokens.dart';

enum RabbitPose { rest, concentrating, reading }

enum RabbitLook { right, down }

/// Compagnon vectoriel autonome. Le propriétaire passe [active] à false
/// lorsqu'il masque sa surface (onglet, Offstage ou sous-vue conservée).
/// TickerMode, route, viewport et cycle de vie sont également respectés.
class RabbitCompanion extends StatefulWidget {
  const RabbitCompanion({
    super.key,
    this.name = Content.companionFallback,
    this.size = RabbitTokens.large,
    this.active = true,
    this.paused = false,
    this.pose = RabbitPose.rest,
    this.autonomous = true,
    this.readingLook = RabbitLook.right,
  }) : assert(size >= RabbitTokens.minimum);

  final String name;
  final double size;
  final bool active;
  final bool paused;
  final RabbitPose pose;
  final bool autonomous;
  final RabbitLook readingLook;

  @override
  State<RabbitCompanion> createState() => _RabbitCompanionState();
}

class _RabbitCompanionState extends State<RabbitCompanion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  final _bounds = GlobalKey();
  final _focusNode = FocusNode();
  final _scrollPositions = <ScrollPosition>{};
  Timer? _timer;
  bool _visible = false;
  bool _foreground = true;
  bool _surface = true;
  bool _reduced = false;
  bool _reacting = false;
  bool _glancing = false;
  bool _fixedReaction = false;
  bool _focused = false;
  double _direction = 1;
  bool _visibilityQueued = false;

  bool get _available => widget.active && _surface && _foreground && _visible;
  bool get _animate => _available && !widget.paused && !_reduced;

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
          setState(_resetPose);
          _scheduleRest();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasAvailable = _available;
    final reduced = MediaQuery.disableAnimationsOf(context);
    _surface =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (reduced != _reduced) {
      _reduced = reduced;
      _cancel(); // Includes a running reaction: no residual frame or timer.
    }
    for (final position in _scrollPositions) {
      position.removeListener(_queueVisibility);
    }
    _scrollPositions.clear();
    // Establish dependencies on every ancestor Scrollable's inherited scope,
    // including position replacement with an otherwise constant child.
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
    if (wasAvailable != _available) _cancel();
    _scheduleRest();
    _queueVisibility();
  }

  @override
  void didUpdateWidget(RabbitCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active ||
        oldWidget.paused != widget.paused) {
      _cancel();
      _sync();
    }
    if (oldWidget.pose != widget.pose ||
        oldWidget.autonomous != widget.autonomous) {
      // Une chatouille garde sa durée locale ; sa fin lira la pose courante.
      if (!_reacting) _cancel();
      _scheduleRest();
    }
    _queueVisibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
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
          final widget = element.widget;
          if (widget is Offstage && widget.offstage) visible = false;
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

  void _resetPose() {
    _reacting = false;
    _glancing = false;
    _fixedReaction = false;
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _motion.stop();
    _resetPose();
  }

  void _sync() {
    if (!_animate) {
      _cancel();
    } else {
      _scheduleRest();
    }
  }

  void _scheduleRest() {
    if (!_animate ||
        !widget.autonomous ||
        widget.pose != RabbitPose.rest ||
        _reacting ||
        _glancing ||
        _timer != null) {
      return;
    }
    _timer = Timer(RabbitTokens.rest, () {
      _timer = null;
      if (!_animate) return;
      setState(() {
        _glancing = true;
        _direction = -_direction;
      });
      _motion.duration = RabbitTokens.glance;
      _motion.forward(from: 0);
    });
  }

  void _tickle() {
    if (!_available || _reacting) return;
    _cancel();
    setState(() {
      _reacting = true;
      _fixedReaction = _reduced || widget.paused;
    });
    if (_fixedReaction) {
      _timer = Timer(RabbitTokens.tickle, () {
        _timer = null;
        if (!mounted) return;
        setState(_resetPose);
        _scheduleRest();
      });
    } else {
      _motion.duration = RabbitTokens.tickle;
      _motion.forward(from: 0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final position in _scrollPositions) {
      position.removeListener(_queueVisibility);
    }
    _timer?.cancel();
    _motion.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name.trim().isEmpty
        ? Content.companionFallback
        : widget.name;
    return _PaintVisibility(
      onComposition: _queueVisibility,
      child: SizedBox.square(
        key: _bounds,
        dimension: widget.size,
        child: Semantics(
          excludeSemantics: true,
          button: true,
          enabled: _available,
          focusable: _available,
          focused: _available ? _focused : null,
          onFocus: _available ? _focusNode.requestFocus : null,
          label: Content.tickleCompanion(name),
          onTap: _available ? _tickle : null,
          child: Material(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(Radii.lg),
            child: InkWell(
              focusNode: _focusNode,
              canRequestFocus: _available,
              onTap: _available ? _tickle : null,
              onFocusChange: (value) => setState(() => _focused = value),
              borderRadius: BorderRadius.circular(Radii.lg),
              child: CustomPaint(
                foregroundPainter: _available && _focused
                    ? const _FocusRingPainter()
                    : null,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (context, _) {
                      final t = _motion.value;
                      final travel =
                          RabbitTokens.travel.inMilliseconds /
                          RabbitTokens.glance.inMilliseconds;
                      final envelope = _glancing
                          ? (t < travel
                                ? Curves.easeInOutBack.transform(t / travel)
                                : t > 1 - travel
                                ? Curves.easeInOutBack.transform(
                                    (1 - t) / travel,
                                  )
                                : 1.0)
                          : 0.0;
                      final reaction = _reacting && !_fixedReaction
                          ? math.sin(t * math.pi)
                          : 0.0;
                      final life = _reacting && !_fixedReaction
                          ? _hopLife(t)
                          : _glancing
                          ? _glanceLife(t, envelope, travel, _direction)
                          : _Life.still;
                      return CustomPaint(
                        painter: RabbitPainter(
                          blink: life.blink,
                          lift: life.lift,
                          squash: life.squash,
                          earSway: life.earSway,
                          earSwayRight: life.earSwayRight,
                          earSpread: life.earSpread,
                          gaze: _reacting
                              ? reaction
                              : widget.pose == RabbitPose.reading &&
                                    widget.readingLook == RabbitLook.right
                              ? 1
                              : _direction * envelope,
                          gazeDown:
                              !_reacting &&
                                  widget.pose == RabbitPose.reading &&
                                  widget.readingLook == RabbitLook.down
                              ? 1
                              : 0,
                          concentrating:
                              !_reacting &&
                              widget.pose == RabbitPose.concentrating,
                          wiggle: _reacting && !_fixedReaction
                              ? math.sin(
                                      t *
                                          math.pi *
                                          2 *
                                          RabbitTokens.wiggleCycles,
                                    ) *
                                    reaction
                              : 0,
                          tickled: _reacting,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paramètres secondaires d'un geste, calculés à partir de sa progression.
class _Life {
  const _Life({
    this.blink = 0,
    this.lift = 0,
    this.squash = 0,
    this.earSway = 0,
    this.earSwayRight = 0,
    this.earSpread = 0,
  });
  static const still = _Life();
  final double blink;
  final double lift;
  final double squash;
  final double earSway;
  final double earSwayRight;
  final double earSpread;
}

/// Clignement : la paupière tombe vite puis se relève plus lentement.
double _blink(double t, double start, double length) {
  final u = (t - start) / length;
  if (u <= 0 || u >= 1) return 0;
  const close = .35;
  final s = u < close
      ? math.sin(u / close * math.pi / 2)
      : math.cos((u - close) / (1 - close) * math.pi / 2);
  return s * s;
}

/// Silhouette de peluche : un œuf plus étroit au menton, légèrement bosselé
/// comme un tissu rembourré.
final Path _headShape = () {
  final head = RabbitTokens.head;
  final path = Path();
  const steps = 72;
  for (var i = 0; i <= steps; i++) {
    final a = i / steps * 2 * math.pi;
    final lumps =
        1 +
        RabbitTokens.headLumps *
            (math.sin(3 * a + .7) + .6 * math.sin(5 * a + 2.1));
    final x =
        head.center.dx +
        head.width /
            2 *
            math.cos(a) *
            (1 - RabbitTokens.eggTaper * math.sin(a)) *
            lumps;
    final y = head.center.dy + head.height / 2 * math.sin(a) * lumps;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path..close();
}();

/// Points du grain de feutre, tirés une fois sur la face avant de la tête.
final List<Offset> _grain = () {
  final random = math.Random(RabbitTokens.grainSeed);
  final head = RabbitTokens.head;
  final points = <Offset>[];
  while (points.length < RabbitTokens.grainCount) {
    final x = random.nextDouble() * 2 - 1;
    final y = random.nextDouble() * 2 - 1;
    if (x * x + y * y >= 1) continue;
    points.add(
      Offset(
        head.center.dx + x * head.width / 2,
        head.center.dy + y * head.height / 2,
      ),
    );
  }
  return points;
}();

/// Oscillation amortie lancée à [start] (secondes), éteinte en fin de geste
/// pour que le retour au repos ne saute pas.
double _wobble(double seconds, double start, double t) {
  final s = seconds - start;
  if (s <= 0) return 0;
  return math.exp(-RabbitTokens.wobbleDamping * s) *
      math.sin(s * RabbitTokens.wobbleFrequency * 2 * math.pi) *
      math.min(1, (1 - t) * 5);
}

/// Regard de côté : clignement au départ, léger étirement pendant les
/// rotations, oreilles qui traînent derrière la tête puis la rattrapent.
_Life _glanceLife(double t, double envelope, double travel, double direction) {
  final seconds = t * RabbitTokens.glance.inMilliseconds / 1000;
  final back = (1 - travel) * RabbitTokens.glance.inMilliseconds / 1000;
  double drag(double delay) =>
      -direction *
      RabbitTokens.earDrag *
      (_wobble(seconds, delay, t) - _wobble(seconds, back + delay, t));
  return _Life(
    blink: _blink(t, .02, .2),
    squash: RabbitTokens.turnStretch * math.sin(envelope * math.pi),
    earSway: drag(0),
    earSwayRight: drag(RabbitTokens.earDelay),
  );
}

/// Chatouille : tassement d'anticipation, saut étiré, atterrissage amorti.
_Life _hopLife(double t) {
  const takeoff = .12;
  const landing = .5;
  final seconds = t * RabbitTokens.tickle.inMilliseconds / 1000;
  final air = t > takeoff && t < landing
      ? math.sin((t - takeoff) / (landing - takeoff) * math.pi)
      : 0.0;
  final squash = t < takeoff
      ? -RabbitTokens.hopSquash * math.sin(t / takeoff * math.pi)
      : t < landing
      ? RabbitTokens.hopStretch * air
      : -RabbitTokens.hopSquash *
            _wobble(
              seconds,
              landing * RabbitTokens.tickle.inMilliseconds / 1000,
              t,
            );
  return _Life(
    lift: -RabbitTokens.hopHeight * air,
    squash: squash,
    earSpread:
        RabbitTokens.earFlop *
        _wobble(
          seconds,
          takeoff * RabbitTokens.tickle.inMilliseconds / 1000,
          t,
        ),
  );
}

/// Observe retained layer composition, including ancestor-only layout or
/// transform changes. This never requests a frame or runs an offscreen timer.
class _PaintVisibility extends SingleChildRenderObjectWidget {
  const _PaintVisibility({required this.onComposition, required super.child});
  final VoidCallback onComposition;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaintVisibility(onComposition);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPaintVisibility renderObject,
  ) {
    renderObject.onComposition = onComposition;
  }
}

class _RenderPaintVisibility extends RenderProxyBox {
  _RenderPaintVisibility(this.onComposition);
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

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(Radii.lg),
    );
    canvas.drawRRect(
      ring.deflate(RabbitTokens.focusHalo),
      Paint()
        ..color = RabbitTokens.coat
        ..style = PaintingStyle.stroke
        ..strokeWidth = RabbitTokens.focusStroke + RabbitTokens.focusHalo,
    );
    canvas.drawRRect(
      ring.deflate(RabbitTokens.focusStroke),
      Paint()
        ..color = RabbitTokens.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = RabbitTokens.focusStroke,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) => false;
}

/// Dessin pur, également inspectable dans les tests de poses.
class RabbitPainter extends CustomPainter {
  const RabbitPainter({
    this.gaze = 0,
    this.gazeDown = 0,
    this.wiggle = 0,
    this.tickled = false,
    this.concentrating = false,
    this.blink = 0,
    this.lift = 0,
    this.squash = 0,
    this.earSway = 0,
    this.earSwayRight = 0,
    this.earSpread = 0,
  });
  final double gaze;
  final double gazeDown;
  final double wiggle;
  final bool tickled;
  final bool concentrating;

  /// 0 yeux ouverts, 1 fermés.
  final double blink;

  /// Décalage vertical du corps (repère de vue, négatif vers le haut).
  final double lift;

  /// Étirement vertical à volume à peu près constant, ancré au sol.
  final double squash;

  /// Inertie d'un regard sur l'oreille gauche, puis la droite (décalée, pour
  /// que les deux ne bougent jamais comme un seul bloc).
  final double earSway;
  final double earSwayRight;

  /// Ouverture symétrique des oreilles (saut).
  final double earSpread;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / RabbitTokens.viewWidth,
      size.height / RabbitTokens.viewHeight,
    );
    canvas.translate(
      (size.width - RabbitTokens.viewWidth * scale) / 2,
      (size.height - RabbitTokens.viewHeight * scale) / 2,
    );
    canvas.scale(scale);
    final outline = Paint()
      ..color = RabbitTokens.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(
        RabbitTokens.stroke,
        RabbitTokens.minimumOutline / scale,
      );
    final ink = Paint()..color = RabbitTokens.ink;
    final line = Paint()
      ..color = RabbitTokens.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(
        RabbitTokens.faceStroke,
        RabbitTokens.minimumFaceStroke / scale,
      )
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final head = RabbitTokens.head;
    final center = head.center;
    final rx = head.width / 2;
    final ry = head.height / 2;
    final yaw = gaze * RabbitTokens.maxYaw;
    final pitch = gazeDown * RabbitTokens.maxPitch;

    // Ombre de contact : reste au sol et se resserre pendant le saut.
    final shadowBox = RabbitTokens.groundShadow;
    final spread = 1 + lift * RabbitTokens.shadowShrink;
    canvas.save();
    canvas.translate(shadowBox.center.dx, shadowBox.center.dy);
    canvas.scale(spread * shadowBox.width / shadowBox.height, spread);
    final shadowCircle = Rect.fromCircle(
      center: Offset.zero,
      radius: shadowBox.height / 2,
    );
    canvas.drawOval(
      shadowCircle,
      Paint()
        ..shader = const RadialGradient(
          colors: [RabbitTokens.shadow, RabbitTokens.shadowClear],
        ).createShader(shadowCircle),
    );
    canvas.restore();

    final ground = RabbitTokens.groundPivot;
    canvas.translate(ground.dx, ground.dy + lift);
    canvas.scale(1 - squash * .6, 1 + squash);
    canvas.translate(-ground.dx, -ground.dy);

    // Oreilles plantées sur le crâne : elles glissent autour de la tête et
    // s'amincissent en tournant, avec un dégradé qui suit la lumière.
    final outside = RabbitTokens.ear;
    final inside = RabbitTokens.earInside;
    final earBounds = outside.getBounds();
    final earCoat = Paint()
      ..shader = const LinearGradient(
        colors: [RabbitTokens.coat, RabbitTokens.coatShade],
      ).createShader(earBounds);
    final earInner = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [RabbitTokens.innerEar, RabbitTokens.innerEarDeep],
      ).createShader(inside.getBounds());
    void ear(double side, Offset pivot, double angle) {
      final longitude = side * RabbitTokens.earLongitude + yaw;
      canvas.save();
      canvas.translate(
        center.dx + rx * RabbitTokens.earRadius * math.sin(longitude),
        pivot.dy,
      );
      canvas.rotate(angle);
      canvas.scale(
        math.cos(longitude) /
            math.cos(RabbitTokens.earLongitude) *
            (side > 0 ? RabbitTokens.rightEarFlare : 1),
        1,
      );
      canvas.drawPath(outside, earCoat);
      canvas.drawPath(outside, outline);
      canvas.drawPath(inside, earInner);
      canvas.restore();
    }

    final follow = gaze * RabbitTokens.earFollow;
    ear(
      -1,
      RabbitTokens.leftPivot,
      RabbitTokens.leftEarAngle +
          wiggle * RabbitTokens.earWiggle +
          follow +
          earSway -
          earSpread,
    );
    ear(
      1,
      RabbitTokens.rightPivot,
      RabbitTokens.rightEarAngle -
          wiggle * RabbitTokens.earWiggle +
          follow +
          earSwayRight +
          earSpread,
    );

    // Tête : œuf de peluche éclairé, la lumière ne tourne pas avec le
    // visage ; il penche légèrement du côté où il regarde.
    canvas.save();
    canvas.translate(RabbitTokens.headPivot.dx, RabbitTokens.headPivot.dy);
    canvas.rotate(
      wiggle * RabbitTokens.headTilt + gaze * RabbitTokens.headRoll,
    );
    canvas.translate(-RabbitTokens.headPivot.dx, -RabbitTokens.headPivot.dy);
    canvas.drawPath(
      _headShape,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(RabbitTokens.light.dx, RabbitTokens.light.dy),
          radius: RabbitTokens.lightReach,
          colors: const [
            RabbitTokens.coat,
            RabbitTokens.coatShade,
            RabbitTokens.coatDeep,
          ],
          stops: const [0, .55, 1],
        ).createShader(head),
    );
    // Les traits qui passent derrière le bord de la sphère disparaissent.
    canvas.save();
    canvas.clipPath(_headShape);

    // Chaque point du visage dessiné de face est replacé sur l'ellipsoïde
    // tourné (lacet puis tangage) : les traits épousent la courbure.
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    (Offset, double) place(Offset flat) {
      final x = (flat.dx - center.dx) / rx;
      final y = (flat.dy - center.dy) / ry;
      final z = math.sqrt(math.max(0, 1 - x * x - y * y));
      final turnedX = x * cosYaw + z * sinYaw;
      final turnedZ = z * cosYaw - x * sinYaw;
      final tiltedY = y * cosPitch + turnedZ * sinPitch;
      return (
        Offset(center.dx + rx * turnedX, center.dy + ry * tiltedY),
        turnedZ * cosPitch - y * sinPitch,
      );
    }

    Offset project(Offset flat) => place(flat).$1;

    // Grain de feutre fixé à la surface : il tourne avec la tête, seuls les
    // points encore face à nous sont peints.
    final dark = <Offset>[];
    final light = <Offset>[];
    for (var i = 0; i < _grain.length; i++) {
      final (point, depth) = place(_grain[i]);
      if (depth > 0) (i.isEven ? dark : light).add(point);
    }
    final grain = Paint()
      ..strokeWidth = RabbitTokens.grainSize
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(
      PointMode.points,
      dark,
      grain..color = RabbitTokens.grainDark,
    );
    canvas.drawPoints(
      PointMode.points,
      light,
      grain..color = RabbitTokens.grainLight,
    );

    // ponytail: rééchantillonnage à chaque image, quelques contours courts.
    Path wrap(Path flat) {
      final wrapped = Path();
      for (final contour in flat.computeMetrics()) {
        final steps = math.max(
          8,
          (contour.length / RabbitTokens.wrapStep).ceil(),
        );
        for (var i = 0; i <= steps; i++) {
          final point = project(
            contour.getTangentForOffset(contour.length * i / steps)!.position,
          );
          if (i == 0) {
            wrapped.moveTo(point.dx, point.dy);
          } else {
            wrapped.lineTo(point.dx, point.dy);
          }
        }
        if (contour.isClosed) wrapped.close();
      }
      return wrapped;
    }

    // Coutures de la peluche : front et milieu du visage.
    canvas.drawPath(
      wrap(RabbitTokens.seams),
      Paint()
        ..color = RabbitTokens.seam
        ..style = PaintingStyle.stroke
        ..strokeWidth = RabbitTokens.seamStroke
        ..strokeCap = StrokeCap.round,
    );

    final open =
        (concentrating ? RabbitTokens.concentrationEyeScale : 1.0) *
        (1 - blink * RabbitTokens.blinkClosure);
    if (tickled) {
      canvas.drawPath(wrap(RabbitTokens.happyEyes), line);
    } else {
      for (final eye in [RabbitTokens.leftEye, RabbitTokens.rightEye]) {
        canvas.drawPath(
          wrap(
            Path()..addOval(
              Rect.fromCenter(
                center: eye.center,
                width: eye.width,
                height: eye.height * open,
              ),
            ),
          ),
          ink,
        );
      }
    }
    canvas.drawPath(wrap(RabbitTokens.mouth), line);
    canvas.drawPath(wrap(RabbitTokens.nose), ink);
    canvas.restore();
    canvas.drawPath(_headShape, outline);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RabbitPainter oldDelegate) =>
      oldDelegate.gaze != gaze ||
      oldDelegate.gazeDown != gazeDown ||
      oldDelegate.wiggle != wiggle ||
      oldDelegate.tickled != tickled ||
      oldDelegate.concentrating != concentrating ||
      oldDelegate.blink != blink ||
      oldDelegate.lift != lift ||
      oldDelegate.squash != squash ||
      oldDelegate.earSway != earSway ||
      oldDelegate.earSwayRight != earSwayRight ||
      oldDelegate.earSpread != earSpread;
}
