import 'package:flutter/material.dart';

import 'dart:async';

import 'app/bootstrap.dart';
import 'app/routes.dart';
import 'data/notification_repository.dart';
import 'models/connection.dart';
import 'models/companion_background.dart';
import 'models/connection_gateway.dart';
import 'models/draft.dart';
import 'models/profile_accent.dart';
import 'models/timeline.dart';

import 'ui/content.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final (
      :gateway,
      :outbox,
      :conversation,
      :backgrounds,
      :accents,
      :notifications,
    ) = await bootstrap();
    runApp(
      MainApp(
        gateway: gateway,
        outbox: outbox,
        conversation: conversation,
        backgrounds: backgrounds,
        accents: accents,
        notifications: notifications,
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        theme: buildTheme(null, Brightness.light),
        darkTheme: buildTheme(null, Brightness.dark),
        home: const Scaffold(
          body: SafeArea(child: Center(child: Text(Content.startupError))),
        ),
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    required this.gateway,
    required this.outbox,
    required this.conversation,
    this.backgrounds,
    this.accents,
    this.notifications,
  });
  final ConnectionGateway gateway;
  final CompanionBackgroundStore? backgrounds;

  /// Couleurs des profils ; en mémoire si nul.
  final ProfileAccentStore? accents;
  final OutboxGateway outbox;
  final NotificationRepository? notifications;
  final ConversationGateway conversation;
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  late final AppRoutes _routes;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _routes = AppRoutes(
      widget.gateway,
      widget.outbox,
      widget.conversation,
      backgrounds: widget.backgrounds,
      accents: widget.accents,
      notifications: widget.notifications,
    );
    unawaited(widget.gateway.restore());
    unawaited(widget.notifications?.resume() ?? Future<void>.value());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final backgroundWrites = _routes.profiles.backgroundWritesDone;
    _routes.dispose();
    // L'outbox termine ses écritures avant que le gateway ferme la base.
    unawaited(
      widget.outbox.dispose().whenComplete(
        () => backgroundWrites.whenComplete(
          () => widget.conversation.dispose().whenComplete(() async {
            await widget.notifications?.dispose();
            await widget.gateway.dispose();
          }),
        ),
      ),
    );
    super.dispose();
  }

  /// Retour au premier plan : la socket a pu tomber en arrière-plan, ou rester
  /// à moitié ouverte (elle se dit alors connectée) : un `gateway.ping` court
  /// tranche. La resynchronisation suit la nouvelle socket ; le travail
  /// serveur n'est jamais annulé par l'app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.notifications?.resume() ?? Future<void>.value());
    }
    final gateway = widget.gateway;
    final snapshot = gateway.snapshot;
    if (state != AppLifecycleState.resumed ||
        snapshot.connection == null ||
        !snapshot.authenticated ||
        snapshot.busy) {
      return;
    }
    if (snapshot.link != LinkState.connected) {
      unawaited(gateway.reconnect());
      return;
    }
    unawaited(
      gateway
          .call('gateway.ping', const {}, timeout: pingTimeout)
          .then<void>(
            (_) {},
            onError: (Object _) {
              if (mounted) unawaited(gateway.reconnect());
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Palette fixe de l'app (DESIGN.md) : pas de Dynamic Color.
    return MaterialApp.router(
      title: Content.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(null, Brightness.light),
      darkTheme: buildTheme(null, Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: _routes.router,
    );
  }
}
