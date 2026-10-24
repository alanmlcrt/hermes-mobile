import 'package:flutter/material.dart';

import '../../models/draft.dart';
import '../../models/profile.dart';
import '../../models/timeline.dart';
import '../../ui/components/activity_line.dart';
import '../../ui/components/activity_group.dart';
import '../../ui/components/appear.dart';
import '../../ui/components/composer.dart';
import '../../ui/components/message_bubble.dart';
import '../../ui/components/profile_avatar.dart';
import '../../ui/components/status_label.dart';
import '../../ui/components/work_state_label.dart';
import '../../ui/content.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../profiles/profile_accents.dart';
import 'draft_view_model.dart';

class DraftView extends StatefulWidget {
  const DraftView({
    super.key,
    required this.create,
    required this.accents,
    this.continuation = false,
    this.onHome,
    this.onHistory,
    this.onNewConversation,
  });

  /// Le ViewModel vit aussi longtemps que la page, pas que le rendu.
  final DraftViewModel Function() create;

  /// Couleur du profil de la conversation.
  final ProfileAccents accents;

  /// Suite d'une conversation existante (route `/c/...`), pas un brouillon neuf.
  final bool continuation;

  /// Retour à l'accueil (choix du profil à qui parler).
  final VoidCallback? onHome;

  /// Conversations du profil (feuille du bas), ouvertes depuis la pastille
  /// du nom.
  final void Function(ProfileKey profile)? onHistory;
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
  final _activityExpansion = <Object, bool>{};
  final _detailExpansion = <Object, bool>{};
  final _activityKeys = <Object, GlobalKey>{};
  TimelineProjection? _renderedTimeline;

