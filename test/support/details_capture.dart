// Vérification synthétique de DraftView ; captures locales optionnelles.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/features/conversation/draft_view.dart';
import 'package:hermes_mobile/features/conversation/draft_view_model.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/activity_group.dart';
import 'package:hermes_mobile/ui/components/activity_line.dart';
import 'package:hermes_mobile/ui/components/activity_details.dart';
import 'package:hermes_mobile/ui/components/work_state_label.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';

import 'connection_fakes.dart';

void main() {
  testWidgets(
    'DraftView : détails, focus, mises à jour, groupe, matrice et captures',
    (tester) async {
      const captures = bool.fromEnvironment('DETAIL_CAPTURES');
      if (captures) {
        for (final entry in {
          'ActivityCapture': 'C:/Windows/Fonts/segoeui.ttf',
          'monospace': 'C:/Windows/Fonts/consola.ttf',
          'MaterialIcons': 'C:/Users/alanc/fvm/versions/3.47.7/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        }.entries) {
          await (FontLoader(entry.key)..addFont(
                Future.value(
                  ByteData.sublistView(File(entry.value).readAsBytesSync()),
                ),
              ))
              .load();
        }
      }
      final semantics = tester.ensureSemantics();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final directory = Directory(
        '_bmad-output/implementation-artifacts/story-3-2-verification/captures',
      );
      if (captures) directory.createSync(recursive: true);
      for (final brightness in Brightness.values) {
        for (final size in [
          const Size(320, 900),
          const Size(375, 900),
          const Size(812, 375),
        ]) {
          tester.view.physicalSize = size;
          for (final keyboard in [false, true]) {
            final outbox = MemoryOutbox();
            final conversation = MemoryConversation();
            final h = Harness();
            final draft = await outbox.openContinuation(
              const ConnectionKey('capture'),
              const ProfileKey('default'),
              'synthetic-session',
            );
            final key = TimelineKey(
              draft.connection,
              draft.profile,
              draft.storedSessionId!,
            );
            const first = ActivityItem(
              1,
              ActivityKind.tool,
              toolId: 'A',
              eventKey: 'stable-a',
              started: true,
              details: {
                'name': 'SYNTHETIC',
                'args': {'dry_run': false, 'limit': 0},
              },
            );
            const second = ActivityItem(
              1,
              ActivityKind.tool,
              toolId: 'B',
              eventKey: 'stable-b',
              started: true,
              details: {'context': 'Champ partiel reçu'},
            );
            TimelineProjection projection({bool complete = false}) =>
                TimelineProjection(
                  turns: 1,
                  userTurns: 1,
                  workState: WorkState.running,
                  items: [
                    UserItem(
                      1,
                      'Demande synthétique',
                      operation: const OperationKey('synthetic'),
                    ),
                    first.copyWith(
                      completed: complete,
                      responseReceived: complete,
                      detailPatch: complete
                          ? {
                              'result': {
                                'error': 'Erreur reçue',
                                'output': [
                                  ...List.generate(
                                    40,
                                    (i) => 'Ligne $i : ${'contenu reçu ' * 5}',
                                  ),
                                  '[truncated]',
                                ].join('\n'),
                              },
                              'inline_diff': '- avant\n+ après',
                            }
                          : null,
                    ),
                    second,
                    if (complete)
                      const ResponseItem(1, 'Premier fragment reçu'),
                  ],
                );
            conversation.projections[key] = projection();
            final boundary = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                theme: buildTheme(null, brightness).copyWith(
                  textTheme: buildTheme(
                    null,
                    brightness,
                  ).textTheme.apply(fontFamily: 'ActivityCapture'),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: const TextScaler.linear(2),
                    viewInsets: EdgeInsets.only(
                      bottom: keyboard ? size.height / 4 : 0,
                    ),
                  ),
                  child: RepaintBoundary(key: boundary, child: child!),
                ),
                home: DraftView(
                  create: () => DraftViewModel(
                    outbox: outbox,
                    gateway: h.repository,
                    conversation: conversation,
                    key: draft.key,
                  ),
                  onOpenProfiles: (_) async => null,
                ),
              ),
            );
            await tester.pumpAndSettle();
            Finder command() => find.descendant(
              of: find.byWidgetPredicate(
                (w) => w is ActivityLine && w.details['name'] == 'SYNTHETIC',
              ),
              matching: find.byType(TextButton),
            );
            await tester.ensureVisible(command());
            final focus = Focus.of(
              tester.element(
                find.descendant(
                  of: command(),
                  matching: find.text(Content.activityTool),
                ),
              ),
            );
            focus.requestFocus();
            await tester.pump();
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(find.byType(ActivityDetails), findsOneWidget);
            final loads = conversation.loaded.length;
            conversation.set(key, projection(complete: true));
            await tester.pumpAndSettle();
            expect(focus.hasFocus, isTrue);
            expect(find.byType(WorkStateLabel), findsOneWidget);
            conversation.set(key, projection(complete: true));
            await tester.pumpAndSettle();
            expect(focus.hasFocus, isTrue);
            expect(find.byType(ActivityDetails), findsOneWidget);
            expect(find.text(Content.detailOutput), findsOneWidget);
            expect(
              tester
                  .getSemantics(
                    find.bySemanticsLabel(
                      '${Content.activityTool}, ${Content.activityEndAccessible}',
                    ),
                  )
                  .flagsCollection
                  .isExpanded,
              ui.Tristate.isTrue,
            );
            await tester.ensureVisible(command());
            await tester.pumpAndSettle();
            if (captures) {
              await tester.runAsync(() async {
                final picture =
                    await (boundary.currentContext!.findRenderObject()!
                            as RenderRepaintBoundary)
                        .toImage();
                final bytes = await picture.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '${directory.path}/draft-${brightness.name}-${size.width.toInt()}-200-${keyboard ? 'keyboard' : 'no-keyboard'}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                picture.dispose();
              });
            }
            final output = find.byWidgetPredicate(
              (w) => w is Text && (w.data?.contains('[truncated]') ?? false),
            );
            await Scrollable.ensureVisible(
              tester.element(output),
              alignment: 0,
            );
            await tester.pumpAndSettle();
            final horizontal = tester.state<ScrollableState>(
              find.descendant(
                of: find
                    .ancestor(
                      of: output,
                      matching: find.byWidgetPredicate(
                        (w) =>
                            w is SingleChildScrollView &&
                            w.scrollDirection == Axis.horizontal,
                      ),
                    )
                    .first,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.right,
                ),
              ),
            );
            expect(horizontal.position.maxScrollExtent, greaterThan(0));
            horizontal.position.jumpTo(horizontal.position.maxScrollExtent);
            await tester.pumpAndSettle();
            if (captures) {
              await tester.runAsync(() async {
                final picture =
                    await (boundary.currentContext!.findRenderObject()!
                            as RenderRepaintBoundary)
                        .toImage();
                final bytes = await picture.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '${directory.path}/output-${brightness.name}-${size.width.toInt()}-200-${keyboard ? 'keyboard' : 'no-keyboard'}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                picture.dispose();
              });
            }
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .jumpTo(0);
            await tester.pump();
            await tester.scrollUntilVisible(
              find.byType(ActivityGroup),
              80,
              scrollable: find.byType(Scrollable).first,
            );
            await Scrollable.ensureVisible(
              tester.element(find.byType(ActivityGroup)),
              alignment: 0,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byType(ActivityGroup));
            await tester.pumpAndSettle();
            expect(find.byType(ActivityDetails), findsNothing);
            await tester.tap(find.byType(ActivityGroup));
            await tester.pumpAndSettle();
            expect(find.byType(ActivityDetails), findsOneWidget);
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .jumpTo(0);
            await tester.pump();
            await tester.scrollUntilVisible(
              command(),
              60,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.ensureVisible(command());
            Focus.of(
              tester.element(
                find.descendant(
                  of: command(),
                  matching: find.text(Content.activityTool),
                ),
              ),
            ).requestFocus();
            await tester.pump();
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(find.byType(ActivityDetails), findsNothing);
            expect(outbox.sent, isEmpty);
            expect(conversation.loaded.length, loads);
            expect(conversation.listCalls, isEmpty);
            expect(h.transport.frames, isEmpty);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await h.repository.dispose();
          }
        }
      }
      semantics.dispose();
    },
  );
}
