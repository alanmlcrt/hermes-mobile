import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/storage/attachment_files.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/data/file_limits.dart';
import 'package:hermes_mobile/features/conversation/draft_view.dart';
import 'package:hermes_mobile/features/conversation/draft_view_model.dart';
import 'package:hermes_mobile/features/profiles/profile_accents.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/attachment.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/attachment_list.dart';
import 'package:hermes_mobile/ui/components/message_bubble.dart';
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
    'real SQLite reopen keeps each sent attachment in its owning message',
    (tester) async {
      sqfliteFfiInit();
      late Harness h;
      late Directory directory;
      late Database db;
      late ConversationRepository conversation;
      late OutboxRepository outbox;
      late Draft draft;
      late DraftViewModel vm;
      final limits = FileLimits.fromJson(
        jsonDecode(File('contracts/file-limits.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      Future<void> open() async {
        db = await openConnectionDatabase(
          factory: databaseFactoryFfi,
          path: '${directory.path}/history.sqlite',
        );
        conversation = ConversationRepository(
          db,
          gateway: h.repository,
          mapping: await EventMapping.load(),
        );
        outbox = OutboxRepository(
          db,
          gateway: h.repository,
          conversation: conversation,
          attachmentFiles: AttachmentFiles(root: () async => directory),
          loadFileLimits: () async => limits,
        );
      }

      await tester.runAsync(() async {
        h = Harness();
        directory = await Directory.systemTemp.createTemp(
          'real-history-widget-',
        );
        await h.connect();
        await open();
        draft = await outbox.openNewDraft(
          h.repository.snapshot.connection!.key,
          const ProfileKey('default'),
        );
        var row = 41;
        h.transport.rpc = (method, params) => switch (method) {
          'session.create' => Map<String, dynamic>.from(
            fixture('session-create')['result'] as Map,
          ),
          'file.attach' => {
            'attached': true,
            'ref_text': '@file:${params['name']}',
          },
          'prompt.submit' => {'status': 'streaming', 'user_row_id': ++row},
          'session.history' => {'messages': []},
          _ => null,
        };
        for (final name in ['premier.pdf', 'second.pdf']) {
          await outbox.saveText(draft.key, 'Message $name');
          await outbox.addAttachment(
            draft.key,
            PickedFile(
              name: name,
              mediaType: 'application/pdf',
              data: Uint8List.fromList([1, 2, 3]),
            ),
          );
          await outbox.send(draft.key);
          expect(outbox.status(draft.key).state, OperationState.accepted);
        }
        draft = (await outbox.draft(draft.key))!;
        await outbox.dispose();
        await conversation.dispose();
        await db.close();
        await open();
        conversation.resumer = null;
        final timeline = TimelineKey(
          draft.connection,
          draft.profile,
          draft.storedSessionId!,
        );
        final restored = await conversation.load(timeline);
        expect(
          restored.items.whereType<UserItem>().map(
            (i) => i.attachments.single.name,
          ),
          ['premier.pdf', 'second.pdf'],
        );
        vm = DraftViewModel(
          outbox: outbox,
          gateway: h.repository,
          conversation: conversation,
          key: draft.key,
        );
        // Initialize all real database reads outside the simulated widget clock.
        for (var i = 0; i < 100 && vm.draft == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(vm.draft, isNotNull);
      });
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(null, Brightness.light),
            home: DraftView(
              accents: ProfileAccents(h.repository),
              create: () => vm,
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final name in ['premier.pdf', 'second.pdf']) {
          final message = find.byWidgetPredicate(
            (w) => w is MessageBubble && w.text == 'Message $name',
          );
          expect(message, findsOneWidget);
          expect(
            find.descendant(of: message, matching: find.text(name)),
            findsOneWidget,
          );
          final other = name == 'premier.pdf' ? 'second.pdf' : 'premier.pdf';
          expect(
            find.descendant(of: message, matching: find.text(other)),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await outbox.dispose();
          await conversation.dispose();
          await db.close();
          await h.repository.dispose();
          await directory.delete(recursive: true);
        });
      }
    },
  );
  testWidgets(
    'conversation reopened from stored projection renders attachments inside their message',
    (tester) async {
      final h = Harness();
      final outbox = LimitedMemoryOutbox();
      final conversation = MemoryConversation();
      final draft = await outbox.openContinuation(
        const ConnectionKey('c'),
        const ProfileKey('default'),
        'session',
      );
      final stored = const TimelineProjection(
        items: [
          UserItem(
            1,
            'Texte historique conservé',
            operation: OperationKey('sent'),
            userRowId: 42,
            attachments: [
              Attachment(
                key: 'a',
                name: 'Rapport archivé.pdf',
                mediaType: 'application/pdf',
                bytes: 123,
                localPath: '',
                sent: true,
                cleaned: true,
                state: AttachmentState.received,
              ),
            ],
          ),
        ],
      ).toJson();
      conversation.set(
        const TimelineKey(ConnectionKey('c'), ProfileKey('default'), 'session'),
        TimelineProjection.fromJson(stored),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(null, Brightness.light),
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
      final bubble = find.byType(MessageBubble);
      expect(
        find.descendant(of: bubble, matching: find.text('Rapport archivé.pdf')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bubble, matching: find.text('application/pdf')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bubble,
          matching: find.text('Reçu dans la conversation'),
        ),
        findsOneWidget,
      );
      expect(find.text('Texte historique conservé'), findsOneWidget);
      expect(find.text(Content.remove), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await h.repository.dispose();
    },
  );
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
      expect(vm.blockedReason, contains('Hors ligne'));
      outbox.pieces[draft.key] = [];
      outbox.setStatus(draft.key, const SendStatus());
      await tester.pump();
      expect(vm.attachments, isEmpty);
      vm.dispose();
      await h.repository.dispose();
    },
  );
  testWidgets(
    'sheet limits, select, named removal, VM send and denied permission preserve draft',
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
      expect(outbox.sent, [draft.key]);
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
            const MessageBubble(
              text: 'Demande historique',
              fromUser: true,
              attachments: [
                Attachment(
                  key: 'history',
                  name: 'Un document historique au nom très long et conservé après nettoyage.pdf',
                  mediaType: 'application/pdf',
                  bytes: 123,
                  localPath: '',
                  missing: true,
                  sent: true,
                  cleaned: true,
                  state: AttachmentState.received,
                ),
              ],
            ),
            AttachmentList(
              attachments: const [
                Attachment(
                  key: 'a',
                  name: 'Un document au nom long avec beaucoup de mots.pdf',
                  mediaType: 'application/pdf',
                  bytes: 123,
                  localPath: '',
                  missing: true,
                  state: AttachmentState.failed,
                  errorCode: 'attachment.refused',
                ),
                Attachment(
                  key: 'b',
                  name: 'Transféré.pdf',
                  mediaType: 'application/pdf',
                  bytes: 123,
                  localPath: '',
                  state: AttachmentState.uploaded,
                ),
                Attachment(
                  key: 'c',
                  name: 'Reçu.pdf',
                  mediaType: 'application/pdf',
                  bytes: 123,
                  localPath: '',
                  state: AttachmentState.received,
                  sent: true,
                ),
              ],
              onRemove: (_) {},
              onRetry: (_) {},
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
