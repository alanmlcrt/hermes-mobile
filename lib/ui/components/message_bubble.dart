import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../content.dart';
import '../tokens.dart';

/// Message du fil : la demande d'Alanc en texte brut, la réponse de Hermes en
/// Markdown (emojis, listes, blocs de code défilant horizontalement). Aucune
/// animation d'apparition.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.text, this.fromUser = false});

  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = fromUser
        ? Text(text, style: TextStyle(color: scheme.bubbleContent))
        : MarkdownBody(
            data: text,
            // Aucune image distante : une URL de modèle ne déclenche pas de requête.
            imageBuilder: (uri, title, alt) =>
                Text(alt == null || alt.isEmpty ? uri.toString() : alt),
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              code: TextStyle(
                fontFamily: CodeStyle.family,
                color: scheme.content,
                backgroundColor: scheme.codeSurface,
              ),
              codeblockPadding: const EdgeInsets.all(Spacing.sm),
              codeblockDecoration: BoxDecoration(
                color: scheme.codeSurface,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
            ),
          );
    return Align(
      alignment: fromUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Semantics(
        container: true,
        label: fromUser ? Content.yourRequest : Content.hermesReply,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fromUser ? scheme.bubbleSurface : scheme.canvas,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Padding(padding: const EdgeInsets.all(Spacing.md), child: body),
        ),
      ),
    );
  }
}
