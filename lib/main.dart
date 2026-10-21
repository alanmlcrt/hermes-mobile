import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'dart:async';

import 'app/bootstrap.dart';
import 'app/routes.dart';
import 'models/connection_gateway.dart';

import 'ui/content.dart';
import 'ui/dynamic_color_bridge.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final gateway = await bootstrap();
    runApp(MainApp(gateway: gateway));
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
  const MainApp({super.key, required this.gateway});
  final ConnectionGateway gateway;
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final AppRoutes _routes;
  @override
  void initState() {
    super.initState();
    _routes = AppRoutes(widget.gateway);
    unawaited(widget.gateway.restore());
  }

  @override
  void dispose() {
    _routes.dispose();
    unawaited(widget.gateway.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp.router(
        title: Content.appTitle,
        theme: buildTheme(fromDynamicScheme(lightDynamic), Brightness.light),
        darkTheme: buildTheme(fromDynamicScheme(darkDynamic), Brightness.dark),
        themeMode: ThemeMode.system,
        routerConfig: _routes.router,
      ),
    );
  }
}