  /// Éléments du fil déjà affichés : seuls les nouveaux arrivent en fondu.
  final _appeared = <Key>{};
  bool _appearReady = false;
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
    listenable: Listenable.merge([_viewModel, widget.accents]),
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
      final name = profile == null
          ? draft?.profile.value
          : Content.profileName(profile.label, profile.key.value);
      final scaffold = Scaffold(
        appBar: AppBar(
          leading: widget.onHome == null
              ? null
              : Center(
                  child: IconButton.filledTonal(
                    tooltip: Content.home,
                    onPressed: widget.onHome,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
          title: draft == null
              ? Text(
                  widget.continuation
                      ? Content.timelineTitle
                      : Content.newConversation,
                )
              : _profilePill(context, draft, name!),
          actions: [
            if (draft != null &&
                widget.continuation &&
                widget.onNewConversation != null)
              IconButton.filledTonal(
                tooltip: Content.newConversation,
                onPressed: () => widget.onNewConversation!(draft.profile),
                icon: const Icon(Icons.add),
              ),
            const SizedBox(width: Spacing.sm),
          ],
          shape: Border(
            bottom: BorderSide(color: Theme.of(context).colorScheme.line),
          ),
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
                if (draft != null ||
                    (vm.timeline.workState != null &&
                        vm.timeline.workState != WorkState.succeeded))
                  // Défile si la saisie dépasse l'écran (texte 200 %, paysage).
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: vm.showStop || vm.stopStatus != null
                          ? (viewport.maxHeight - Layout.threadMinHeight).clamp(
                              0,
                              viewport.maxHeight,
                            )
                          : viewport.maxHeight * .5,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(Spacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Toujours monté, même pendant la lecture d'un ancien
                          // bloc très éloigné de la fin du fil paresseux. Les
                          // trois points s'effacent dès que Hermes écrit.
                          AnimatedSwitcher(
                            duration: motionDuration(context, Motion.short),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    alignment: Alignment.topCenter,
                                    child: child,
                                  ),
                                ),
                            child: switch (_shownWork(vm)) {
                              final work? => Padding(
                                // Un changement d'état remplace le texte
                                // sans rejouer l'arrivée.
                                key: const ValueKey('work'),
                                padding: const EdgeInsets.only(
                                  bottom: Spacing.sm,
                                ),
                                child: Semantics(
                                  liveRegion: true,
                                  child: WorkStateLabel(
                                    state: work,
                                    localStatus: vm.stopText,
                                  ),
                                ),
                              ),
                              null => const SizedBox.shrink(),
                            },
                          ),
                          if (draft != null)
                            Composer(
                              hint: Content.writeTo(name!),
                              controller: _controller,
                              onChanged: vm.update,
                              onSend: blocked == null ? vm.send : null,
                              stopping: vm.showStop,
                              onStop: vm.canStop ? vm.stop : null,
                              disabledReason: blocked,
                              status: _shownWork(vm) == null
                                  ? vm.statusText
                                  : null,
                            ),
                          if (vm.showStop ||
                              vm.stopStatus != null ||
                              vm.timeline.workState == WorkState.stopped)
                            const Padding(
                              padding: EdgeInsets.only(top: Spacing.xs),
                              child: Text(Content.stopReminder),
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
      return draft == null
          ? scaffold
          : AccentScope(
              accent: widget.accents.of(draft.profile),
              child: scaffold,
            );
    },
  );

  /// État du travail affiché au-dessus de la saisie : rien une fois terminé,
  /// ni pendant que la réponse s'écrit (elle montre déjà que Hermes répond).
  static WorkState? _shownWork(DraftViewModel vm) {
    final work = vm.timeline.workState;
    if (vm.stopText != null) return work ?? WorkState.unknown;
    if (work == WorkState.succeeded && vm.stopStatus != null) return work;
    if (work == WorkState.succeeded) return null;
    if (work == WorkState.running &&
        vm.companionPhase == CompanionPhase.reading) {
      return null;
    }
    return work;
  }

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
      if (draft != null &&
          !widget.continuation &&
          vm.timeline.items.isEmpty &&
          vm.timeline.workState == null)
        _welcome(context, vm, viewport),
    ];
    if (atBottom && (timelineChanged || viewportChanged) && !readingDetails) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (c.hasClients) c.jumpTo(c.position.maxScrollExtent);
      });
    }
    // Au premier affichage, le fil déjà là ne s'anime pas.
    if (!_appearReady) {
      _appeared.addAll(children.map((child) => child.key).nonNulls);
      if (draft != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _appearReady = true,
        );
      }
    }
    return ListView.builder(
      controller: c,
      padding: const EdgeInsets.all(Spacing.md),
      itemCount: children.length,
      itemBuilder: (context, i) {
        final child = children[i];
        final key = child.key;
        if (key == null) return child;
        return Appear(
          key: key,
          animate: _appearReady && _appeared.add(key),
          child: child,
        );
      },
      findChildIndexCallback: (key) {
        final at = children.indexWhere((child) => child.key == key);
        return at < 0 ? null : at;
      },
    );
  }

  /// Pastille d'en-tête : avatar et nom du profil ; ouvre ses conversations.
  /// Région live : le profil de la conversation est annoncé en entier.
  Widget _profilePill(BuildContext context, Draft draft, String name) {
    final scheme = Theme.of(context).colorScheme;
    final open = widget.onHistory == null
        ? null
        : () => widget.onHistory!(draft.profile);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileAvatar(label: name, size: Layout.avatarSmall),
        const SizedBox(width: Spacing.sm),
        Flexible(
          child: ExcludeSemantics(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (open != null) ...[
          const SizedBox(width: Spacing.xs),
          ExcludeSemantics(
            child: Icon(
              Icons.expand_more,
              size: IconSizes.sm,
              color: scheme.muted,
            ),
          ),
        ],
      ],
    );
    return Tooltip(
      message: Content.conversations,
      excludeFromSemantics: true,
      child: MergeSemantics(
        child: Semantics(
          liveRegion: true,
          label: Content.draftProfile(name),
          hint: open == null ? null : Content.openConversationsHint,
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: scheme.card,
              foregroundColor: scheme.content,
              disabledForegroundColor: scheme.content,
              shape: StadiumBorder(side: BorderSide(color: scheme.line)),
              padding: const EdgeInsetsDirectional.only(
                start: Spacing.xs,
                end: Spacing.sm + Spacing.xs,
              ),
            ),
            onPressed: open,
            child: row,
          ),
        ),
      ),
    );
  }

  /// Conversation neuve : avatar du profil, question, suggestions qui
  /// pré-remplissent la saisie sans l'envoyer.
  Widget _welcome(BuildContext context, DraftViewModel vm, Size viewport) {
    final theme = Theme.of(context);
    final profile = vm.profile;
    final name = profile == null
        ? vm.draft!.profile.value
        : Content.profileName(profile.label, profile.key.value);
    return Padding(
      padding: EdgeInsets.only(top: viewport.height * Layout.welcomeTop),
      child: Column(
        children: [
          ProfileAvatar(label: name, size: Layout.avatarWelcome),
          const SizedBox(height: Spacing.md),
          Semantics(
            header: true,
            child: Text(
              Content.greeting,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final text in Content.suggestions)
                ActionChip(
                  label: Text(text),
                  onPressed: () {
                    _controller.text = text;
                    vm.update(text);
                  },
                ),
            ],
          ),
        ],
      ),
    );
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
      // Signaux internes de Hermes (usage, raisonnement…) : rien à montrer.
      if (item is ActivityItem && item.kind == ActivityKind.unknown) continue;
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
        paused: vm.resyncing,
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
        for (final (index, item) in items.indexed) {
          entries.add(
            Padding(
              key: ValueKey(('early', index)),
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: block(item),
            ),
          );
        }
        continue;
      }
      final responses = <Widget>[];
      for (final (index, item) in items.indexed) {
        if (item is UserItem) {
          entries.add(
            Padding(
              key: ValueKey(('user', turn, index)),
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: block(item),
            ),
          );
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
      // ponytail: Otc retiré en attendant sa refonte ; il reprendra sa place
      // en tête des réponses du tour (vm.companionPhase).
      for (final item in responses) {
        entries.add(
          Padding(
            key: item.key,
            padding: const EdgeInsets.only(top: Spacing.sm),
            child: item,
          ),
        );
      }
    }
    return [
      ...entries,
      if (work == WorkState.failed && timeline.errorCode != null) ...[
        const SizedBox(height: Spacing.xs),
        Text(Content.error(timeline.errorCode!)),
      ],
    ];
  }
}
