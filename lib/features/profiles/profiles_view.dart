import 'package:flutter/material.dart';

import '../../models/connection.dart';
import '../../models/profile.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import '../../ui/components/status_label.dart';
import '../../ui/components/section_card.dart';
import '../../ui/components/profile_choice.dart';
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
  // ponytail: sans effet tant qu'Otc est retiré de cet écran.
  final bool active;
  @override
  State<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends State<ProfilesView> {
  /// Groupe de réglages : intertitre discret, carte arrondie.
  /// Sans AnimatedSize : à durée nulle il se redessine pendant sa mise en page.
  Widget _group(BuildContext context, String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Spacing.md, bottom: Spacing.sm),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
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
      final note = Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
      return Scaffold(
        appBar: AppBar(title: const Text(Content.profilesTitle)),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: viewModel.refresh,
            child: ListView(
              padding: const EdgeInsets.all(Spacing.md),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _group(context, Content.serverSection, [
                  StatusLabel(icon: icon, label: label),
                  const SizedBox(height: Spacing.xs),
                  Text(state.connection?.origin.toString() ?? '', style: note),
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
                  if (state.error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(Content.error(state.error!.code)),
                    ),
                ]),
                const SizedBox(height: Spacing.md),
                _group(context, Content.profilesSection, [
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
                  for (final profile in state.profiles)
                    ProfileChoice(
                      profile: profile,
                      selected: state.selectedProfile == profile.key,
                      onTap: state.busy
                          ? null
                          : () async {
                              await viewModel.select(profile.key);
                              // Un seul retour, et seulement si le choix
                              // est enregistré.
                              if (!context.mounted ||
                                  ModalRoute.of(context)?.isCurrent != true ||
                                  viewModel.snapshot.selectedProfile !=
                                      profile.key) {
                                return;
                              }
                              widget.onPicked?.call(profile.key);
                            },
                    ),
                  const SizedBox(height: Spacing.sm),
                  Text(Content.localSelection, style: note),
                ]),
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
