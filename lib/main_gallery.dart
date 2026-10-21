// Point d'entrée de développement : `fvm flutter run -t lib/main_gallery.dart`.
// N'est pas importé par lib/main.dart, donc absent de l'APK release.
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'ui/content.dart';
import 'ui/dynamic_color_bridge.dart';
import 'ui/gallery.dart';
import 'ui/theme.dart';

void main() {
  runApp(const GalleryApp());
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final light = fromDynamicScheme(lightDynamic);
        final dark = fromDynamicScheme(darkDynamic);
        return MaterialApp(
          title: GalleryContent.title,
          theme: buildTheme(light, Brightness.light),
          darkTheme: buildTheme(dark, Brightness.dark),
          themeMode: ThemeMode.system,
          home: ComponentGallery(lightScheme: light, darkScheme: dark),
        );
      },
    );
  }
}
