// Capture manuelle des écrans principaux (refonte 2026-10-23) :
// flutter test test/support/grok_capture.dart --dart-define=OUT=<dossier>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes_mobile/app/routes.dart';
import 'package:hermes_mobile/main.dart';
import 'package:hermes_mobile/models/companion_background.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/history.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/content.dart';

import 'connection_fakes.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/grok-visuals');
const _default = ProfileKey('default');

Future<void> _font(
  String family,
  String path, [
  List<String> more = const [],
]) async {
  final loader = FontLoader(family);
  for (final file in [path, ...more]) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(file).readAsBytesSync())),
    );
  }
  await loader.load();
}

void main() {
  testWidgets('captures de la refonte', (tester) async {
    // Police de l'app, chargée à la main (les tests n'ont que Ahem).
    await _font('Inter', 'assets/fonts/inter-400.ttf', [
      'assets/fonts/inter-500.ttf',
      'assets/fonts/inter-600.ttf',
      'assets/fonts/inter-700.ttf',
    ]);
    await _font('monospace', 'C:/Windows/Fonts/consola.ttf');
    await _font(
      'MaterialIcons',
      'C:/Users/alanc/fvm/versions/3.47.7/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    tester.view.physicalSize = const Size(412 * 2.5, 892 * 2.5);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final dir = Directory(_out)..createSync(recursive: true);
    final boundary = GlobalKey();

    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${dir.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final brightness in [Brightness.dark, Brightness.light]) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      final b = brightness.name;

      // Connexion (aucun serveur enregistré).
      final fresh = Harness();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MainApp(
            gateway: fresh.repository,
            outbox: MemoryOutbox(),
            conversation: MemoryConversation(),
          ),
        ),
      );
      await shot('$b-0-connexion');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));

      // Application connectée.
      final previous = Harness();
      await previous.connect();
      final h = Harness();
      h.store.value = previous.store.value;
      h.secrets.values.addAll(previous.secrets.values);
      final memory = MemoryConversation();
      final connection = h.store.value!.key;
      final now = DateTime.now();
      memory.lists[(connection, _default)] = [
        SessionSummary(
          id: 's1',
          title: 'Script de sauvegarde du NAS',
          startedAt: now,
          messageCount: 4,
        ),
        SessionSummary(
          id: 's2',
          title: 'Recette de pâtes au pesto',
          startedAt: now,
          messageCount: 2,
        ),
        SessionSummary(
          id: 's3',
          title: 'Planifier le voyage à Lisbonne',
          startedAt: now.subtract(const Duration(days: 1)),
          messageCount: 9,
        ),
        SessionSummary(
          id: 's4',
          title: 'Comparer deux forfaits mobiles',
          startedAt: now.subtract(const Duration(days: 3)),
          messageCount: 6,
        ),
        SessionSummary(
          id: 's5',
          title: 'Résumé du livre « Dune »',
          startedAt: now.subtract(const Duration(days: 12)),
          messageCount: 3,
        ),
        SessionSummary(
          id: 's6',
          title: 'Configurer Home Assistant',
          startedAt: now.subtract(const Duration(days: 60)),
          messageCount: 14,
        ),
      ];
      memory.set(
        TimelineKey(connection, _default, 's1'),
        const TimelineProjection(
          turns: 1,
          userTurns: 1,
          items: [
            UserItem(
              1,
              'Écris-moi un script bash qui sauvegarde /data vers le NAS chaque nuit.',
              operation: OperationKey('op'),
            ),
            ActivityItem(
              1,
              ActivityKind.webSearch,
              eventKey: 'a1',
              toolId: 'a1',
              started: true,
              completed: true,
              responseReceived: true,
              details: {
                'name': 'web_search',
                'args': {'query': 'rsync sauvegarde incrémentale NAS'},
              },
            ),
            ActivityItem(
              1,
              ActivityKind.command,
              eventKey: 'a2',
              toolId: 'a2',
              started: true,
              completed: true,
              responseReceived: true,
              details: {
                'name': 'terminal',
                'args': {
                  'command': 'rsync -a --delete /data/ nas:/backup/data/',
                },
              },
            ),
            ResponseItem(
              1,
              'Voici un script simple avec **rsync** :\n\n```bash\n#!/bin/bash\nrsync -a --delete /data/ nas:/backup/data/\n```\n\nAjoute-le ensuite à `crontab -e` :\n\n- `0 3 * * * /usr/local/bin/backup.sh`\n- vérifie les logs le lendemain matin.',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MainApp(
            gateway: h.repository,
            outbox: MemoryOutbox(),
            conversation: memory,
            backgrounds: const DefaultCompanionBackgroundStore(),
          ),
        ),
      );
      await shot('$b-1-accueil');

      final router = GoRouter.of(tester.element(find.byType(Scaffold).last));
      router.go('/?profile=travail');
      await shot('$b-2-nouvelle-conversation');

      router.go(conversationPath(connection, _default, 's1'));
      await shot('$b-3-conversation');
      await tester.tap(find.text(Content.activitySummary(2, 0)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exécution d’une commande'));
      await shot('$b-3b-outils');

      await tester.tap(find.byTooltip(Content.conversations));
      await shot('$b-4-historique');
      await tester.tap(find.byTooltip(Content.profileSettings));
      await shot('$b-5-reglages-profil');
      router.go('/');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(Content.settings));
      await shot('$b-6-profils');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
}
