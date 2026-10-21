import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/connection/connection_view.dart';
import '../features/connection/connection_view_model.dart';
import '../features/conversation/continuation_view.dart';
import '../features/conversation/draft_view.dart';
import '../features/conversation/draft_view_model.dart';
import '../features/history/history_view.dart';
import '../features/history/history_view_model.dart';
import '../features/profiles/profiles_view.dart';
import '../features/profiles/profiles_view_model.dart';
import '../models/connection.dart';
import '../models/connection_gateway.dart';
import '../models/draft.dart';
import '../models/profile.dart';
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

String historyPath(ProfileKey profile) =>
    '/history/${Uri.encodeComponent(profile.value)}';

class _Refresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

class AppRoutes {
  AppRoutes(
    ConnectionGateway gateway,
    OutboxGateway outbox,
    ConversationGateway conversation,
  ) {
    connection = ConnectionViewModel(gateway);
    profiles = ProfilesViewModel(gateway);
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
        if (path == '/') {
          return resolveLaunchTarget(
            gateway,
            outbox,
            requestedProfile: state.uri.queryParameters['profile'],
          );
        }
        // Perte d'authentification : retour à l'écran de connexion.
        if (!gateway.snapshot.authenticated &&
            (path == '/profiles' ||
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
            builder: (context, _) => gateway.snapshot.authenticated
                ? _profiles(context)
                : _connection(context),
          ),
        ),
        GoRoute(
          path: '/profiles',
          builder: (context, state) =>
              _profiles(context, pick: state.extra == true),
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
            onOpenProfiles: (pick) =>
                context.push<ProfileKey>('/profiles', extra: pick),
            onOpenHistory: (p) => context.push(historyPath(p)),
          ),
        ),
        GoRoute(
          path: '/history/:profile',
          builder: (context, state) => HistoryView(
            key: ValueKey(state.pathParameters['profile']),
            create: () => HistoryViewModel(
              gateway: gateway,
              conversation: conversation,
              profile: ProfileKey(state.pathParameters['profile']!),
            ),
            onOpen: (session) {
              final connection = gateway.snapshot.connection;
              if (connection == null) return;
              context.push(
                conversationPath(
                  connection.key,
                  ProfileKey(state.pathParameters['profile']!),
                  session,
                ),
              );
            },
            onNewConversation: (p) => context.go(
              Uri(path: '/', queryParameters: {'profile': p.value}).toString(),
            ),
          ),
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
              onOpenProfiles: (pick) =>
                  context.push<ProfileKey>('/profiles', extra: pick),
              onOpenHistory: (p) => context.push(historyPath(p)),
              onNewConversation: (p) => context.go(
                Uri(path: '/', queryParameters: {'profile': p.value}).toString(),
              ),
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
      authenticated = now;
      _refresh.ping();
    };
    profiles.addListener(_onProfiles);
  }
  late final ConnectionViewModel connection;
  late final ProfilesViewModel profiles;
  final _refresh = _Refresh();
  late final VoidCallback _onProfiles;
  late final GoRouter router;
  Widget _profiles(BuildContext context, {bool pick = false}) => ProfilesView(
    viewModel: profiles,
    onPicked: pick ? (key) => context.pop(key) : null,
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
    _refresh.dispose();
  }
}
