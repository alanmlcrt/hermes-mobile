import 'package:flutter/material.dart';

import '../../models/history.dart';
import '../content.dart';
import '../tokens.dart';

/// Une conversation de l'historique : titre (sinon aperçu, sinon libellé
/// générique), date locale et nombre de messages, annoncés d'un bloc ; la
/// conversation ouverte est teintée de la couleur du profil.
class HistoryRow extends StatelessWidget {
  const HistoryRow({
    super.key,
    required this.session,
    this.onTap,
    this.selected = false,
  });
  final SessionSummary session;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final date = session.startedAt;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      selected: selected,
      selectedColor: scheme.content,
      selectedTileColor: scheme.accent.withValues(alpha: Palette.accentTint),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      title: Text(
        session.title ?? session.preview ?? Content.untitledConversation,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      visualDensity: VisualDensity.compact,
      subtitle: Text(
        [
          if (date != null) Content.historyDate(date),
          Content.messageCount(session.messageCount),
        ].join(' · '),
      ),
      onTap: onTap,
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
