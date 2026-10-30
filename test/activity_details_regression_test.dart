import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/activity_details.dart';
import 'package:hermes_mobile/ui/components/activity_line.dart';
import 'package:hermes_mobile/ui/content.dart';

void main() {
  test(
    'chaîne structurée vide et patch vide : aucun ancien texte de secours',
    () {
      expect(
        ActivityDetails.sections({
          'args': '',
          'args_text': 'anciens arguments',
          'result': ' ',
          'result_text': 'ancienne sortie',
        }),
        isEmpty,
      );
      final initial = ActivityItem(
        1,
        ActivityKind.tool,
        details: ActivityDetailFields.decode({'context': 'ancien contexte'}),
      );
      final updated = initial.copyWith(
        detailPatch: ActivityDetailFields.decode({'context': ''}),
      );
      expect(updated.details['context'], '');
      expect(ActivityDetails.sections(updated.details), isEmpty);
    },
  );

  test('détails reçus, copiés et restaurés : JSON gelé sans alias mutable', () {
    final source = <String, Object?>{
      'list': [1, 2],
    };
    final received = ActivityDetailFields.decode({'args': source});
    (source['list'] as List)[0] = 9;
    expect((received['args'] as Map)['list'], [1, 2]);
    expect(
      () => ((received['args'] as Map)['list'] as List)[0] = 3,
      throwsUnsupportedError,
    );
    final item = ActivityItem(1, ActivityKind.tool, details: received);
    final patch = <String, Object?>{
      'error': 'reçu',
      'nested': <String>['a'],
    };
    final copied = item.copyWith(detailPatch: {'result': patch});
    (patch['nested'] as List).add('b');
    expect((copied.details['result'] as Map)['nested'], ['a']);
    final restored = ActivityItem.fromJson(copied.toJson());
    expect(() => restored.details.clear(), throwsUnsupportedError);
    expect(
      () => (restored.details['result'] as Map).clear(),
      throwsUnsupportedError,
    );
  });

  testWidgets('insertion de section : Sortie conserve son propre défilement', (
    tester,
  ) async {
    final details = <String, Object?>{
      'result': List.generate(60, (i) => 'SORTIE $i'),
    };
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ActivityDetails(details: details);
            },
          ),
        ),
      ),
    );
    Finder output() => find.byWidgetPredicate(
      (w) => w is Text && (w.data?.contains('SORTIE') ?? false),
    );
    ScrollController outputScroll() => tester
        .widget<Scrollbar>(
          find.ancestor(of: output(), matching: find.byType(Scrollbar)).last,
        )
        .controller!;
    final controller = outputScroll();
    controller.jumpTo(200);
    await tester.pump();
    update(() => details['args'] = List.generate(30, (i) => 'ARGUMENT $i'));
    await tester.pump();
    expect(outputScroll(), same(controller));
    expect(outputScroll().offset, 200);
    final arguments = find.byWidgetPredicate(
      (w) => w is Text && (w.data?.contains('ARGUMENT') ?? false),
    );
    final argumentScroll = tester
        .widget<Scrollbar>(
          find.ancestor(of: arguments, matching: find.byType(Scrollbar)).last,
        )
        .controller!;
    expect(argumentScroll.offset, 0);
  });

  testWidgets(
    '320 px et texte 200 % : gestes dans les deux axes et fin visible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ActivityLine(
              kind: ActivityKind.tool,
              expanded: true,
              details: {
                'result': [
                  for (var i = 0; i < 60; i++) 'Ligne $i ${'code ' * 30}',
                  '[truncated]',
                ],
              },
              onChanged: (_) => fail('Le défilement ne doit pas replier'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bars = tester
          .widgetList<Scrollbar>(find.byType(Scrollbar))
          .toList();
      expect(bars.every((b) => b.thumbVisibility == true), isTrue);
      final vertical = bars.first.controller!;
      final horizontal = bars.last.controller!;
      final viewport = tester.getRect(
        find
            .byWidgetPredicate(
              (w) =>
                  w is SingleChildScrollView &&
                  w.scrollDirection == Axis.vertical,
            )
            .first,
      );
      await tester.timedDragFrom(
        viewport.center,
        const Offset(-30000, 0),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      expect(
        horizontal.offset,
        closeTo(horizontal.position.maxScrollExtent, 1),
      );
      await tester.timedDragFrom(
        viewport.center,
        const Offset(0, -10000),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      expect(vertical.offset, closeTo(vertical.position.maxScrollExtent, 1));
      await tester.timedDragFrom(
        viewport.center,
        const Offset(30000, 0),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      final body = find.descendant(
        of: find.byType(SelectionArea),
        matching: find.byType(Text),
      );
      final text = tester.widget<Text>(body).data!;
      final render = tester.renderObject<RenderParagraph>(
        find.descendant(of: body, matching: find.byType(RichText)).first,
      );
      final index = text.indexOf('[truncated]');
      final box = render
          .getBoxesForSelection(
            TextSelection(baseOffset: index, extentOffset: index + 11),
          )
          .first
          .toRect();
      expect(viewport.contains(render.localToGlobal(box.center)), isTrue);
      expect(find.byType(ActivityDetails), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('sélection et copie conservées après ajout d’une section', (
    tester,
  ) async {
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      if (call.method == 'Clipboard.getData') return {'text': copied};
      if (call.method == 'Clipboard.hasStrings') {
        return {'value': copied != null};
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final details = <String, Object?>{'result': 'Texte reçu à copier'};
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ActivityDetails(details: details);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Texte reçu à copier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all').last);
    await tester.pumpAndSettle();
    update(() => details['args'] = 'arguments reçus');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy').last);
    await tester.pumpAndSettle();
    expect(copied, 'Texte reçu à copier');
    expect(find.text(Content.detailArguments), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
