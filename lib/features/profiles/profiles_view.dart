import 'package:flutter/material.dart';

import '../../models/connection.dart';
import '../../models/profile.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import '../../ui/components/status_label.dart';
import '../../ui/components/section_card.dart';
import '../../ui/components/profile_choice.dart';
import 'profiles_view_model.dart';

class ProfilesView extends StatelessWidget {
  const ProfilesView({
    super.key,
    required this.viewModel,
    required this.onChangeServer,
    this.onPicked,
  });

  /// Ouvert depuis un brouillon neuf : renvoie le profil choisi.
  final ValueChanged<ProfileKey>? onPicked;
  final ProfilesViewModel viewModel;
  final VoidCallback onChangeServer;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final state = viewModel.snapshot;
      final loading =
          state.profilesState == ProfilesState.loading ||
          state.profilesState == ProfilesState.refreshing;
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
                      onPressed: state.busy ? null : onChangeServer,
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
                            onPicked?.call(profile.key);
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
