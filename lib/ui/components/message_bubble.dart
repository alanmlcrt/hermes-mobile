import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../content.dart';
import '../tokens.dart';
import '../../models/attachment.dart';
import 'attachment_list.dart';

/// Message du fil (style AI SDK Elements `<Message>` / `<MessageContent>`) :
/// - Message utilisateur (`fromUser: true`) : aligné à droite dans un conteneur
///   sobre aux coins modérés (`Radii.lg`).
/// - Réponse de l'assistant (`fromUser: false`) : pleine largeur directement sur
///   la toile, sans bulle grise, avec blocs de code bordés (`<CodeBlock>`).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    this.fromUser = false,
    this.notificationUnfollowed = false,
    this.attachments = const [],
  });

  final String text;
  final bool fromUser;
  final bool notificationUnfollowed;
  final List<Attachment> attachments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = fromUser
        ? Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.emphasisContent,
            ),
          )
        : MarkdownBody(
            data: text,
            // Aucune image distante : une URL de modèle ne déclenche pas de requête.
            imageBuilder: (uri, title, alt) =>
                Text(alt == null || alt.isEmpty ? uri.toString() : alt),
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium?.copyWith(color: scheme.content),
              code: TextStyle(
                fontFamily: CodeStyle.family,
                color: scheme.content,
                backgroundColor: scheme.codeSurface,
              ),
              codeblockPadding: const EdgeInsets.all(Spacing.sm + Spacing.xs),
              codeblockDecoration: BoxDecoration(
                color: scheme.codeSurface,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: scheme.line),
              ),
              blockquoteDecoration: BoxDecoration(
                color: scheme.bubbleSurface,
                borderRadius: BorderRadius.circular(Radii.xs),
                border: Border(
                  left: BorderSide(
                    color: scheme.outline,
                    width: Layout.swatchSelected,
                  ),
                ),
              ),
            ),
          );
    final label = fromUser ? Content.yourRequest : Content.hermesReply;
    final content = attachments.isEmpty && !notificationUnfollowed
        ? body
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (text.isNotEmpty) body,
              if (notificationUnfollowed)
                Text(
                  Content.notificationUnfollowed,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.emphasisContent,
                  ),
                ),
              if (attachments.isNotEmpty) ...[
                if (text.isNotEmpty || notificationUnfollowed)
                  const SizedBox(height: Spacing.sm),
                DefaultTextStyle(
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.content,
                  ),
                  child: AttachmentList(attachments: attachments),
                ),
              ],
            ],
          );
    if (!fromUser) {
      return Semantics(
        container: true,
        label: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          child: content,
        ),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * Layout.bubbleMaxWidth,
        ),
        child: Semantics(
          container: true,
          label: label,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.emphasis,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: scheme.line),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm + Spacing.xxs,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
