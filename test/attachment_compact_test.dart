import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/attachment.dart';
import 'package:hermes_mobile/ui/components/attachment_list.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';

void main() {
  const name =
      'Document avec un nom complet très long qui doit rester accessible.pdf';
  Attachment piece(
    AttachmentState state, {
    bool missing = false,
    bool sent = false,
  }) => Attachment(
    key: 'test',
    name: name,
    mediaType: 'application/pdf',
    bytes: 5242996,
    localPath: '',
    state: state,
    missing: missing,
    sent: sent,
  );
  for (final brightness in Brightness.values) {
    testWidgets('compact semantics, actions and states $brightness', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Attachment? removed;
      Attachment? retried;
      Future<void> show(Attachment attachment) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(null, brightness),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: AttachmentList(
                    attachments: [attachment],
                    onRemove: (a) => removed = a,
                    onRetry: (a) => retried = a,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      final selected = piece(AttachmentState.selected);
      await show(selected);
      expect(find.text('application/pdf'), findsNothing);
      expect(find.text(Content.attachmentSelected), findsNothing);
      expect(find.bySemanticsLabel(name), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(name)).value,
        Content.attachmentSelected,
      );
      final remove = find.byTooltip(Content.removeAttachment(name));
      expect(
        find.bySemanticsLabel(Content.removeAttachment(name)),
        findsOneWidget,
      );
      expect(tester.getSize(remove).shortestSide, greaterThanOrEqualTo(48));
      await tester.tap(remove);
      expect(removed, same(selected));
      for (final state in AttachmentState.values.where(
        (s) => s != AttachmentState.selected,
      )) {
        final attachment = piece(state);
        await show(attachment);
        expect(
          find.text(Content.attachmentStatus(state, false, null)),
          findsOneWidget,
        );
        if (state == AttachmentState.failed ||
            state == AttachmentState.uncertain) {
          final retry = find.byType(TextButton);
          expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
          expect(
            find.bySemanticsLabel(RegExp('Réessayer l’envoi de')),
            findsOneWidget,
          );
          await tester.tap(retry);
          expect(retried, same(attachment));
        }
      }
      await show(piece(AttachmentState.selected, missing: true));
      expect(find.textContaining(Content.attachmentMissing), findsOneWidget);
      await show(piece(AttachmentState.received, sent: true));
      expect(find.byTooltip(Content.removeAttachment(name)), findsNothing);
      semantics.dispose();
    });
  }
}
