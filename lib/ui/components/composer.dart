import 'package:flutter/material.dart';

import '../content.dart';
import '../tokens.dart';

/// Composant `PromptInput` (style AI SDK Elements / shadcn) : bloc encadré
/// unifié comprenant éventuellement un en-tête de pièces jointes (`header`),
/// une zone de texte multiligne (`PromptInputTextarea`) et une barre d'outils
/// inférieure (`PromptInputToolbar`) avec bouton d'ajout à gauche et bouton
/// d'envoi/arrêt monochrome à droite.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    this.controller,
    this.header,
    this.onAttach,
    this.onChanged,
    this.onSend,
    this.stopping = false,
    this.onStop,
    this.disabledReason,
    this.status,
    this.hint = Content.composerLabel,
    this.maxLines = ComposerLines.max,
  });
  final TextEditingController? controller;
  final Widget? header;
  final VoidCallback? onAttach;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSend;
  final bool stopping;
  final VoidCallback? onStop;
  final String? disabledReason;

  /// État d’envoi annoncé (région live), sans texte affiché.
  final String? status;

  /// Indication dans le champ (« Écrire à Travail »).
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(
            minHeight: Layout.composerMinHeight,
          ),
          decoration: BoxDecoration(
            color: scheme.card,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: scheme.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (header != null) ...[
                  header!,
                  const SizedBox(height: Spacing.xs),
                ],
                TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: ComposerLines.min,
                  maxLines: maxLines,
                  decoration: InputDecoration(
                    hintText: hint,
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: Spacing.xs,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (onAttach != null)
                      SizedBox.square(
                        dimension: Layout.stopButton,
                        child: IconButton(
                          tooltip: Content.attach,
                          onPressed: onAttach,
                          style: IconButton.styleFrom(
                            foregroundColor: scheme.muted,
                            shape: CircleBorder(
                              side: BorderSide(color: scheme.line),
                            ),
                          ),
                          icon: const Icon(
                            Icons.add,
                            size: IconSizes.sm,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    MergeSemantics(
                      child: Semantics(
                        label: stopping ? Content.stop : Content.send,
                        excludeSemantics: stopping,
                        button: stopping ? true : null,
                        enabled: stopping ? onStop != null : null,
                        onTap: stopping ? onStop : null,
                        hint: !stopping && onSend == null
                            ? disabledReason
                            : null,
                        child: SizedBox.square(
                          dimension: stopping
                              ? Layout.stopButton
                              : Layout.sendButton,
                          child: IconButton.filled(
                            tooltip: stopping ? Content.stop : Content.send,
                            onPressed: stopping ? onStop : onSend,
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: scheme.emphasis,
                              foregroundColor: scheme.emphasisContent,
                              disabledBackgroundColor: scheme.chip,
                              disabledForegroundColor: scheme.muted,
                              shape: const CircleBorder(),
                            ),
                            icon: Icon(
                              stopping ? Icons.stop : Icons.arrow_upward,
                              size: IconSizes.sm,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Annoncés (région live, indication du bouton) sans texte affiché.
        if (status != null)
          Semantics(
            container: true,
            liveRegion: true,
            label: status,
            child: const SizedBox.shrink(),
          ),
      ],
    );
  }
}
