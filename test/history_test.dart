import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes_mobile/app/routes.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/hermes_adapter.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/features/history/history_view_model.dart';
import 'package:hermes_mobile/main.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/connection_gateway.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/history.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/history_row.dart';
import 'package:hermes_mobile/features/history/history_view.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'contracts_test.dart' show contract;
import 'support/connection_fakes.dart';
import 'support/home_helper.dart';

Map<String, dynamic> _result(String name) =>
    Map<String, dynamic>.from(fixture(name)['result'] as Map);

const _default = ProfileKey('default');
const _travail = ProfileKey('travail');

/// Liste dont chaque appel reste en attente jusqu'à ce que le test l'achève.
class _QueuedLists extends MemoryConversation {
  final pending = <Completer<List<SessionSummary>>>[];
  @override
  Future<List<SessionSummary>> sessions(ConnectionKey c, ProfileKey p) {
    final completer = Completer<List<SessionSummary>>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  sqfliteFfiInit();

  group('décodage de session.list', () {
    test(
      'ordre du serveur, titre sinon aperçu, date, casse des identifiants',
      () {
        final rows = HermesRpc.sessions(_result('session-list'));
        expect(rows.map((r) => r.id), [
          'SYNTHETIC_SESSION_B',
          'SYNTHETIC_SESSION_A',
          'synthetic_session_a',
        ]);
        expect(rows[0].title, 'SYNTHETIC_TITLE');
        expect(rows[0].messageCount, 4);
        expect(
          rows[0].startedAt,
          DateTime.fromMillisecondsSinceEpoch(1760000000500, isUtc: true),
        );
        // Titre vide : seul l'aperçu reste ; rien du tout : libellé générique à l'affichage.
        expect(rows[1].title, isNull);
        expect(rows[1].preview, 'SYNTHETIC_PREVIEW_A');
        expect(rows[2].preview, isNull);
        expect(rows[2].startedAt, isNull);
      },
    );

    test('liste vide, ligne sans id écartée, forme invalide refusée', () {
      expect(HermesRpc.sessions(_result('session-list-empty')), isEmpty);
      expect(
        HermesRpc.sessions({
          'sessions': [
            {'title': 'sans id'},
            {'id': ''},
            {'id': 'x'},
          ],
        }).single.id,
        'x',
      );
      expect(
        () => HermesRpc.sessions({'sessions': 'non'}),
        throwsA(isA<AppError>()),
      );
    });

    test('paramètres : profil et limite par défaut', () {
      expect(HermesRpc.listParams(_travail), {
        'profile': 'travail',
        'limit': 200,
      });
    });
  });

  group('HistoryViewModel : rafraîchissements qui se chevauchent', () {
    for (final failing in [false, true]) {
      test(
        'le plus récent gagne même terminé en premier (${failing ? 'erreur' : 'succès'})',
        () async {
          final h = Harness();
          await h.connect();
          final conversation = _QueuedLists();
          final vm = HistoryViewModel(
            gateway: h.repository,
            conversation: conversation,
            profile: _default,
          );
          addTearDown(() async {
            vm.dispose();
            await h.repository.dispose();
          });
          // Premier chargement (constructeur) en attente, un second le double.
          final first = conversation.pending.single;
          unawaited(vm.refresh());
          final second = conversation.pending.last;
          if (failing) {
            second.completeError(StateError('x'));
          } else {
            second.complete([const SessionSummary(id: 'neuf')]);
          }
          await Future<void>.delayed(Duration.zero);
          // L'ancien, plus lent, aboutit après : il est écarté.
          first.complete([const SessionSummary(id: 'ancien')]);
          await Future<void>.delayed(Duration.zero);
          expect(vm.state, failing ? HistoryState.error : HistoryState.ready);
          expect(vm.sessions.map((s) => s.id), failing ? isEmpty : ['neuf']);
        },
      );
    }
  });

  group('décodage tolérant', () {
    test('message_count numérique quelconque, started_at invalide : liste conservée', () {
      final rows = HermesRpc.sessions({
        'sessions': [
          {'id': 'a', 'message_count': 3.0, 'started_at': 1e30},
          {'id': 'b', 'message_count': -4, 'started_at': double.nan},
          {
            'id': 'c',
            'message_count': double.infinity,
            'started_at': double.infinity,
          },
        ],
      });
      expect(rows.map((r) => r.messageCount), [3, 0, 0]);
      expect(rows.map((r) => r.startedAt), [null, null, null]);
    });
  });

  group('dépôts (SQLite et socket simulés)', () {
    late Database database;
    late Harness h;
    late OutboxRepository outbox;
    late ConversationRepository conversation;
    late ConnectionKey connection;

    setUp(() async {
      database = await openConnectionDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      h = Harness();
      await h.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      connection = h.repository.snapshot.connection!.key;
      conversation = ConversationRepository(
        database,
        gateway: h.repository,
        mapping: EventMapping(contract('event-mapping')),
        timeout: const Duration(milliseconds: 100),
      );
      outbox = OutboxRepository(
        database,
        gateway: h.repository,
        timeout: const Duration(milliseconds: 100),
        conversation: conversation,
      );
    });
    tearDown(() async {
      await outbox.dispose();
      await conversation.dispose();
      await h.repository.dispose();
      await database.close();
    });

    List<Map<String, dynamic>> calls(String method) => [
      for (final f in h.transport.frames)
        if (f['method'] == method) f['params'] as Map<String, dynamic>,
    ];

    test(
      'liste par profil : chaque profil demande et reçoit la sienne',
      () async {
        h.transport.rpc = (method, params) => method != 'session.list'
            ? null
            : {
                'sessions': [
                  {'id': 'de-${params['profile']}', 'message_count': 2},
                ],
              };
        final a = await conversation.sessions(connection, _default);
        final b = await conversation.sessions(connection, _travail);
        expect(a.single.id, 'de-default');
        expect(b.single.id, 'de-travail');
        expect(calls('session.list'), [
          {'profile': 'default', 'limit': 200},
          {'profile': 'travail', 'limit': 200},
        ]);
      },
    );

    test(
      'autre connexion : refus sans requête ; erreur RPC : levée, sans reste',
      () async {
        h.transport.rpc = (method, params) =>
            method == 'session.list' ? const RpcFail(5035) : null;
        await expectLater(
          conversation.sessions(const ConnectionKey('autre'), _default),
          throwsA(isA<AppError>()),
        );
        expect(calls('session.list'), isEmpty);
        await expectLater(
          conversation.sessions(connection, _default),
          throwsA(isA<RpcError>()),
        );
        h.transport.rpc = (method, params) =>
            method == 'session.list' ? _result('session-list-empty') : null;
        expect(await conversation.sessions(connection, _default), isEmpty);
      },
    );

    test('brouillon de suite : get-or-create par (connexion, profil, session), casse respectée', () async {
      final abc = await outbox.openContinuation(connection, _default, 'abc');
      expect(abc.storedSessionId, 'abc');
      expect(abc.body, isEmpty);
      expect(
        (await outbox.openContinuation(connection, _default, 'abc')).key,
        abc.key,
      );
      final upper = await outbox.openContinuation(connection, _default, 'Abc');
      final other = await outbox.openContinuation(connection, _travail, 'abc');
      expect({abc.key, upper.key, other.key}, hasLength(3));
      // Deux ouvertures concurrentes : un seul brouillon.
      final both = await Future.wait([
        outbox.openContinuation(connection, _default, 'xyz'),
        outbox.openContinuation(connection, _default, 'xyz'),
      ]);
      expect(both[0].key, both[1].key);
      // Les textes restent séparés.
      await outbox.saveText(abc.key, 'a');
      await outbox.saveText(upper.key, 'U');
      expect((await outbox.draft(abc.key))!.body, 'a');
      expect((await outbox.draft(upper.key))!.body, 'U');
    });

    test('index unique en base ; accueil sans session même si un brouillon de suite a du texte', () async {
      final abc = await outbox.openContinuation(connection, _default, 'abc');
      await outbox.saveText(abc.key, 'suite');
      await expectLater(
        database.insert('outbox_drafts', {
          'draft_key': 'doublon',
          'connection_key': connection.value,
          'profile_key': 'default',
          'stored_session_id': 'abc',
          'body': '',
          'updated_at': 'x',
        }),
        throwsA(isA<DatabaseException>()),
      );
      final home = await outbox.openNewDraft(connection, _default);
      expect(home.key, isNot(abc.key));
      expect(home.storedSessionId, isNull);
      expect(home.body, isEmpty);
      // Retrouvé par l'historique, texte intact.
      final again = await outbox.openContinuation(connection, _default, 'abc');
      expect((again.key, again.body), (abc.key, 'suite'));
    });

    test('brouillon d\'une conversation créée ici : retrouvé tel quel par la liste', () async {
      h.transport.rpc = (method, params) => switch (method) {
        'session.create' => _result('session-create'),
        'prompt.submit' => _result('prompt-submit'),
        _ => null,
      };
      final draft = await outbox.openNewDraft(connection, _default);
      await outbox.saveText(draft.key, 'première');
      await outbox.send(draft.key);
      final stored = (await outbox.draft(draft.key))!.storedSessionId!;
      final reopened = await outbox.openContinuation(
        connection,
        _default,
        stored,
      );
      expect(reopened.key, draft.key);
    });

    test(
      'poursuivre : envoi sur la session ouverte, aucune session.create',
      () async {
        h.transport.rpc = (method, params) => switch (method) {
          'session.resume' => {
            ..._result('session-resume'),
            'session_id': 'a1b2c3d4',
          },
          'prompt.submit' => _result('prompt-submit'),
          _ => null,
        };
        final draft = await outbox.openContinuation(
          connection,
          _default,
          'abc',
        );
        await outbox.saveText(draft.key, 'suite');
        await outbox.send(draft.key);
        expect(outbox.status(draft.key).state, OperationState.accepted);
        expect(calls('session.create'), isEmpty);
        expect(calls('session.resume').single, {
          'session_id': 'abc',
          'profile': 'default',
        });
        expect(calls('prompt.submit').single['session_id'], 'a1b2c3d4');
        expect(
          (await conversation.load(TimelineKey(connection, _default, 'abc')))
              .items
              .whereType<UserItem>()
              .single
              .text,
          'suite',
        );
      },
    );
  });

  group('écrans', () {
    Future<Harness> launched() async {
      final previous = Harness();
      await previous.connect();
      final h = Harness();
      h.store.value = previous.store.value;
      h.secrets.values.addAll(previous.secrets.values);
      return h;
    }

    Future<(Harness, MemoryOutbox, MemoryConversation, ConnectionKey)> open(
      WidgetTester tester,
    ) async {
      final h = await launched();
      final outbox = MemoryOutbox();
      final memory = MemoryConversation();
      await tester.pumpWidget(
        MainApp(gateway: h.repository, outbox: outbox, conversation: memory),
      );
      await tester.pumpAndSettle();
      await enterHome(tester);
      return (h, outbox, memory, h.store.value!.key);
    }

    GoRouter router(WidgetTester tester) =>
        GoRouter.of(tester.element(find.byType(Scaffold).last));
    // Page du dessus (une page poussée ne change pas la configuration de base).
    String location(WidgetTester tester) =>
        GoRouterState.of(tester.element(find.byType(Scaffold).last)).uri
            .toString();
    Future<void> go(WidgetTester tester, String path) async {
      unawaited(router(tester).push(path));
      await tester.pumpAndSettle();
    }

    SessionSummary row(String id, {String? title, int count = 1}) =>
        SessionSummary(
          id: id,
          title: title,
          startedAt: DateTime.utc(2026, 10, 21, 9, 30),
          messageCount: count,
        );

    testWidgets(
      'accueil : « Conversations » ouvre la liste du profil, dans l\'ordre serveur, profil annoncé',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final (_, outbox, memory, connection) = await open(tester);
        memory.lists[(connection, _default)] = [
          row('b', title: 'Deuxième', count: 3),
          row('a', title: 'Première'),
        ];
        memory.lists[(connection, _travail)] = [
          row('t', title: 'Travail seul'),
        ];
        final gate = memory.listGate = Completer<void>();
        await tester.tap(find.byTooltip(Content.conversations));
        await tester.pump();
        await tester.pump();
        expect(find.text(Content.historyLoading), findsOne);
        expect(find.byType(HistoryRow), findsNothing);
        gate.complete();
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(HistoryView),
            matching: find.bySemanticsLabel(
              Content.draftProfile('Principal (default)'),
            ),
          ),
          findsOne,
        );
        final titles = tester
            .widgetList<HistoryRow>(find.byType(HistoryRow))
            .map((r) => r.session.id);
        expect(titles, ['b', 'a']);
        final date = Content.historyDate(DateTime.utc(2026, 10, 21, 9, 30));
        expect(find.text('$date · 3 messages'), findsOne);
        expect(
          tester.getSemantics(find.byType(HistoryRow).first),
          isSemantics(label: 'Deuxième\n$date · 3 messages', isButton: true),
        );
        // Aucun brouillon ni session créés par la simple consultation.
        expect(outbox.drafts, hasLength(1));
        // Autre profil : sa liste seule, son profil annoncé.
        // La feuille se referme avant d'ouvrir celle d'un autre profil.
        router(tester).pop();
        await tester.pumpAndSettle();
        await go(tester, historyPath(_travail));
        expect(
          find.descendant(
            of: find.byType(HistoryView),
            matching: find.bySemanticsLabel(
              Content.draftProfile('Travail (travail)'),
            ),
          ),
          findsOne,
        );
        expect(
          tester
              .widgetList<HistoryRow>(find.byType(HistoryRow))
              .map((r) => r.session.id),
          ['t'],
        );
        // Les premières listes viennent de l'accueil (dernière conversation).
        expect(memory.listCalls.skip(memory.listCalls.length - 2), [
          (connection, _default),
          (connection, _travail),
        ]);
        semantics.dispose();
      },
    );

