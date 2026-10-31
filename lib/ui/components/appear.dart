import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../tokens.dart';

/// Arrivée d'un élément : fondu, léger glissement vers le haut et mise à
/// l'échelle subtile depuis [alignment], une seule fois. [index] décale le
/// départ pour une entrée en cascade (sans minuteur : un intervalle de la
/// même animation). Immobile si [animate] est faux ou sous mouvement réduit.
class Appear extends StatefulWidget {
  const Appear({
    super.key,
    required this.animate,
    required this.child,
    this.index = 0,
    this.alignment = Alignment.center,
  });
  final bool animate;
  final Widget child;
  final int index;
  final AlignmentGeometry alignment;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: widget.animate ? 0 : 1,
  );
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    final steps = widget.index.clamp(0, Motion.staggerMax);
    final delay = Motion.stagger * steps;
    final total = Motion.medium + delay;
    _controller.duration = total;
    _curve = _controller.drive(
      CurveTween(
        curve: Interval(
          delay.inMicroseconds / total.inMicroseconds,
          1,
          curve: Motion.enter,
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.value < 1) {
      if (motionDuration(context, Motion.medium) == Duration.zero) {
        _controller.value = 1;
      } else if (!_controller.isAnimating) {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: _curve.drive(
        Tween(begin: const Offset(0, Layout.appearShift), end: Offset.zero),
      ),
      child: ScaleTransition(
        alignment: widget.alignment.resolve(Directionality.of(context)),
        scale: _curve.drive(
          Tween(begin: Layout.appearScale, end: Layout.normalScale),
        ),
        child: widget.child,
      ),
    ),
  );
}

/// Micro-interaction tactile : léger retrait d'échelle (`Layout.pressScale`)
/// sous le doigt et rebond doux au relâchement, sans capturer l'arène de
/// gestes ni perturber la sémantique. Respecte le mouvement réduit.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.haptic = false,
  });

  final Widget child;
  final bool enabled;
  final bool haptic;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final duration = motionDuration(context, Motion.short);
    if (!widget.enabled || duration == Duration.zero) {
      return widget.child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        _setPressed(true);
        if (widget.haptic) HapticFeedback.selectionClick();
      },
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? Layout.pressScale : Layout.normalScale,
        duration: duration,
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
