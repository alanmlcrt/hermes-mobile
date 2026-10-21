import 'package:flutter/material.dart';

import '../content.dart';
import '../tokens.dart';

/// Saisie multiligne sans limite de longueur ; le champ défile au-delà de
/// [ComposerLines.max]. Bouton d'envoi désactivé si [onSend] est nul, avec
/// [disabledReason] affiché et annoncé.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    this.controller,
    this.onChanged,
    this.onSend,
    this.disabledReason,
    this.status,
  });
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSend;
  final String? disabledReason;

  /// État d'envoi annoncé (région live) ; remplace l'affichage de la raison.
  final String? status;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        minLines: ComposerLines.min,
        maxLines: ComposerLines.max,
        decoration: const InputDecoration(
          labelText: Content.composerLabel,
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: Spacing.sm),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: MergeSemantics(
          child: Semantics(
            hint: onSend == null ? disabledReason : null,
            child: FilledButton.icon(
              onPressed: onSend,
              icon: const Icon(Icons.send),
              label: const Text(Content.send),
            ),
          ),
        ),
      ),
      if (status != null) ...[
        const SizedBox(height: Spacing.xs),
        Semantics(container: true, liveRegion: true, child: Text(status!)),
      ],
      if (onSend == null &&
          disabledReason != null &&
          disabledReason != status) ...[
        const SizedBox(height: Spacing.xs),
        ExcludeSemantics(child: Text(disabledReason!)),
      ],
    ],
  );
}
