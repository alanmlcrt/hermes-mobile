import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/room.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vm.addListener(_changed);
    unawaited(vm.open());
  }

  void _changed() {
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
    _text.dispose();
    super.dispose();
  }

  Widget _entry(RoomEntry entry) {
    final member = vm.snapshot?.room.members
        .where((m) => m.id == entry.member || m.profile.value == entry.member)
        .firstOrNull;
    return Padding(
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
            MessageBubble(text: entry.text, fromUser: entry.fromUser),
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(vm.snapshot?.room.name ?? Content.rooms),
        actions: [
          IconButton(
            tooltip: Content.roomRefresh,
            onPressed: vm.loading ? null : vm.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Spacing.md),
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
                  for (final entry in vm.snapshot?.entries ?? <RoomEntry>[])
                    _entry(entry),
                  for (final send in vm.sends)
                    if (send.state != 'confirmed')
                      Text(Content.roomSendStatus(send.state)),
                ],
              ),
            ),
            Flexible(
              flex: Layout.roomComposerFlex,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Spacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(Content.roomMentionHelp),
                    if (vm.text.contains('@'))
                      Wrap(
                        spacing: Spacing.xs,
                        children: [
                          for (final mention in vm.mentions)
                            ActionChip(
                              label: Text('@$mention'),
                              onPressed: () {
                                final at = _text.selection.isValid
                                    ? _text.selection.baseOffset
                                    : vm.text.length;
                                final start = vm.text.lastIndexOf(
                                  '@',
                                  at > 0 ? at - 1 : 0,
                                );
                                if (start >= 0) {
                                  vm.edit(
                                    '${vm.text.substring(0, start)}@$mention ${vm.text.substring(at)}',
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    Composer(
                      controller: _text,
                      onChanged: vm.edit,
                      onSend: vm.canSend ? vm.send : null,
                      disabledReason: vm.available.contains(RoomFeature.send)
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
}
