import 'package:flutter/material.dart';

import '../../models/connection_gateway.dart';
import '../../models/history.dart';
import '../../models/profile.dart';
import '../../models/timeline.dart';
import '../../ui/components/profile_avatar.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import '../profiles/profile_accents.dart';

/// Accueil (façon messagerie) : on choisit à quel profil parler, chacun avec
/// sa dernière conversation. [onOpen] reçoit la session la plus récente,
/// nulle s'il n'y en a pas encore (nouvelle conversation).
class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.gateway,
    required this.conversation,
    required this.accents,
    required this.onOpen,
    required this.onSettings,
  });
  final ConnectionGateway gateway;
  final ConversationGateway conversation;
  final ProfileAccents accents;
  final void Function(ProfileKey profile, String? session) onOpen;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profiles = gateway.snapshot.profiles;
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Semantics(
          header: true,
          child: Text(
            Content.wordmark,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        actions: [
          IconButton.filledTonal(
            tooltip: Content.settings,
            onPressed: onSettings,
            icon: const Icon(Icons.tune),
          ),
          const SizedBox(width: Spacing.sm),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: accents,
          builder: (context, _) => profiles.isEmpty
              ? Center(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      Content.loadingProfiles,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.muted,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  itemCount: profiles.length,
                  itemBuilder: (context, i) => _ProfileRow(
                    key: ValueKey(profiles[i].key),
                    profile: profiles[i],
                    gateway: gateway,
                    conversation: conversation,
                    accents: accents,
                    onOpen: onOpen,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatefulWidget {
  const _ProfileRow({
    super.key,
    required this.profile,
    required this.gateway,
    required this.conversation,
    required this.accents,
    required this.onOpen,
  });
  final Profile profile;
  final ConnectionGateway gateway;
  final ConversationGateway conversation;
  final ProfileAccents accents;
  final void Function(ProfileKey profile, String? session) onOpen;

  @override
  State<_ProfileRow> createState() => _ProfileRowState();
}

class _ProfileRowState extends State<_ProfileRow> {
  // ponytail: une requête de liste par profil ; un résumé serveur si la liste
  // de profils grandit.
  late final Future<SessionSummary?> _latest = _load();

  Future<SessionSummary?> _load() async {
    final connection = widget.gateway.snapshot.connection?.key;
    if (connection == null) return null;
    final list = await widget.conversation.sessions(
      connection,
      widget.profile.key,
    );
    return list.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = widget.profile;
    final name = Content.profileName(p.label, p.key.value);
    return FutureBuilder<SessionSummary?>(
      future: _latest,
      builder: (context, snap) {
        final latest = snap.data;
        final date = latest?.startedAt;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg - Spacing.xs,
            vertical: Spacing.xs,
          ),
          leading: ProfileAvatar(
            label: name,
            size: Layout.avatar,
            accent: widget.accents.of(p.key),
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            switch (snap.connectionState) {
              ConnectionState.done when latest != null =>
                latest.title ?? latest.preview ?? Content.untitledConversation,
              ConnectionState.done => Content.homeNoConversation,
              _ => Content.historyLoading,
            },
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.muted),
          ),
          trailing: date == null
              ? null
              : Text(
                  Content.homeTime(date, DateTime.now()),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.muted,
                  ),
                ),
          onTap: () => widget.onOpen(p.key, latest?.id),
        );
      },
    );
  }
}
