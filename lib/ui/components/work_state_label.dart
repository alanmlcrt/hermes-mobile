import 'package:flutter/material.dart';

import '../../models/timeline.dart';
import '../content.dart';
import '../tokens.dart';
import 'activity_catalog.dart';
import 'status_label.dart';

/// État du travail distant : icône + libellé, jamais la couleur seule. Envoi
/// et travail en cours : bulle de Hermes avec les trois points animés.
class WorkStateLabel extends StatelessWidget {
  const WorkStateLabel({super.key, required this.state, this.localStatus});

  final WorkState state;

  /// Intention présentée séparément de la projection distante.
  final String? localStatus;

  static String label(WorkState state) => switch (state) {
    WorkState.sending => Content.workSending,
    WorkState.running => Content.workRunning,
    WorkState.waitingInput => Content.workWaitingInput,
    WorkState.waitingApproval => Content.workWaitingApproval,
    WorkState.succeeded => Content.workSucceeded,
    WorkState.failed => Content.workFailed,
    WorkState.stopped => Content.workStopped,
    WorkState.unknown => Content.workUnknown,
  };

  static IconData icon(WorkState state) => switch (state) {
    WorkState.sending => Icons.upload_outlined,
    WorkState.running => Icons.hourglass_empty,
    WorkState.waitingInput => Icons.help_outline,
    WorkState.waitingApproval => Icons.gpp_maybe_outlined,
    WorkState.succeeded => Icons.check_circle_outline,
    WorkState.failed => Icons.error_outline,
    WorkState.stopped => Icons.stop_circle_outlined,
    WorkState.unknown => Icons.sync_problem,
  };

  @override
  Widget build(BuildContext context) {
    if (localStatus != null) {
      return StatusLabel(icon: Icons.stop_circle_outlined, label: localStatus!);
    }
    if (state != WorkState.sending && state != WorkState.running) {
      return StatusLabel(icon: icon(state), label: label(state));
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.bubbleSurface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: scheme.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm + Spacing.xs,
            vertical: Spacing.xs + Spacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ActivityIllustration(kind: ActivityKind.unknown),
              const SizedBox(width: Spacing.sm),
              Flexible(
                child: Text(
                  label(state),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
