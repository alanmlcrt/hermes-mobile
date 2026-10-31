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
    this.marker = const ConversationMarker(),
    this.onTogglePin,
    this.onToggleUnread,
    this.hidden = false,
    this.onHide,
    this.onDelete,
    this.notice,
    this.busy = false,
  });

  /// Ligne de la section « Masquées » : l'entrée devient « Rétablir ».
  final bool hidden;
  final VoidCallback? onHide;
  final VoidCallback? onDelete;

  /// Erreur ou état à vérifier, annoncé sous la ligne.
  final String? notice;

  /// Masquage ou suppression en cours : actions suspendues.
  final bool busy;
  final ConversationMarker marker;
  final VoidCallback? onTogglePin;
  final VoidCallback? onToggleUnread;
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
      // Repères en texte et icône, annoncés avec le titre (jamais la couleur seule).
      title: Row(
        children: [
          if (widget.marker.pinned) ...[
            const Icon(
              Icons.push_pin,
              size: IconSizes.sm,
              semanticLabel: Content.pinned,
            ),
            const SizedBox(width: Spacing.xs),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: widget.marker.unread
                  ? const TextStyle(fontWeight: FontWeight.w700)
                  : null,
            ),
          ),
          if (widget.marker.unread) ...[
            const SizedBox(width: Spacing.xs),
            Text(
              Content.unread,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.accent, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
      visualDensity: VisualDensity.compact,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (date != null) Content.historyDate(date),
              Content.messageCount(session.messageCount),
            ].join(' · '),
          ),
          if (widget.busy || widget.notice != null)
            Semantics(
              liveRegion: true,
              child: Text(widget.busy ? Content.rowWorking : widget.notice!),
            ),
        ],
      ),
      trailing: widget.onRename == null
          ? null
          : MenuAnchor(
              childFocusNode: _menuFocus,
              menuChildren: [
                if (widget.onTogglePin != null)
                  MenuItemButton(
                    leadingIcon: Icon(
                      widget.marker.pinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin,
                    ),
                    onPressed: widget.onTogglePin,
                    child: Text(
                      widget.marker.pinned ? Content.unpin : Content.pin,
                    ),
                  ),
                if (widget.onToggleUnread != null)
                  MenuItemButton(
                    leadingIcon: Icon(
                      widget.marker.unread
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                    ),
                    onPressed: widget.onToggleUnread,
                    child: Text(
                      widget.marker.unread
                          ? Content.markRead
                          : Content.markUnread,
                    ),
                  ),
                if (widget.onHide != null)
                  MenuItemButton(
                    leadingIcon: Icon(
                      widget.hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: widget.busy ? null : widget.onHide,
                    child: Text(widget.hidden ? Content.restore : Content.hide),
                  ),
                if (widget.onDelete != null)
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.delete_outline),
                    onPressed: widget.busy ? null : widget.onDelete,
                    child: const Text(Content.delete),
                  ),
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
