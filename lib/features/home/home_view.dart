import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/connection_gateway.dart';
import '../../models/history.dart';
import '../../models/profile.dart';
import '../../models/timeline.dart';
import '../../ui/components/appear.dart';
import '../../ui/components/profile_avatar.dart';
import '../../ui/content.dart';
import '../../ui/theme.dart';
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
    this.onProfileSettings,
    this.onRooms,
  });
  final ConnectionGateway gateway;
  final ConversationGateway conversation;
  final ProfileAccents accents;
  final void Function(ProfileKey profile, String? session) onOpen;
  final VoidCallback onSettings;
  final ValueChanged<ProfileKey>? onProfileSettings;
  final VoidCallback? onRooms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profiles = gateway.snapshot.profiles;
    return Scaffold(
      bottomNavigationBar: onRooms == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                Spacing.md,
                0,
                Spacing.md,
                Spacing.sm,
              ),
              child: Appear(
                animate: true,
                index: profiles.length + 1,
                child: PressScale(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(Layout.touchTarget),
                    ),
                    onPressed: onRooms,
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text(Content.rooms),
                  ),
                ),
              ),
            ),
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
          IconButton(
            tooltip: Content.settings,
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.card,
              side: BorderSide(color: theme.colorScheme.line),
            ),
            onPressed: onSettings,
            icon: const Icon(Icons.tune, size: IconSizes.sm),
          ),
          const SizedBox(width: Spacing.sm),
        ],
        shape: Border(bottom: BorderSide(color: theme.colorScheme.line)),
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
                  // Entrée en cascade à chaque arrivée sur l'accueil.
                  itemBuilder: (context, i) => Appear(
                    key: ValueKey(profiles[i].key),
                    animate: true,
                    index: i,
                    child: _ProfileRow(
                      profile: profiles[i],
                      gateway: gateway,
                      conversation: conversation,
                      accents: accents,
                      onOpen: onOpen,
                      onProfileSettings: onProfileSettings,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatefulWidget {
  const _ProfileRow({
    required this.profile,
    required this.gateway,
    required this.conversation,
    required this.accents,
    required this.onOpen,
    this.onProfileSettings,
  });
  final Profile profile;
  final ConnectionGateway gateway;
  final ConversationGateway conversation;
  final ProfileAccents accents;
  final void Function(ProfileKey profile, String? session) onOpen;
  final ValueChanged<ProfileKey>? onProfileSettings;

  @override
  State<_ProfileRow> createState() => _ProfileRowState();
}

class _ProfileRowState extends State<_ProfileRow> {
  static final _cachedLatest = <(String, String), SessionSummary?>{};

  // ponytail: une requête de liste par profil ; un résumé serveur si la liste
  // de profils grandit.
  Future<SessionSummary?>? _latest;

  /// L'accueil reste monté sous une conversation empilée : chaque retour au
  /// premier plan relit la dernière conversation ; caché, rien n'est chargé.
  bool _current = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (current && !_current) _latest = _load();
    _current = current;
  }

  /// La dernière conversation est non lue (7.3) ; relu à chaque fin de tour.
  bool _unread = false;
  StreamSubscription<TimelineKey>? _changes;

  @override
  void initState() {
    super.initState();
    _changes = widget.conversation.changes.listen((key) {
      if (key.profile == widget.profile.key) unawaited(_readMarker());
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  Future<SessionSummary?> _load() async {
    final connection = widget.gateway.snapshot.connection?.key;
    if (connection == null) return null;
    final list = await widget.conversation.sessions(
      connection,
      widget.profile.key,
    );
    _session = list.firstOrNull?.id;
    _cachedLatest[(connection.value, widget.profile.key.value)] =
        list.firstOrNull;
    await _readMarker();
    return list.firstOrNull;
  }

  String? _session;

  Future<void> _readMarker() async {
    final connection = widget.gateway.snapshot.connection?.key;
    final session = _session;
    if (connection == null || session == null) return;
    try {
      final marks = await widget.conversation.markers(
        connection,
        widget.profile.key,
      );
      final unread = marks[session]?.unread ?? false;
      if (mounted && unread != _unread) setState(() => _unread = unread);
    } catch (_) {
      /* Marqueur illisible : la ligne reste sans repère. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = widget.profile;
    final name = Content.profileName(p.label, p.key.value);
    final connection = widget.gateway.snapshot.connection?.key;
    final cacheKey = connection == null
        ? null
        : (connection.value, p.key.value);
    final hasCached = cacheKey != null && _cachedLatest.containsKey(cacheKey);
    return FutureBuilder<SessionSummary?>(
      future: _latest,
      initialData: cacheKey == null ? null : _cachedLatest[cacheKey],
      builder: (context, snap) {
        final latest = snap.data;
        final done = snap.connectionState == ConnectionState.done || hasCached;
        final date = latest?.startedAt;
        return PressScale(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg - Spacing.xs,
              vertical: Spacing.xs,
            ),
            leading: IconButton(
              tooltip: Content.profileSettings,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: Layout.touchTarget,
                minHeight: Layout.touchTarget,
              ),
              onPressed: widget.onProfileSettings == null
                  ? null
                  : () => widget.onProfileSettings!(p.key),
              icon: ProfileAvatar(
                label: name,
                size: Layout.avatar,
                accent: widget.accents.of(p.key),
                heroTag: ('avatar', p.key),
              ),
            ),
            title: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            // Fondu croisé du « chargement » vers le dernier message.
            subtitle: AnimatedSwitcher(
              duration: motionDuration(context, Motion.medium),
              switchInCurve: Motion.enter,
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [...previous, ?current],
              ),
              child: Text(
                key: ValueKey((done, latest?.id, _unread)),
                done
                    ? (latest != null
                          ? (latest.title ??
                                latest.preview ??
                                Content.untitledConversation)
                          : Content.homeNoConversation)
                    : Content.historyLoading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _unread ? scheme.content : scheme.muted,
                  fontWeight: _unread ? FontWeight.w700 : null,
                ),
              ),
            ),
            // Texte « Non lu » en plus du gras : jamais la couleur seule.
            trailing: date == null && !_unread
                ? null
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (date != null)
                        Text(
                          Content.homeTime(date, DateTime.now()),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.muted,
                          ),
                        ),
                      if (_unread)
                        Appear(
                          animate: true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ExcludeSemantics(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const SizedBox.square(
                                    dimension: Layout.unreadDot,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Spacing.xs),
                              Text(
                                Content.unread,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
            onTap: () => widget.onOpen(p.key, latest?.id),
          ),
        );
      },
    );
  }
}
