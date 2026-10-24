import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// Arrivée d'un élément du fil : fondu et léger glissement vers le haut,
/// une seule fois. Immobile si [animate] est faux ou sous mouvement réduit.
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
      child: widget.child,
    ),
  );
}
