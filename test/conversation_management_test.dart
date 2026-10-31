// Stories 7.4 (masquer), 7.5 (supprimer), 7.6 (rechercher). `session.set_hidden`
// et `session.delete` ne sont pas qualifiées sur installation : ces tests
// simulent le contrat documentaire et ne prouvent pas Hermes installé.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/app/routes.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/storage/attachment_files.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/features/history/history_view_model.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/conversation_search.dart';
import 'package:hermes_mobile/models/history.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'contracts_test.dart' show contract;
import 'support/connection_fakes.dart';

const _default = ProfileKey('default');

Matcher _code(String code) =>
    isA<AppError>().having((e) => e.code, 'code', code);

Future<void> until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(done(), isTrue);
}

void main() {
  sqfliteFfiInit();

  group('repository (socket simulée)', () {
    late Database database;
    late Harness h;
    late OutboxRepository outbox;
    late ConversationRepository conversation;
    late ConnectionKey connection;
    late TimelineKey key;
    late Directory files;

    ConversationRepository repo() => ConversationRepository(
      database,
      gateway: h.repository,
      mapping: EventMapping(contract('event-mapping')),
      timeout: const Duration(milliseconds: 100),
    );
    OutboxRepository box(ConversationRepository c) => OutboxRepository(
      database,
      gateway: h.repository,
      timeout: const Duration(milliseconds: 100),
      conversation: c,
      attachmentFiles: AttachmentFiles(root: () async => files),
    );

    setUp(() async {
      files = await Directory.systemTemp.createTemp('hermes-delete-');
      database = await openConnectionDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      h = Harness();
      await h.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      connection = h.repository.snapshot.connection!.key;
      key = TimelineKey(connection, _default, 'Stored_A');
      conversation = repo();
      outbox = box(conversation);
    });
    tearDown(() async {
      await outbox.dispose();
      await conversation.dispose();
      await h.repository.dispose();
      await database.close();
      await files.delete(recursive: true);
    });

    List<Map<String, dynamic>> calls(String method) => [
      for (final f in h.transport.frames)
        if (f['method'] == method) f['params'] as Map<String, dynamic>,
    ];

    group('7.4 masquer', () {
      test('ID stocké, état confirmé rendu', () async {
        h.transport.rpc = (m, p) => m == 'session.set_hidden'
            ? {'hidden': p['hidden'], 'session_key': 'k'}
            : null;
        expect(await conversation.setHidden(key, true), isTrue);
        expect(calls('session.set_hidden').single, {
          'session_id': 'Stored_A',
          'hidden': true,
          'profile': 'default',
        });
        expect(await conversation.setHidden(key, false), isFalse);
      });

      test('absente, refusée, réponse perdue sans rejeu', () async {
        h.transport.rpc = (m, p) => const RpcFail(4004);
        await expectLater(
          conversation.setHidden(key, true),
          throwsA(_code('hide.refused')),
        );
        h.transport.rpc = (m, p) => null;
        await expectLater(
          conversation.setHidden(key, true),
          throwsA(_code('rpc.uncertain')),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(calls('session.set_hidden'), hasLength(2));
        h.transport.rpc = (m, p) => const RpcFail(-32601);
        await expectLater(
          conversation.setHidden(key, true),
          throwsA(_code('hide.missing')),
        );
        expect(conversation.hideMissing(connection), isTrue);
      });

      test('masquées = include_hidden moins la liste par défaut', () async {
        h.transport.rpc = (m, p) => m == 'session.list'
            ? {
                'sessions': [
                  {'id': 'A'},
                  if (p['include_hidden'] == true) {'id': 'H'},
                ],
              }
            : null;
        final hidden = await conversation.hiddenSessions(connection, _default);
        expect([for (final s in hidden) s.id], ['H']);
      });
    });

    group('7.5 supprimer', () {
      Future<int> drafts() async => (await database.query(
        'outbox_drafts',
        where: 'stored_session_id = ?',
        whereArgs: ['Stored_A'],
      )).length;

      Future<void> seed() async {
        final draft = await outbox.openContinuation(
          connection,
          _default,
          'Stored_A',
        );
        await outbox.saveText(draft.key, 'brouillon');
        await conversation.setPinned(key, true);
        // Autre fil : rien ne doit le toucher.
        await conversation.setPinned(
          TimelineKey(connection, _default, 'Stored_B'),
          true,
        );
      }

      test('succès : un appel, tombstone, données locales du seul fil '
          'effacées, liste filtrée', () async {
        await seed();
        h.transport.rpc = (m, p) => switch (m) {
          'session.delete' => {'deleted': 'Stored_A'},
          'session.list' => {
            'sessions': [
              {'id': 'Stored_A'},
              {'id': 'Stored_B'},
            ],
          },
          _ => null,
        };
        await conversation.delete(key);
        expect(calls('session.delete').single, {
          'session_id': 'Stored_A',
          'profile': 'default',
        });
        expect(await drafts(), 0);
        final marks = await conversation.markers(connection, _default);
        expect(marks.containsKey('Stored_A'), isFalse);
        expect(marks['Stored_B']!.pinned, isTrue);
        expect(await conversation.isDeleted(key), isTrue);
        final list = await conversation.sessions(connection, _default);
        expect([for (final s in list) s.id], ['Stored_B']);
      });

      test('refus : rien effacé, pas de tombstone', () async {
        await seed();
        h.transport.rpc = (m, p) => const RpcFail(4004);
        await expectLater(
          conversation.delete(key),
          throwsA(_code('delete.refused')),
        );
        expect(await drafts(), 1);
        expect(await conversation.isDeleted(key), isFalse);
        expect(
          await conversation.uncertainDeletions(connection, _default),
          isEmpty,
        );
      });

      test('réponse perdue : à vérifier après redémarrage, tout conservé, '
          'aucun rejeu', () async {
        await seed();
        h.transport.rpc = (m, p) => null;
        await expectLater(
          conversation.delete(key),
          throwsA(_code('rpc.uncertain')),
        );
        await outbox.dispose();
        await conversation.dispose();
        conversation = repo();
        outbox = box(conversation);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(await conversation.uncertainDeletions(connection, _default), {
          'Stored_A',
        });
        expect(await drafts(), 1);
        expect(
          (await conversation.markers(
            connection,
            _default,
          ))['Stored_A']!.pinned,
          isTrue,
        );
        expect(calls('session.delete'), hasLength(1));
      });

      test('envoi incertain : refus sans appel', () async {
        final draft = await outbox.openContinuation(
          connection,
          _default,
          'Stored_A',
        );
        await database.insert('outbox_operations', {
          'operation_key': 'op-1',
          'draft_key': draft.key.value,
          'connection_key': connection.value,
          'profile_key': 'default',
          'body': 'x',
          'revision': 1,
          'state': 'unknown',
          'created_at': '2026-10-31',
          'updated_at': '2026-10-31',
        });
        await expectLater(
          conversation.delete(key),
          throwsA(_code('delete.busy')),
        );
        expect(calls('session.delete'), isEmpty);
      });

      test('panne après succès : nettoyage repris sans second appel', () async {
        await seed();
        await database.insert('conversation_deletions', {
          'connection_key': connection.value,
          'profile_key': 'default',
          'stored_session_id': 'Stored_A',
          'state': 'deleted',
        });
        await outbox.dispose();
        await conversation.dispose();
        conversation = repo();
        outbox = box(conversation);
        for (var i = 0; i < 100 && await drafts() > 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(await drafts(), 0);
        expect(calls('session.delete'), isEmpty);
      });

      test(
        'notification tardive : accueil et « conversation supprimée »',
        () async {
          await database.insert('conversation_deletions', {
            'connection_key': connection.value,
            'profile_key': 'default',
            'stored_session_id': 'Stored_A',
            'state': 'deleted',
            'purged': 1,
          });
          var deleted = 0;
          var missing = 0;
          final path = await resolveLaunchTarget(
            h.repository,
            outbox,
            notification: Future.value((
              connection: connection,
              profile: _default,
              session: 'Stored_A',
            )),
            onMissingTarget: () => missing++,
            isDeleted: conversation.isDeleted,
            onDeletedTarget: () => deleted++,
          );
          expect(path, '/');
          expect((deleted, missing), (1, 0));
        },
      );
    });

    test('7.6 textes chargés : messages et réponses du profil', () async {
      await database.insert('conversation_timelines', {
        'connection_key': connection.value,
        'profile_key': 'default',
        'stored_session_id': 'Stored_A',
        'projection': jsonEncode(
          const TimelineProjection(items: [ResponseItem(1, 'Réponse chargée')])
              .toJson(),
        ),
        'updated_at': '2026-10-31',
      });
      final texts = await conversation.loadedTexts(connection, _default);
      expect(texts, {
        'Stored_A': ['Réponse chargée'],
      });
    });
  });

  group('7.6 moteur de recherche', () {
    test('casse et accents ignorés, passage original', () {
      final (start, end) = match('Mon Résumé', 'resume')!;
      expect('Mon Résumé'.substring(start, end), 'Résumé');
      expect(match('Vacances', fold('VACANCES').$1), (0, 8));
      expect(match('rien', 'x'), isNull);
    });

    test('marques combinantes et emoji : limites intactes', () {
      const text = '🚀 Résumé !';
      final (start, end) = match(text, 'resume')!;
      expect(text.substring(start, end), 'Résumé');
      final (s2, e2) = match('a🚀b', '🚀b')!;
      expect('a🚀b'.substring(s2, e2), '🚀b');
    });

    test('titre, aperçu puis contenu chargé ; un résultat par fil', () {
      const p = ProfileKey('p');
      final hits = searchSessions(
        'vacances',
        profile: p,
        sessions: const [
          SessionSummary(id: '1', title: 'Résumé'),
          SessionSummary(id: '2', preview: 'Vacances'),
          SessionSummary(id: '3', title: 'Autre'),
        ],
        texts: {
          '3': ['Parlons de vacances et de vacances encore'],
        },
      );
      expect([for (final h in hits) h.session.id], ['2', '3']);
      expect(hits[1].text.substring(hits[1].start, hits[1].end), 'vacances');
      expect(searchSessions('  ', profile: p, sessions: const []), isEmpty);
    });
  });

  group('HistoryViewModel', () {
    late Harness h;
    late MemoryConversation memory;
    late ConnectionKey connection;
    setUp(() async {
      h = Harness();
      await h.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      connection = h.repository.snapshot.connection!.key;
      memory = MemoryConversation();
      memory.lists[(connection, _default)] = const [
        SessionSummary(id: 'A', title: 'Résumé'),
        SessionSummary(id: 'B', title: 'Budget'),
      ];
    });
    tearDown(() => h.repository.dispose());

    HistoryViewModel vm() => HistoryViewModel(
      gateway: h.repository,
      conversation: memory,
      profile: _default,
    );

    test('masquer après confirmation, « Annuler » confirmé, section '
        '« Masquées »', () async {
      final v = vm();
      await until(() => v.state == HistoryState.ready);
      memory.hideGate = Completer();
      final pending = v.setHidden(v.sessions.first, true);
      expect(v.statusOf('A')!.busy, isTrue);
      expect(v.sessions, hasLength(2)); // rien ne bouge avant confirmation
      memory.hideGate!.complete();
      expect(await pending, isTrue);
      memory.hideGate = null;
      expect([for (final s in v.sessions) s.id], ['B']);
      v.showSection(HistorySection.hidden);
      await until(() => v.state == HistoryState.ready);
      expect([for (final s in v.sessions) s.id], ['A']);
      v.showSection(HistorySection.main);
      await until(() => v.state == HistoryState.ready);
      expect(await v.undoHide(), isTrue);
      await until(() => v.sessions.length == 2);
      v.dispose();
    });

    test('erreurs : le fil reste, message distinct', () async {
      final v = vm();
      await until(() => v.state == HistoryState.ready);
      memory.hideError = const AppError('hide.refused');
      expect(await v.setHidden(v.sessions.first, true), isFalse);
      expect(v.sessions, hasLength(2));
      expect(v.statusOf('A')!.error, 'hide.refused');
      memory.hideError = const AppError('rpc.uncertain');
      await v.setHidden(v.sessions.first, true);
      expect(v.statusOf('A')!.error, 'hide.uncertain');
      memory.deleteError = const AppError('rpc.uncertain');
      expect(await v.delete(v.sessions.last), isFalse);
      expect(v.statusOf('B')!.error, 'delete.uncertain');
      expect(v.sessions, hasLength(2));
      v.dispose();
    });

    test('suppression confirmée : la ligne part ensuite', () async {
      final v = vm();
      await until(() => v.state == HistoryState.ready);
      expect(await v.delete(v.sessions.first), isTrue);
      expect([for (final s in v.sessions) s.id], ['B']);
      expect(memory.deleteCalls, hasLength(1));
      v.dispose();
    });

    test('recherche : locale, tous les profils, requête obsolète écartée, '
        'vide = liste normale', () async {
      memory.texts[TimelineKey(connection, _default, 'B')] = ['un résumé ici'];
      final v = vm();
      await until(() => v.state == HistoryState.ready);
      v.search('resume');
      v.search('budget'); // la première réponse est ignorée
      await until(() => v.searchState == SearchState.done);
      expect([for (final h in v.results[_default]!) h.session.id], ['B']);
      v.search('resume');
      await until(() => v.searchState == SearchState.done);
      expect([for (final h in v.results[_default]!) h.session.id], ['A', 'B']);
      v.search('zzz');
      await until(() => v.searchState == SearchState.done);
      expect(v.results, isEmpty);
      expect(v.searchFailed, isEmpty);
      memory.listError = const AppError('transport.offline');
      v.setAllProfiles(true);
      await until(() => v.searchState == SearchState.done);
      // Le profil courant utilise sa liste chargée ; les autres échouent.
      expect(v.searchFailed.contains(_default), isFalse);
      v.search('  ');
      expect(v.searching, isFalse);
      expect(v.searchState, SearchState.idle);
      v.dispose();
    });
  });
}
