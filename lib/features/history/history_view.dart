import 'package:flutter/material.dart';

import '../../models/history.dart';
import '../../models/profile.dart';
import '../../ui/components/history_row.dart';
import '../../ui/components/profile_avatar.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import '../profiles/profile_accents.dart';
import 'history_view_model.dart';

/// Conversations d'un profil, en feuille du bas ouverte depuis la pastille
/// du nom ; ouvrir une ligne reprend la conversation.
class HistoryView extends StatefulWidget {
  const HistoryView({
    super.key,
    required this.create,
    required this.accents,
    required this.onOpen,
    required this.onNewConversation,
    this.onSettings,
    this.current,
  });
  final ProfileAccents accents;

  /// Conversation ouverte sous la feuille, surlignée.
  final String? current;
  final void Function(ProfileKey profile)? onSettings;

  /// Le ViewModel vit aussi longtemps que la page, pas que le rendu.
  final HistoryViewModel Function() create;
  final void Function(String session) onOpen;
  final void Function(ProfileKey profile) onNewConversation;
  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  late final _viewModel = widget.create();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Widget _list(List<Widget> children) => ListView.builder(
    shrinkWrap: true,
    padding: const EdgeInsetsDirectional.only(
      start: Spacing.md,
      end: Spacing.md,
      bottom: Spacing.lg,
    ),
    itemCount: children.length,
    itemBuilder: (context, i) => children[i],
  );

  /// Ordre serveur conservé ; un intertitre à chaque changement de tranche
  /// de date.
  List<Widget> _rows(BuildContext context, HistoryViewModel vm) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    String? bucket;
    final rows = <Widget>[];
    for (final s in vm.sessions) {
      final date = s.startedAt;
      final b = date == null ? bucket : Content.historyBucket(date, now);
      if (b != null && b != bucket) {
        bucket = b;
        rows.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: Spacing.md,
              bottom: Spacing.xs,
              start: Spacing.xs,
            ),
            child: Semantics(
              header: true,
              child: Text(
                b,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.muted,
                ),
              ),
            ),
          ),
        );
      }
      rows.add(
        HistoryRow(
          session: s,
          selected: s.id == widget.current,
          onTap: () => widget.onOpen(s.id),
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_viewModel, widget.accents]),
    builder: (context, _) {
      final vm = _viewModel;
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final loading = vm.state == HistoryState.loading;
      final children = <Widget>[
        Row(
          children: [
            ProfileAvatar(label: vm.profileName, size: Layout.avatarSheet),
            const SizedBox(width: Spacing.sm + Spacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Le profil listé est annoncé : aucune liste sans son profil.
                  Semantics(
                    container: true,
                    header: true,
                    label: Content.draftProfile(vm.profileName),
                    excludeSemantics: true,
                    child: Text(
                      vm.profileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (vm.state == HistoryState.ready)
                    Text(
                      Content.conversationCount(vm.sessions.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.muted,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: Content.refreshHistory,
              onPressed: loading ? null : vm.refresh,
              icon: const Icon(Icons.refresh),
            ),
            if (widget.onSettings != null)
              IconButton.filledTonal(
                tooltip: Content.profileSettings,
                onPressed: () => widget.onSettings!(vm.profile),
                icon: const Icon(Icons.tune),
              ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(Layout.headerButton),
          ),
          onPressed: () => widget.onNewConversation(vm.profile),
          icon: const Icon(Icons.add),
          label: const Text(Content.newConversation),
        ),
        const SizedBox(height: Spacing.sm),
        ...switch (vm.state) {
          HistoryState.loading => const [
            HistoryNotice(
              icon: Icons.hourglass_empty,
              message: Content.historyLoading,
            ),
          ],
          HistoryState.empty => const [
            HistoryNotice(
              icon: Icons.inbox_outlined,
              message: Content.historyEmpty,
            ),
          ],
          HistoryState.error => [
            HistoryNotice(
              icon: Icons.error_outline,
              message: Content.historyError,
              actionLabel: Content.retryList,
              onAction: vm.refresh,
            ),
          ],
          HistoryState.ready => [
            ..._rows(context, vm),
            if (vm.sessions.length >= sessionListLimit)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Spacing.sm),
                child: Text(Content.historyLimitNote),
              ),
          ],
        },
      ];
      // Sans Scaffold : la feuille fournit la surface ; Material pour les
      // tuiles si la vue est montée seule.
      return Material(
        type: MaterialType.transparency,
        child: AccentScope(
          accent: widget.accents.of(vm.profile),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * Layout.sheetMax,
            ),
            child: _list(children),
          ),
        ),
      );
    },
  );
}
