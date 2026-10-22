// Capture manuelle locale : flutter test test/support/activity_capture.dart
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
import 'package:hermes_mobile/ui/components/conversation_companion.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';

import 'connection_fakes.dart';

void main() {
  testWidgets('captures DraftView complet, clavier simulé et texte 200 %', (
    tester,
  ) async {
    for (final entry in {
      'ActivityCapture': 'C:/Windows/Fonts/segoeui.ttf',
      'MaterialIcons': 'C:/Users/alanc/fvm/versions/3.47.7/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(File(entry.value).readAsBytesSync()),
            ),
          ))
          .load();
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final directory = Directory(
      '_bmad-output/implementation-artifacts/story-3-1-verification/captures',
    );
    directory.createSync(recursive: true);
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 375.0]) {
        tester.view.physicalSize = Size(width, 1000);
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
        conversation.projections[key] = TimelineProjection(
          turns: 1,
          userTurns: 1,
          workState: WorkState.running,
          companionPhase: CompanionPhase.reading,
          items: [
            UserItem(
              1,
              'Ma demande',
              operation: const OperationKey('synthetic'),
            ),
            const ActivityItem(
              1,
              ActivityKind.tool,
              toolId: 'A',
              started: true,
              completed: true,
              eventKey: 'a',
              responseReceived: true,
            ),
            const ActivityItem(
              1,
              ActivityKind.unknown,
              eventKey: 'b',
              responseReceived: true,
            ),
            const ResponseItem(1, 'Voici la réponse.'),
          ],
        );
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
                viewInsets: const EdgeInsets.only(bottom: 220),
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
        for (final expanded in [false, true]) {
          if (expanded) {
            await tester.ensureVisible(find.byType(ActivityGroup));
            await tester.tap(find.byType(ActivityGroup));
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(find.byType(ConversationCompanion));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(Content.activitySummary(2, 1)), findsOneWidget);
          await tester.runAsync(() async {
            final picture =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${directory.path}/draft-${brightness.name}-${width.toInt()}-200-keyboard-${expanded ? 'expanded' : 'collapsed'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
        expect(outbox.sent, isEmpty);
        await tester.pumpWidget(const SizedBox());
        await h.repository.dispose();
      }
    }
  });
}
