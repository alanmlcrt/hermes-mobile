import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/file_limits.dart';
import 'package:hermes_mobile/data/storage/attachment_files.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/attachment.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';

import 'support/connection_fakes.dart';

class RefuseDeletion extends AttachmentFiles {
  RefuseDeletion(Directory root) : super(root: () async => root);
  @override
  Future<void> remove(DraftKey draft, String key) async =>
      throw const FileSystemException('synthetic');
}

class PausedCopy extends AttachmentFiles {
  PausedCopy(Directory root) : super(root: () async => root);
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<File> copy(
    DraftKey draft,
    String key,
    PickedFile picked,
    int maximum,
  ) async {
    started.complete();
    await release.future;
    return super.copy(draft, key, picked, maximum);
  }
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database db;
  late OutboxRepository outbox;
  late Harness h;
  late Draft draft;
  final limits = FileLimits.fromJson(
    jsonDecode(File('contracts/file-limits.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  Future<void> open({AttachmentFiles? files}) async {
    db = await openConnectionDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/hermes.sqlite',
    );
    outbox = OutboxRepository(
      db,
      gateway: h.repository,
      attachmentFiles: files ?? AttachmentFiles(root: () async => directory),
      loadFileLimits: () async => limits,
    );
    draft = await outbox.openNewDraft(
      const ConnectionKey('c'),
      const ProfileKey('default'),
    );
  }

  PickedFile picked(String name, String type) => PickedFile(
    name: name,
    mediaType: type,
    data: Uint8List.fromList([1, 2, 3]),
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hermes-attachments-');
    h = Harness();
    await open();
    await outbox.saveText(draft.key, 'texte conservé');
  });
  tearDown(() async {
    await outbox.dispose();
    await db.close();
    await h.repository.dispose();
    await directory.delete(recursive: true);
  });
  test('private bytes, four files ordered across restart, removal and missing copy', () async {
    final names = ['../photo.png', 'photo.jpg', 'photo.jpeg', 'document.pdf'];
    final types = ['image/png', 'image/jpeg', 'image/jpeg', 'application/pdf'];
    await Future.wait([
      for (var i = 0; i < names.length; i++)
        outbox.addAttachment(draft.key, picked(names[i], types[i])),
    ]);
    var pieces = await outbox.attachments(draft.key);
    expect(pieces.map((a) => a.name), names);
    for (final piece in pieces) {
      expect(
        piece.localPath.replaceAll(r'\', '/'),
        endsWith('/attachments/${draft.key.value}/${piece.key}'),
      );
      expect(await File(piece.localPath).readAsBytes(), [1, 2, 3]);
      expect(piece.bytes, 3);
      expect(piece.state, AttachmentState.selected);
    }
    await outbox.dispose();
    await db.close();
    await open();
    pieces = await outbox.attachments(draft.key);
    expect(pieces.map((a) => a.name), names);
    await outbox.removeAttachment(draft.key, pieces.first.key);
    expect(await File(pieces.first.localPath).exists(), isFalse);
    await File(pieces.last.localPath).delete();
    expect((await outbox.attachments(draft.key)).last.missing, isTrue);
    expect((await outbox.draft(draft.key))!.revision, 1);
  });
  test(
    'refused size and type make no private copy, text is retained',
    () async {
      final source = File('${directory.path}/huge');
      final handle = await source.open(mode: FileMode.write);
      await handle.truncate(limits.maxBytesFor('image/png')! + 1);
      await handle.close();
      for (final file in [
        PickedFile(name: 'huge.png', mediaType: 'image/png', path: source.path),
        picked('photo.heic', 'image/heic'),
      ]) {
        await expectLater(
          outbox.addAttachment(draft.key, file),
          throwsA(isA<AppError>()),
        );
      }
      expect(await outbox.attachments(draft.key), isEmpty);
      expect(
        await Directory('${directory.path}/attachments').exists(),
        isFalse,
      );
      expect((await outbox.draft(draft.key))!.body, 'texte conservé');
    },
  );
  test('failed deletion retains the record and bytes', () async {
    await outbox.addAttachment(draft.key, picked('a.pdf', 'application/pdf'));
    final piece = (await outbox.attachments(draft.key)).single;
    await outbox.dispose();
    await db.close();
    await open(files: RefuseDeletion(directory));
    await expectLater(
      outbox.removeAttachment(draft.key, piece.key),
      throwsA(isA<AppError>()),
    );
    expect((await outbox.attachments(draft.key)).single.key, piece.key);
    expect(await File(piece.localPath).exists(), isTrue);
  });
  test('refus SQLite de DELETE conserve ligne et octets privés', () async {
    await outbox.addAttachment(draft.key, picked('a.pdf', 'application/pdf'));
    final piece = (await outbox.attachments(draft.key)).single;
    await db.execute(
      'CREATE TRIGGER refuse_attachment_delete BEFORE DELETE ON outbox_attachments '
      "BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
    );
    await expectLater(
      outbox.removeAttachment(draft.key, piece.key),
      throwsA(isA<AppError>()),
    );
    expect((await outbox.attachments(draft.key)).single.key, piece.key);
    expect(await File(piece.localPath).readAsBytes(), [1, 2, 3]);
    expect(await File(piece.localPath).parent.list().length, 1);
  });
  test(
    'copie depuis un chemin réel indépendante de la source après relance',
    () async {
      final bytes = List<int>.generate(4097, (i) => i % 256);
      final source = File('${directory.path}/source.pdf');
      await source.writeAsBytes(bytes);
      await outbox.addAttachment(
        draft.key,
        PickedFile(
          name: 'source.pdf',
          mediaType: 'application/pdf',
          path: source.path,
        ),
      );
      await source.delete();
      await outbox.dispose();
      await db.close();
      await open();
      final piece = (await outbox.attachments(draft.key)).single;
      expect(piece.bytes, bytes.length);
      expect(piece.missing, isFalse);
      expect(await File(piece.localPath).readAsBytes(), bytes);
    },
  );
  test(
    'attached draft blocks repository send before any session or prompt',
    () async {
      await h.connect();
      await outbox.addAttachment(draft.key, picked('a.pdf', 'application/pdf'));
      final before = h.transport.frames.length;
      await outbox.send(draft.key);
      expect(outbox.status(draft.key).errorCode, 'attachment.send_blocked');
      expect(h.transport.frames.length, before);
      expect(await db.query('outbox_operations'), isEmpty);
      expect((await outbox.draft(draft.key))!.body, 'texte conservé');
      expect(await outbox.attachments(draft.key), hasLength(1));
    },
  );
  test('profile change preserves attachment-only target draft', () async {
    final target = await outbox.openNewDraft(
      const ConnectionKey('c'),
      const ProfileKey('other'),
    );
    await outbox.addAttachment(target.key, picked('a.pdf', 'application/pdf'));
    await outbox.reassignNewDraft(draft.key, const ProfileKey('other'));
    expect(
      (await outbox.draft(target.key))!.profile,
      const ProfileKey('default'),
    );
    expect(await outbox.attachments(target.key), hasLength(1));
  });
  test('in-flight add is awaited by send; later add and removal cannot race submission', () async {
    await outbox.dispose();
    await db.close();
    final paused = PausedCopy(directory);
    await open(files: paused);
    await h.connect();
    final adding = outbox.addAttachment(
      draft.key,
      picked('a.pdf', 'application/pdf'),
    );
    await paused.started.future;
    final before = h.transport.frames.length;
    final sending = outbox.send(draft.key);
    await expectLater(
      outbox.addAttachment(draft.key, picked('b.pdf', 'application/pdf')),
      throwsA(isA<AppError>()),
    );
    await expectLater(
      outbox.removeAttachment(draft.key, 'unknown'),
      throwsA(isA<AppError>()),
    );
    paused.release.complete();
    await adding;
    await sending;
    expect(h.transport.frames.length, before);
    expect(outbox.status(draft.key).errorCode, 'attachment.send_blocked');
    expect((await outbox.draft(draft.key))!.body, 'texte conservé');
    expect(await outbox.attachments(draft.key), hasLength(1));
  });
}
