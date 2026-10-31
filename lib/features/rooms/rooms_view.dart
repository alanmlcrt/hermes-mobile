import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/history.dart';
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
  });
  final RoomsViewModel Function() create;
  final ProfileAccents accents;
  final ValueChanged<RoomSummary> onOpen;
  @override
  State<RoomsView> createState() => _RoomsViewState();
}

class _RoomsViewState extends State<RoomsView> {
  late final vm = widget.create();
  @override
  void initState() {
    super.initState();
    unawaited(vm.refresh());
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
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
            if (vm.loading) const Text(Content.roomsLoading),
            if (vm.error != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(Content.roomError(vm.error!)),
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
                notice: room.working ? Content.roomWorking : null,
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
