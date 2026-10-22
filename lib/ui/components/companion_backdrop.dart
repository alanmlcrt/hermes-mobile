import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/companion_background.dart';
import '../tokens.dart';

/// Le filtre appartient au fond uniquement : le visage reste net.
class CompanionBackdrop extends StatelessWidget {
  const CompanionBackdrop({
    super.key,
    required this.child,
    this.palette = CompanionPalette.lavenderPeach,
  });
  final Widget child;
  final CompanionPalette palette;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(Radii.lg),
    child: Stack(
      children: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: RabbitTokens.frostSigma,
              sigmaY: RabbitTokens.frostSigma,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: switch (palette) {
                  CompanionPalette.lavenderPeach => RabbitTokens.backdrop,
                  CompanionPalette.mintSky => RabbitTokens.mintSky,
                  CompanionPalette.roseLilac => RabbitTokens.roseLilac,
                },
              ),
            ),
          ),
        ),
        const Positioned.fill(child: ColoredBox(color: RabbitTokens.frost)),
        child,
      ],
    ),
  );
}
