import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../content.dart';
import '../tokens.dart';

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
  }) : assert(size >= RabbitTokens.minimum);

  final String name;
  final double size;
  final bool active;
  final bool paused;

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
    if (!_animate || _reacting || _glancing || _timer != null) return;
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
                                ? Curves.easeInOut.transform(t / travel)
                                : t > 1 - travel
                                ? Curves.easeInOut.transform((1 - t) / travel)
                                : 1.0)
                          : 0.0;
                      final reaction = _reacting && !_fixedReaction
                          ? math.sin(t * math.pi)
                          : 0.0;
                      return CustomPaint(
                        painter: RabbitPainter(
                          gaze: _direction * envelope + reaction,
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
  const RabbitPainter({this.gaze = 0, this.wiggle = 0, this.tickled = false});
  final double gaze;
  final double wiggle;
  final bool tickled;

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
    final coat = Paint()..color = RabbitTokens.coat;
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
      ..strokeCap = StrokeCap.round;
    void ear(Path outside, Path inside, Offset pivot, double angle) {
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(angle);
      canvas.translate(-pivot.dx, -pivot.dy);
      canvas.drawPath(outside, coat);
      canvas.drawPath(outside, outline);
      canvas.drawPath(inside, Paint()..color = RabbitTokens.innerEar);
      canvas.restore();
    }

    ear(
      RabbitTokens.leftEar,
      RabbitTokens.leftInner,
      RabbitTokens.leftPivot,
      wiggle * RabbitTokens.earWiggle,
    );
    ear(
      RabbitTokens.rightEar,
      RabbitTokens.rightInner,
      RabbitTokens.rightPivot,
      -wiggle * RabbitTokens.earWiggle,
    );
    canvas.save();
    canvas.translate(
      RabbitTokens.headPivot.dx + gaze * RabbitTokens.turnDistance,
      RabbitTokens.headPivot.dy,
    );
    canvas.rotate(wiggle * RabbitTokens.headTilt);
    canvas.scale(1 - gaze.abs() * RabbitTokens.headForeshortening, 1);
    canvas.translate(-RabbitTokens.headPivot.dx, -RabbitTokens.headPivot.dy);
    canvas.drawOval(RabbitTokens.head, coat);
    canvas.drawOval(RabbitTokens.head, outline);
    canvas.translate(
      RabbitTokens.headPivot.dx + gaze * RabbitTokens.gazeDistance,
      0,
    );
    canvas.scale(1 - gaze.abs() * RabbitTokens.faceForeshortening, 1);
    canvas.translate(-RabbitTokens.headPivot.dx, 0);
    if (tickled) {
      canvas.drawPath(RabbitTokens.happyEyes, line);
    } else {
      canvas.drawOval(RabbitTokens.leftEye, ink);
      canvas.drawOval(RabbitTokens.rightEye, ink);
    }
    canvas.drawPath(RabbitTokens.nose, ink);
    canvas.drawPath(RabbitTokens.mouth, line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RabbitPainter oldDelegate) =>
      oldDelegate.gaze != gaze ||
      oldDelegate.wiggle != wiggle ||
      oldDelegate.tickled != tickled;
}
