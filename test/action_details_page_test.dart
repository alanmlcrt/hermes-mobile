import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/features/profiles/profile_accents.dart';
import 'package:hermes_mobile/features/conversation/draft_view.dart';
import 'package:hermes_mobile/features/conversation/draft_view_model.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/activity_line.dart';
import 'package:hermes_mobile/ui/components/activity_details.dart';
import 'package:hermes_mobile/ui/content.dart';

import 'support/connection_fakes.dart';
import 'support/details_capture.dart' as scenarios;

const _key = TimelineKey(
  ConnectionKey('details'),
  ProfileKey('default'),
  'session',
);

TimelineProjection projection(List<TimelineItem> items) => TimelineProjection(
  turns: 1,
  userTurns: 1,
  workState: WorkState.running,
  items: items,
);

Future<MemoryConversation> page(
  WidgetTester tester,
  TimelineProjection initial, {
  ValueNotifier<double>? insets,
}) async {
  tester.view.physicalSize = const Size(375, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final memory = MemoryConversation()..projections[_key] = initial;
  final outbox = MemoryOutbox();
  final draft = await outbox.openContinuation(
    _key.connection,
    _key.profile,
    _key.session,
  );
  final harness = Harness();
  addTearDown(() => unawaited(harness.repository.dispose()));
  final keyboard = insets ?? ValueNotifier(0.0);
  if (insets == null) addTearDown(keyboard.dispose);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => ValueListenableBuilder<double>(
        valueListenable: keyboard,
        builder: (context, bottom, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            viewInsets: EdgeInsets.only(bottom: bottom),
          ),
          child: child!,
        ),
      ),
      home: DraftView(
        create: () => DraftViewModel(
          outbox: outbox,
          gateway: harness.repository,
          conversation: memory,
          key: draft.key,
        ),
        accents: ProfileAccents(harness.repository),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return memory;
}

Finder action(String name) => find.byWidgetPredicate(
  (w) => w is ActivityLine && w.details['name'] == name,
);
Finder command(String name) =>
    find.descendant(of: action(name), matching: find.byType(TextButton));
ScrollPosition outer(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void main() {
  // Les assertions de la matrice de capture s’exécutent aussi en CI, sans polices locales.
  scenarios.main();

  testWidgets(
    'détail : pas de saut local, focus conservé en devenant groupe et à l’enrichissement',
    (tester) async {
      const first = ActivityItem(
        1,
        ActivityKind.tool,
        eventKey: 'A',
        toolId: 'A',
        details: {
          'name': 'A',
          'args': ['début', 'suite'],
        },
      );
      const second = ActivityItem(
        1,
        ActivityKind.tool,
        eventKey: 'B',
        toolId: 'B',
        details: {'name': 'B'},
      );
      final memory = await page(tester, projection([first]));
      final position = outer(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final focus = Focus.of(
        tester.element(
          find.descendant(
            of: command('A'),
            matching: find.text(Content.activityTool),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      final before = position.pixels;
      final heading = tester.getTopLeft(command('A'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(before, 0.1));
      expect(tester.getTopLeft(command('A')), heading);
      memory.set(_key, projection([first, second]));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(tester.widget<ActivityLine>(action('A')).expanded, isTrue);
      final beforeResult = position.pixels;
      memory.set(
        _key,
        projection([
          first.copyWith(
            detailPatch: {'result': List.generate(80, (i) => 'Ligne $i')},
          ),
          second,
        ]),
      );
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(position.pixels, closeTo(beforeResult, 0.1));
      expect(find.byType(ActivityDetails), findsOneWidget);
    },
  );

  testWidgets(
    'clavier et nouveaux fragments : ancrage en bas conservé hors consultation',
    (tester) async {
      final keyboard = ValueNotifier(0.0);
      addTearDown(keyboard.dispose);
      final text = List.generate(80, (i) => 'Ligne $i').join('\n\n');
      final memory = await page(
        tester,
        projection([ResponseItem(1, text)]),
        insets: keyboard,
      );
      expect(outer(tester).extentAfter, closeTo(0, 0.1));
      keyboard.value = 220;
      await tester.pumpAndSettle();
      expect(outer(tester).extentAfter, closeTo(0, 0.1));
      memory.set(
        _key,
        projection([ResponseItem(1, '$text\n\nNouveau fragment')]),
      );
      await tester.pumpAndSettle();
      expect(outer(tester).extentAfter, closeTo(0, 0.1));
    },
  );

  testWidgets(
    'deux détails indépendants, retour après éviction et consultation refermée avant réponse',
    (tester) async {
      const first = ActivityItem(
        1,
        ActivityKind.tool,
        eventKey: 'A',
        details: {'name': 'A', 'args': 'a'},
      );
      const second = ActivityItem(
        1,
        ActivityKind.tool,
        eventKey: 'B',
        details: {'name': 'B', 'args': 'b'},
      );
      final history = ResponseItem(
        1,
        List.filled(100, 'Historique').join('\n\n'),
      );
      final memory = await page(tester, projection([history, first, second]));
      await tester.ensureVisible(command('A'));
      await tester.pumpAndSettle();
      await tester.tap(command('A'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        command('B'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(command('B'));
      await tester.pumpAndSettle();
      await tester.tap(command('B'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(command('A'));
      await tester.pumpAndSettle();
      await tester.tap(command('A'));
      await tester.pumpAndSettle();
      expect(tester.widget<ActivityLine>(action('A')).expanded, isFalse);
      expect(tester.widget<ActivityLine>(action('B')).expanded, isTrue);
      outer(tester).jumpTo(0);
      await tester.pumpAndSettle();
      expect(action('A'), findsNothing);
      outer(tester).jumpTo(outer(tester).maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.widget<ActivityLine>(action('A')).expanded, isFalse);
      expect(tester.widget<ActivityLine>(action('B')).expanded, isTrue);
      await tester.ensureVisible(command('B'));
      await tester.tap(command('B'));
      await tester.pumpAndSettle();
      memory.set(
        _key,
        projection([
          history,
          first.copyWith(responseReceived: true),
          second.copyWith(responseReceived: true),
          const ResponseItem(1, 'Premier fragment'),
        ]),
      );
      await tester.pumpAndSettle();
      expect(action('A'), findsOneWidget);
      expect(action('B'), findsOneWidget);
      expect(find.byType(ActivityDetails), findsNothing);
    },
  );
}
