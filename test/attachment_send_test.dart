import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hermes_mobile/data/file_limits.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/storage/attachment_files.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/models/attachment.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/models/connection_gateway.dart';
import 'package:hermes_mobile/features/conversation/draft_view.dart';
import 'package:hermes_mobile/features/conversation/draft_view_model.dart';
import 'package:hermes_mobile/features/profiles/profile_accents.dart';
import 'package:hermes_mobile/ui/theme.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/components/attachment_list.dart';

import 'support/connection_fakes.dart';

class ReadFailureFiles extends AttachmentFiles {
  ReadFailureFiles(Directory directory) : super(root: () async => directory);
  bool fail = false;
  @override
  Future<File> file(DraftKey draft, String key) {
    if (fail) throw const FileSystemException('synthetic read failure');
    return super.file(draft, key);
  }
}

class ScopedGateway implements ConnectionGateway {
  ScopedGateway(this.base);
  final ConnectionGateway base;
  int extraGeneration = 0;
  bool otherConnection = false;
  void Function(String)? afterCall;
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
  int get socketGeneration => base.socketGeneration + extraGeneration;
  @override
  Stream<ConnectionSnapshot> get snapshots => base.snapshots;
  @override
  Stream<GatewayEvent> get events => base.events;
  @override
  String? get replayEpoch => base.replayEpoch;
  @override
  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = rpcTimeout,
  }) async {
    final result = await base.call(method, params, timeout: timeout);
    afterCall?.call(method);
    return result;
  }

  @override
  Future<void> restore() => base.restore();
  @override
  Future<void> confirmOrigin(Uri origin) => base.confirmOrigin(origin);
  @override
  Future<void> authenticate(String password) => base.authenticate(password);
  @override
  Future<void> refreshProfiles() => base.refreshProfiles();
  @override
  Future<void> selectProfile(ProfileKey key) => base.selectProfile(key);
  @override
  Future<void> reconnect() => base.reconnect();
  @override
  Future<void> dispose() async {}
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database db;
  late Harness h;
  late OutboxRepository outbox;
  late Draft draft;
  final limits = FileLimits.fromJson(
    jsonDecode(File('contracts/file-limits.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  Future<void> open() async {
    db = await openConnectionDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/hermes.sqlite',
    );
    outbox = OutboxRepository(
      db,
      gateway: h.repository,
      attachmentFiles: AttachmentFiles(root: () async => directory),
      loadFileLimits: () async => limits,
    );
    draft = await outbox.openNewDraft(
      h.repository.snapshot.connection!.key,
      const ProfileKey('default'),
    );
  }

  Future<void> add(String name, String type) => outbox.addAttachment(
    draft.key,
    PickedFile(
      name: name,
      mediaType: type,
      data: Uint8List.fromList([1, 2, 3]),
    ),
  );

  Map<String, dynamic> created() =>
      Map<String, dynamic>.from(fixture('session-create')['result'] as Map);
  Map<String, dynamic> submitted() =>
      Map<String, dynamic>.from(fixture('prompt-submit')['result'] as Map);
  int calls(String method) =>
      h.transport.frames.where((f) => f['method'] == method).length;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hermes-attach-send-');
    h = Harness();
    await h.connect();
    await open();
    await outbox.saveText(draft.key, 'Bonjour');
  });
  tearDown(() async {
    await outbox.dispose();
    await db.close();
    await h.repository.dispose();
    await directory.delete(recursive: true);
  });

  test('success: scoped references in prompt, receipt only from server history', () async {
    await add('a.pdf', 'application/pdf');
    await add('b.png', 'image/png');
    h.transport.rpc = (method, params) {
      if (method == 'file.attach' || method == 'image.attach_bytes') {
        expect(params['session_id'], created()['session_id']);
        expect(params['profile'], 'default');
        expect(params.containsKey('path'), isFalse);
        final encoded = method == 'file.attach'
            ? (params['data_url'] as String).split(',').last
            : params['content_base64'] as String;
        expect(base64Decode(encoded), [1, 2, 3]);
        if (method == 'file.attach') {
          expect(
            params['data_url'],
            startsWith('data:application/pdf;base64,'),
          );
          expect(params['name'], 'a.pdf');
        } else {
          expect(params['filename'], 'b.png');
          expect(params['ext'], 'png');
        }
      }
      return switch (method) {
        'session.create' => created(),
        'file.attach' => {'attached': true, 'ref_text': '@file:a.pdf'},
        'image.attach_bytes' => {
          'attached': true,
          'text': '@image:/server/b.png',
        },
        'prompt.submit' => submitted(),
        'session.history' => {
          'messages': [
            {
              'role': 'user',
              'row_id': 42,
              'content':
                  '@file:a.pdf\n@image:/server/b.png\nBonjour\n'
                  '--- Attached Context ---\n@file:a.pdf\n@image:/server/b.png',
            },
          ],
        },
        _ => null,
      };
    };
    await outbox.send(draft.key);
    expect(outbox.status(draft.key).state, OperationState.accepted);
    final prompt =
        (h.transport.frames.firstWhere(
              (f) => f['method'] == 'prompt.submit',
            )['params']
            as Map)['text'];
    expect(prompt, contains('@file:a.pdf'));
    expect(prompt, contains('@image:/server/b.png'));
    expect(prompt, contains('Bonjour'));
    final pieces = await outbox.attachments(draft.key);
    expect(pieces.map((a) => a.state), [
      AttachmentState.received,
      AttachmentState.received,
    ]);
    expect(pieces.every((a) => a.sent), isTrue);
    expect(pieces.every((a) => File(a.localPath).existsSync()), isFalse);
    expect(pieces.every((a) => a.cleaned), isTrue);
    await expectLater(
      outbox.removeAttachment(draft.key, pieces.first.key),
      throwsA(
        isA<AppError>().having((e) => e.code, 'code', 'attachment.retained'),
      ),
    );
    await outbox.saveText(draft.key, 'Encore');
    await outbox.send(draft.key);
    expect(calls('file.attach'), 1);
    expect(calls('image.attach_bytes'), 1);
    final prompts = h.transport.frames
        .where((f) => f['method'] == 'prompt.submit')
        .toList();
    expect((prompts.last['params'] as Map)['text'], 'Encore');
  });

  test('accepted upload without history proof remains uploaded', () async {
    await add('a.pdf', 'application/pdf');
    h.transport.rpc = (method, params) => switch (method) {
      'session.create' => created(),
      'file.attach' => {'attached': true, 'ref_text': '@file:a.pdf'},
      'prompt.submit' => submitted(),
      'session.history' => {
        'messages': [
          {'role': 'user', 'row_id': 42, 'content': '@file:a.pdf\nBonjour'},
        ],
      },
      _ => null,
    };
    await outbox.send(draft.key);
    expect(
      (await outbox.attachments(draft.key)).single.state,
      AttachmentState.uploaded,
    );
  });

  test(
    'duplicate exact PNG prompt echoes never prove receipt or delete bytes',
    () async {
      await add('a.png', 'image/png');
      String prompt = '';
      h.transport.rpc = (method, params) {
        if (method == 'prompt.submit') {
          prompt = params['text'] as String;
          return submitted();
        }
        return switch (method) {
          'session.create' => created(),
          'image.attach_bytes' => {
            'attached': true,
            'text': '@image:/server/a.png',
          },
          'session.history' => {
            'messages': [
              {'role': 'user', 'row_id': 42, 'content': '$prompt\n$prompt'},
            ],
          },
          _ => null,
        };
      };
      await outbox.send(draft.key);
      final piece = (await outbox.attachments(draft.key)).single;
      expect(piece.state, AttachmentState.uploaded);
      expect(piece.cleaned, isFalse);
      expect(File(piece.localPath).existsSync(), isTrue);
    },
  );

  test(
    'shared server reference is ambiguous for both receipt and cleanup',
    () async {
      await add('a.pdf', 'application/pdf');
      await add('b.pdf', 'application/pdf');
      String prompt = '';
      h.transport.rpc = (method, params) {
        if (method == 'prompt.submit') {
          prompt = params['text'] as String;
          return submitted();
        }
        return switch (method) {
          'session.create' => created(),
          'session.resume' => Map<String, dynamic>.from(
            fixture('session-resume')['result'] as Map,
          ),
          'file.attach' => {'attached': true, 'ref_text': '@file:shared.pdf'},
          'session.history' => {
            'messages': [
              {
                'role': 'user',
                'row_id': 42,
                'content':
                    '$prompt\n--- Attached Context ---\n@file:shared.pdf',
              },
            ],
          },
          _ => null,
        };
      };
      await outbox.send(draft.key);
      var pieces = await outbox.attachments(draft.key);
      expect(
        pieces.every(
          (a) =>
              a.state == AttachmentState.uploaded &&
              !a.cleaned &&
              File(a.localPath).existsSync(),
        ),
        isTrue,
      );
      // Even a pre-existing receipt marker cannot authorize ambiguous cleanup.
      await db.update('outbox_attachments', {'state': 'received'});
      await db.update('outbox_operation_attachments', {
        'state': 'received',
        'receipt_row_id': 42,
      });
      final stored = (await outbox.draft(draft.key))!;
      final timeline = TimelineKey(
        stored.connection,
        stored.profile,
        stored.storedSessionId!,
      );
      final resumed = await outbox.resume(timeline);
      await outbox.reconcile(timeline, resumed, [42]);
      pieces = await outbox.attachments(draft.key);
      expect(
        pieces.every((a) => !a.cleaned && File(a.localPath).existsSync()),
        isTrue,
      );
    },
  );

  test(
    'partial refusal keeps success and draft; explicit retry reuses success',
    () async {
      await add('a.pdf', 'application/pdf');
      await add('b.pdf', 'application/pdf');
      var fail = true;
      h.transport.rpc = (method, params) => switch (method) {
        'session.create' => created(),
        'file.attach' =>
          params['name'] == 'a.pdf'
              ? {'attached': true, 'ref_text': '@file:a.pdf'}
              : fail
              ? {'attached': false}
              : {'attached': true, 'ref_text': '@file:b.pdf'},
        'prompt.submit' => submitted(),
        'session.history' => {'messages': []},
        _ => null,
      };
      await outbox.send(draft.key);
      expect(calls('prompt.submit'), 0);
      var pieces = await outbox.attachments(draft.key);
      expect(pieces.map((a) => a.state), [
        AttachmentState.uploaded,
        AttachmentState.failed,
      ]);
      expect((await outbox.draft(draft.key))!.body, 'Bonjour');
      await outbox.send(draft.key);
      expect(calls('file.attach'), 2);
      await outbox.retryAttachment(draft.key, pieces.last.key);
      fail = false;
      await outbox.send(draft.key);
      expect(calls('file.attach'), 3);
      expect(calls('prompt.submit'), 1);
      pieces = await outbox.attachments(draft.key);
      expect(pieces.every((a) => a.sent), isTrue);
      final attempts = await db.query(
        'outbox_operation_attachments',
        orderBy: 'rowid',
      );
      expect(attempts, hasLength(4));
      expect(attempts.take(2).map((r) => r['state']), [
        AttachmentState.uploaded.name,
        AttachmentState.failed.name,
      ]);
      expect(attempts.skip(2).map((r) => r['state']), [
        AttachmentState.uploaded.name,
        AttachmentState.uploaded.name,
      ]);
      expect(
        attempts.every(
          (r) =>
              r['profile_key'] == 'default' &&
              r['stored_session_id'] == '<SYNTHETIC_STORED_SESSION>',
        ),
        isTrue,
      );
    },
  );

  test(
    'invalid response is uncertain and never prompts or retries itself',
    () async {
      await add('a.pdf', 'application/pdf');
      h.transport.rpc = (method, params) => switch (method) {
        'session.create' => created(),
        'file.attach' => {'attached': true},
        _ => null,
      };
      await outbox.send(draft.key);
      expect(
        (await outbox.attachments(draft.key)).single.state,
        AttachmentState.uncertain,
      );
      await outbox.send(draft.key);
      expect(calls('file.attach'), 1);
      expect(calls('prompt.submit'), 0);
      expect((await outbox.draft(draft.key))!.body, 'Bonjour');
    },
  );

  test('restart changes in-flight upload to uncertain', () async {
    await add('a.pdf', 'application/pdf');
    final piece = (await outbox.attachments(draft.key)).single;
    await db.update(
      'outbox_attachments',
      {'state': AttachmentState.uploading.name},
      where: 'attachment_key = ?',
      whereArgs: [piece.key],
    );
    await outbox.dispose();
    await db.close();
    await open();
    expect(
      (await outbox.attachments(draft.key)).single.state,
      AttachmentState.uncertain,
    );
    await outbox.send(draft.key);
    expect(calls('file.attach'), 0);
    expect(calls('prompt.submit'), 0);
  });

  test('socket loss during upload is uncertain and never prompts', () async {
    await add('a.pdf', 'application/pdf');
    h.transport.rpc = (method, params) => switch (method) {
      'session.create' => created(),
      'file.attach' => const RpcDrop(),
      _ => null,
    };
    await outbox.send(draft.key);
    expect(
      (await outbox.attachments(draft.key)).single.state,
      AttachmentState.uncertain,
    );
    expect(calls('prompt.submit'), 0);
  });

  test('image reference echoed by prompt is not receipt proof', () async {
    await add('b.png', 'image/png');
    h.transport.rpc = (method, params) => switch (method) {
      'session.create' => created(),
      'image.attach_bytes' => {
        'attached': true,
        'text': '@image:/server/b.png',
      },
      'prompt.submit' => submitted(),
      'session.history' => {
        'messages': [
          {
            'role': 'user',
            'row_id': 42,
            'content': '@image:/server/b.png\nBonjour',
          },
        ],
      },
      _ => null,
    };
    await outbox.send(draft.key);
    expect(
      (await outbox.attachments(draft.key)).single.state,
      AttachmentState.uploaded,
    );
  });

  test('server image reference before prompt proves receipt', () async {
    await add('b.png', 'image/png');
    h.transport.rpc = (method, params) => switch (method) {
      'session.create' => created(),
      'image.attach_bytes' => {
        'attached': true,
        'text': '@image:/server/b.png',
      },
      'prompt.submit' => submitted(),
      'session.history' => {
        'messages': [
          {
            'role': 'user',
            'row_id': 42,
            'content': '@image:/server/b.png\n@image:/server/b.png\nBonjour',
          },
        ],
      },
      _ => null,
    };
    await outbox.send(draft.key);
    expect(
      (await outbox.attachments(draft.key)).single.state,
      AttachmentState.received,
    );
  });

  test(
    'profile selection elsewhere cannot redirect the frozen target',
    () async {
      await add('a.pdf', 'application/pdf');
      h.transport.rpc = (method, params) => switch (method) {
        'session.create' => created(),
        'file.attach' => {'attached': true, 'ref_text': '@file:a.pdf'},
        'prompt.submit' => submitted(),
        'session.history' => {'messages': []},
        _ => null,
      };
      await h.repository.selectProfile(const ProfileKey('travail'));
      await outbox.send(draft.key);
      final attach = h.transport.frames.firstWhere(
        (f) => f['method'] == 'file.attach',
      );
      expect((attach['params'] as Map)['profile'], 'default');
      expect(
        (await outbox.draft(draft.key))!.profile,
        const ProfileKey('default'),
      );
    },
  );

  test('JPEG sends original bytes with the verified image extension', () async {
    await add('a.jpeg', 'image/jpeg');
    h.transport.rpc = (method, params) {
      if (method == 'image.attach_bytes') {
        expect(params['session_id'], created()['session_id']);
        expect(params['profile'], 'default');
        expect(params['filename'], 'a.jpeg');
        expect(params['ext'], 'jpg');
        expect(params.containsKey('path'), isFalse);
        expect(base64Decode(params['content_base64'] as String), [1, 2, 3]);
      }
      return switch (method) {
        'session.create' => created(),
        'image.attach_bytes' => {
          'attached': true,
          'text': '@image:/server/a.jpeg',
        },
        'prompt.submit' => submitted(),
        'session.history' => {
          'messages': [
            {
              'role': 'user',
              'row_id': 42,
              'content':
                  '@image:/server/a.jpeg\n'
                  '@image:/server/a.jpeg\nBonjour',
            },
          ],
        },
        _ => null,
      };
    };
    await outbox.send(draft.key);
    expect(outbox.status(draft.key).state, OperationState.accepted);
    expect(calls('image.attach_bytes'), 1);
    expect(calls('file.attach'), 0);
    expect(calls('prompt.submit'), 1);
    expect(
      (await outbox.attachments(draft.key)).single.state,
      AttachmentState.received,
    );
  });

  test('JPEG is supported only through its measured byte ceiling', () {
    expect(limits.categoryOf('image/jpeg'), AttachmentCategory.image);
    expect(limits.refusal('image/jpeg', 20965448), isNull);
    expect(limits.refusal('image/jpeg', 20965449), 'attachment.size');
    expect(limits.refusal('image/heic', 1), 'attachment.type');
  });

  test('oversized JPEG is refused before creating a remote session', () async {
    await add('a.jpg', 'image/jpeg');
    await db.update(
      'outbox_attachments',
      {'bytes': 20965449},
      where: 'draft_key = ?',
      whereArgs: [draft.key.value],
    );

    await outbox.send(draft.key);

    expect(outbox.status(draft.key).errorCode, 'attachment.size');
    expect(calls('session.create'), 0);
    expect(calls('image.attach_bytes'), 0);
    expect(calls('prompt.submit'), 0);
  });

  test('received image and uncertain receipt labels remain distinct', () {
    expect(
      Content.attachmentStatus(AttachmentState.uploaded, false, null),
      contains('réception à vérifier'),
    );
    expect(
      Content.attachmentStatus(AttachmentState.received, true, null),
      contains('Reçu'),
    );
    expect(Content.attachmentVisionUnknown, isNot(contains('sera analysée')));
  });

  for (final image in [false, true]) {
    test('preuve exacte, sans collision de préfixe (${image ? 'PNG' : 'PDF'})', () async {
      final type = image ? 'image/png' : 'application/pdf';
      final name = image ? 'a.png' : 'a.pdf';
      final short = image ? '@image:/server/$name' : '@file:$name';
      final long = '$short.backup';
      await add(name, type);
      await add('$name.backup', type);
      String? prompt;
      h.transport.rpc = (method, params) {
        if (method == 'prompt.submit') {
          prompt = params['text'] as String;
          return submitted();
        }
        return switch (method) {
          'session.create' => created(),
          'file.attach' || 'image.attach_bytes' => {
            'attached': true,
            image ? 'text' : 'ref_text':
                (params[image ? 'filename' : 'name'] == name) ? short : long,
          },
          'session.history' => {
            'messages': [
              {
                'role': 'user',
                'row_id': 42,
                'content':
                    '$prompt\n${image ? '' : '--- Attached Context ---\n'}$long',
              },
            ],
          },
          _ => null,
        };
      };
      await outbox.send(draft.key);
      expect((await outbox.attachments(draft.key)).map((a) => a.state), [
        AttachmentState.uploaded,
        AttachmentState.received,
      ]);
    });
  }

  test(
    'ancien message identique sans identifiant courant ne prouve rien',
    () async {
      await add('a.pdf', 'application/pdf');
      h.transport.rpc = (method, params) => switch (method) {
        'session.create' => created(),
        'file.attach' => {'attached': true, 'ref_text': '@file:a.pdf'},
        'prompt.submit' => {'status': 'streaming'},
        'session.history' => {
          'messages': [
            {
              'role': 'user',
              'row_id': 1,
              'content':
                  '@file:a.pdf\nBonjour\n--- Attached Context ---\n@file:a.pdf',
            },
          ],
        },
        _ => null,
      };
      await outbox.send(draft.key);
      expect(
        (await outbox.attachments(draft.key)).single.state,
        AttachmentState.uploaded,
      );
    },
  );

  for (final invalid in [true, false]) {
    test(
      invalid
          ? 'accusé image sans référence exploitable bloque le prompt'
          : 'erreur serveur interne laisse la pièce incertaine',
      () async {
        await add('a.png', 'image/png');
        h.transport.rpc = (method, params) => switch (method) {
          'session.create' => created(),
          'image.attach_bytes' =>
            invalid ? {'attached': true, 'text': 'OK'} : const RpcFail(-32603),
          _ => null,
        };
        await outbox.send(draft.key);
        expect(calls('prompt.submit'), 0);
        expect(
          (await outbox.attachments(draft.key)).single.state,
          AttachmentState.uncertain,
        );
      },
    );
  }

  test('session déjà active : aucune pièce téléversée', () async {
    await add('a.pdf', 'application/pdf');
    h.transport.rpc = (method, params) => switch (method) {
      'session.create' => created(),
      'session.resume' => {
        ...Map<String, dynamic>.from(
          fixture('session-resume')['result'] as Map,
        ),
        'running': true,
      },
      _ => null,
    };
    await outbox.ensureSession(draft.key);
    await h.repository.reconnect();
    await outbox.send(draft.key);
    expect(calls('file.attach'), 0);
    expect(calls('prompt.submit'), 0);
    expect(outbox.status(draft.key).errorCode, 'send.turn_active');
  });

  for (final changeConnection in [false, true]) {
    test(
      'changement ${changeConnection ? 'de connexion' : 'de génération'} entre pièces arrête le pipeline',
      () async {
        await add('a.pdf', 'application/pdf');
        await add('b.pdf', 'application/pdf');
        await outbox.dispose();
        final scoped = ScopedGateway(h.repository);
        outbox = OutboxRepository(
          db,
          gateway: scoped,
          attachmentFiles: AttachmentFiles(root: () async => directory),
          loadFileLimits: () async => limits,
        );
        scoped.afterCall = (method) {
          if (method == 'file.attach') {
            if (changeConnection) {
              scoped.otherConnection = true;
            } else {
              scoped.extraGeneration++;
            }
          }
        };
        h.transport.rpc = (method, params) => switch (method) {
          'session.create' => created(),
          'file.attach' => {'attached': true, 'ref_text': '@file:a.pdf'},
          _ => null,
        };
        await outbox.send(draft.key);
        expect(calls('file.attach'), 1);
        expect(calls('prompt.submit'), 0);
        expect(
          (await outbox.attachments(draft.key)).first.state,
          AttachmentState.uncertain,
        );
      },
    );
  }

  test('échec de relecture avant prompt libère le brouillon et conserve les copies', () async {
    await outbox.dispose();
    final files = ReadFailureFiles(directory);
    outbox = OutboxRepository(
      db,
      gateway: h.repository,
      attachmentFiles: files,
      loadFileLimits: () async => limits,
      onStep: (step) {
        if (step == 'notificationTracking') files.fail = true;
      },
    );
    await add('a.pdf', 'application/pdf');
    h.transport.rpc = (method, params) => switch (method) {
      'session.create' => created(),
      'file.attach' => {'attached': true, 'ref_text': '@file:a.pdf'},
      _ => null,
    };
    await outbox.send(draft.key);
    expect(calls('prompt.submit'), 0);
    expect(outbox.status(draft.key).busy, isFalse);
    expect((await outbox.draft(draft.key))!.body, 'Bonjour');
    files.fail = false;
    expect(
      File((await outbox.attachments(draft.key)).single.localPath).existsSync(),
      isTrue,
    );
  });

  for (final lostResponse in [true, false]) {
    test(
      lostResponse
          ? 'réponse perdue rapprochée : anciennes pièces exclues du prochain envoi'
          : 'commit accepté en échec : aucun renvoi avant rapprochement',
      () async {
        await add('a.pdf', 'application/pdf');
        if (!lostResponse) {
          await db.execute(
            "CREATE TRIGGER fail_accept BEFORE UPDATE OF state ON outbox_operations "
            "WHEN NEW.state = 'accepted' BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
          );
        }
        var lose = lostResponse;
        h.transport.rpc = (method, params) => switch (method) {
          'session.create' => created(),
          'session.resume' => Map<String, dynamic>.from(
            fixture('session-resume')['result'] as Map,
          ),
          'file.attach' => {'attached': true, 'ref_text': '@file:a.pdf'},
          'prompt.submit' => lose ? const RpcDrop() : submitted(),
          'session.history' => {
            'messages': [
              {
                'role': 'user',
                'row_id': 42,
                'content': '@file:a.pdf\nBonjour\n--- Attached Context ---\n@file:a.pdf',
              },
            ],
          },
          _ => null,
        };
        await outbox.send(draft.key);
        expect(outbox.status(draft.key).state, OperationState.unknown);
        // Le repère représente l'historique vide connu avant la demande.
        await db.update('outbox_operations', {'row_watermark': 0});
        if (lostResponse) await h.repository.reconnect();
        await outbox.send(draft.key);
        expect(calls('prompt.submit'), 1);
        if (!lostResponse) await db.execute('DROP TRIGGER fail_accept');
        final original = (await outbox.draft(draft.key))!;
        final key = TimelineKey(
          original.connection,
          original.profile,
          original.storedSessionId!,
        );
        final resumed = await outbox.resume(key);
        await outbox.reconcile(key, resumed, [42]);
        expect((await outbox.attachments(draft.key)).single.sent, isTrue);
        expect(
          (await outbox.attachments(draft.key)).single.state,
          AttachmentState.received,
        );
        lose = false;
        await outbox.saveText(draft.key, 'Encore');
        await outbox.send(draft.key);
        expect(calls('file.attach'), 1);
        expect(calls('prompt.submit'), 2);
        expect(
          (h.transport.frames.lastWhere(
                (f) => f['method'] == 'prompt.submit',
              )['params']
              as Map)['text'],
          'Encore',
        );
      },
    );
  }

  testWidgets(
    'page réelle : réessayer remet la pièce en attente puis permet l’envoi',
    (tester) async {
      await tester.runAsync(() => add('a.pdf', 'application/pdf'));
      var refuse = true;
      h.transport.rpc = (method, params) => switch (method) {
        'session.create' => created(),
        'file.attach' =>
          refuse
              ? {'attached': false}
              : {'attached': true, 'ref_text': '@file:a.pdf'},
        'prompt.submit' => submitted(),
        'session.history' => {'messages': []},
        _ => null,
      };
      await tester.runAsync(() => outbox.send(draft.key));
      late DraftViewModel vm;
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
            ),
          ),
        ),
      );
      Future<void> flush() async {
        await tester.pump();
        // Drain native SQLite work before leaving the fake widget-test clock.
        await tester.runAsync(() async {
          await outbox.attachments(draft.key);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pump();
      }

      for (
        var i = 0;
        i < 30 && find.text(Content.attachmentRetry).evaluate().isEmpty;
        i++
      ) {
        await flush();
      }
      expect(vm.attachments.single.state, AttachmentState.failed);
      await tester.tap(find.text(Content.attachmentRetry));
      for (
        var i = 0;
        i < 30 && vm.attachments.single.state != AttachmentState.selected;
        i++
      ) {
        await flush();
      }
      expect(vm.attachments.single.state, AttachmentState.selected);
      expect(vm.blockedReason, isNull);
      refuse = false;
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip(Content.send));
        for (
          var i = 0;
          i < 200 && outbox.status(draft.key).state != OperationState.accepted;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
      expect(outbox.status(draft.key).state, OperationState.accepted);
      expect(calls('file.attach'), 2);
      expect(calls('prompt.submit'), 1);
      await flush();
      await flush();
      await tester.pumpWidget(const SizedBox());
      await flush();
    },
  );

  test(
    'pièce seule acceptée : nom visible dans la projection locale',
    () async {
      await outbox.dispose();
      final conversation = ConversationRepository(
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
      await outbox.saveText(draft.key, '');
      await add('rapport.pdf', 'application/pdf');
      h.transport.rpc = (method, params) => switch (method) {
        'session.create' => created(),
        'file.attach' => {'attached': true, 'ref_text': '@file:rapport.pdf'},
        'prompt.submit' => submitted(),
        'session.history' => {'messages': []},
        _ => null,
      };
      try {
        await outbox.send(draft.key);
        final current = (await outbox.draft(draft.key))!;
        final key = TimelineKey(
          current.connection,
          current.profile,
          current.storedSessionId!,
        );
        expect(
          conversation
              .projection(key)
              .items
              .whereType<UserItem>()
              .single
              .attachments
              .single
              .name,
          'rapport.pdf',
        );
      } finally {
        await conversation.dispose();
      }
    },
  );

  test('preuve différée à la fin du tour, sans renvoi', () async {
    await add('a.pdf', 'application/pdf');
    var proved = false;
    h.transport.rpc = (method, params) => switch (method) {
      'session.create' => created(),
      'file.attach' => {'attached': true, 'ref_text': '@file:a.pdf'},
      'prompt.submit' => submitted(),
      'session.history' => {
        'messages': proved
            ? [
                {
                  'role': 'user',
                  'row_id': 42,
                  'content': '@file:a.pdf\nBonjour\n--- Attached Context ---\n@file:a.pdf',
                },
              ]
            : [],
      },
      _ => null,
    };
    await outbox.send(draft.key);
    expect(
      (await outbox.attachments(draft.key)).single.state,
      AttachmentState.uploaded,
    );
    proved = true;
    h.transport.sockets.last.controller.add({
      'jsonrpc': '2.0',
      'method': 'event',
      'params': {
        'type': 'message.complete',
        'session_id': created()['session_id'],
        'payload': <String, dynamic>{},
      },
    });
    for (var i = 0; i < 100; i++) {
      if ((await outbox.attachments(draft.key)).single.state ==
          AttachmentState.received) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      (await outbox.attachments(draft.key)).single.state,
      AttachmentState.received,
    );
    expect(calls('file.attach'), 1);
    expect(calls('prompt.submit'), 1);
  });

  testWidgets('each attachment exposes a text state and explicit retry', (
    tester,
  ) async {
    final pieces = [
      const Attachment(
        key: 'a',
        name: 'a.pdf',
        mediaType: 'application/pdf',
        bytes: 3,
        localPath: '',
        state: AttachmentState.uploading,
      ),
      const Attachment(
        key: 'b',
        name: 'b.pdf',
        mediaType: 'application/pdf',
        bytes: 3,
        localPath: '',
        state: AttachmentState.received,
        sent: true,
      ),
      const Attachment(
        key: 'c',
        name: 'c.pdf',
        mediaType: 'application/pdf',
        bytes: 3,
        localPath: '',
        state: AttachmentState.failed,
        errorCode: 'attachment.refused',
      ),
    ];
    Attachment? retried;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentList(
            attachments: pieces,
            onRetry: (a) => retried = a,
          ),
        ),
      ),
    );
    expect(find.text('Téléversement en cours'), findsOneWidget);
    expect(find.text('Reçu dans la conversation'), findsOneWidget);
    expect(find.textContaining('Envoi refusé'), findsOneWidget);
    await tester.tap(find.text(Content.attachmentRetry));
    expect(retried?.key, 'c');
  });
}
