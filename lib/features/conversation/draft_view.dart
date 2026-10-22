import 'package:flutter/material.dart';

import '../../models/draft.dart';
import '../../models/profile.dart';
import '../../models/timeline.dart';
import '../../ui/components/activity_line.dart';
import '../../ui/components/activity_group.dart';
import '../../ui/components/composer.dart';
import '../../ui/components/conversation_companion.dart';
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
  bool _companionPaused = false;
  final _activityExpansion = <Object, bool>{};
  final _detailExpansion = <Object, bool>{};
  final _activityKeys = <Object, GlobalKey>{};
  TimelineProjection? _renderedTimeline;
  Size? _threadViewport;

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
            // Le libellé agrandi ne doit pas déborder de la barre étroite.
            if (!ConversationCompanion.sideBySide(
              context,
              MediaQuery.sizeOf(context).width,
            ))
              IconButton(
                tooltip: Content.profilesTitle,
                onPressed: () => _openProfiles(vm),
                icon: const Icon(Icons.people_outline),
              )
            else
              TextButton(
                onPressed: () => _openProfiles(vm),
                child: const Text(Content.profilesTitle),
              ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _thread(context, vm, draft, profile, viewport.biggest),
                ),
                // Sans brouillon chargé, une saisie écraserait le texte stocké.
                if (draft != null || vm.timeline.workState != null)
                  // Défile si la saisie dépasse l'écran (texte 200 %, paysage).
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: viewport.maxHeight * 0.5,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(Spacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (vm.timeline.workState case final work?) ...[
                            // Toujours monté, même pendant la lecture d'un ancien
                            // bloc très éloigné de la fin du fil paresseux.
                            Semantics(
                              liveRegion: true,
                              child: WorkStateLabel(state: work),
                            ),
                            const SizedBox(height: Spacing.sm),
                          ],
                          if (draft != null)
                            Composer(
                              controller: _controller,
                              onChanged: vm.update,
                              onSend: blocked == null ? vm.send : null,
                              disabledReason: blocked,
                              status: vm.statusText,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
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
    Size viewport,
  ) {
    final c = _scroll;
    final timelineChanged = !identical(_renderedTimeline, vm.timeline);
    _renderedTimeline = vm.timeline;
    final viewportChanged = viewport != _threadViewport;
    _threadViewport = viewport;
    final focused = FocusManager.instance.primaryFocus?.context;
    // Un changement de route peut laisser brièvement le focus sur un élément
    // déjà détaché. Ne pas remonter ses ancêtres pendant cette transition.
    final readingDetails =
        focused is Element &&
        focused.renderObject?.attached == true &&
        focused.findAncestorWidgetOfExactType<ActivityLine>()?.expanded == true;
    final atBottom =
        !c.hasClients ||
        c.position.maxScrollExtent - c.position.pixels < Spacing.md;
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
      ..._timeline(context, vm),
    ];
    if (atBottom && (timelineChanged || viewportChanged) && !readingDetails) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (c.hasClients) c.jumpTo(c.position.maxScrollExtent);
      });
    }
    return ListView.builder(
      controller: c,
      padding: const EdgeInsets.all(Spacing.md),
      itemCount: children.length,
      itemBuilder: (context, i) => children[i],
      findChildIndexCallback: (key) {
        final at = children.indexWhere((child) => child.key == key);
        return at < 0 ? null : at;
      },
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
  List<Widget> _timeline(BuildContext context, DraftViewModel vm) {
    final timeline = vm.timeline;
    if (timeline.items.isEmpty && timeline.workState == null) return const [];
    final work = timeline.workState;
    final latestTurn = timeline.items.fold<int>(
      timeline.turns > timeline.userTurns ? timeline.turns : timeline.userTurns,
      (latest, item) => item.turn > latest ? item.turn : latest,
    );
    // Un seul passage de regroupement ; les blocs de chaque tour sont ensuite
    // des entrées distinctes du ListView.builder (pas de Column de tout le tour).
    final groups = <int, List<TimelineItem>>{};
    for (final item in timeline.items) {
      (groups[item.turn] ??= []).add(item);
    }
    if (work != null) groups.putIfAbsent(latestTurn, () => []);
    Widget block(TimelineItem item) => switch (item) {
      ResponseItem() => MessageBubble(text: item.text),
      ActivityItem() => ActivityLine(
        key: item.eventKey == null
            ? null
            : _activityKeys.putIfAbsent((
                vm.draft?.key,
                item.eventKey,
              ), GlobalKey.new),
        kind: item.kind,
        completed: item.completed,
        paused: _companionPaused || vm.resyncing,
        details: item.details,
        expanded:
            _detailExpansion[(vm.draft?.key, item.eventKey ?? item)] ?? false,
        onChanged: (value) => setState(
          () =>
              _detailExpansion[(vm.draft?.key, item.eventKey ?? item)] = value,
        ),
      ),
      UserItem() => MessageBubble(text: item.text, fromUser: true),
    };
    // Les activités provisoires du prochain envoi restent après l'historique,
    // sans créer de réservation Otc avant l'accusé ou le démarrage serveur.
    final turns = groups.keys.where((turn) => turn != 0).toList()..sort();
    if (groups.containsKey(0)) turns.add(0);
    final entries = <Widget>[];
    for (final turn in turns) {
      final items = groups[turn]!;
      if (turn == 0) {
        // Activités préalables à l'accusé : visibles mais pas encore un tour.
        for (final item in items) {
          entries.addAll([const SizedBox(height: Spacing.sm), block(item)]);
        }
        continue;
      }
      final responses = <Widget>[];
      for (final item in items) {
        if (item is UserItem) {
          entries.addAll([const SizedBox(height: Spacing.sm), block(item)]);
        }
      }
      for (var i = 0; i < items.length;) {
        final item = items[i];
        if (item is UserItem) {
          i++;
          continue;
        }
        if (item is! ActivityItem) {
          responses.add(
            KeyedSubtree(
              key: ValueKey(('response', turn, i)),
              child: block(item),
            ),
          );
          i++;
          continue;
        }
        var end = i + 1;
        while (end < items.length && items[end] is ActivityItem) {
          end++;
        }
        final activities = items.sublist(i, end).cast<ActivityItem>();
        final groupId = (vm.draft?.key, turn, item.eventKey ?? i);
        // Consulter un détail maintient le groupe ouvert ; un repli manuel
        // du groupe reste prioritaire, même si ce détail est encore ouvert.
        final expanded =
            _activityExpansion[groupId] ??
            (!activities.any((a) => a.responseReceived) ||
                activities.any(
                  (a) => _detailExpansion.containsKey((
                    vm.draft?.key,
                    a.eventKey ?? a,
                  )),
                ));
        if (activities.length >= 2) {
          responses.add(
            ActivityGroup(
              key: ValueKey(groupId),
              count: activities.length,
              pending: activities.where((a) => !a.completed).length,
              expanded: expanded,
              onChanged: (value) =>
                  setState(() => _activityExpansion[groupId] = value),
            ),
          );
        }
        if (activities.length < 2 || expanded) {
          for (var offset = 0; offset < activities.length; offset++) {
            final activity = activities[offset];
            responses.add(
              KeyedSubtree(
                key: ValueKey((
                  'activity',
                  turn,
                  activity.eventKey ?? i + offset,
                )),
                child: block(activity),
              ),
            );
          }
        }
        i = end;
      }
      final current = turn == latestTurn;
      if (current && work != null) {
        entries.add(
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _companionPaused = !_companionPaused),
              icon: Icon(_companionPaused ? Icons.play_arrow : Icons.pause),
              label: Text(
                _companionPaused
                    ? Content.resumeCompanion
                    : Content.pauseCompanion,
              ),
            ),
          ),
        );
      }
      entries.add(
        ConversationCompanion(
          key: ValueKey('companion-turn-$turn'),
          current: current,
          phase: vm.companionPhase,
          resting:
              work == WorkState.succeeded ||
              work == WorkState.failed ||
              work == WorkState.stopped,
          active: !vm.resyncing,
          paused: _companionPaused,
          child: responses.isEmpty ? const SizedBox.shrink() : responses.first,
        ),
      );
      for (final item in responses.skip(1)) {
        entries.addAll([
          Padding(
            key: item.key,
            padding: const EdgeInsets.only(top: Spacing.sm),
            child: ConversationCompanionContinuation(child: item),
          ),
        ]);
      }
    }
    return [
      Semantics(
        header: true,
        child: Text(
          Content.timelineTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      ...entries,
      if (work == WorkState.failed && timeline.errorCode != null) ...[
        const SizedBox(height: Spacing.xs),
        Text(Content.error(timeline.errorCode!)),
      ],
    ];
  }
}
