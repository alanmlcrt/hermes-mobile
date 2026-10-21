import 'package:flutter/material.dart';

import '../../models/timeline.dart';
import '../content.dart';
import 'status_label.dart';

/// État du travail distant : icône + libellé, jamais la couleur seule.
class WorkStateLabel extends StatelessWidget {
  const WorkStateLabel({super.key, required this.state});

  final WorkState state;

  static String label(WorkState state) => switch (state) {
    WorkState.sending => Content.workSending,
    WorkState.running => Content.workRunning,
    WorkState.succeeded => Content.workSucceeded,
    WorkState.failed => Content.workFailed,
    WorkState.stopped => Content.workStopped,
    WorkState.unknown => Content.workUnknown,
  };

  static IconData icon(WorkState state) => switch (state) {
    WorkState.sending => Icons.upload_outlined,
    WorkState.running => Icons.hourglass_empty,
    WorkState.succeeded => Icons.check_circle_outline,
    WorkState.failed => Icons.error_outline,
    WorkState.stopped => Icons.stop_circle_outlined,
    WorkState.unknown => Icons.sync_problem,
  };

  @override
  Widget build(BuildContext context) =>
      StatusLabel(icon: icon(state), label: label(state));
}
