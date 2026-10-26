import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../content.dart';
import '../tokens.dart';
import '../../models/attachment.dart';
import 'attachment_list.dart';

/// Message du fil, en bulle : la demande d'Alanc en texte brut, la réponse de
/// Hermes en Markdown (emojis, listes, blocs de code défilant horizontalement). Aucune
/// animation d'apparition.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    this.fromUser = false,
    this.attachments = const [],
  });

  final String text;
  final bool fromUser;
  final List<Attachment> attachments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = fromUser
        ? Text(text, style: TextStyle(color: scheme.emphasisContent))
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
    final label = fromUser ? Content.yourRequest : Content.hermesReply;
    // Deux bulles pleines : grise pour Hermes, encre pour Alanc.
    return Align(
      alignment: fromUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * Layout.bubbleMaxWidth,
        ),
        child: Semantics(
          container: true,
          label: label,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fromUser ? scheme.emphasis : scheme.bubbleSurface,
              borderRadius: BorderRadius.circular(Radii.bubble),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm + Spacing.xs,
              ),
              child: attachments.isEmpty
                  ? body
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (text.isNotEmpty) body,
                        if (attachments.isNotEmpty) ...[
                          const SizedBox(height: Spacing.sm),
                          DefaultTextStyle(
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: scheme.content,
                            ),
                            child: AttachmentList(attachments: attachments),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