    testWidgets(
      'accueil : un profil avec historique rouvre sa dernière conversation',
      (tester) async {
        final (_, _, memory, connection) = await open(tester);
        memory.lists[(connection, _default)] = [
          row('b', title: 'Deuxième'),
          row('a', title: 'Première'),
        ];
        router(tester).go('/');
        await tester.pumpAndSettle();
        expect(find.text('Deuxième'), findsOne);
        await tester.tap(find.text('Principal (default)'));
        await tester.pumpAndSettle();
        expect(location(tester), conversationPath(connection, _default, 'b'));
      },
    );

    testWidgets(
      'vide, erreur distincte sans liste périmée, actualisation manuelle',
      (tester) async {
        final (_, _, memory, connection) = await open(tester);
        memory.lists[(connection, _default)] = [row('a', title: 'Première')];
        await tester.tap(find.byTooltip(Content.conversations));
        await tester.pumpAndSettle();
        expect(find.byType(HistoryRow), findsOne);
        // Erreur : message distinct, ancienne liste retirée.
        memory.listError = const RpcError(5035);
        await tester.tap(find.byTooltip(Content.refreshHistory));
        await tester.pumpAndSettle();
        expect(find.text(Content.historyError), findsOne);
        expect(find.text(Content.historyEmpty), findsNothing);
        expect(find.byType(HistoryRow), findsNothing);
        // Réessayer, vide.
        memory.listError = null;
        memory.lists[(connection, _default)] = [];
        await tester.tap(find.text(Content.retryList));
        await tester.pumpAndSettle();
        expect(find.text(Content.historyEmpty), findsOne);
        expect(find.text(Content.historyError), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ouvrir une ligne : /c/..., fil chargé, saisie sur le brouillon de cette conversation ; casse distincte',
      (tester) async {
        final (_, outbox, memory, connection) = await open(tester);
        memory.lists[(connection, _default)] = [row('abc'), row('Abc')];
        await tester.tap(find.byTooltip(Content.conversations));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(HistoryRow).first);
        await tester.pumpAndSettle();
        expect(location(tester), conversationPath(connection, _default, 'abc'));
        expect(memory.loaded, [TimelineKey(connection, _default, 'abc')]);
        await tester.enterText(find.byType(TextField), 'texte abc');
        await tester.pumpAndSettle();
        final abc = outbox.drafts.values.singleWhere(
          (d) => d.storedSessionId == 'abc',
        );
        expect(abc.body, 'texte abc');
        // Seconde conversation (identifiant voisin) : brouillon et fil séparés.
        await go(tester, conversationPath(connection, _default, 'Abc'));
        expect(memory.loaded.last, TimelineKey(connection, _default, 'Abc'));
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        await tester.enterText(find.byType(TextField), 'texte Abc');
        await tester.pumpAndSettle();
        expect(
          outbox.drafts.values.where((d) => d.storedSessionId != null),
          hasLength(2),
        );
        expect(
          outbox.drafts.values
              .singleWhere((d) => d.storedSessionId == 'abc')
              .body,
          'texte abc',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('échec de reprise : message, brouillon intact', (tester) async {
      final (_, outbox, memory, connection) = await open(tester);
      final key = TimelineKey(connection, _default, 'abc');
      memory.failedKeys.add(key);
      await go(tester, conversationPath(connection, _default, 'abc'));
      expect(find.text(Content.resumeFailed), findsOne);
      await tester.enterText(find.byType(TextField), 'gardé');
      await tester.pumpAndSettle();
      expect(
        outbox.drafts.values
            .singleWhere((d) => d.storedSessionId == 'abc')
            .body,
        'gardé',
      );
      memory.resyncingKeys.add(key);
      memory.set(key, const TimelineProjection());
      await tester.pumpAndSettle();
      expect(find.text(Content.resumeFailed), findsNothing);
    });

    testWidgets(
      'autre connexion : retour à l\'accueil, aucun brouillon de suite',
      (tester) async {
        final (_, outbox, memory, _) = await open(tester);
        await go(
          tester,
          conversationPath(const ConnectionKey('autre'), _default, 'abc'),
        );
        expect(Uri.parse(location(tester)).path, '/');
        expect(
          outbox.drafts.values.where((d) => d.storedSessionId != null),
          isEmpty,
        );
        expect(memory.loaded, isEmpty);
      },
    );

    testWidgets(
      '« Nouvelle conversation » depuis /c/... : brouillon neuf du profil, sans session',
      (tester) async {
        final (_, outbox, _, connection) = await open(tester);
        await go(tester, conversationPath(connection, _travail, 'abc'));
        await tester.enterText(find.byType(TextField), 'suite');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(Content.newConversation));
        await tester.pumpAndSettle();
        final fresh = outbox.drafts.values.singleWhere(
          (d) => d.key.value == location(tester).split('/').last,
        );
        expect(fresh.storedSessionId, isNull);
        expect(fresh.profile, _travail);
        expect(fresh.body, isEmpty);
        // Le texte de suite reste sur son brouillon.
        expect(
          outbox.drafts.values
              .singleWhere((d) => d.storedSessionId == 'abc')
              .body,
          'suite',
        );
        // Depuis l'historique aussi.
        await tester.tap(find.byTooltip(Content.conversations));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(HistoryView),
            matching: find.byTooltip(Content.newConversation),
          ),
        );
        await tester.pumpAndSettle();
        expect(location(tester), '/draft/${fresh.key.value}');
      },
    );

    testWidgets(
      'sans authentification : /history et /c mènent à la connexion',
      (tester) async {
        final h = await launched();
        h.transport.ticketStatus = 500;
        final outbox = MemoryOutbox();
        await tester.pumpWidget(
          MainApp(
            gateway: h.repository,
            outbox: outbox,
            conversation: MemoryConversation(),
          ),
        );
        await tester.pumpAndSettle();
        await enterHome(tester);
        h.transport.profilesStatus = 401;
        h.transport.refreshStatus = 401;
        h.transport.loginStatus = 401;
        unawaited(h.repository.refreshProfiles());
        await tester.pumpAndSettle();
        expect(h.repository.snapshot.authenticated, isFalse);
        for (final path in [
          historyPath(_default),
          conversationPath(const ConnectionKey('c'), _default, 'abc'),
        ]) {
          router(tester).go(path);
          await tester.pumpAndSettle();
          expect(find.text(Content.connectTitle), findsOne, reason: path);
        }
        expect(
          outbox.drafts.values.where((d) => d.storedSessionId != null),
          isEmpty,
        );
      },
    );

    testWidgets('/?profile=inconnu : brouillon du profil courant', (
      tester,
    ) async {
      final (_, outbox, _, _) = await open(tester);
      final home = outbox.drafts.values.single;
      router(tester).go('/?profile=inconnu');
      await tester.pumpAndSettle();
      expect(location(tester), '/draft/${home.key.value}');
      expect(outbox.drafts, hasLength(1));
    });

    testWidgets(
      '/c/... avec stockage en échec : erreur, « Réessayer » rouvre',
      (tester) async {
        final (_, outbox, _, connection) = await open(tester);
        outbox.failOpen = true;
        await go(tester, conversationPath(connection, _default, 'abc'));
        expect(find.text(Content.error('storage.unavailable')), findsOne);
        expect(find.byType(TextField), findsNothing);
        outbox.failOpen = false;
        await tester.tap(find.text(Content.retryList));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOne);
        expect(find.text(Content.error('storage.unavailable')), findsNothing);
      },
    );

