import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/history.dart';
import '../../models/profile.dart';
import '../../models/room.dart';
import '../../ui/components/history_row.dart';
import '../../ui/components/profile_avatar.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import '../profiles/profile_accents.dart';
import 'rooms_view_model.dart';

class RoomsView extends StatefulWidget {
  const RoomsView({
    super.key,
    required this.create,
    required this.accents,
    required this.onOpen,
    this.profiles = const [],
  });
  final RoomsViewModel Function() create;
  final ProfileAccents accents;
  final ValueChanged<RoomSummary> onOpen;
  final List<Profile> profiles;
  @override
  State<RoomsView> createState() => _RoomsViewState();
}

class _RoomsViewState extends State<RoomsView> with WidgetsBindingObserver {
  late final vm = widget.create();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(vm.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    vm.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      vm.foreground(state == AppLifecycleState.resumed);

  Future<void> _create() async {
    await vm.prepareCreate();
    if (!mounted) return;
    final controller = TextEditingController(text: vm.name);
    final result = await showDialog<RoomSummary>(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: vm,
        builder: (context, _) => AlertDialog(
          scrollable: true,
          title: const Text(Content.newRoom),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                enabled: !vm.creating && !vm.creationUncertain,
                decoration: const InputDecoration(labelText: Content.roomName),
                onChanged: vm.setName,
              ),
              const Text(Content.roomMemberLimit),
              for (final p in widget.profiles)
                CheckboxListTile(
                  title: Text(Content.profileName(p.label, p.key.value)),
                  subtitle: vm.eligible.contains(p.key)
                      ? null
                      : const Text(Content.roomIneligible),
                  value: vm.selected.contains(p.key),
                  onChanged:
                      vm.eligible.contains(p.key) &&
                          !vm.creating &&
                          !vm.creationUncertain
                      ? (v) => vm.select(p.key, v == true)
                      : null,
                ),
              if (vm.createError != null)
                Semantics(
                  liveRegion: true,
                  child: Text(Content.roomError(vm.createError!)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: vm.creating
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text(Content.roomCancel),
            ),
            if (vm.creationUncertain)
              TextButton(
                onPressed: () async {
                  final room = await vm.verifyCreation();
                  if (dialogContext.mounted && room != null) {
                    Navigator.pop(dialogContext, room);
                  }
                },
                child: const Text(Content.roomVerify),
              ),
            FilledButton(
              onPressed: vm.canCreate
                  ? () async {
                      final room = await vm.create();
                      if (dialogContext.mounted && room != null) {
                        Navigator.pop(dialogContext, room);
                      }
                    }
                  : null,
              child: const Text(Content.roomCreate),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (result != null && mounted) {
      vm.name = '';
      vm.selected.clear();
      vm.creationId = vm.repository.newId();
      widget.onOpen(result);
      unawaited(vm.refresh());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(Content.rooms)),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            if (vm.canOfferCreate)
              TextButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text(Content.newRoom),
              ),
            if (vm.loading) const Text(Content.roomsLoading),
            if (vm.error == null && vm.creationProblem != null) ...[
              Text(Content.roomError(vm.creationProblem!)),
              if (vm.diagnostic != null)
                SelectableText(Content.roomCapabilityDetails(vm.diagnostic!)),
              TextButton(
                onPressed: vm.refresh,
                child: const Text(Content.retryList),
              ),
            ],
            if (vm.error != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(Content.roomError(vm.error!)),
              ),
              if (vm.diagnostic != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  child: SelectableText(
                    Content.roomCapabilityDetails(vm.diagnostic!),
                  ),
                ),
              TextButton(
                onPressed: vm.refresh,
                child: const Text(Content.retryList),
              ),
            ] else if (!vm.loading && vm.rooms.isEmpty)
              const Text(Content.roomsEmpty),
            for (final room in vm.rooms) ...[
              HistoryRow(
                session: SessionSummary(
                  id: room.id,
                  title: room.name,
                  preview: room.preview,
                  startedAt: room.updatedAt,
                ),
                onTap: () => widget.onOpen(room),
                notice: room.needsUser
                    ? Content.roomNeedsUser
                    : room.working
                    ? Content.roomWorking
                    : null,
              ),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.xs,
                children: [
                  for (final member in room.members)
                    Semantics(
                      label: member.name,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ProfileAvatar(
                            label: member.name,
                            size: IconSizes.lg,
                            accent: widget.accents.of(member.profile),
                          ),
                          const SizedBox(width: Spacing.xs),
                          Flexible(child: Text(member.name)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
