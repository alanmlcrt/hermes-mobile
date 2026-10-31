import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/room.dart';
import '../../models/timeline.dart';
import '../../ui/components/approval_card.dart';
import '../../ui/components/activity_line.dart';
import '../../ui/components/composer.dart';
import '../../ui/components/message_bubble.dart';
import '../../ui/components/profile_avatar.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import '../profiles/profile_accents.dart';
import 'room_view_model.dart';

class RoomView extends StatefulWidget {
  const RoomView({super.key, required this.create, required this.accents});
  final RoomViewModel Function() create;
  final ProfileAccents accents;
  @override
  State<RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<RoomView> with WidgetsBindingObserver {
  late final vm = widget.create();
  final _text = TextEditingController();
  final _attention = GlobalKey();
  bool _focusedAttention = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _text.addListener(_caretChanged);
    vm.addListener(_changed);
    unawaited(vm.open());
  }

  void _caretChanged() {
    if (mounted) setState(() {});
  }

  TextRange? get _activeMention {
    final value = _text.value;
    if (!value.selection.isValid || !value.selection.isCollapsed) return null;
    final at = value.selection.baseOffset;
    final before = value.text.substring(0, at);
    if (!RegExp(r'(^|[\s(])@([A-Za-z0-9._:-]*)$').hasMatch(before)) return null;
    final start = before.lastIndexOf('@');
    final tail = RegExp(r'^[A-Za-z0-9._:-]*')
        .firstMatch(value.text.substring(at))!;
    return TextRange(start: start, end: at + tail.group(0)!.length);
  }

