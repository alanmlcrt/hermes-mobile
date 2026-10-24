// Démo manuelle : images successives d'un envoi dans le chat (Otc concentré,
// activités, lecture, repos). Assembler ensuite en GIF.
// flutter test test/support/chat_demo_capture.dart --dart-define=OUT=<dossier>
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

import 'connection_fakes.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/chat-demo');
const _default = ProfileKey('default');
const _question = 'Quel temps fera-t-il demain à Lisbonne ?';
const _answer =
    'Demain à **Lisbonne** : grand soleil le matin, quelques nuages '
    'l’après-midi.\n\n- Températures : 17 °C à 24 °C\n- Vent faible du nord\n\n'
    'Parfait pour visiter Belém !';

Future<void> _font(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await loader.load();
}

void main() {
  testWidgets('démo envoi chat', (tester) async {
    await _font('Roboto', 'C:/Windows/Fonts/segoeui.ttf');
    await _font('monospace', 'C:/Windows/Fonts/consola.ttf');
    await _font(
      'MaterialIcons',
      'C:/Users/alanc/fvm/versions/3.47.7/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    tester.view.physicalSize = const Size(412 * 2, 892 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    final dir = Directory(_out)..createSync(recursive: true);
    final boundary = GlobalKey();
    var frame = 0;

    // [ms] de temps simulé entre deux images, [count] images.
    Future<void> film(int count, {int ms = 80}) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(Duration(milliseconds: ms));
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${dir.path}/f${(frame++).toString().padLeft(4, '0')}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }

    final previous = Harness();
    await previous.connect();
    final h = Harness();
    h.store.value = previous.store.value;
    h.secrets.values.addAll(previous.secrets.values);
    final memory = MemoryConversation();
    final connection = h.store.value!.key;
    final key = TimelineKey(connection, _default, 's1');
    memory.lists[(connection, _default)] = [
      SessionSummary(
        id: 's1',
        title: 'Voyage à Lisbonne',
        startedAt: DateTime.now(),
        messageCount: 2,
      ),
    ];
    const user = UserItem(1, _question, operation: OperationKey('op'));
    memory.set(key, const TimelineProjection());
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
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).last))
        .go(conversationPath(connection, _default, 's1'));
    await tester.pumpAndSettle();
    await film(6);

    // Saisie progressive.
    final field = find.byType(TextField);
    for (var i = 4; i <= _question.length; i += 4) {
      await tester.enterText(field, _question.substring(0, i));
      await film(1);
    }
    await tester.enterText(field, _question);
    await film(6);
    await tester.enterText(field, '');

    // Envoi accepté puis Otc se concentre pendant les activités.
    TimelineProjection at(
      List<TimelineItem> items,
      WorkState work,
      CompanionPhase phase,
    ) => TimelineProjection(
      items: items,
      workState: work,
      companionPhase: phase,
      turns: 1,
      userTurns: 1,
    );
    memory.set(
      key,
      at([user], WorkState.sending, CompanionPhase.concentrating),
    );
    await film(8);
    const search = ActivityItem(
      1,
      ActivityKind.webSearch,
      eventKey: 'a1',
      started: true,
    );
    memory.set(
      key,
      at([user, search], WorkState.running, CompanionPhase.concentrating),
    );
    await film(18);
    const browse = ActivityItem(
      1,
      ActivityKind.webBrowse,
      eventKey: 'a2',
      started: true,
    );
    const searched = ActivityItem(
      1,
      ActivityKind.webSearch,
      eventKey: 'a1',
      started: true,
      completed: true,
    );
    memory.set(
      key,
      at(
        [user, searched, browse],
        WorkState.running,
        CompanionPhase.concentrating,
      ),
    );
    await film(18);
    const browsed = ActivityItem(
      1,
      ActivityKind.webBrowse,
      eventKey: 'a2',
      started: true,
      completed: true,
      responseReceived: true,
    );

    // La réponse arrive par fragments : Otc lit.
    for (var i = 6; i <= _answer.length; i += 6) {
      memory.set(
        key,
        at(
          [user, searched, browsed, ResponseItem(1, _answer.substring(0, i))],
          WorkState.running,
          CompanionPhase.reading,
        ),
      );
      await film(1);
    }
    memory.set(
      key,
      at(
        [user, searched, browsed, const ResponseItem(1, _answer)],
        WorkState.succeeded,
        CompanionPhase.neutral,
      ),
    );
    await film(30);
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
