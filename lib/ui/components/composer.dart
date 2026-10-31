import 'package:flutter/material.dart';

import '../content.dart';
import '../theme.dart';
import '../tokens.dart';
import 'appear.dart';

/// Composant `PromptInput` (style AI SDK Elements / shadcn) : bloc encadré
/// unifié comprenant éventuellement un en-tête de pièces jointes (`header`),
/// une zone de texte multiligne (`PromptInputTextarea`) et une barre d'outils
/// inférieure (`PromptInputToolbar`) avec bouton d'ajout à gauche et bouton
/// d'envoi/arrêt monochrome à droite.
class Composer extends StatefulWidget {
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
    this.compact = false,
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
  final bool compact;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  bool _focused = false;

  Widget _input() => Focus(
    onFocusChange: (value) {
      if (_focused != value) setState(() => _focused = value);
    },
    child: TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      minLines: ComposerLines.min,
      maxLines: widget.maxLines,
      decoration: InputDecoration(
        hintText: widget.hint,
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
  );

  Widget _action(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actionCallback = widget.stopping ? widget.onStop : widget.onSend;
    final dimension = widget.stopping ? Layout.stopButton : Layout.sendButton;
    return MergeSemantics(
      child: Semantics(
        label: widget.stopping ? Content.stop : Content.send,
        excludeSemantics: widget.stopping,
        button: widget.stopping ? true : null,
        enabled: widget.stopping ? widget.onStop != null : null,
        onTap: widget.stopping ? widget.onStop : null,
        hint: !widget.stopping && widget.onSend == null
            ? widget.disabledReason
            : null,
        child: PressScale(
          enabled: actionCallback != null,
          haptic: true,
          child: AnimatedContainer(
            duration: motionDuration(context, Motion.short),
            curve: Curves.easeOutCubic,
            width: dimension,
            height: dimension,
            child: IconButton.filled(
              tooltip: widget.stopping ? Content.stop : Content.send,
              onPressed: actionCallback,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: scheme.emphasis,
                foregroundColor: scheme.emphasisContent,
                disabledBackgroundColor: scheme.chip,
                disabledForegroundColor: scheme.muted,
                shape: const CircleBorder(),
              ),
              icon: Icon(
                widget.stopping ? Icons.stop : Icons.arrow_upward,
                size: IconSizes.sm,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = motionDuration(context, Motion.short);
    final compact = widget.compact && widget.onAttach == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(
            minHeight: Layout.composerMinHeight,
          ),
          decoration: BoxDecoration(
            color: scheme.card,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: _focused ? scheme.outline : scheme.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.header != null) ...[
                  widget.header!,
                  const SizedBox(height: Spacing.xs),
                ],
                if (compact)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _input()),
                      const SizedBox(width: Spacing.xs),
                      _action(context),
                    ],
                  )
                else ...[
                  _input(),
                  const SizedBox(height: Spacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.onAttach != null)
                        PressScale(
                          child: SizedBox.square(
                            dimension: Layout.stopButton,
                            child: IconButton(
                              tooltip: Content.attach,
                              onPressed: widget.onAttach,
                              style: IconButton.styleFrom(
                                foregroundColor: scheme.muted,
                                shape: CircleBorder(
                                  side: BorderSide(color: scheme.line),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: IconSizes.sm),
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      _action(context),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        // Annoncés (région live, indication du bouton) sans texte affiché.
        if (widget.status != null)
          Semantics(
            container: true,
            liveRegion: true,
            label: widget.status,
            child: const SizedBox.shrink(),
          ),
      ],
    );
  }
}
