import 'package:flutter/material.dart';

import '../../models/draft.dart';
import '../../models/profile.dart';
import '../../models/timeline.dart';
import '../../ui/components/activity_line.dart';
import '../../ui/components/composer.dart';
import '../../ui/components/message_bubble.dart';
import '../../ui/components/profile_choice.dart';
import '../../ui/components/status_label.dart';
import '../../ui/components/work_state_label.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import 'draft_view_model.dart';

class DraftView extends StatefulWidget {
  const DraftView({
    super.key,
    required this.create,
    required this.onOpenProfiles,
    this.continuation = false,
    this.onOpenHistory,
    this.onNewConversation,
  });

  /// Le ViewModel vit aussi longtemps que la page, pas que le rendu.
  final DraftViewModel Function() create;
  /// [pick] : l'écran renvoie le profil choisi (brouillon neuf seulement).
  final Future<ProfileKey?> Function(bool pick) onOpenProfiles;

  /// Suite d'une conversation existante (route `/c/...`), pas un brouillon neuf.
  final bool continuation;

  /// Historique du profil de cette conversation (ou du brouillon neuf).
  final void Function(ProfileKey profile)? onOpenHistory;
  final void Function(ProfileKey profile)? onNewConversation;
  @override
  State<DraftView> createState() => _DraftViewState();
}

class _DraftViewState extends State<DraftView> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late final _viewModel = widget.create();
  bool _filled = false;
  int _clearTick = 0;

  @override
  void dispose() {
    _viewModel.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _viewModel,
    builder: (context, _) {
      final vm = _viewModel;
      final draft = vm.draft;
      if (!_filled && draft != null) {
        _filled = true;
        _controller.text = draft.body;
      }
      if (_clearTick != vm.clearTick) {
        _clearTick = vm.clearTick;
        _controller.clear();
      }
      final profile = vm.profile;
      final blocked = vm.blockedReason;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.continuation
                ? Content.timelineTitle
                : Content.newConversation,
          ),
          actions: [
            TextButton(
              onPressed: () => _openProfiles(vm),
              child: const Text(Content.profilesTitle),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _thread(context, vm, draft, profile)),
              // Sans brouillon chargé, une saisie écraserait le texte stocké.
              if (draft != null)
                // Défile si la saisie dépasse l'écran (texte 200 %, paysage).
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(Spacing.md),
                    child: Composer(
                      controller: _controller,
                      onChanged: vm.update,
                      onSend: blocked == null ? vm.send : null,
                      disabledReason: blocked,
                      status: vm.statusText,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  /// Fil paresseux au-dessus de la saisie ; suit le dernier élément quand
  /// l'utilisateur est déjà en bas.
  Widget _thread(
    BuildContext context,
    DraftViewModel vm,
    Draft? draft,
    Profile? profile,
  ) {
    final c = _scroll;
    final atBottom =
        !c.hasClients || c.position.maxScrollExtent - c.position.pixels < Spacing.md;
    final children = <Widget>[
      if (draft != null) _profileRow(context, vm, draft, profile),
      if (draft != null &&
          (widget.onOpenHistory != null ||
              (widget.continuation && widget.onNewConversation != null)))
        Wrap(
          spacing: Spacing.sm,
          children: [
            if (widget.onOpenHistory != null)
              TextButton(
                onPressed: () => widget.onOpenHistory!(draft.profile),
                child: const Text(Content.conversations),
              ),
            if (widget.continuation && widget.onNewConversation != null)
              TextButton(
                onPressed: () => widget.onNewConversation!(draft.profile),
                child: const Text(Content.newConversation),
              ),
          ],
        ),
      if (vm.resumeFailed)
        Semantics(liveRegion: true, child: const Text(Content.resumeFailed)),
      if (vm.error != null)
        Semantics(
          liveRegion: true,
          child: Text(
            draft == null
                ? Content.error(vm.error!.code)
                : '${Content.error(vm.error!.code)} ${Content.draftKept}',
          ),
        ),
      if (vm.resyncing)
        Semantics(
          liveRegion: true,
          child: const StatusLabel(
            icon: Icons.sync,
            label: ConnectionLabels.resyncing,
          ),
        ),
      ..._timeline(context, vm.timeline),
    ];
    if (atBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (c.hasClients) c.jumpTo(c.position.maxScrollExtent);
      });
    }
    return ListView.builder(
      controller: c,
      padding: const EdgeInsets.all(Spacing.md),
      itemCount: children.length,
      itemBuilder: (context, i) => children[i],
    );
  }

  /// Profil du brouillon : bouton de choix tant que la conversation est neuve,
  /// texte seul ensuite. Région live : le profil choisi est annoncé.
  Widget _profileRow(
    BuildContext context,
    DraftViewModel vm,
    Draft draft,
    Profile? profile,
  ) {
    final name = profile == null
        ? draft.profile.value
        : Content.profileName(profile.label, profile.key.value);
    final label = Content.draftProfile(name);
    if (!vm.canChooseProfile) return Text(label);
    return Align(
      alignment: Alignment.centerLeft,
      // Fusionné : le bouton lui-même est la région live annonçant le profil.
      child: MergeSemantics(
        child: Semantics(
          liveRegion: true,
          hint: Content.chooseProfileHint,
          child: TextButton.icon(
            onPressed: vm.sendStatus.busy ? null : () => _pick(context, vm),
            icon: const Icon(Icons.expand_more),
            label: Text(label),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, DraftViewModel vm) async {
    final chosen = await showModalBottomSheet<ProfileKey>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Semantics(
                header: true,
                child: Text(
                  Content.chooseProfile,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final p in vm.gateway.snapshot.profiles)
              ProfileChoice(
                profile: p,
                selected: p.key == vm.draft?.profile,
                onTap: () => Navigator.of(context).pop(p.key),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) await vm.selectProfile(chosen);
  }

  /// « Mes profils » depuis un brouillon neuf renvoie le profil choisi.
  Future<void> _openProfiles(DraftViewModel vm) async {
    final chosen = await widget.onOpenProfiles(vm.canChooseProfile);
    if (chosen != null && mounted) await vm.selectProfile(chosen);
  }

  /// Éléments du fil ; rebâti sans aucun appel (état dans la projection).
  List<Widget> _timeline(BuildContext context, TimelineProjection timeline) {
    if (timeline.items.isEmpty && timeline.workState == null) return const [];
    final work = timeline.workState;
    return [
      Semantics(
        header: true,
        child: Text(
          Content.timelineTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      for (final item in timeline.items) ...[
        const SizedBox(height: Spacing.sm),
        switch (item) {
          UserItem() => MessageBubble(text: item.text, fromUser: true),
          ResponseItem() => MessageBubble(text: item.text),
          ActivityItem() => ActivityLine(kind: item.kind),
        },
      ],
      if (work != null) ...[
        const SizedBox(height: Spacing.sm),
        // Région live : chaque changement d'état est annoncé.
        Semantics(liveRegion: true, child: WorkStateLabel(state: work)),
      ],
      if (work == WorkState.failed && timeline.errorCode != null) ...[
        const SizedBox(height: Spacing.xs),
        Text(Content.error(timeline.errorCode!)),
      ],
    ];
  }
}
