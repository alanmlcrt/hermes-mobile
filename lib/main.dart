import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'ui/content.dart';
import 'ui/dynamic_color_bridge.dart';
import 'ui/theme.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp(
        title: Content.appTitle,
        theme: buildTheme(fromDynamicScheme(lightDynamic), Brightness.light),
        darkTheme: buildTheme(fromDynamicScheme(darkDynamic), Brightness.dark),
        themeMode: ThemeMode.system,
        home: const Scaffold(
          body: Center(child: Text(Content.homePlaceholder)),
        ),
      ),
    );
  }
}
