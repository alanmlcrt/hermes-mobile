import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/file_limits.dart';
import 'package:hermes_mobile/features/conversation/draft_view.dart';
import 'package:hermes_mobile/features/conversation/draft_view_model.dart';
import 'package:hermes_mobile/features/profiles/profile_accents.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/attachment.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/ui/components/attachment_list.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';

import 'support/connection_fakes.dart';

class FakePicker implements AttachmentPicker {
  AppError? error;
  List<PickedFile> files = const [];
  @override
  Future<List<PickedFile>> pick(AttachmentSource source) async {
    if (error != null) throw error!;
    return files;
  }
}

class LimitedMemoryOutbox extends MemoryOutbox {
  AppError? addError;
  @override
  Future<void> addAttachment(DraftKey key, PickedFile file) async {
    if (addError != null) throw addError!;
    return super.addAttachment(key, file);
  }

  @override
  Future<List<AttachmentLimit>> attachmentLimits() async => FileLimits.fromJson(
    jsonDecode(File('contracts/file-limits.json').readAsStringSync())
        as Map<String, dynamic>,
  ).limits;
}

void main() {
  testWidgets(
    'un événement externe rafraîchit les pièces de la page courante',
    (tester) async {
      final h = Harness();
      final outbox = LimitedMemoryOutbox();
      final draft = await outbox.openContinuation(
        const ConnectionKey('c'),
        const ProfileKey('default'),
        'session',
      );
      final vm = DraftViewModel(
        outbox: outbox,
        gateway: h.repository,
        conversation: MemoryConversation(),
        key: draft.key,
      );
      await tester.pump();
      expect(vm.attachments, isEmpty);
      const piece = Attachment(
        key: 'external',
        name: 'externe.pdf',
        mediaType: 'application/pdf',
        bytes: 3,
        localPath: 'private',
      );
      outbox.pieces[draft.key] = [piece];
      outbox.setStatus(const DraftKey('another-draft'), const SendStatus());
      await tester.pump();
      expect(vm.attachments, isEmpty);
      outbox.setStatus(draft.key, const SendStatus());
      await tester.pump();
      expect(vm.attachments.single.key, piece.key);
      expect(vm.blockedReason, Content.attachmentSendBlocked);
      outbox.pieces[draft.key] = [];
      outbox.setStatus(draft.key, const SendStatus());
      await tester.pump();
      expect(vm.attachments, isEmpty);
      vm.dispose();
      await h.repository.dispose();
    },
  );
  testWidgets(
    'sheet limits, select, named removal, blocked VM send and denied permission preserve draft',
    (tester) async {
      final h = Harness();
      final outbox = LimitedMemoryOutbox();
      final draft = await outbox.openNewDraft(
        const ConnectionKey('c'),
        const ProfileKey('default'),
      );
      await outbox.saveText(draft.key, 'à conserver');
      final picker = FakePicker()
        ..files = [
          PickedFile(
            name: 'document.pdf',
            mediaType: 'application/pdf',
            data: Uint8List(3),
          ),
        ];
      late DraftViewModel vm;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(null, Brightness.light),
          home: DraftView(
            accents: ProfileAccents(h.repository),
            create: () => vm = DraftViewModel(
              outbox: outbox,
              gateway: h.repository,
              conversation: MemoryConversation(),
              key: draft.key,
              picker: picker,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final join = find.byTooltip(Content.attach);
      expect(tester.getSize(join).shortestSide, greaterThanOrEqualTo(44));
      await tester.tap(join);
      await tester.pumpAndSettle();
      expect(find.byType(AttachmentSelectionSheet), findsOneWidget);
      expect(find.text(Content.attachmentFormats), findsOneWidget);
      expect(find.textContaining('maximum par fichier'), findsNWidgets(4));
      expect(find.textContaining('pièces maximum'), findsNothing);
      await tester.tap(find.text(Content.files));
      await tester.pumpAndSettle();
      expect(find.text('document.pdf'), findsOneWidget);
      expect(find.text('application/pdf'), findsOneWidget);
      expect(find.text(Content.fileSize(3)), findsOneWidget);
      await vm.send();
      expect(outbox.sent, isEmpty);
      expect(outbox.drafts[draft.key]!.body, 'à conserver');
      expect(vm.attachments, hasLength(1));
      expect(
        find.bySemanticsLabel(RegExp('Retirer document.pdf')),
        findsOneWidget,
      );
      await tester.tap(find.text(Content.remove));
      await tester.pumpAndSettle();
      expect(find.text('document.pdf'), findsNothing);
      picker.error = const AppError('attachment.permission');
      await vm.pickAttachments(AttachmentSource.files);
      await tester.pumpAndSettle();
      expect(find.text(Content.error('attachment.permission')), findsOneWidget);
      expect(vm.attachments, isEmpty);
      picker.error = null;
      outbox.addError = const AppError('attachment.size');
      await vm.pickAttachments(AttachmentSource.files);
      await tester.pumpAndSettle();
      final pdfLimit = (await outbox.attachmentLimits()).singleWhere(
        (l) => l.category == AttachmentCategory.pdf,
      );
      expect(
        find.text(Content.attachmentSizeRefused(pdfLimit.maxBytes)),
        findsOneWidget,
      );
      outbox.addError = const AppError('attachment.type');
      picker.files = [
        const PickedFile(name: 'photo.heic', mediaType: 'image/heic'),
      ];
      await vm.pickAttachments(AttachmentSource.photos);
      await tester.pumpAndSettle();
      expect(
        find.text(Content.attachmentTypeRefused('image/heic')),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'à conserver'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      await h.repository.dispose();
    },
  );
  testWidgets('aperçu privé et repli nom/type si décodage impossible', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'attachment-preview-',
    );
    final png = File('${directory.path}/local-key')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j3ioAAAAASUVORK5CYII=',
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentList(
            attachments: [
              Attachment(
                key: 'local-key',
                name: 'photo.png',
                mediaType: 'image/png',
                bytes: png.lengthSync(),
                localPath: png.path,
              ),
            ],
            onRemove: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('photo.png'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    directory.deleteSync(recursive: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentList(
            attachments: const [
              Attachment(
                key: 'bad',
                name: 'invalid.jpg',
                mediaType: 'image/jpeg',
                bytes: 4,
                localPath: 'absent-private-copy',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('invalid.jpg'), findsOneWidget);
    expect(find.text('image/jpeg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'attachment list and sheet $size $brightness text 200% reduced motion',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          for (final child in [
            AttachmentList(
              attachments: const [
                Attachment(
                  key: 'a',
                  name: 'Un document au nom long avec beaucoup de mots.pdf',
                  mediaType: 'application/pdf',
                  bytes: 123,
                  localPath: '',
                  missing: true,
                ),
              ],
              onRemove: (_) {},
            ),
            AttachmentSelectionSheet(
              limits: await LimitedMemoryOutbox().attachmentLimits(),
            ),
          ]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: buildTheme(null, brightness),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: const TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: Scaffold(body: SingleChildScrollView(child: child)),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            for (final button in find.byType(TextButton).evaluate()) {
              expect(
                tester.getSize(find.byWidget(button.widget)).height,
                greaterThanOrEqualTo(44),
              );
            }
          }
        },
      );
    }
  }
}
