import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/connection/connection_view.dart';
import '../features/connection/connection_view_model.dart';
import '../features/conversation/continuation_view.dart';
import '../features/conversation/draft_view.dart';
import '../features/conversation/draft_view_model.dart';
import '../features/history/history_view.dart';
import '../features/history/history_view_model.dart';
import '../features/home/home_view.dart';
import '../features/profiles/profile_accents.dart';
import '../features/profiles/profile_settings_view.dart';
import '../features/profiles/profiles_view.dart';
import '../features/profiles/profiles_view_model.dart';
import '../models/connection.dart';
import '../models/companion_background.dart';
import '../models/connection_gateway.dart';
import '../models/draft.dart';
import '../models/profile.dart';
import '../models/profile_accent.dart';
import '../models/timeline.dart';

/// Seul décideur de l'écran d'ouverture : notification (Epic 5), puis
/// restauration (story 2.4), puis accueil. Seul l'accueil existe : nouvelle
/// conversation sur le profil courant ; sans profil, `null` laisse le choix.
///
/// [requestedProfile] : « Nouvelle conversation » depuis l'historique d'un
/// profil ; ignoré s'il n'existe pas sur ce serveur.
Future<String?> resolveLaunchTarget(
  ConnectionGateway gateway,
  OutboxGateway outbox, {
  String? requestedProfile,
}) async {
  final snapshot = gateway.snapshot;
  final connection = snapshot.connection;
  final requested = snapshot.profiles
      .where((p) => p.key.value == requestedProfile)
      .firstOrNull;
  final profile =
      requested?.key ?? snapshot.selectedProfile ?? connection?.selectedProfile;
  if (!snapshot.authenticated || connection == null || profile == null) {
    return null;
  }
  try {
    final draft = await outbox.openNewDraft(connection.key, profile);
    return '/draft/${draft.key.value}';
  } catch (_) {
    return null;
  }
}

/// Route d'une conversation existante ; chaque identifiant est encodé tel quel
/// (opaque, sensible à la casse).
String conversationPath(
  ConnectionKey connection,
  ProfileKey profile,
  String session,
) =>
    '/c/${Uri.encodeComponent(connection.value)}/'
    '${Uri.encodeComponent(profile.value)}/${Uri.encodeComponent(session)}';

/// Conversations d'un profil (feuille du bas) ; [current] y est surlignée.
String historyPath(ProfileKey profile, {String? current}) => Uri(
  path: '/history/${Uri.encodeComponent(profile.value)}',
  queryParameters: current == null ? null : {'current': current},
).toString();

String profileSettingsPath(ProfileKey profile) =>
    '/profile/${Uri.encodeComponent(profile.value)}';

/// Page présentée en feuille du bas, au-dessus de la page qui l'a ouverte.
class _SheetPage<T> extends Page<T> {
  const _SheetPage({super.key, required this.child});
  final Widget child;
  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
    settings: this,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => child,
  );
}

class _Refresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

