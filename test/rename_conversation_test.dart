// Story 7.2 — renommer une conversation. `session.title` n'est pas qualifiée
// sur installation : ces tests simulent le contrat documentaire et ne prouvent
// pas la compatibilité de Hermes installé.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/hermes_adapter.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/features/history/history_view_model.dart';
import 'package:hermes_mobile/features/history/rename_conversation_dialog.dart';
import 'package:hermes_mobile/main.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/connection_gateway.dart';
import 'package:hermes_mobile/models/history.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/history_row.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'contracts_test.dart' show contract;
import 'support/connection_fakes.dart';
import 'support/home_helper.dart';

const _default = ProfileKey('default');
const _travail = ProfileKey('travail');

Matcher _code(String code) =>
    isA<AppError>().having((e) => e.code, 'code', code);

SessionSummary _row(String id, {String? title}) => SessionSummary(
  id: id,
  title: title,
  startedAt: DateTime.utc(2026, 10, 21, 9, 30),
  messageCount: 2,
);

Future<void> until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(done(), isTrue);
}

/// Listes retenues une à une quand [queue] est vrai.
class _QueuedLists extends MemoryConversation {
  bool queue = false;
  final pending = <Completer<List<SessionSummary>>>[];
  @override
  Future<List<SessionSummary>> sessions(ConnectionKey c, ProfileKey p) {
    if (!queue) return super.sessions(c, p);
    final completer = Completer<List<SessionSummary>>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  sqfliteFfiInit();

  group('dialecte session.title', () {
    test('paramètres : runtime, profil, titre', () {
      expect(HermesRpc.titleParams('rt-1', _travail, 'Projet vacances'), {
        'session_id': 'rt-1',
        'profile': 'travail',
        'title': 'Projet vacances',
      });
    });

    test('réponse confirmée, en attente, mal formée', () {
      expect(HermesRpc.titled({'title': 'T'}), (title: 'T', pending: false));
      expect(
        HermesRpc.titled({'title': 'T', 'session_key': 'k', 'pending': null}),
        (title: 'T', pending: false),
      );
      expect(HermesRpc.titled({'title': 'T', 'pending': true}), (
        title: 'T',
        pending: true,
      ));
      for (final bad in <Map<String, dynamic>>[
        {},
        {'title': 3},
        {'title': '  '},
        {'title': 'T', 'pending': 'oui'},
        {'title': 'T', 'session_key': 4},
      ]) {
        expect(
          () => HermesRpc.titled(bad),
          throwsA(_code('contract.invalid_response')),
        );
      }
    });
  });

  group('ConversationRepository.rename (socket simulée)', () {
    late Database database;
    late Harness h;
    late OutboxRepository outbox;
    late ConversationRepository conversation;
    late ConnectionKey connection;
    late TimelineKey key;

    setUp(() async {
      database = await openConnectionDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      h = Harness();
      await h.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      connection = h.repository.snapshot.connection!.key;
      key = TimelineKey(connection, _default, 'Stored_A');
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

    Object? Function(String, Map<String, dynamic>) script(Object? title) =>
        (method, params) => switch (method) {
          'session.resume' => {'session_id': 'runtime-1'},
          'session.title' => title,
          _ => null,
        };

    test('reprise existante (sans création) puis titre sur le runtime ; titre confirmé rendu', () async {
      h.transport.rpc = script({'title': 'Projet vacances (serveur)'});
      expect(
        await conversation.rename(key, 'Projet vacances'),
        'Projet vacances (serveur)',
      );
      expect(calls('session.create'), isEmpty);
      expect(calls('session.resume').single, {
        'session_id': 'Stored_A',
        'profile': 'default',
      });
      expect(calls('session.title').single, {
        'session_id': 'runtime-1',
        'profile': 'default',
        'title': 'Projet vacances',
      });
      // Rien n'est publié dans la projection locale.
      expect(conversation.projection(key).items, isEmpty);
      // Liaison réutilisée sur la même socket : pas de seconde reprise.
      await conversation.rename(key, 'Encore');
      expect(calls('session.resume'), hasLength(1));
      expect(calls('session.title'), hasLength(2));
    });

    test('autre connexion : refus sans requête', () async {
      h.transport.rpc = script({'title': 'x'});
      await expectLater(
        conversation.rename(
          TimelineKey(const ConnectionKey('autre'), _default, 'Stored_A'),
          'x',
        ),
        throwsA(_code('connection.mismatch')),
      );
      expect(
        h.transport.frames
            .where((f) => f['method'] != null)
            .where(
              (f) =>
                  f['method'] == 'session.resume' ||
                  f['method'] == 'session.title',
            ),
        isEmpty,
      );
    });

    test('méthode absente : rename.missing mémorisé, plus aucun appel sur cette connexion', () async {
      h.transport.rpc = script(const RpcFail(-32601));
      expect(conversation.renameMissing(connection), isFalse);
      await expectLater(
        conversation.rename(key, 'x'),
        throwsA(_code('rename.missing')),
      );
      expect(conversation.renameMissing(connection), isTrue);
      expect(conversation.renameMissing(const ConnectionKey('autre')), isFalse);
      await expectLater(
        conversation.rename(key, 'y'),
        throwsA(_code('rename.missing')),
      );
      expect(calls('session.title'), hasLength(1));
    });

    test('refus : rename.refused', () async {
      h.transport.rpc = script(const RpcFail(4004));
      await expectLater(
        conversation.rename(key, 'x'),
        throwsA(_code('rename.refused')),
      );
      expect(conversation.renameMissing(connection), isFalse);
    });

    test(
      'confirmation différée : rename.pending, aucun succès présumé',
      () async {
        h.transport.rpc = script({'title': 'x', 'pending': true});
        await expectLater(
          conversation.rename(key, 'x'),
          throwsA(_code('rename.pending')),
        );
      },
    );

    test('réponse mal formée : contract.invalid_response', () async {
      h.transport.rpc = script({'pending': false});
      await expectLater(
        conversation.rename(key, 'x'),
        throwsA(_code('contract.invalid_response')),
      );
    });

    test('réponse perdue : rpc.uncertain, aucun rejeu automatique', () async {
      h.transport.rpc = script(null);
      await expectLater(
        conversation.rename(key, 'x'),
        throwsA(_code('rpc.uncertain')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(calls('session.title'), hasLength(1));
    });

    test('reprise refusée : titre jamais envoyé', () async {
      h.transport.rpc = (method, params) =>
          method == 'session.resume' ? const RpcFail(4064) : {'title': 'x'};
      await expectLater(
        conversation.rename(key, 'x'),
        throwsA(_code('rename.unreachable')),
      );
      expect(calls('session.title'), isEmpty);
    });

    Future<void> reconnect() async {
      await h.transport.sockets.last.drop();
      await until(() => h.delays.isNotEmpty);
      h.delays.last.complete();
      await until(
        () =>
            h.transport.sockets.length == 2 &&
            h.repository.snapshot.link == LinkState.connected,
      );
    }

    test(
      'méthode absente puis reconnexion : capacité retestée, titre renvoyé',
      () async {
        h.transport.rpc = script(const RpcFail(-32601));
        await expectLater(
          conversation.rename(key, 'x'),
          throwsA(_code('rename.missing')),
        );
        expect(conversation.renameMissing(connection), isTrue);
        await reconnect();
        expect(conversation.renameMissing(connection), isFalse);
        h.transport.rpc = script({'title': 'y'});
        expect(await conversation.rename(key, 'y'), 'y');
        expect(calls('session.title'), hasLength(2));
      },
    );

    test('socket coupée pendant la reprise : rename.unreachable, titre jamais envoyé', () async {
      final resuming = Completer<void>();
      h.transport.rpc = (method, params) => null;
      h.transport.onFrame = (frame) {
        if (frame['method'] == 'session.resume' && !resuming.isCompleted) {
          resuming.complete();
        }
      };
      final pending = conversation.rename(key, 'x');
      await resuming.future;
      await h.transport.sockets.last.drop();
      await expectLater(pending, throwsA(_code('rename.unreachable')));
      expect(calls('session.title'), isEmpty);
    });

    test(
      'reprise hors ligne : transport.offline, titre jamais envoyé',
      () async {
        h.transport.rpc = script({'title': 'x'});
        await h.transport.sockets.last.drop();
        await until(() => h.repository.snapshot.link != LinkState.connected);
        await expectLater(
          conversation.rename(key, 'x'),
          throwsA(_code('transport.offline')),
        );
        expect(calls('session.title'), isEmpty);
      },
    );

    for (final (label, resume) in [
      ('mal formée', <String, dynamic>{'session_id': 3}),
      ('sans réponse', null),
    ]) {
      test(
        'reprise $label : rename.unreachable, titre jamais envoyé',
        () async {
          h.transport.rpc = (method, params) =>
              method == 'session.resume' ? resume : {'title': 'x'};
          await expectLater(
            conversation.rename(key, 'x'),
            throwsA(_code('rename.unreachable')),
          );
          expect(calls('session.title'), isEmpty);
        },
      );
    }

    test('double validation : une seule mutation en cours par clé', () async {
      final gate = Completer<void>();
      h.transport.rpc = (method, params) => switch (method) {
        'session.resume' => {'session_id': 'runtime-1'},
        _ => null,
      };
      // Liaison posée puis titre retenu : la seconde demande arrive pendant la première.
      h.transport.onFrame = (frame) {
        if (frame['method'] == 'session.title' && !gate.isCompleted) {
          gate.complete();
        }
      };
      final first = conversation.rename(key, 'x');
      await gate.future;
      await expectLater(
        conversation.rename(key, 'y'),
        throwsA(_code('rename.busy')),
      );
      // Une autre session n'est pas bloquée.
      final other = conversation.rename(
        TimelineKey(connection, _default, 'Stored_B'),
        'z',
      );
      await expectLater(first, throwsA(_code('rpc.uncertain')));
      await expectLater(other, throwsA(_code('rpc.uncertain')));
      expect(calls('session.title').map((p) => p['title']), ['x', 'z']);
    });
  });

  group('HistoryViewModel : renommage', () {
    late Harness h;
    late MemoryConversation memory;
    late ConnectionKey connection;

    setUp(() async {
      h = Harness();
      await h.connect();
      connection = h.repository.snapshot.connection!.key;
      memory = MemoryConversation();
      memory.lists[(connection, _default)] = [
        _row('a', title: 'Projet'),
        _row('b', title: 'Autre'),
      ];
      memory.lists[(connection, _travail)] = [_row('a', title: 'Projet')];
    });
    tearDown(() => h.repository.dispose());

    Future<HistoryViewModel> model([ProfileKey profile = _default]) async {
      final vm = HistoryViewModel(
        gateway: h.repository,
        conversation: memory,
        profile: profile,
      );
      addTearDown(vm.dispose);
      await Future<void>.delayed(Duration.zero);
      return vm;
    }

    String? title(HistoryViewModel vm, String id) =>
        vm.sessions.singleWhere((s) => s.id == id).title;

    test(
      'vide, espaces, identique (espaces externes retirés) : aucun appel',
      () async {
        final vm = await model();
        final a = vm.sessions.first;
        for (final (input, code) in [
          ('', 'rename.empty'),
          ('   ', 'rename.empty'),
          ('Projet', 'rename.same'),
          ('  Projet  ', 'rename.same'),
        ]) {
          expect(await vm.rename(a, input), isFalse);
          expect(vm.renameOf('a')!.error, code);
          expect(vm.renameOf('a')!.draft, input);
        }
        expect(memory.renameCalls, isEmpty);
        // Casse différente : un autre titre.
        expect(HistoryViewModel.titleProblem(a, 'projet'), isNull);
      },
    );

    test('titre affiché seulement après confirmation, cible exacte, titre normalisé', () async {
      final vm = await model();
      final gate = memory.renameGate = Completer<void>();
      memory.renamed = 'Projet vacances';
      final done = vm.rename(vm.sessions.first, '  Projet vacances ');
      expect(vm.renameOf('a')!.busy, isTrue);
      expect(title(vm, 'a'), 'Projet');
      // Double validation : rien de plus.
      expect(await vm.rename(vm.sessions.first, 'Autre chose'), isFalse);
      expect(memory.renameCalls, [
        (TimelineKey(connection, _default, 'a'), 'Projet vacances'),
      ]);
      gate.complete();
      expect(await done, isTrue);
      expect(title(vm, 'a'), 'Projet vacances');
      expect(title(vm, 'b'), 'Autre');
      expect(vm.renameOf('a'), isNull);
    });

    for (final code in [
      'rename.refused',
      'transport.offline',
      'rpc.uncertain',
      'rename.pending',
      'rename.missing',
      'contract.invalid_response',
      'connection.mismatch',
    ]) {
      test('échec $code : ancien titre et saisie conservés', () async {
        final vm = await model();
        memory.renameError = AppError(code);
        expect(await vm.rename(vm.sessions.first, 'Projet vacances'), isFalse);
        expect(title(vm, 'a'), 'Projet');
        expect(vm.renameOf('a')!.draft, 'Projet vacances');
        expect(vm.renameOf('a')!.error, code);
        expect(
          HistoryViewModel.needsRefresh(code),
          {
            'rpc.uncertain',
            'rename.pending',
            'contract.invalid_response',
            'connection.mismatch',
          }.contains(code),
        );
        // Aucun rejeu : un seul appel.
        expect(memory.renameCalls, hasLength(1));
      });
    }

    test('erreur RPC brute : message générique, saisie conservée', () async {
      final vm = await model();
      memory.renameError = const RpcError(4004);
      expect(await vm.rename(vm.sessions.first, 'X'), isFalse);
      expect(vm.renameOf('a')!.error, 'rename.failed');
    });

    test(
      'réponse ancienne : liste rechargée en échec, aucune projection modifiée',
      () async {
        final vm = await model();
        final gate = memory.renameGate = Completer<void>();
        final done = vm.rename(vm.sessions.first, 'Neuf');
        memory.listError = const RpcError(5035);
        await vm.refresh();
        expect(vm.state, HistoryState.error);
        gate.complete();
        expect(await done, isTrue);
        expect(vm.sessions, isEmpty);
      },
    );

    test(
      'réponse arrivée après une actualisation : appliquée à sa seule ligne',
      () async {
        final vm = await model();
        final gate = memory.renameGate = Completer<void>();
        final done = vm.rename(vm.sessions.first, 'Neuf');
        await vm.refresh();
        expect(title(vm, 'a'), 'Projet');
        gate.complete();
        await done;
        expect(title(vm, 'a'), 'Neuf');
        expect(title(vm, 'b'), 'Autre');
      },
    );

    test(
      'confirmation pendant une relecture : la liste est relue après elle',
      () async {
        final queued = _QueuedLists()..lists.addAll(memory.lists);
        memory = queued;
        final vm = await model();
        queued.queue = true;
        final rename = memory.renameGate = Completer<void>();
        final done = vm.rename(vm.sessions.first, 'Neuf');
        final loading = vm.refresh();
        expect(vm.state, HistoryState.loading);
        rename.complete();
        expect(await done, isTrue);
        // Une relecture supplémentaire suit la confirmation.
        expect(queued.pending, hasLength(2));
        // La relecture en cours précédait le changement serveur : écartée.
        queued.pending.first.complete([_row('a', title: 'Projet')]);
        await loading;
        queued.pending.last.complete([_row('a', title: 'Neuf')]);
        await Future<void>.delayed(Duration.zero);
        expect(vm.state, HistoryState.ready);
        expect(title(vm, 'a'), 'Neuf');
      },
    );

    test(
      'liste en échec : renommage refusé (connection.mismatch), aucun appel',
      () async {
        final vm = await model();
        final a = vm.sessions.first;
        memory.listError = const RpcError(5035);
        await vm.refresh();
        expect(await vm.rename(a, 'Neuf'), isFalse);
        expect(vm.renameOf('a')!.error, 'connection.mismatch');
        expect(memory.renameCalls, isEmpty);
      },
    );

    test(
      'échec puis actualisation : erreur effacée, saisie conservée',
      () async {
        final vm = await model();
        memory.renameError = const AppError('rpc.uncertain');
        await vm.rename(vm.sessions.first, 'Neuf');
        await vm.refresh();
        expect(vm.renameOf('a')!.error, isNull);
        expect(vm.renameOf('a')!.draft, 'Neuf');
      },
    );

    test(
      'profils séparés : même identifiant, seul le profil visé est renommé',
      () async {
        final principal = await model();
        final travail = await model(_travail);
        await principal.rename(principal.sessions.first, 'Neuf');
        expect(memory.renameCalls.single.$1.profile, _default);
        expect(title(principal, 'a'), 'Neuf');
        expect(title(travail, 'a'), 'Projet');
      },
    );

    test('actualisation : le titre distant (changé sur Desktop) remplace l\'ancien, autres profils intacts', () async {
      final principal = await model();
      final travail = await model(_travail);
      memory.lists[(connection, _default)] = [
        _row('a', title: 'Titre Desktop'),
        _row('b', title: 'Autre'),
      ];
      await principal.refresh();
      expect(title(principal, 'a'), 'Titre Desktop');
      expect(title(travail, 'a'), 'Projet');
    });

    test('annulation : rien transmis, état effacé', () async {
      final vm = await model();
      memory.renameError = const AppError('rename.refused');
      await vm.rename(vm.sessions.first, 'X');
      vm.dismissRename('a');
      expect(vm.renameOf('a'), isNull);
      expect(memory.renameCalls, hasLength(1));
    });

    test('méthode absente constatée : renameMissing', () async {
      final vm = await model();
      expect(vm.renameMissing, isFalse);
      memory.missingRename.add(connection);
      expect(vm.renameMissing, isTrue);
    });
  });

  group('écrans', () {
    Future<(MemoryConversation, ConnectionKey)> open(
      WidgetTester tester, {
      List<SessionSummary>? rows,
    }) async {
      final previous = Harness();
      await previous.connect();
      final h = Harness();
      h.store.value = previous.store.value;
      h.secrets.values.addAll(previous.secrets.values);
      final memory = MemoryConversation();
      final connection = h.store.value!.key;
      memory.lists[(connection, _default)] =
          rows ?? [_row('a', title: 'Projet')];
      await tester.pumpWidget(
        MainApp(
          gateway: h.repository,
          outbox: MemoryOutbox(),
          conversation: memory,
        ),
      );
      await tester.pumpAndSettle();
      await enterHome(tester);
      await tester.tap(find.byTooltip(Content.conversations));
      await tester.pumpAndSettle();
      return (memory, connection);
    }

    Finder field() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    Finder menu() => find.byTooltip(Content.conversationActions('Projet'));

    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(menu());
      await tester.pumpAndSettle();
      await tester.tap(find.text(Content.rename));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'menu « Renommer » : champ nommé et initialisé, titre affiché après confirmation, focus rendu',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final (memory, connection) = await open(tester);
        await openDialog(tester);
        expect(find.byType(RenameConversationDialog), findsOne);
        expect(tester.widget<TextField>(field()).controller!.text, 'Projet');
        expect(
          tester.getSemantics(find.bySemanticsLabel(Content.renameField)),
          isSemantics(isTextField: true, isFocused: true),
        );
        expect(find.bySemanticsLabel(Content.renameCancel), findsOne);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.bySemanticsLabel(Content.renameConfirm),
          ),
          findsOne,
        );
        final gate = memory.renameGate = Completer<void>();
        await tester.enterText(field(), 'Projet vacances');
        await tester.tap(
          find.widgetWithText(FilledButton, Content.renameConfirm),
        );
        await tester.pump();
        // Progression ; ancien titre toujours affiché sous le dialogue.
        expect(find.bySemanticsLabel(Content.renaming), findsOne);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, Content.renameConfirm),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester.widget<HistoryRow>(find.byType(HistoryRow)).session.title,
          'Projet',
        );
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.byType(RenameConversationDialog), findsNothing);
        expect(memory.renameCalls, [
          (TimelineKey(connection, _default, 'a'), 'Projet vacances'),
        ]);
        expect(
          tester.widget<HistoryRow>(find.byType(HistoryRow)).session.title,
          'Projet vacances',
        );
        // Focus rendu au menu de la ligne.
        final focused = FocusManager.instance.primaryFocus!.context!;
        expect(
          find
              .ancestor(
                of: find.byWidget(focused.widget),
                matching: find.byType(HistoryRow),
              )
              .evaluate(),
          isNotEmpty,
        );
        semantics.dispose();
      },
    );

