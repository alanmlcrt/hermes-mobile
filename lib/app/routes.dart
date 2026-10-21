import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/connection/connection_view.dart';
import '../features/connection/connection_view_model.dart';
import '../features/conversation/draft_view.dart';
import '../features/conversation/draft_view_model.dart';
import '../features/profiles/profiles_view.dart';
import '../features/profiles/profiles_view_model.dart';
import '../models/connection_gateway.dart';
import '../models/draft.dart';
import '../models/profile.dart';
import '../models/timeline.dart';

/// Seul décideur de l'écran d'ouverture : notification (Epic 5), puis
/// restauration (story 2.4), puis accueil. Seul l'accueil existe : nouvelle
/// conversation sur le profil courant ; sans profil, `null` laisse le choix.
Future<String?> resolveLaunchTarget(
  ConnectionGateway gateway,
  OutboxGateway outbox,
) async {
  final snapshot = gateway.snapshot;
  final connection = snapshot.connection;
  final profile = snapshot.selectedProfile ?? connection?.selectedProfile;
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
        if (path == '/') return resolveLaunchTarget(gateway, outbox);
        // Perte d'authentification : retour à l'écran de connexion.
        if (!gateway.snapshot.authenticated &&
            (path == '/profiles' || path.startsWith('/draft/'))) {
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
            create: () => DraftViewModel(
              outbox: outbox,
              gateway: gateway,
              conversation: conversation,
              key: DraftKey(state.pathParameters['draftKey']!),
            ),
            onOpenProfiles: (pick) =>
                context.push<ProfileKey>('/profiles', extra: pick),
          ),
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
