import 'package:flutter/material.dart';

import '../../models/timeline.dart';
import '../content.dart';
import '../tokens.dart';
import 'rabbit_companion.dart';

/// Une réservation par tour, indépendante des fragments et des poses.
/// Les tours précédents conservent leur enveloppe sans action dupliquée.
class ConversationCompanion extends StatelessWidget {
  const ConversationCompanion({
    super.key,
    required this.child,
    this.phase = CompanionPhase.neutral,
    this.resting = false,
    this.current = true,
    this.active = true,
    this.paused = false,
  });

  final Widget child;
  final CompanionPhase phase;
  final bool resting;
  final bool current;
  final bool active;
  final bool paused;

  /// MarkdownStyleSheet.fromTheme utilise bodyMedium pour la réponse.
  /// Une échelle non linéaire doit être évaluée à cette taille réelle.
  static bool sideBySide(BuildContext context, double width) {
    final fontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;
    return width >= RabbitTokens.conversationSideWidth &&
        MediaQuery.textScalerOf(context).scale(fontSize) / fontSize <
            RabbitTokens.conversationTextLimit;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = sideBySide(context, constraints.maxWidth);
        final slot = DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: current
              ? RabbitCompanion(
                  name: Content.companionName,
                  size: RabbitTokens.compact,
                  active: active,
                  paused: paused,
                  autonomous: resting,
                  readingLook: side ? RabbitLook.right : RabbitLook.down,
                  pose: switch (phase) {
                    CompanionPhase.neutral => RabbitPose.rest,
                    CompanionPhase.concentrating => RabbitPose.concentrating,
                    CompanionPhase.reading => RabbitPose.reading,
                  },
                )
              : const ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: RabbitTokens.compact,
                    child: CustomPaint(painter: RabbitPainter()),
                  ),
                ),
        );
        if (side) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              slot,
              const SizedBox(width: Spacing.sm),
              Expanded(child: child),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerLeft, child: slot),
            const SizedBox(height: Spacing.sm),
            child,
          ],
        );
      },
    );
  }
}

/// Les blocs suivants restent des enfants distincts du ListView paresseux,
/// avec le même retrait que le premier bloc, sans autre réservation ni action.
class ConversationCompanionContinuation extends StatelessWidget {
  const ConversationCompanionContinuation({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: EdgeInsets.only(
        left: ConversationCompanion.sideBySide(context, constraints.maxWidth)
            ? RabbitTokens.compact + Spacing.sm
            : 0,
      ),
      child: child,
    ),
  );
}
