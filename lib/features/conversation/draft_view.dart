import 'package:flutter/material.dart';

import '../../ui/components/composer.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import 'draft_view_model.dart';

class DraftView extends StatefulWidget {
  const DraftView({
    super.key,
    required this.create,
    required this.onOpenProfiles,
  });

  /// Le ViewModel vit aussi longtemps que la page, pas que le rendu.
  final DraftViewModel Function() create;
  final VoidCallback onOpenProfiles;
  @override
  State<DraftView> createState() => _DraftViewState();
}

class _DraftViewState extends State<DraftView> {
  final _controller = TextEditingController();
  late final _viewModel = widget.create();
  bool _filled = false;
  int _clearTick = 0;

  @override
  void dispose() {
    _viewModel.dispose();
    _controller.dispose();
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
          title: const Text(Content.newConversation),
          actions: [
            TextButton(
              onPressed: widget.onOpenProfiles,
              child: const Text(Content.profilesTitle),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Spacing.md),
            children: [
              if (draft != null)
                Text(
                  Content.draftProfile(
                    profile == null
                        ? draft.profile.value
                        : Content.profileName(profile.label, profile.key.value),
                  ),
                ),
              if (vm.error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    draft == null
                        ? Content.error(vm.error!.code)
                        : '${Content.error(vm.error!.code)} ${Content.draftKept}',
                  ),
                ),
              const SizedBox(height: Spacing.md),
              // Sans brouillon chargé, une saisie écraserait le texte stocké.
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
      );
    },
  );
}
