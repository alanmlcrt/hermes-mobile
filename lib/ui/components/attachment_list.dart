import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/attachment.dart';
import '../content.dart';
import '../tokens.dart';

class AttachmentList extends StatelessWidget {
  const AttachmentList({
    super.key,
    required this.attachments,
    this.onRemove,
    this.onRetry,
  });
  final List<Attachment> attachments;
  final ValueChanged<Attachment>? onRemove;
  final ValueChanged<Attachment>? onRetry;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xs + Spacing.xxs,
              ),
              decoration: BoxDecoration(
                color: scheme.bubbleSurface,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: scheme.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (a.isImage && !a.missing && !a.cleaned) ...[
                        Semantics(
                          label: Content.attachmentPreview(a.name),
                          image: true,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.xs),
                            child: Image.file(
                              File(a.localPath),
                              width: AttachmentTokens.preview,
                              height: AttachmentTokens.preview,
                              cacheWidth: AttachmentTokens.cacheWidth,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                      ] else ...[
                        ExcludeSemantics(
                          child: Container(
                            width: AttachmentTokens.preview,
                            height: AttachmentTokens.preview,
                            decoration: BoxDecoration(
                              color: scheme.card,
                              borderRadius: BorderRadius.circular(Radii.xs),
                              border: Border.all(color: scheme.line),
                            ),
                            child: Icon(
                              a.isImage
                                  ? Icons.image_outlined
                                  : Icons.description_outlined,
                              size: IconSizes.sm,
                              color: scheme.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              label: a.name,
                              value:
                                  a.state == AttachmentState.selected &&
                                      !a.missing
                                  ? Content.attachmentSelected
                                  : null,
                              excludeSemantics: true,
                              child: Tooltip(
                                message: a.name,
                                child: Text(
                                  a.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.content,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              Content.compactFileSize(a.bytes),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!a.sent)
                        Semantics(
                          label: Content.removeAttachment(a.name),
                          button: true,
                          enabled: onRemove != null,
                          onTap: onRemove == null ? null : () => onRemove!(a),
                          excludeSemantics: true,
                          child: IconButton(
                            tooltip: Content.removeAttachment(a.name),
                            onPressed: onRemove == null
                                ? null
                                : () => onRemove!(a),
                            constraints: const BoxConstraints.tightFor(
                              width: Layout.touchTarget,
                              height: Layout.touchTarget,
                            ),
                            icon: Icon(
                              Icons.close,
                              size: IconSizes.sm,
                              color: scheme.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (a.state != AttachmentState.selected ||
                      (a.missing && !a.sent)) ...[
                    const SizedBox(height: Spacing.xs),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${Content.attachmentStatus(a.state, a.sent, a.errorCode)}'
                        '${a.missing && !a.sent ? ' ${Content.attachmentMissing}' : ''}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.muted,
                        ),
                      ),
                    ),
                  ],
                  if (!a.sent &&
                      (a.state == AttachmentState.failed ||
                          a.state == AttachmentState.uncertain))
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Semantics(
                        label: Content.retryAttachment(a.name),
                        child: TextButton(
                          onPressed: onRetry == null ? null : () => onRetry!(a),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(
                              Layout.stopButton,
                              Layout.stopButton,
                            ),
                          ),
                          child: const Text(Content.attachmentRetry),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class AttachmentSelectionSheet extends StatelessWidget {
  const AttachmentSelectionSheet({super.key, required this.limits});
  final List<AttachmentLimit> limits;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Content.attach,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              Content.attachmentFormats,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.muted),
            ),
            for (final limit in limits) ...[
              if (limit.maxCount != null)
                Text(
                  '${switch (limit.category) {
                    AttachmentCategory.text => Content.attachmentText,
                    AttachmentCategory.image => Content.photos,
                    AttachmentCategory.pdf => Content.attachmentPdf,
                    AttachmentCategory.office => Content.attachmentOffice,
                  }} : ${Content.attachmentCountLimit(limit.maxCount!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.muted,
                  ),
                ),
            ],
            const SizedBox(height: Spacing.md),
            TextButton.icon(
              style: TextButton.styleFrom(
                alignment: AlignmentDirectional.centerStart,
                backgroundColor: scheme.bubbleSurface,
                minimumSize: const Size.fromHeight(Layout.touchTarget),
                shape: StadiumBorder(side: BorderSide(color: scheme.line)),
              ),
              onPressed: () => Navigator.pop(context, AttachmentSource.photos),
              icon: const Icon(Icons.photo_outlined, size: IconSizes.sm),
              label: const Text(Content.photos),
            ),
            const SizedBox(height: Spacing.sm),
            TextButton.icon(
              style: TextButton.styleFrom(
                alignment: AlignmentDirectional.centerStart,
                backgroundColor: scheme.bubbleSurface,
                minimumSize: const Size.fromHeight(Layout.touchTarget),
                shape: StadiumBorder(side: BorderSide(color: scheme.line)),
              ),
              onPressed: () => Navigator.pop(context, AttachmentSource.files),
              icon: const Icon(Icons.attach_file, size: IconSizes.sm),
              label: const Text(Content.files),
            ),
          ],
        ),
      ),
    );
  }
}