    testWidgets('/c/... : profil en lecture seule, aucun sélecteur', (
      tester,
    ) async {
      final (_, _, _, connection) = await open(tester);
      await go(tester, conversationPath(connection, _default, 'abc'));
      final label = find.bySemanticsLabel(
        Content.draftProfile('Principal (default)'),
      );
      expect(label, findsOne);
      expect(
        find.ancestor(of: label, matching: find.byType(TextButton)),
        findsNothing,
      );
    });

    testWidgets('limite atteinte : note ; en dessous : aucune', (tester) async {
      final (_, _, memory, connection) = await open(tester);
      memory.lists[(connection, _default)] = [
        for (var i = 0; i < sessionListLimit; i++) row('s$i', title: 'T$i'),
      ];
      await tester.tap(find.byTooltip(Content.conversations));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(Content.historyLimitNote),
        500,
        scrollable: find
            .descendant(
              of: find.byType(HistoryView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text(Content.historyLimitNote), findsOne);
      memory.lists[(connection, _default)] = [row('a', title: 'A')];
      await tester.fling(
        find
            .descendant(
              of: find.byType(HistoryView),
              matching: find.byType(Scrollable),
            )
            .first,
        const Offset(0, 100000),
        100000,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(Content.refreshHistory));
      await tester.pumpAndSettle();
      expect(find.text(Content.historyLimitNote), findsNothing);
    });

    for (final size in [const Size(375, 700), const Size(700, 375)]) {
      testWidgets(
        '200 % : historique et conversation sans débordement ($size)',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final semantics = tester.ensureSemantics();
          final (_, _, memory, connection) = await open(tester);
          memory.lists[(connection, _default)] = [
            row(
              'a',
              title:
                  'Un titre de conversation assez long pour passer à la ligne',
              count: 12,
            ),
          ];
          await tester.tap(find.byTooltip(Content.conversations));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byType(HistoryRow),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(HistoryView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.byType(HistoryRow), findsOne);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.byType(HistoryRow));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(HistoryRow));
          await tester.pumpAndSettle();
          expect(find.byTooltip(Content.newConversation), findsOne);
          expect(find.byType(TextField), findsOne);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }
  });
}
