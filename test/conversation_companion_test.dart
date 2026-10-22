import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/conversation_companion.dart';
import 'package:hermes_mobile/ui/components/rabbit_companion.dart';
import 'package:hermes_mobile/ui/components/work_state_label.dart';
import 'package:hermes_mobile/ui/theme.dart';
import 'package:hermes_mobile/ui/tokens.dart';

RabbitPainter pose(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<RabbitPainter>()
    .single;

void main() {
  testWidgets('échelle non linéaire du corps et regard vers le texte dessous', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(null, Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: _BodyTextScaler()),
          child: const Scaffold(
            body: ConversationCompanion(
              phase: CompanionPhase.reading,
              child: Text('Réponse'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final rabbit = tester.getRect(find.byType(RabbitCompanion));
    final reply = tester.getRect(find.text('Réponse'));
    expect(reply.top, greaterThanOrEqualTo(rabbit.bottom));
    expect(pose(tester).gaze, 0);
    expect(pose(tester).gazeDown, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'poses, statut immédiat pendant chatouilles et aucun terminal différé',
    (tester) async {
      final phase = ValueNotifier(CompanionPhase.neutral);
      final work = ValueNotifier(WorkState.sending);
      addTearDown(phase.dispose);
      addTearDown(work.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: Listenable.merge([phase, work]),
              builder: (_, _) => ConversationCompanion(
                phase: phase.value,
                resting: work.value == WorkState.succeeded,
                child: Semantics(
                  liveRegion: true,
                  child: WorkStateLabel(state: work.value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(pose(tester).gaze, 0);
      expect(pose(tester).concentrating, isFalse);
      phase.value = CompanionPhase.concentrating;
      work.value = WorkState.running;
      await tester.pump();
      expect(pose(tester).concentrating, isTrue);
      await tester.pump(const Duration(seconds: 20));
      expect(pose(tester).gaze, 0);
      expect(tester.binding.transientCallbackCount, 0);
      phase.value = CompanionPhase.reading;
      await tester.pump();
      expect(pose(tester).gaze, 1);
      final textRect = tester.getRect(find.byType(WorkStateLabel));
      await tester.tap(find.byType(RabbitCompanion));
      await tester.pump();
      expect(pose(tester).tickled, isTrue);
      work.value = WorkState.succeeded;
      phase.value = CompanionPhase.neutral;
      await tester.pump();
      expect(find.text('Terminé'), findsOneWidget);
      expect(pose(tester).tickled, isTrue);
      // Une nouvelle génération remplace la fin pendant la réaction locale.
      work.value = WorkState.running;
      phase.value = CompanionPhase.reading;
      await tester.pump();
      await tester.pump(RabbitTokens.tickle);
      await tester.pump(const Duration(milliseconds: 1));
      expect(pose(tester).tickled, isFalse);
      expect(pose(tester).gaze, 1);
      expect(tester.getRect(find.byType(WorkStateLabel)), textRect);
      await tester.pump(const Duration(seconds: 20));
      expect(pose(tester).gaze, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    '320/375, paysage, clavier et 200 % : enveloppe stable par pose',
    (tester) async {
      addTearDown(tester.view.reset);
      for (final brightness in Brightness.values) {
        for (final size in [
          const Size(320, 720),
          const Size(375, 812),
          const Size(812, 375),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          for (final scale in [1.0, 1.5, 2.0]) {
            Rect? previous;
            for (final keyboard in [0.0, 100.0]) {
              for (final phase in CompanionPhase.values) {
                await tester.pumpWidget(
                  MaterialApp(
                    theme: buildTheme(null, brightness),
                    home: MediaQuery(
                      data: MediaQueryData(
                        size: size,
                        textScaler: TextScaler.linear(scale),
                        viewInsets: EdgeInsets.only(bottom: keyboard),
                      ),
                      child: Scaffold(
                        body: SingleChildScrollView(
                          child: ConversationCompanion(
                            phase: phase,
                            child: const Text(
                              'Réponse de Hermes, toujours lisible',
                              key: ValueKey('reply'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pump();
                final rabbit = tester.getRect(find.byType(RabbitCompanion));
                final reply = tester.getRect(
                  find.byKey(const ValueKey('reply')),
                );
                expect(rabbit.size, const Size.square(64));
                expect(rabbit.overlaps(reply), isFalse);
                expect(previous == null || previous == reply, isTrue);
                previous = reply;
                final side = size.width >= 360 && scale < 1.5;
                if (phase == CompanionPhase.reading) {
                  expect(pose(tester).gaze, side ? 1 : 0);
                  expect(pose(tester).gazeDown, side ? 0 : 1);
                }
                expect(
                  side
                      ? reply.left >= rabbit.right
                      : reply.top >= rabbit.bottom,
                  isTrue,
                );
                expect(tester.takeException(), isNull);
              }
            }
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('historique neutre sans interaction ni annonce supplémentaire', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ConversationCompanion(
                current: false,
                phase: CompanionPhase.reading,
                child: Text('Ancien tour'),
              ),
              ConversationCompanion(
                child: WorkStateLabel(state: WorkState.running),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Chatouiller Otc'), findsOneWidget);
    expect(find.byType(RabbitCompanion), findsOneWidget);
    expect(find.bySemanticsLabel('Hermes travaille…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });
}

class _BodyTextScaler extends TextScaler {
  const _BodyTextScaler();
  @override
  double scale(double fontSize) => fontSize * (fontSize < 10 ? 1 : 2);
  @override
  double get textScaleFactor => 1;
}