  void _insertMention(RoomMention mention, TextRange range) {
    final current = _text.text;
    if (range.end > current.length) return;
    final end = range.end < current.length && current[range.end] == ' '
        ? range.end + 1
        : range.end;
    final inserted = '@${mention.token} ';
    final next = current.replaceRange(range.start, end, inserted);
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: range.start + inserted.length),
    );
    vm.edit(next);
  }

  Future<void> _help() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text(Content.roomMentionsTitle),
      content: const Text(Content.roomMentionHelp),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(Content.roomHelpClose),
        ),
      ],
    ),
  );

  void _changed() {
    if (!_focusedAttention &&
        (vm.snapshot?.entries.any((e) => e.needsUser) == true ||
            vm.approvals.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _attention.currentContext;
        if (!mounted || target == null) return;
        _focusedAttention = true;
        unawaited(Scrollable.ensureVisible(target));
      });
    }
    if (_text.text != vm.text) {
      _text.value = TextEditingValue(
        text: vm.text,
        selection: TextSelection.collapsed(offset: vm.text.length),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      vm.foreground(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    vm.removeListener(_changed);
    vm.dispose();
    _text.removeListener(_caretChanged);
    _text.dispose();
    super.dispose();
  }

  Widget _entry(RoomEntry entry) {
    final member = vm.snapshot?.room.members
        .where((m) => m.id == entry.member || m.profile.value == entry.member)
        .firstOrNull;
    return Padding(
      key:
          entry.id ==
              vm.snapshot?.entries.where((e) => e.needsUser).lastOrNull?.id
          ? _attention
          : null,
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!entry.fromUser)
            Wrap(
              spacing: Spacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (member != null)
                  ProfileAvatar(
                    label: member.name,
                    size: IconSizes.lg,
                    accent: widget.accents.of(member.profile),
                  ),
                Text(member?.name ?? entry.member),
              ],
            ),
          if (entry.needsUser) const Text(Content.roomNeedsUser),
          if (entry.activity != null)
            ActivityLine(
              kind: entry.activity!,
              completed: entry.completed,
              details: entry.details,
            )
          else
            MessageBubble(
              text: vm.displayText(entry),
              fromUser: entry.fromUser,
            ),
        ],
      ),
    );
  }

  Future<void> _discard(RoomTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Content.roomDiscard),
        content: const Text(Content.roomDiscardConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Content.roomCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(Content.roomDiscard),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await vm.taskAction(task, discard: true);
  }

  Widget _task(RoomTask task) {
    final member = vm.snapshot?.room.members
        .where((m) => m.id == task.member)
        .firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Content.roomTaskStatus(
                member?.name ?? task.member,
                task.failed,
                task.reason,
              ),
            ),
            Wrap(
              spacing: Spacing.sm,
              children: [
                if (task.failed &&
                    task.retryable &&
                    vm.available.contains(RoomFeature.retry))
                  TextButton(
                    onPressed: vm.busy
                        ? null
                        : () => vm.taskAction(task, discard: false),
                    child: const Text(Content.retryList),
                  ),
                if (task.canDiscard &&
                    vm.available.contains(RoomFeature.discard))
                  TextButton(
                    onPressed: vm.busy ? null : () => _discard(task),
                    child: const Text(Content.roomDiscard),
                  ),
              ],
            ),
            if (!task.failed && !task.canDiscard)
              const Text(Content.roomTaskContextMissing),
          ],
        ),
      ),
    );
  }

  Widget _approval(RoomApproval a) {
    final member = vm.snapshot?.room.members
        .where((m) => m.id == a.member)
        .firstOrNull;
    final decision = vm.decisions[a.commandKey];
    final hasMessageAttention =
        vm.snapshot?.entries.any((e) => e.needsUser) == true;
    return Column(
      key:
          !hasMessageAttention &&
              a.commandKey == vm.approvals.lastOrNull?.commandKey
          ? _attention
          : null,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(member?.name ?? a.member),
        if (!a.actionable) const Text(Content.roomApprovalContextMissing),
        ApprovalCard(
          description: a.description,
          command: a.command,
          state: decision?.state ?? QuestionState.open,
          blocked: decision?.blocked,
          canDecide:
              a.actionable &&
              !vm.busy &&
              vm.interventions != null &&
              vm.available.contains(RoomFeature.approve),
          onDecide: (choice) => vm.decide(a, choice),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final range = _activeMention;
      final query = range == null
          ? ''
          : _text.text
                .substring(range.start + 1, _text.selection.baseOffset)
                .toLowerCase();
      final suggestions = range == null
          ? const <RoomMention>[]
          : vm.mentions
                .where(
                  (m) =>
                      m.label.toLowerCase().contains(query) ||
                      m.token.toLowerCase().startsWith(query),
                )
                .toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(vm.snapshot?.room.name ?? Content.rooms),
          actions: [
            IconButton(
              tooltip: Content.roomMentionsTitle,
              onPressed: _help,
              icon: const Icon(Icons.alternate_email),
            ),
            IconButton(
              tooltip: Content.roomRefresh,
              onPressed: vm.loading ? null : vm.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) => Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(Spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (vm.snapshot == null && vm.loading)
                          const Text(Content.roomsLoading),
                        if (vm.error != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(Content.roomError(vm.error!)),
                          ),
                        if (vm.snapshot?.working == true)
                          const Text(Content.roomWorking),
                        if (vm.stopState != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(Content.roomStopStatus(vm.stopState!)),
                          ),
                        if (vm.snapshot?.working == true &&
                            vm.available.contains(RoomFeature.stop))
                          TextButton.icon(
                            onPressed: vm.busy ? null : vm.stop,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text(Content.roomStop),
                          ),
                        for (final task in vm.snapshot?.tasks ?? <RoomTask>[])
                          _task(task),
                        if (vm.snapshot?.waiting == true)
                          const Text(Content.roomWaiting),
                        for (final entry
                            in vm.snapshot?.entries ?? <RoomEntry>[])
                          _entry(entry),
                        for (final a in vm.approvals) _approval(a),
                        for (final send in vm.sends)
                          if (send.state != 'confirmed')
                            Text(Content.roomSendStatus(send.state)),
                      ],
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        viewport.maxHeight *
                        (viewport.maxHeight < Layout.roomCompactViewport
                            ? Layout.roomComposerShortFraction
                            : Layout.roomComposerMaxFraction),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(Spacing.sm),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (suggestions.isNotEmpty)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final mention in suggestions)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: Spacing.xs,
                                    ),
                                    child: ActionChip(
                                      label: Text(
                                        Content.roomMentionLabel(mention.label),
                                      ),
                                      onPressed: () =>
                                          _insertMention(mention, range!),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        Composer(
                          compact: true,
                          hint: Content.roomComposerLabel,
                          maxLines:
                              viewport.maxHeight < Layout.roomCompactViewport
                              ? ComposerLines.roomShort
                              : ComposerLines.room,
                          controller: _text,
                          onChanged: vm.edit,
                          onSend: vm.canSend ? vm.send : null,
                          disabledReason:
                              vm.available.contains(RoomFeature.send)
                              ? null
                              : Content.roomSendUnavailable,
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
}
