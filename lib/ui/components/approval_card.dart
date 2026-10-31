import 'package:flutter/material.dart';

import '../../models/timeline.dart';
import '../content.dart';
import '../tokens.dart';
import 'status_label.dart';

/// Autorisation demandée par Hermes dans le fil : description et commande
/// telles qu'émises (commande en chasse fixe, entière), état dit par un
/// libellé. Seuls « Autoriser » (`once`) et « Refuser » (`deny`) sont
/// proposés ; l'état n'avance qu'à la confirmation de Hermes.
class ApprovalCard extends StatelessWidget {
  const ApprovalCard({
    super.key,
    required this.description,
    required this.command,
    required this.state,
    this.blocked,
    this.previousUnanswered = false,
    this.canDecide = true,
    this.onDecide,
  });

  final String description;
  final String command;
  final QuestionState state;

  /// Posé à la confirmation : `true` refusée, `false` autorisée.
  final bool? blocked;
  final bool previousUnanswered;

  /// Faux hors connexion : la carte reste, les boutons sont désactivés.
  final bool canDecide;
  final ValueChanged<String>? onDecide;

  static String label(QuestionState state, {bool? blocked}) => switch (state) {
    QuestionState.open => Content.approvalOpen,
    QuestionState.sending => Content.approvalSending,
    QuestionState.sent => Content.approvalSent,
    QuestionState.confirmed =>
      blocked == true ? Content.approvalDenied : Content.approvalAllowed,
    QuestionState.unknown => Content.approvalUnknown,
    QuestionState.expired => Content.approvalExpired,
    QuestionState.cancelled => Content.approvalCancelled,
    QuestionState.closed => Content.approvalClosed,
  };

  static IconData icon(QuestionState state, {bool? blocked}) => switch (state) {
    QuestionState.open => Icons.gpp_maybe_outlined,
    QuestionState.sending => Icons.upload_outlined,
    QuestionState.sent => Icons.outbox_outlined,
    QuestionState.confirmed =>
      blocked == true ? Icons.block : Icons.check_circle_outline,
    QuestionState.unknown => Icons.sync_problem,
    QuestionState.expired => Icons.timer_off_outlined,
    QuestionState.cancelled => Icons.cancel_outlined,
    QuestionState.closed => Icons.lock_outline,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final open = state == QuestionState.open;
    final enabled = canDecide && onDecide != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                Content.approvalTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.muted,
                ),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Semantics(
              liveRegion: true,
              child: StatusLabel(
                icon: icon(state, blocked: blocked),
                label: label(state, blocked: blocked),
              ),
            ),
            if (open && previousUnanswered) ...[
              const SizedBox(height: Spacing.xs),
              const Text(Content.approvalPreviousUnanswered),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              SelectableText(
                description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.content,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: Spacing.sm),
            Text(
              Content.approvalCommand,
              style: theme.textTheme.labelMedium?.copyWith(color: scheme.muted),
            ),
            const SizedBox(height: Spacing.xs),
            // Commande entière, dans un bloc terminal encadré style AI Elements.
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.codeSurface,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: scheme.line),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.sm + Spacing.xs),
                child: SelectableText(
                  command,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: CodeStyle.family,
                    color: scheme.content,
                  ),
                ),
              ),
            ),
            if (open) ...[
              const SizedBox(height: Spacing.md),
              if (!canDecide)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: Text(
                    Content.approvalOffline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.muted,
                    ),
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: [
                  _Decision(
                    label: Content.approvalDeny,
                    semantics: Content.approvalDenySemantics,
                    onPressed: enabled
                        ? () => onDecide!(ApprovalChoice.deny)
                        : null,
                  ),
                  _Decision(
                    label: Content.approvalAllow,
                    semantics: Content.approvalAllowSemantics,
                    filled: true,
                    onPressed: enabled
                        ? () => onDecide!(ApprovalChoice.once)
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bouton de décision : nom accessible distinct, cible d'au moins
/// [Layout.touchTarget].
class _Decision extends StatelessWidget {
  const _Decision({
    required this.label,
    required this.semantics,
    required this.onPressed,
    this.filled = false,
  });
  final String label;
  final String semantics;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    const size = Size(Layout.touchTarget, Layout.touchTarget);
    // Nom accessible porté par le bouton lui-même : l'action reste la sienne.
    final child = Semantics(
      label: semantics,
      child: ExcludeSemantics(child: Text(label)),
    );
    return filled
        ? FilledButton(
            style: FilledButton.styleFrom(minimumSize: size),
            onPressed: onPressed,
            child: child,
          )
        : OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: size),
            onPressed: onPressed,
            child: child,
          );
  }
}
