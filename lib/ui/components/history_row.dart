import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/history.dart';
import '../content.dart';
import '../tokens.dart';

/// Une conversation de l'historique : titre (sinon aperçu, sinon libellé
/// générique), date locale et nombre de messages, annoncés d'un bloc ; la
/// conversation ouverte est teintée de la couleur du profil. Le menu de fin
/// de ligne propose « Renommer » ; le focus lui revient après le dialogue.
class HistoryRow extends StatefulWidget {
  const HistoryRow({
    super.key,
    required this.session,
    this.onTap,
    this.selected = false,
    this.onRename,
    this.renameMissing = false,
  });
  final SessionSummary session;
  final bool selected;
  final VoidCallback? onTap;

  /// Ouvre le renommage ; se termine à la fermeture du dialogue.
  final Future<void> Function()? onRename;

  /// Méthode absente constatée : entrée désactivée et expliquée.
  final bool renameMissing;

  @override
  State<HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<HistoryRow> {
  final _menuFocus = FocusNode(debugLabel: 'history-row-menu');

  @override
  void dispose() {
    _menuFocus.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    await widget.onRename!();
    if (mounted) _menuFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final date = session.startedAt;
    final scheme = Theme.of(context).colorScheme;
    final label =
        session.title ?? session.preview ?? Content.untitledConversation;
    return ListTile(
      selected: widget.selected,
      selectedColor: scheme.content,
      selectedTileColor: scheme.accent.withValues(alpha: Palette.accentTint),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      visualDensity: VisualDensity.compact,
      subtitle: Text(
        [
          if (date != null) Content.historyDate(date),
          Content.messageCount(session.messageCount),
        ].join(' · '),
      ),
      trailing: widget.onRename == null
          ? null
          : MenuAnchor(
              childFocusNode: _menuFocus,
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(Icons.edit_outlined),
                  onPressed: widget.renameMissing
                      ? null
                      : () => unawaited(_rename()),
                  child: widget.renameMissing
                      ? const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(Content.rename),
                            Text(Content.renameMissing),
                          ],
                        )
                      : const Text(Content.rename),
                ),
              ],
              builder: (context, controller, _) => IconButton(
                focusNode: _menuFocus,
                tooltip: Content.conversationActions(label),
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                icon: const Icon(Icons.more_vert),
              ),
            ),
      onTap: widget.onTap,
    );
  }
}

/// Chargement, vide ou erreur de l'historique : texte et icône, jamais la
/// couleur seule ; annoncé comme région live.
class HistoryNotice extends StatelessWidget {
  const HistoryNotice({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icon)),
              const SizedBox(width: Spacing.sm),
              Expanded(child: Text(message)),
            ],
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    ),
  );
}
