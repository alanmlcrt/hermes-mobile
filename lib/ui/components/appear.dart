import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../tokens.dart';

/// Arrivée d'un élément du fil : fondu, léger glissement vers le haut et
/// mise à l'échelle subtile, une seule fois. Immobile si [animate] est faux
/// ou sous mouvement réduit.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.animate, required this.child});
  final bool animate;
  final Widget child;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: widget.animate ? 0 : 1,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = motionDuration(context, Motion.medium);
    if (_controller.value < 1) {
      if (duration == Duration.zero) {
        _controller.value = 1;
      } else {
        _controller.animateTo(1, duration: duration);
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
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
