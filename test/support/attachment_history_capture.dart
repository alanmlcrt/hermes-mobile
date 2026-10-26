// Explicit local capture: flutter test test/support/attachment_history_capture.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/attachment.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/features/conversation/draft_view.dart';
import 'package:hermes_mobile/features/conversation/draft_view_model.dart';
import 'package:hermes_mobile/features/profiles/profile_accents.dart';
import 'package:hermes_mobile/ui/theme.dart';

import 'connection_fakes.dart';

void main() {
  testWidgets('reopened attachment history at 200% in portrait and landscape', (
    tester,
  ) async {
    await (FontLoader('Inter')..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/inter-400.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
    final output = Directory(
      '_bmad-output/implementation-artifacts/story-4-4-verification/captures',
    )..createSync(recursive: true);
    final h = Harness();
    final outbox = MemoryOutbox();
    final draft = await outbox.openContinuation(
      const ConnectionKey('capture'),
      const ProfileKey('default'),
      'history',
    );
    final conversation = MemoryConversation();
    conversation.set(
      const TimelineKey(
        ConnectionKey('capture'),
        ProfileKey('default'),
        'history',
      ),
      const TimelineProjection(
        items: [
          UserItem(
            1,
            'Voici le rapport demandé.',
            operation: OperationKey('accepted'),
            userRowId: 42,
            attachments: [
              Attachment(
                key: 'pdf',
                name: 'Rapport trimestriel conservé après nettoyage.pdf',
                mediaType: 'application/pdf',
                bytes: 5242996,
                localPath: '',
                missing: true,
                cleaned: true,
                sent: true,
                state: AttachmentState.received,
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(tester.view.reset);
    for (final size in [const Size(375, 812), const Size(812, 375)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final brightness in Brightness.values) {
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(null, brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: DraftView(
              accents: ProfileAccents(h.repository),
              create: () => DraftViewModel(
                outbox: outbox,
                gateway: h.repository,
                conversation: conversation,
                key: draft.key,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        Future<void> capture(String suffix) => tester.runAsync(() async {
          final picture =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            '${output.path}/history-${brightness.name}-${size.width.toInt()}-200$suffix.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
        await capture('');
        if (size.width > size.height) {
          await tester.drag(find.byType(ListView).first, const Offset(0, 600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await capture('-top');
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
    await h.repository.dispose();
  });
}
