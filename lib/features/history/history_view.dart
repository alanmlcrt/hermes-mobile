import 'package:flutter/material.dart';

import '../../models/history.dart';
import '../../models/profile.dart';
import '../../ui/components/history_row.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import 'history_view_model.dart';

/// Conversations d'un profil ; ouvrir une ligne reprend la conversation.
class HistoryView extends StatefulWidget {
  const HistoryView({
    super.key,
    required this.create,
    required this.onOpen,
    required this.onNewConversation,
  });

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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _viewModel,
    builder: (context, _) {
      final vm = _viewModel;
      final loading = vm.state == HistoryState.loading;
      final children = <Widget>[
        // Le profil listé est annoncé : aucune liste sans son profil.
        Semantics(
          header: true,
          child: Text(
            Content.draftProfile(vm.profileName),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Wrap(
          spacing: Spacing.sm,
          children: [
            TextButton(
              onPressed: loading ? null : vm.refresh,
              child: const Text(Content.refreshHistory),
            ),
            TextButton(
              onPressed: () => widget.onNewConversation(vm.profile),
              child: const Text(Content.newConversation),
            ),
          ],
        ),
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
            for (final s in vm.sessions)
              HistoryRow(session: s, onTap: () => widget.onOpen(s.id)),
            if (vm.sessions.length >= sessionListLimit)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Spacing.sm),
                child: Text(Content.historyLimitNote),
              ),
          ],
        },
      ];
      return Scaffold(
        appBar: AppBar(title: const Text(Content.conversations)),
        body: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.all(Spacing.md),
            itemCount: children.length,
            itemBuilder: (context, i) => children[i],
          ),
        ),
      );
    },
  );
}
