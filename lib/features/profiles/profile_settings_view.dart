import 'package:flutter/material.dart';

import '../../models/connection_gateway.dart';
import '../../models/profile.dart';
import '../../models/profile_accent.dart';
import '../../ui/components/profile_avatar.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import 'profile_accents.dart';
import '../../models/notifications.dart';
import '../../ui/components/notification_settings.dart';

/// Réglages d'un profil, ouverts depuis ses conversations : nom repris de
/// Hermes (jamais modifiable ici), couleur, identifiant et connexion.
class ProfileSettingsView extends StatelessWidget {
  const ProfileSettingsView({
    super.key,
    required this.gateway,
    required this.accents,
    required this.profile,
    required this.onChangeServer,
    required this.onAllProfiles,
    this.notifications,
  });
  final ConnectionGateway gateway;
  final ProfileAccents accents;
  final ProfileKey profile;
  final VoidCallback onChangeServer;
  final VoidCallback onAllProfiles;
  final NotificationClient? notifications;

  Future<void> _choose(BuildContext context, ProfileAccent accent) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await accents.choose(profile, accent);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text(Content.profileColorFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: accents,
    builder: (context, _) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final snapshot = gateway.snapshot;
      final label = snapshot.profiles
          .where((p) => p.key == profile)
          .firstOrNull
          ?.label;
      final name = label == null
          ? profile.value
          : Content.profileName(label, profile.value);
      final selected = accents.of(profile);
      final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.muted);
      return AccentScope(
        accent: selected,
        child: Scaffold(
          appBar: AppBar(title: const Text(Content.profileSettings)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(Spacing.md),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                      vertical: Spacing.lg,
                    ),
                    child: Column(
                      children: [
                        ProfileAvatar(label: name, size: Layout.avatarLarge),
                        const SizedBox(height: Spacing.md),
                        Semantics(
                          header: true,
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(Content.nameFromHermes, style: muted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                if (notifications != null)
                  NotificationSettings(device: notifications!),
                _Section(
                  icon: Icons.palette_outlined,
                  title: Content.appearance,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Content.profileColor,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(Content.profileColorHint, style: muted),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                      ),
                      child: Wrap(
                        children: [
                          for (final accent in ProfileAccent.values)
                            _Swatch(
                              accent: accent,
                              selected: accent == selected,
                              onTap: () => _choose(context, accent),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                _Section(
                  icon: Icons.person_outline,
                  title: Content.profileSection,
                  children: [
                    ListTile(
                      title: const Text(Content.identifier),
                      trailing: Text(profile.value, style: muted),
                    ),
                    const Divider(indent: Spacing.md, endIndent: Spacing.md),
                    ListTile(
                      title: const Text(Content.connectionRow),
                      subtitle: Text(
                        snapshot.connection?.origin.toString() ?? '',
                      ),
                      trailing: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: scheme.chip,
                          minimumSize: const Size.square(Layout.headerButton),
                        ),
                        onPressed: snapshot.busy ? null : onChangeServer,
                        child: const Text(Content.change),
                      ),
                    ),
                    const Divider(indent: Spacing.md, endIndent: Spacing.md),
                    ListTile(
                      title: const Text(Content.allProfiles),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: onAllProfiles,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Carte de réglages : intertitre discret avec icône à la couleur du profil.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(icon, size: IconSizes.sm, color: scheme.accent),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Semantics(
                    header: true,
                    child: Text(
                      title.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Pastille de couleur : cible de [Layout.swatch], disque de
/// [Layout.swatchDot], anneau quand elle est choisie.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });
  final ProfileAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AccentTokens.of(accent);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: Content.accentName(accent.id),
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: Layout.swatch / 2,
        child: SizedBox.square(
          dimension: Layout.swatch,
          child: Center(
            child: Container(
              width: Layout.swatchDot,
              height: Layout.swatchDot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: selected
                    // Anneau de la couleur, séparé du disque par la carte.
                    ? [
                        BoxShadow(
                          color: color,
                          spreadRadius:
                              Layout.swatchSelected + Layout.swatchSelected,
                        ),
                        BoxShadow(
                          color: scheme.card,
                          spreadRadius: Layout.swatchSelected,
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: IconSizes.sm,
                      color: AccentTokens.onAccent,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