class AppRoutes {
  AppRoutes(
    ConnectionGateway gateway,
    OutboxGateway outbox,
    ConversationGateway conversation, {
    CompanionBackgroundStore? backgrounds,
    ProfileAccentStore? accents,
  }) {
    connection = ConnectionViewModel(gateway);
    this.accents = ProfileAccents(gateway, accents);
    profiles = ProfilesViewModel(gateway, backgrounds: backgrounds);
    router = GoRouter(
      refreshListenable: _refresh,
      redirect: (context, state) {
        if (state.uri.scheme == 'hermes-mobile') {
          return Uri(
            path: '/pair',
            queryParameters: {'link': state.uri.toString()},
          ).toString();
        }
        final path = state.uri.path;
        if (path == '/' &&
            (state.uri.queryParameters.containsKey('profile') ||
                _noProfiles(gateway.snapshot))) {
          return resolveLaunchTarget(
            gateway,
            outbox,
            requestedProfile: state.uri.queryParameters['profile'],
          );
        }
        // Perte d'authentification : retour à l'écran de connexion.
        if (!gateway.snapshot.authenticated &&
            (path == '/profiles' ||
                path.startsWith('/profile/') ||
                path.startsWith('/draft/') ||
                path.startsWith('/history/') ||
                path.startsWith('/c/'))) {
          return '/';
        }
        // Une conversation d'une autre connexion n'est jamais ouverte.
        try {
          // `pathSegments` est déjà décodé.
          final segments = state.uri.pathSegments;
          if (segments.length > 1 &&
              segments.first == 'c' &&
              segments[1] != gateway.snapshot.connection?.key.value) {
            return '/';
          }
        } catch (_) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ListenableBuilder(
            listenable: profiles,
            builder: (context, _) => !gateway.snapshot.authenticated
                ? _connection(context)
                : _noProfiles(gateway.snapshot)
                ? _profiles(context)
                : HomeView(
                    gateway: gateway,
                    conversation: conversation,
                    accents: this.accents,
                    onOpen: (profile, session) {
                      final connection = gateway.snapshot.connection;
                      context.go(
                        session == null || connection == null
                            ? _newConversation(profile)
                            : conversationPath(
                                connection.key,
                                profile,
                                session,
                              ),
                      );
                    },
                    onSettings: () => context.push('/profiles'),
                  ),
          ),
        ),
        GoRoute(
          path: '/profiles',
          builder: (context, state) => _profiles(context),
        ),
        GoRoute(
          path: '/profile/:profile',
          builder: (context, state) => ProfileSettingsView(
            key: ValueKey(state.pathParameters['profile']),
            gateway: gateway,
            accents: this.accents,
            profile: ProfileKey(state.pathParameters['profile']!),
            onChangeServer: () {
              connection.edit();
              context.go('/pair');
            },
            onAllProfiles: () => context.push('/profiles'),
          ),
        ),
        GoRoute(
          path: '/draft/:draftKey',
          builder: (context, state) => DraftView(
            // Clé par brouillon : un autre brouillon ne réutilise pas l'état de la page.
            key: ValueKey(state.pathParameters['draftKey']),
            create: () => DraftViewModel(
              outbox: outbox,
              gateway: gateway,
              conversation: conversation,
              key: DraftKey(state.pathParameters['draftKey']!),
            ),
            accents: this.accents,
            onHome: () => context.go('/'),
            onHistory: (p) => context.push(historyPath(p)),
          ),
        ),
        GoRoute(
          path: '/history/:profile',
          pageBuilder: (context, state) {
            final profile = ProfileKey(state.pathParameters['profile']!);
            final current = state.uri.queryParameters['current'];
            return _SheetPage(
              key: state.pageKey,
              child: HistoryView(
                key: ValueKey(state.pathParameters['profile']),
                create: () => HistoryViewModel(
                  gateway: gateway,
                  conversation: conversation,
                  profile: profile,
                ),
                accents: this.accents,
                current: current,
                onOpen: (session) {
                  final connection = gateway.snapshot.connection;
                  if (connection == null) return;
                  if (session == current) {
                    context.pop();
                    return;
                  }
                  context.go(
                    conversationPath(connection.key, profile, session),
                  );
                },
                onNewConversation: (p) => context.go(_newConversation(p)),
                onSettings: (p) => context.push(profileSettingsPath(p)),
              ),
            );
          },
        ),
        GoRoute(
          path: '/c/:connection/:profile/:session',
          builder: (context, state) {
            final profile = ProfileKey(state.pathParameters['profile']!);
            final session = state.pathParameters['session']!;
            return ContinuationView(
              key: ValueKey(state.uri.path),
              outbox: outbox,
              connection: ConnectionKey(state.pathParameters['connection']!),
              profile: profile,
              session: session,
              createViewModel: (key) => DraftViewModel(
                outbox: outbox,
                gateway: gateway,
                conversation: conversation,
                key: key,
              ),
              accents: this.accents,
              onHome: () => context.go('/'),
              onHistory: (p) => context.push(historyPath(p, current: session)),
              onNewConversation: (p) => context.go(_newConversation(p)),
            );
          },
        ),
        GoRoute(
          path: '/pair',
          builder: (context, state) =>
              _connection(context, link: state.uri.queryParameters['link']),
        ),
      ],
      errorBuilder: (context, state) =>
          _connection(context, link: state.uri.toString()),
    );
    // Hors accueil, seule une perte d'authentification relance les
    // redirections : une notification de profils rejouerait l'écran « Mes
    // profils » après son retour au brouillon.
    var authenticated = gateway.snapshot.authenticated;
    _onProfiles = () {
      final now = gateway.snapshot.authenticated;
      final home = router.routeInformationProvider.value.uri.path == '/';
      if (now == authenticated && !home) return;
      final lost = authenticated && !now;
      authenticated = now;
      // Une page empilée (« Mes profils », réglages) ne survit pas à la perte
      // d'authentification : retour à la racine, qui affiche la connexion.
      if (lost && router.canPop()) {
        router.go('/');
        return;
      }
      _refresh.ping();
    };
    profiles.addListener(_onProfiles);
  }
  late final ConnectionViewModel connection;
  late final ProfilesViewModel profiles;
  late final ProfileAccents accents;
  final _refresh = _Refresh();
  late final VoidCallback _onProfiles;
  late final GoRouter router;

  /// Aucun profil connu une fois la liste reçue (vide ou en échec). Pendant
  /// son chargement, l'accueil s'affiche et attend : le lancement ne saute
  /// pas directement dans une conversation.
  static bool _noProfiles(ConnectionSnapshot snapshot) =>
      snapshot.profiles.isEmpty &&
      snapshot.profilesState != ProfilesState.initial &&
      snapshot.profilesState != ProfilesState.loading &&
      snapshot.profilesState != ProfilesState.refreshing;
  static String _newConversation(ProfileKey profile) =>
      Uri(path: '/', queryParameters: {'profile': profile.value}).toString();
  Widget _profiles(BuildContext context) => ProfilesView(
    viewModel: profiles,
    onChangeServer: () {
      connection.edit();
      context.go('/pair');
    },
  );
  Widget _connection(BuildContext context, {String? link}) => ConnectionView(
    viewModel: connection,
    incomingLink: link,
    onAuthenticated: () => context.go('/'),
  );
  void dispose() {
    router.dispose();
    connection.dispose();
    profiles.removeListener(_onProfiles);
    profiles.dispose();
    accents.dispose();
    _refresh.dispose();
  }
}
