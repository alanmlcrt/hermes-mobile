import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/attachment.dart';
import '../content.dart';
import '../tokens.dart';

class AttachmentList extends StatelessWidget {
  const AttachmentList({super.key, required this.attachments, this.onRemove});
  final List<Attachment> attachments;
  final ValueChanged<Attachment>? onRemove;
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
                    if (a.isImage && !a.missing) ...[
                      ExcludeSemantics(
                        child: Image.file(
                          File(a.localPath),
                          width: AttachmentTokens.preview,
                          height: AttachmentTokens.preview,
                          cacheWidth: AttachmentTokens.cacheWidth,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
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
                Text(
                  a.missing
                      ? Content.attachmentMissing
                      : Content.attachmentSelected,
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Semantics(
                    label: Content.removeAttachment(a.name),
                    child: TextButton(
                      onPressed: onRemove == null ? null : () => onRemove!(a),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          Layout.stopButton,
                          Layout.stopButton,
                        ),
                      ),
                      child: const Text(Content.remove),
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
