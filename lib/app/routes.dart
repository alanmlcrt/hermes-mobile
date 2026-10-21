import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/connection/connection_view.dart';
import '../features/connection/connection_view_model.dart';
import '../features/profiles/profiles_view.dart';
import '../features/profiles/profiles_view_model.dart';
import '../models/connection_gateway.dart';

class AppRoutes {
  AppRoutes(ConnectionGateway gateway) {
    connection = ConnectionViewModel(gateway);
    profiles = ProfilesViewModel(gateway);
    router = GoRouter(
      refreshListenable: profiles,
      redirect: (context, state) => state.uri.scheme == 'hermes-mobile'
          ? Uri(
              path: '/pair',
              queryParameters: {'link': state.uri.toString()},
            ).toString()
          : null,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ListenableBuilder(
            listenable: profiles,
            builder: (context, _) => gateway.snapshot.authenticated
                ? ProfilesView(
                    viewModel: profiles,
                    onChangeServer: () {
                      connection.edit();
                      context.go('/pair');
                    },
                  )
                : _connection(context),
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
  }
  late final ConnectionViewModel connection;
  late final ProfilesViewModel profiles;
  late final GoRouter router;
  Widget _connection(BuildContext context, {String? link}) => ConnectionView(
    viewModel: connection,
    incomingLink: link,
    onAuthenticated: () => context.go('/'),
  );
  void dispose() {
    router.dispose();
    connection.dispose();
    profiles.dispose();
  }
}
