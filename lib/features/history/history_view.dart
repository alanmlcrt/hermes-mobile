import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/conversation_search.dart';
import '../../models/history.dart';
import '../../models/profile.dart';
import '../../ui/components/history_row.dart';
import '../../ui/components/profile_avatar.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import '../profiles/profile_accents.dart';
import 'delete_conversation_dialog.dart';
import 'history_view_model.dart';
import 'rename_conversation_dialog.dart';

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
    this.onOpenIn,
  });

  /// Ouvre un résultat de recherche d'un autre profil (cible complète).
  final void Function(ProfileKey profile, String session)? onOpenIn;
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
          onRename: () => showRenameConversationDialog(context, vm, s),
          renameMissing: vm.renameMissing,
          marker: vm.markerOf(s.id),
          onTogglePin: () => unawaited(vm.togglePin(s.id)),
          onToggleUnread: () => unawaited(vm.toggleUnread(s.id)),
          hidden: vm.section == HistorySection.hidden,
          onHide: vm.hideMissing
              ? null
              : () => unawaited(_hide(context, vm, s)),
          onDelete: () => unawaited(_delete(context, vm, s)),
          busy: vm.statusOf(s.id)?.busy ?? false,
          notice: switch (vm.statusOf(s.id)?.error) {
            final code? => Content.rowError(code),
            null => null,
          },
        ),
      );
    }
    return rows;
  }

  /// Masque (liste principale) ou rétablit (« Masquées ») ; « Annuler »
  /// envoie l'inverse, confirmé lui aussi.
  Future<void> _hide(
    BuildContext context,
    HistoryViewModel vm,
    SessionSummary s,
  ) async {
    final hiding = vm.section == HistorySection.main;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!await vm.setHidden(s, hiding) || messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(hiding ? Content.conversationHidden : Content.restored),
          action: hiding
              ? SnackBarAction(
                  label: Content.undo,
                  onPressed: () => unawaited(vm.undoHide()),
                )
              : null,
        ),
      );
  }

  Future<void> _delete(
    BuildContext context,
    HistoryViewModel vm,
    SessionSummary s,
  ) async {
    final title = s.title ?? s.preview ?? Content.untitledConversation;
    if (await confirmDeleteConversation(context, title)) {
      await vm.delete(s);
    }
  }

  Widget _search(BuildContext context, HistoryViewModel vm) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          labelText: Content.searchHint,
        ),
        textInputAction: TextInputAction.search,
        onChanged: vm.search,
      ),
      Wrap(
        spacing: Spacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterChip(
            label: const Text(Content.searchAllProfiles),
            selected: vm.allProfiles,
            onSelected: vm.setAllProfiles,
          ),
          SegmentedButton<HistorySection>(
            segments: const [
              ButtonSegment(
                value: HistorySection.main,
                label: Text(Content.sectionMain),
              ),
              ButtonSegment(
                value: HistorySection.hidden,
                label: Text(Content.sectionHidden),
                icon: Icon(Icons.visibility_off_outlined),
              ),
            ],
            selected: {vm.section},
            onSelectionChanged: (s) => vm.showSection(s.single),
          ),
        ],
      ),
    ],
  );

  List<Widget> _results(BuildContext context, HistoryViewModel vm) {
    final theme = Theme.of(context);
    return [
      Text(
        Content.searchCoverage,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.muted,
        ),
      ),
      if (vm.searchState == SearchState.searching)
        const HistoryNotice(
          icon: Icons.hourglass_empty,
          message: Content.searchRunning,
        ),
      for (final p in vm.searchFailed)
        HistoryNotice(
          icon: Icons.error_outline,
          message: Content.searchFailed(vm.nameOf(p)),
        ),
      if (vm.searchState == SearchState.done && vm.results.isEmpty)
        const HistoryNotice(
          icon: Icons.search_off,
          message: Content.searchEmpty,
        ),
      for (final MapEntry(key: p, value: hits) in vm.results.entries) ...[
        Padding(
          padding: const EdgeInsetsDirectional.only(
            top: Spacing.md,
            bottom: Spacing.xs,
            start: Spacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(vm.nameOf(p), style: theme.textTheme.labelLarge),
          ),
        ),
        for (final hit in hits) _hit(context, vm, hit),
      ],
    ];
  }

  Widget _hit(BuildContext context, HistoryViewModel vm, SearchHit hit) {
    final title =
        hit.session.title ??
        hit.session.preview ??
        Content.untitledConversation;
    // Passage en gras et souligné : jamais la couleur seule.
    const strong = TextStyle(
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );
    return Semantics(
      button: true,
      label: Content.searchResult(vm.nameOf(hit.profile), title, hit.text),
      excludeSemantics: true,
      child: ListTile(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: hit.text.substring(0, hit.start)),
              TextSpan(
                text: hit.text.substring(hit.start, hit.end),
                style: strong,
              ),
              TextSpan(text: hit.text.substring(hit.end)),
            ],
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => hit.profile == vm.profile || widget.onOpenIn == null
            ? widget.onOpen(hit.session.id)
            : widget.onOpenIn!(hit.profile, hit.session.id),
      ),
    );
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
        _search(context, vm),
        const SizedBox(height: Spacing.sm),
        if (vm.section == HistorySection.hidden && vm.hideMissing)
          const HistoryNotice(icon: Icons.block, message: Content.hideMissing),
        if (vm.searching)
          ..._results(context, vm)
        else
          ...switch (vm.state) {
            HistoryState.loading => const [
              HistoryNotice(
                icon: Icons.hourglass_empty,
                message: Content.historyLoading,
              ),
            ],
            HistoryState.empty => [
              HistoryNotice(
                icon: Icons.inbox_outlined,
                message: vm.section == HistorySection.hidden
                    ? Content.hiddenEmpty
                    : Content.historyEmpty,
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
              if (vm.markerFailed)
                const HistoryNotice(
                  icon: Icons.error_outline,
                  message: Content.markerFailed,
                ),
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
