import 'package:flutter/material.dart';

import '../../models/connection.dart';
import '../../models/profile.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import '../../ui/components/status_label.dart';
import '../../ui/components/section_card.dart';
import '../../ui/components/profile_choice.dart';
import '../../ui/components/profile_companion_panel.dart';
import '../../ui/components/companion_background_editor.dart';
import 'profiles_view_model.dart';

class ProfilesView extends StatefulWidget {
  const ProfilesView({
    super.key,
    required this.viewModel,
    required this.onChangeServer,
    this.onPicked,
    this.active = true,
  });

  /// Ouvert depuis un brouillon neuf : renvoie le profil choisi.
  final ValueChanged<ProfileKey>? onPicked;
  final ProfilesViewModel viewModel;
  final VoidCallback onChangeServer;

  /// À désactiver si la surface est conservée dans une sous-vue masquée.
  final bool active;
  @override
  State<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends State<ProfilesView> {
  (String, ConnectionKey, ProfileKey)? _verifiedSelection;
  bool _editingBackground = false;

  Future<void> _editBackground() async {
    if (_editingBackground) return;
    final vm = widget.viewModel;
    final identity = vm.backgroundIdentity;
    if (identity == null || vm.backgroundLoading || vm.backgroundError) return;
    _editingBackground = true;
    final navigator = Navigator.of(context);
    final route = MaterialPageRoute<void>(
      builder: (_) => CompanionBackgroundEditor(
        initialPalette: vm.palette,
        onApply: (palette) => vm.saveBackground(identity, palette),
      ),
    );
    void identityChanged() {
      if (vm.backgroundIdentity != identity && route.isActive) {
        navigator.removeRoute(route);
      }
    }

    vm.addListener(identityChanged);
    try {
      await navigator.push(route);
    } finally {
      _editingBackground = false;
      vm.removeListener(identityChanged);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final viewModel = widget.viewModel;
      final state = viewModel.snapshot;
      final loading =
          state.profilesState == ProfilesState.loading ||
          state.profilesState == ProfilesState.refreshing;
      final selected = state.selectedProfile;
      final identity = state.connection != null && selected != null
          ? (
              parseOrigin(state.connection!.origin.toString()).toString(),
              state.connection!.key,
              selected,
            )
          : null;
      final present = state.profiles.any((profile) => profile.key == selected);
      final knownSelection =
          selected != null &&
          state.connection != null &&
          (present || (loading && _verifiedSelection == identity));
      _verifiedSelection = knownSelection ? identity : null;
      final (icon, label) = switch (state.link) {
        LinkState.connected => (
          Icons.cloud_done_outlined,
          ConnectionLabels.connected,
        ),
        LinkState.resyncing => (Icons.sync, ConnectionLabels.resyncing),
        LinkState.offline => (
          Icons.cloud_off_outlined,
          ConnectionLabels.offline,
        ),
      };
      return Scaffold(
        appBar: AppBar(title: const Text(Content.profilesTitle)),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: viewModel.refresh,
            child: ListView(
              padding: const EdgeInsets.all(Spacing.md),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (knownSelection) ...[
                  ProfileCompanionPanel(
                    key: ValueKey(identity),
                    active: widget.active,
                    palette: viewModel.palette,
                    backgroundLoading: viewModel.backgroundLoading,
                    backgroundError: viewModel.backgroundError,
                    onRetryBackground: viewModel.loadBackground,
                    onBackground: _editBackground,
                  ),
                  const SizedBox(height: Spacing.md),
                ],
                StatusLabel(icon: icon, label: label),
                const SizedBox(height: Spacing.md),
                Text(state.connection?.origin.toString() ?? ''),
                const SizedBox(height: Spacing.md),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: loading || state.busy
                          ? null
                          : viewModel.refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text(Content.refresh),
                    ),
                    if (state.link != LinkState.connected)
                      OutlinedButton(
                        onPressed: state.busy ? null : viewModel.reconnect,
                        child: const Text(Content.retry),
                      ),
                    TextButton(
                      onPressed: state.busy ? null : widget.onChangeServer,
                      child: const Text(Content.changeServer),
                    ),
                  ],
                ),
                if (loading)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      state.profilesState == ProfilesState.refreshing
                          ? Content.refreshingProfiles
                          : Content.loadingProfiles,
                    ),
                  ),
                if (state.profilesState == ProfilesState.empty)
                  const Text(Content.emptyProfiles),
                if (state.profilesState == ProfilesState.error)
                  const Text(Content.profilesError),
                if (state.error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(Content.error(state.error!.code)),
                  ),
                const SizedBox(height: Spacing.md),
                for (final profile in state.profiles)
                  ProfileChoice(
                    profile: profile,
                    selected: state.selectedProfile == profile.key,
                    onTap: state.busy
                        ? null
                        : () async {
                            await viewModel.select(profile.key);
                            // Un seul retour, et seulement si le choix est
                            // enregistré.
                            if (!context.mounted ||
                                ModalRoute.of(context)?.isCurrent != true ||
                                viewModel.snapshot.selectedProfile !=
                                    profile.key) {
                              return;
                            }
                            widget.onPicked?.call(profile.key);
                          },
                  ),
                const Text(Content.localSelection),
                const SizedBox(height: Spacing.lg),
                SectionCard(
                  title: Content.capabilitiesTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final capability in state.capabilities)
                        if (capability.state != CapabilityState.present)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: Spacing.xs,
                            ),
                            child: Text(
                              '${Content.capability(capability.name)} : '
                              '${capability.state == CapabilityState.absent ? Content.missing : Content.unverified}',
                            ),
                          ),
                      if (state.acceptanceOpen)
                        const Text(Content.acceptanceOpen),
                    ],
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