    testWidgets('validation vide et annulation : aucun appel, focus rendu', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final (memory, _) = await open(tester);
      await openDialog(tester);
      await tester.enterText(field(), '   ');
      await tester.tap(
        find.widgetWithText(FilledButton, Content.renameConfirm),
      );
      await tester.pumpAndSettle();
      expect(find.text(Content.renameError('rename.empty')), findsOne);
      await tester.tap(find.text(Content.renameCancel));
      await tester.pumpAndSettle();
      expect(find.byType(RenameConversationDialog), findsNothing);
      expect(memory.renameCalls, isEmpty);
      expect(
        find
            .ancestor(
              of: find.byWidget(
                FocusManager.instance.primaryFocus!.context!.widget,
              ),
              matching: find.byType(HistoryRow),
            )
            .evaluate(),
        isNotEmpty,
      );
      semantics.dispose();
    });

    testWidgets(
      'échec : erreur annoncée, saisie conservée, ancien titre ; incertain → actualisation',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final (memory, connection) = await open(tester);
        await openDialog(tester);
        memory.renameError = const AppError('rpc.uncertain');
        await tester.enterText(field(), 'Projet vacances');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        final message = Content.renameError('rpc.uncertain');
        expect(find.text(message), findsOne);
        // Erreur annoncée (région live) dans le dialogue.
        expect(
          find.ancestor(
            of: find.text(message),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.liveRegion == true,
            ),
          ),
          findsOne,
        );
        expect(
          tester.widget<TextField>(field()).controller!.text,
          'Projet vacances',
        );
        expect(memory.renameCalls, hasLength(1));
        // L'actualisation reprend le titre distant.
        memory.lists[(connection, _default)] = [
          _row('a', title: 'Projet vacances'),
        ];
        final listCalls = memory.listCalls.length;
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(Content.refreshHistory),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RenameConversationDialog), findsNothing);
        expect(memory.listCalls.length, listCalls + 1);
        expect(
          tester.widget<HistoryRow>(find.byType(HistoryRow)).session.title,
          'Projet vacances',
        );
        expect(memory.renameCalls, hasLength(1));
        semantics.dispose();
      },
    );

    for (final back in [false, true]) {
      testWidgets(
        'fermeture par ${back ? 'retour' : 'le voile'} : saisie et erreur oubliées',
        (tester) async {
          final (memory, _) = await open(tester);
          await openDialog(tester);
          memory.renameError = const AppError('rename.refused');
          await tester.enterText(field(), 'Refusé');
          await tester.tap(
            find.widgetWithText(FilledButton, Content.renameConfirm),
          );
          await tester.pumpAndSettle();
          expect(find.text(Content.renameError('rename.refused')), findsOne);
          if (back) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tapAt(const Offset(5, 5));
          }
          await tester.pumpAndSettle();
          expect(find.byType(RenameConversationDialog), findsNothing);
          await openDialog(tester);
          expect(tester.widget<TextField>(field()).controller!.text, 'Projet');
          expect(
            find.text(Content.renameError('rename.refused')),
            findsNothing,
          );
          expect(memory.renameCalls, hasLength(1));
        },
      );
    }

    testWidgets('méthode absente constatée : entrée désactivée et expliquée', (
      tester,
    ) async {
      final (memory, connection) = await open(tester);
      memory.missingRename.add(connection);
      // La liste relue reflète la capacité.
      await tester.tap(find.byTooltip(Content.refreshHistory));
      await tester.pumpAndSettle();
      await tester.tap(menu());
      await tester.pumpAndSettle();
      expect(find.text(Content.renameMissing), findsOne);
      final item = tester.widget<MenuItemButton>(
        find.ancestor(
          of: find.text(Content.rename),
          matching: find.byType(MenuItemButton),
        ),
      );
      expect(item.onPressed, isNull);
      await tester.tap(find.text(Content.rename), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(RenameConversationDialog), findsNothing);
      expect(memory.renameCalls, isEmpty);
    });

    testWidgets('texte agrandi : dialogue sans débordement', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(375, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester);
      await tester.scrollUntilVisible(
        menu(),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await openDialog(tester);
      expect(field(), findsOne);
      expect(tester.takeException(), isNull);
    });
  });
}
