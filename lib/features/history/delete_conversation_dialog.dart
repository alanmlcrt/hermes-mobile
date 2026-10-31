import 'package:flutter/material.dart';

import '../../ui/content.dart';
import '../../ui/tokens.dart';

/// Confirmation d'une suppression définitive (7.5) : la conséquence sur
/// Hermes est annoncée ; seul « Supprimer définitivement » rend vrai.
Future<bool> confirmDeleteConversation(
  BuildContext context,
  String title,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Content.deleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: Spacing.sm),
            const Text(Content.deleteBody),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(Content.deleteCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(Content.deleteConfirm),
          ),
        ],
      ),
    ) ??
    false;
