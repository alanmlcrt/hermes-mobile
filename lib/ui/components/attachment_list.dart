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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final a in attachments)
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.card,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: Theme.of(context).colorScheme.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (a.isImage && !a.missing && !a.cleaned) ...[
                      Semantics(
                        label: Content.attachmentPreview(a.name),
                        image: true,
                        child: Image.file(
                          File(a.localPath),
                          width: AttachmentTokens.preview,
                          height: AttachmentTokens.preview,
                          cacheWidth: AttachmentTokens.cacheWidth,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name),
                          Text(a.mediaType),
                          Text(Content.fileSize(a.bytes)),
                        ],
                      ),
                    ),
                  ],
                ),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '${Content.attachmentStatus(a.state, a.sent, a.errorCode)}'
                    '${a.missing && !a.sent ? ' ${Content.attachmentMissing}' : ''}',
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: Spacing.sm,
                    runSpacing: Spacing.xs,
                    children: [
                      if (!a.sent &&
                          (a.state == AttachmentState.failed ||
                              a.state == AttachmentState.uncertain))
                        Semantics(
                          label: Content.retryAttachment(a.name),
                          child: TextButton(
                            onPressed: onRetry == null
                                ? null
                                : () => onRetry!(a),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(
                                Layout.stopButton,
                                Layout.stopButton,
                              ),
                            ),
                            child: const Text(Content.attachmentRetry),
                          ),
                        ),
                      if (!a.sent)
                        Semantics(
                          label: Content.removeAttachment(a.name),
                          child: TextButton(
                            onPressed: onRemove == null
                                ? null
                                : () => onRemove!(a),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(
                                Layout.stopButton,
                                Layout.stopButton,
                              ),
                            ),
                            child: const Text(Content.remove),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class AttachmentSelectionSheet extends StatelessWidget {
  const AttachmentSelectionSheet({super.key, required this.limits});
  final List<AttachmentLimit> limits;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Content.attach, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Spacing.md),
          const Text(Content.attachmentFormats),
          for (final limit in limits) ...[
            Text(
              Content.attachmentLimit(switch (limit.category) {
                AttachmentCategory.text => Content.attachmentText,
                AttachmentCategory.image => Content.photos,
                AttachmentCategory.pdf => Content.attachmentPdf,
                AttachmentCategory.office => Content.attachmentOffice,
              }, limit.maxBytes),
            ),
            if (limit.maxCount != null)
              Text(Content.attachmentCountLimit(limit.maxCount!)),
          ],
          const SizedBox(height: Spacing.md),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, AttachmentSource.photos),
            icon: const Icon(Icons.photo_outlined),
            label: const Text(Content.photos),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, AttachmentSource.files),
            icon: const Icon(Icons.attach_file),
            label: const Text(Content.files),
          ),
        ],
      ),
    ),
  );
}
