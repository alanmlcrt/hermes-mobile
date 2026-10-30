import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/file_limits.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/storage/attachment_files.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/models/attachment.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/connection_gateway.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';

import 'support/connection_fakes.dart';

class HistoryFiles extends AttachmentFiles {
  HistoryFiles(Directory root) : super(root: () async => root);
  bool refuseDeletion = false;
  @override
  Future<void> remove(DraftKey draft, String key) async {
    if (refuseDeletion) throw const FileSystemException('synthetic');
    return super.remove(draft, key);
  }
}

class PreviewFailureFiles extends AttachmentFiles {
  PreviewFailureFiles({this.failExists = false, this.onRead});
  final bool failExists;
  final void Function()? onRead;
  int reads = 0;
  @override
  Future<File> file(DraftKey draft, String key) async {
    reads++;
    onRead?.call();
    if (failExists) return UnreadablePreview();
    throw const FileSystemException('preview root unavailable');
  }
}

class UnreadablePreview implements File {
  @override
  String get path => 'private-preview';
  @override
  Future<bool> exists() async => throw const FileSystemException('stat failed');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class GenerationGateway implements ConnectionGateway {
  GenerationGateway(this.base);
  final ConnectionGateway base;
  int extraGeneration = 0;
  bool otherConnection = false;
  @override
  int get socketGeneration => base.socketGeneration + extraGeneration;
  @override
  ConnectionSnapshot get snapshot => otherConnection
      ? base.snapshot.copyWith(
          connection: Connection(
            key: const ConnectionKey('other'),
            origin: Uri.parse('https://other.test'),
          ),
        )
      : base.snapshot;
  @override
  String? get replayEpoch => base.replayEpoch;
  @override
  Stream<GatewayEvent> get events => base.events;
  @override
  Stream<ConnectionSnapshot> get snapshots => base.snapshots;
  @override
  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = rpcTimeout,
  }) => base.call(method, params, timeout: timeout);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late Database db;
  late Harness h;
  late OutboxRepository outbox;
  late ConversationRepository conversation;
  late Draft draft;
  late HistoryFiles files;
  var evidence = <String>[];
  var ambiguous = false;
  var noRow = false;
  String prompt = '';
  final limits = FileLimits.fromJson(
    jsonDecode(File('contracts/file-limits.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  Future<void> open() async {
    db = await openConnectionDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/db.sqlite',
    );
    conversation = ConversationRepository(
      db,
      gateway: h.repository,
      mapping: await EventMapping.load(),
    );
    files = HistoryFiles(directory);
    outbox = OutboxRepository(
      db,
      gateway: h.repository,
      conversation: conversation,
      attachmentFiles: files,
      loadFileLimits: () async => limits,
    );
  }

  Future<void> close() async {
    await outbox.dispose();
    await conversation.dispose();
    await db.close();
  }

  TimelineKey key() =>
      TimelineKey(draft.connection, draft.profile, draft.storedSessionId!);
  Future<void> add(String name) => outbox.addAttachment(
    draft.key,
    PickedFile(
      name: name,
      mediaType: 'application/pdf',
      data: Uint8List.fromList([1, 2, 3]),
    ),
  );
  Future<void> send() async {
    await outbox.send(draft.key);
    draft = (await outbox.draft(draft.key))!;
    expect(outbox.status(draft.key).state, OperationState.accepted);
  }

  Future<void> reconcile() async {
    final resumed = await outbox.resume(key());
    await outbox.reconcile(key(), resumed, [42]);
    await conversation.load(key());
  }

  Future<void> restart() async {
    await close();
    await open();
    // Read the durable projection without starting a background network resync.
    conversation.resumer = null;
    await conversation.load(key());
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hermes-history-');
    h = Harness();
    await h.connect();
    await open();
    draft = await outbox.openNewDraft(
      h.repository.snapshot.connection!.key,
      const ProfileKey('default'),
    );
    await outbox.saveText(draft.key, 'Bonjour');
    evidence = [];
    ambiguous = noRow = false;
    h.transport.rpc = (method, params) {
      if (method == 'prompt.submit') {
        prompt = params['text'] as String;
        return noRow
            ? {'status': 'streaming'}
            : Map<String, dynamic>.from(
                fixture('prompt-submit')['result'] as Map,
              );
      }
      return switch (method) {
        'session.create' => Map<String, dynamic>.from(
          fixture('session-create')['result'] as Map,
        ),
        'session.resume' => Map<String, dynamic>.from(
          fixture('session-resume')['result'] as Map,
        ),
        'file.attach' => {
          'attached': true,
          'ref_text': '@file:${params['name']}',
        },
        'session.history' => {
          'messages': [
            {
              'role': 'user',
              'row_id': 42,
              'content':
                  '$prompt\n--- Attached Context ---\n${evidence.join('\n')}',
            },
            if (ambiguous)
              {'role': 'user', 'row_id': 43, 'content': 'autre demande'},
          ],
        },
        _ => null,
      };
    };
  });
  tearDown(() async {
    await close();
    await h.repository.dispose();
    await directory.delete(recursive: true);
  });

  test('partial receipt cleans only its own copy; durable names and states survive restart', () async {
    await add('a.pdf');
    await add('b.pdf');
    evidence = ['@file:b.pdf'];
    await send();
    final pieces = await outbox.attachments(draft.key);
    expect(pieces.map((a) => a.cleaned), [false, true]);
    expect(pieces.map((a) => File(a.localPath).existsSync()), [true, false]);
    await restart();
    final item = conversation
        .projection(key())
        .items
        .whereType<UserItem>()
        .single;
    expect(item.attachments.map((a) => a.name), ['a.pdf', 'b.pdf']);
    expect(item.attachments.map((a) => a.mediaType), [
      'application/pdf',
      'application/pdf',
    ]);
    expect(item.attachments.map((a) => a.state), [
      AttachmentState.uploaded,
      AttachmentState.received,
    ]);
    expect(item.attachments.first.localPath, pieces.first.localPath);
    expect(item.attachments.last.cleaned, isTrue);
    await outbox.saveText(draft.key, 'Suite');
    await outbox.send(draft.key);
    expect(
      h.transport.frames.where((f) => f['method'] == 'file.attach'),
      hasLength(2),
    );
    expect(prompt, 'Suite');
  });

  test('failed deletion retains metadata and retries after restart without submitting again', () async {
    files.refuseDeletion = true;
    await add('a.pdf');
    evidence = ['@file:a.pdf'];
    await send();
    final piece = (await outbox.attachments(draft.key)).single;
    expect(piece.state, AttachmentState.received);
    expect(piece.cleaned, isFalse);
    expect(File(piece.localPath).existsSync(), isTrue);
    await restart();
    await reconcile();
    expect(File(piece.localPath).existsSync(), isFalse);
    expect((await outbox.attachments(draft.key)).single.cleaned, isTrue);
    expect(
      conversation
          .projection(key())
          .items
          .whereType<UserItem>()
          .single
          .attachments
          .single
          .name,
      'a.pdf',
    );
    expect(
      h.transport.frames.where((f) => f['method'] == 'prompt.submit'),
      hasLength(1),
    );
  });

  test(
    'interruption after deletion before cleanup flag is idempotent',
    () async {
      await db.execute(
        "CREATE TRIGGER refuse_clean BEFORE UPDATE OF cleaned ON outbox_attachments BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      );
      await add('a.pdf');
      evidence = ['@file:a.pdf'];
      await send();
      final piece = (await outbox.attachments(draft.key)).single;
      expect(piece.cleaned, isFalse);
      expect(File(piece.localPath).existsSync(), isFalse);
      await db.execute('DROP TRIGGER refuse_clean');
      await restart();
      await reconcile();
      expect((await outbox.attachments(draft.key)).single.cleaned, isTrue);
    },
  );

  test('receipt transaction failure never deletes bytes', () async {
    await db.execute(
      "CREATE TRIGGER refuse_receipt BEFORE UPDATE OF state ON outbox_operation_attachments WHEN NEW.state = 'received' BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
    );
    await add('a.pdf');
    evidence = ['@file:a.pdf'];
    await send();
    final piece = (await outbox.attachments(draft.key)).single;
    expect(piece.state, AttachmentState.uploaded);
    expect(File(piece.localPath).existsSync(), isTrue);
    expect(
      (await db.query('outbox_operation_attachments')).single['receipt_row_id'],
      isNull,
    );
  });

  test(
    'multiple fresh rows cannot be disambiguated by matching prompt text',
    () async {
      noRow = ambiguous = true;
      await add('a.pdf');
      evidence = ['@file:a.pdf'];
      await send();
      expect((await outbox.attachments(draft.key)).single.cleaned, isFalse);
      expect(
        (await db.query('outbox_operations')).single['user_row_id'],
        isNull,
      );
      await conversation.resync(key());
      expect(
        conversation
            .projection(key())
            .items
            .whereType<UserItem>()
            .every((i) => i.attachments.isEmpty),
        isTrue,
      );
    },
  );

  test(
    'same row and name in other connection, profile or session never hydrate',
    () async {
      await add('a.pdf');
      await send();
      for (final other in [
        TimelineKey(
          const ConnectionKey('other'),
          draft.profile,
          draft.storedSessionId!,
        ),
        TimelineKey(
          draft.connection,
          const ProfileKey('other'),
          draft.storedSessionId!,
        ),
        TimelineKey(draft.connection, draft.profile, 'other-session'),
      ]) {
        await conversation.accepted(
          other,
          const OperationKey('remote-only'),
          'a.pdf',
          userRowId: 42,
        );
        expect(
          conversation
              .projection(other)
              .items
              .whereType<UserItem>()
              .single
              .attachments,
          isEmpty,
        );
      }
    },
  );

  test(
    '4.3 received records require a new exact proof before cleanup',
    () async {
      await add('a.pdf');
      await send();
      await db.update('outbox_attachments', {'state': 'received'});
      await db.update('outbox_operation_attachments', {'state': 'received'});
      await restart();
      await reconcile();
      final piece = (await outbox.attachments(draft.key)).single;
      expect(File(piece.localPath).existsSync(), isTrue);
      expect(piece.cleaned, isFalse);
      evidence = ['@file:a.pdf'];
      await reconcile();
      expect(File(piece.localPath).existsSync(), isFalse);
    },
  );

  test(
    'deferred receipt never cleans a same-name attachment in the current draft',
    () async {
      await add('a.pdf');
      await send();
      await add('a.pdf');
      evidence = ['@file:a.pdf'];
      await reconcile();
      final pieces = await outbox.attachments(draft.key);
      expect(pieces.first.cleaned, isTrue);
      expect(pieces.last.sent, isFalse);
      expect(pieces.last.cleaned, isFalse);
      expect(File(pieces.last.localPath).existsSync(), isTrue);
      expect(
        conversation
            .projection(key())
            .items
            .whereType<UserItem>()
            .single
            .attachments
            .map((a) => a.key),
        [pieces.first.key],
      );
    },
  );

  test(
    'unconfirmed image restores its validated private path across restart',
    () async {
      await add('photo.png');
      await send();
      // Legacy metadata already carries the media type; no remote path is trusted.
      await db.update('outbox_attachments', {
        'media_type': 'image/png',
        'reference': '@image:/server/private.png',
      });
      final piece = (await outbox.attachments(draft.key)).single;
      await restart();
      final image = conversation
          .projection(key())
          .items
          .whereType<UserItem>()
          .single
          .attachments
          .single;
      expect(image.isImage, isTrue);
      expect(image.localPath, piece.localPath);
      expect(image.localPath, isNot(contains('/server/')));
      expect(image.missing, isFalse);
      expect(image.cleaned, isFalse);
    },
  );

  test('legacy JSON and withRow preserve backward compatibility without trusting stored paths', () {
    final legacy = TimelineItem.fromJson({
      'k': 'user',
      'turn': 1,
      'text': 'old',
      'op': 'old',
    }) as UserItem;
    expect(legacy.attachments, isEmpty);
    final item = UserItem(
      1,
      'body',
      operation: const OperationKey('op'),
      attachments: const [
        Attachment(
          key: 'a',
          name: 'a.png',
          mediaType: 'image/png',
          bytes: 3,
          localPath: '/private',
          sent: true,
        ),
      ],
    );
    final restored =
        TimelineItem.fromJson(item.withRow(42).toJson()) as UserItem;
    expect(restored.userRowId, 42);
    expect(restored.attachments.single.name, 'a.png');
    expect(restored.attachments.single.localPath, isEmpty);
    expect(restored.attachments.single.missing, isTrue);
  });

  test('immediate rowless receipt preserves cached attachments and publishes its exact row', () async {
    noRow = true;
    await add('a.pdf');
    evidence = ['@file:a.pdf'];
    await outbox.ensureSession(draft.key);
    draft = (await outbox.draft(draft.key))!;
    final changed = conversation.changes.firstWhere((_) {
      final item = conversation
          .projection(key())
          .items
          .whereType<UserItem>()
          .singleOrNull;
      return item?.userRowId == 42 &&
          item?.attachments.singleOrNull?.state == AttachmentState.received;
    });
    await send();
    await changed.timeout(const Duration(seconds: 3));
    final item = conversation
        .projection(key())
        .items
        .whereType<UserItem>()
        .single;
    expect(item.attachments.single.name, 'a.pdf');
    expect(item.attachments.single.cleaned, isTrue);
  });

  test('deferred rowless receipt notifies existing cached projection without load or resync', () async {
    noRow = true;
    await add('a.pdf');
    await send();
    final before = conversation.projection(key());
    expect(before.items.whereType<UserItem>().single.userRowId, isNull);
    evidence = ['@file:a.pdf'];
    final changed = conversation.changes.firstWhere(
      (k) =>
          k == key() &&
          conversation
                  .projection(k)
                  .items
                  .whereType<UserItem>()
                  .single
                  .userRowId ==
              42 &&
          conversation
                  .projection(k)
                  .items
                  .whereType<UserItem>()
                  .single
                  .attachments
                  .single
                  .state ==
              AttachmentState.received,
    );
    final resumed = await outbox.resume(key());
    await outbox.reconcile(key(), resumed, [42]);
    await changed.timeout(const Duration(seconds: 3));
    expect(identical(before, conversation.projection(key())), isFalse);
    expect(
      conversation
          .projection(key())
          .items
          .whereType<UserItem>()
          .single
          .attachments
          .single
          .name,
      'a.pdf',
    );
  });

  for (final failExists in [false, true]) {
    test(
      'preview ${failExists ? 'stat' : 'path provider'} failure preserves accepted bubble and metadata',
      () async {
        await add('a.pdf');
        final failing = PreviewFailureFiles(failExists: failExists);
        conversation.attachmentFiles = failing;
        await send();
        final item = conversation
            .projection(key())
            .items
            .whereType<UserItem>()
            .single;
        expect(item.text, 'Bonjour');
        expect(item.attachments.single.name, 'a.pdf');
        expect(item.attachments.single.mediaType, 'application/pdf');
        expect(item.attachments.single.state, AttachmentState.uploaded);
        expect(item.attachments.single.missing, isTrue);
        expect(item.attachments.single.localPath, isEmpty);
      },
    );
  }

  test('already cleaned pieces never resolve a preview path', () async {
    await add('a.pdf');
    evidence = ['@file:a.pdf'];
    await send();
    final failing = PreviewFailureFiles();
    conversation.attachmentFiles = failing;
    final changed = conversation.changes.first;
    conversation.refreshAttachments(key());
    await changed.timeout(const Duration(seconds: 3));
    expect(failing.reads, 0);
    expect(
      conversation
          .projection(key())
          .items
          .whereType<UserItem>()
          .single
          .attachments
          .single
          .cleaned,
      isTrue,
    );
  });

  for (final changeConnection in [false, true]) {
    test(
      '${changeConnection ? 'connection' : 'generation'} changed during hydration cannot publish a stale resync',
      () async {
        await add('a.pdf');
        await send();
        await outbox.dispose();
        await conversation.dispose();
        final scoped = GenerationGateway(h.repository);
        conversation = ConversationRepository(
          db,
          gateway: scoped,
          mapping: await EventMapping.load(),
        );
        outbox = OutboxRepository(
          db,
          gateway: scoped,
          conversation: conversation,
          attachmentFiles: files,
          loadFileLimits: () async => limits,
        );
        var changedGeneration = false;
        var stalePublications = 0;
        TimelineProjection? atGenerationChange;
        final subscription = conversation.changes.listen((_) {
          if (changedGeneration &&
              !identical(atGenerationChange, conversation.projection(key()))) {
            stalePublications++;
          }
        });
        conversation.attachmentFiles = PreviewFailureFiles(
          onRead: () {
            if (!changedGeneration) {
              atGenerationChange = conversation.projection(key());
              if (changeConnection) {
                scoped.otherConnection = true;
              } else {
                scoped.extraGeneration++;
              }
              changedGeneration = true;
            }
          },
        );
        await conversation.resync(key());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(changedGeneration, isTrue);
        expect(stalePublications, 0);
        await subscription.cancel();
      },
    );
  }

  test('successful cleanup retry does not fetch history again for freshly cleaned metadata', () async {
    files.refuseDeletion = true;
    await add('a.pdf');
    evidence = ['@file:a.pdf'];
    await send();
    final callsBefore = h.transport.frames
        .where((f) => f['method'] == 'session.history')
        .length;
    files.refuseDeletion = false;
    final resumed = await outbox.resume(key());
    await outbox.reconcile(key(), resumed, [42]);
    expect((await outbox.attachments(draft.key)).single.cleaned, isTrue);
    expect(
      h.transport.frames.where((f) => f['method'] == 'session.history'),
      hasLength(callsBefore),
    );
  });
}
