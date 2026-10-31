import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/history.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import 'history_view_model.dart';

/// Ouvre le renommage de [session] ; se termine à la fermeture du dialogue
/// (le focus revient alors à l'élément qui l'a ouvert).
Future<void> showRenameConversationDialog(
  BuildContext context,
  HistoryViewModel viewModel,
  SessionSummary session,
) => showDialog<void>(
  context: context,
  builder: (_) =>
      RenameConversationDialog(viewModel: viewModel, session: session),
  // Toute fermeture sans succès (annuler, voile, retour) oublie la saisie ;
  // un renommage en cours garde son état.
).whenComplete(() => viewModel.dismissRename(session.id));

/// Champ initialisé (saisie conservée sinon titre courant), erreur annoncée,
/// progression et annulation ; aucun appel réseau dans la vue.
class RenameConversationDialog extends StatefulWidget {
  const RenameConversationDialog({
    super.key,
    required this.viewModel,
    required this.session,
  });
  final HistoryViewModel viewModel;
  final SessionSummary session;

  @override
  State<RenameConversationDialog> createState() =>
      _RenameConversationDialogState();
}

class _RenameConversationDialogState extends State<RenameConversationDialog> {
  late final _controller = TextEditingController(
    text:
        widget.viewModel.renameOf(widget.session.id)?.draft ??
        widget.session.title ??
        '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await widget.viewModel.rename(widget.session, _controller.text);
    if (ok && mounted) Navigator.of(context).pop();
  }

  void _cancel() => Navigator.of(context).pop();

  void _refresh() {
    Navigator.of(context).pop();
    unawaited(widget.viewModel.refresh());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final status = widget.viewModel.renameOf(widget.session.id);
      final busy = status?.busy == true;
      final error = status?.error;
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        scrollable: true,
        title: const Text(Content.renameTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(Content.renameHint),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _controller,
              autofocus: true,
              readOnly: busy,
              textInputAction: TextInputAction.done,
              onSubmitted: busy ? null : (_) => unawaited(_submit()),
              decoration: const InputDecoration(labelText: Content.renameField),
            ),
            if (busy) ...[
              const SizedBox(height: Spacing.sm),
              const LinearProgressIndicator(semanticsLabel: Content.renaming),
            ],
            if (error != null) ...[
              const SizedBox(height: Spacing.sm),
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(Icons.error_outline, color: scheme.error),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        Content.renameError(error),
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (HistoryViewModel.needsRefresh(error))
            TextButton(
              onPressed: busy ? null : _refresh,
              child: const Text(Content.refreshHistory),
            ),
          TextButton(
            onPressed: _cancel,
            child: const Text(Content.renameCancel),
          ),
          FilledButton(
            onPressed: busy ? null : () => unawaited(_submit()),
            child: const Text(Content.renameConfirm),
          ),
        ],
      );
    },
  );
}
