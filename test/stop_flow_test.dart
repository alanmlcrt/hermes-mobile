import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/hermes_adapter.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/composer.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';
import 'package:hermes_mobile/features/conversation/draft_view.dart';
import 'package:hermes_mobile/features/conversation/draft_view_model.dart';
import 'package:hermes_mobile/features/profiles/profile_accents.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'contracts_test.dart' show contract;
import 'support/connection_fakes.dart';

Map<String, dynamic> result(String name) =>
    Map<String, dynamic>.from(fixture(name)['result'] as Map);

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database db;
  late Harness h;
  late ConversationRepository conversation;
  late OutboxRepository outbox;
  late Draft draft;
  late TimelineKey key;
  Object? response;
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 15));
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await settle();
    }
    expect(done(), isTrue);
  }

  int calls() => h.transport.frames
      .where((f) => f['method'] == 'session.interrupt')
      .length;
  void emit(String type, Map<String, dynamic> payload, int seq) {
    h.transport.sockets.last.controller.add({
      'jsonrpc': '2.0',
      'method': 'event',
      'params': {
        'session_id': 'a1b2c3d4',
        'type': type,
        'payload': payload,
        'seq': seq,
      },
    });
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hermes-stop-');
    db = await openConnectionDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/db',
    );
    h = Harness();
    await h.connect();
    await settle();
    response = {'status': 'interrupted'};
    h.transport.rpc = (method, params) => switch (method) {
      'session.create' => result('session-create'),
      'prompt.submit' => result('prompt-submit'),
      'session.interrupt' => response,
      _ => null,
    };
    conversation = ConversationRepository(
      db,
      gateway: h.repository,
      mapping: EventMapping(contract('event-mapping')),
    );
    outbox = OutboxRepository(
      db,
      gateway: h.repository,
      conversation: conversation,
      timeout: const Duration(milliseconds: 100),
    );
    draft = await outbox.openNewDraft(
      h.repository.snapshot.connection!.key,
      const ProfileKey('default'),
    );
    await outbox.saveText(draft.key, 'première demande');
    await outbox.send(draft.key);
    draft = (await outbox.draft(draft.key))!;
    key = TimelineKey(draft.connection, draft.profile, draft.storedSessionId!);
    emit('message.start', {}, 1);
    await until(() => conversation.stopTarget(key) != null);
    await outbox.saveText(draft.key, 'brouillon conservé');
  });
  tearDown(() async {
    await outbox.dispose();
    await conversation.dispose();
    await h.repository.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'persistance ciblée, double pression et RPC ne confirment pas le terminal',
    () async {
      response = null;
      final first = outbox.stop(draft.key);
      final second = outbox.stop(draft.key);
      await until(() => calls() == 1);
      final row = (await db.query('outbox_stops')).single;
      expect(row['connection_key'], draft.connection.value);
      expect(row['profile_key'], draft.profile.value);
      expect(row['stored_session_id'], draft.storedSessionId);
      expect(row['runtime'], 'a1b2c3d4');
      expect(row['observed_turn'], 1);
      expect(h.transport.frames.last['params'], {
        'session_id': 'a1b2c3d4',
        'profile': 'default',
      });
      await Future.wait([first, second]);
      expect(outbox.stopStatus(draft.key)!.state, StopState.unknown);
      expect(conversation.projection(key).workState, WorkState.running);
      expect((await outbox.draft(draft.key))!.body, 'brouillon conservé');
      await outbox.stop(draft.key);
      expect(calls(), 1);
      emit('message.complete', {'status': 'interrupted'}, 2);
      await until(
        () => conversation.projection(key).workState == WorkState.stopped,
      );
    },
  );

  test('RPC accepté reste demandé ; terminal réussi prévaut', () async {
    await outbox.stop(draft.key);
    expect(outbox.stopStatus(draft.key)!.state, StopState.requested);
    expect(conversation.projection(key).workState, WorkState.running);
    emit('message.complete', {'status': 'complete'}, 2);
    await until(
      () => conversation.projection(key).workState == WorkState.succeeded,
    );
  });

  test('échec de persistance : aucun RPC', () async {
    await db.execute(
      "CREATE TRIGGER no_stop BEFORE INSERT ON outbox_stops BEGIN SELECT RAISE(FAIL, 'synthetic'); END",
    );
    await outbox.stop(draft.key);
    expect(calls(), 0);
    expect(outbox.stopStatus(draft.key)!.errorCode, 'storage.unavailable');
  });

  test('fin pendant attente SQLite : aucune transmission tardive', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final lock = db.transaction((t) async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final stopping = outbox.stop(draft.key);
    emit('message.complete', {'status': 'interrupted'}, 2);
    await settle();
    release.complete();
    await lock;
    await stopping;
    expect(calls(), 0);
    expect(outbox.stopStatus(draft.key)!.state, StopState.stale);
  });

  test('nouveau tour : ancienne intention sans effet', () async {
    await outbox.stop(draft.key);
    emit('message.complete', {'status': 'interrupted'}, 2);
    emit('message.start', {}, 3);
    await until(() => conversation.projection(key).turns == 2);
    expect(outbox.stopStatus(draft.key), isNull);
    expect(calls(), 1);
    await outbox.stop(draft.key);
    expect(calls(), 2);
  });

  test('refus ou réponse invalide : explicite, sans double appel', () async {
    response = const RpcFail(-32601);
    await outbox.stop(draft.key);
    expect(outbox.stopStatus(draft.key)!.errorCode, 'rpc.-32601');
    await outbox.stop(draft.key);
    expect(calls(), 1);
  });

  test(
    'restauration SQLite : intention inconnue sans reprise ni RPC',
    () async {
      await outbox.stop(draft.key);
      await outbox.dispose();
      await conversation.dispose();
      await db.close();
      db = await openConnectionDatabase(
        factory: databaseFactoryFfi,
        path: '${directory.path}/db',
      );
      conversation = ConversationRepository(
        db,
        gateway: h.repository,
        mapping: EventMapping(contract('event-mapping')),
      );
      outbox = OutboxRepository(
        db,
        gateway: h.repository,
        conversation: conversation,
      );
      await outbox.draft(draft.key);
      expect(outbox.stopStatus(draft.key)!.state, StopState.unknown);
      expect(calls(), 1);
      await outbox.stop(draft.key);
      expect(calls(), 1);
    },
  );

  test('profil modifié pendant attente : intention périmée', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final lock = db.transaction((t) async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final stopping = outbox.stop(draft.key);
    await h.repository.selectProfile(const ProfileKey('travail'));
    release.complete();
    await lock;
    await stopping;
    expect(calls(), 0);
    expect(outbox.stopStatus(draft.key)!.state, StopState.stale);
  });

  test('conversation affichée hors profil global : arrêt disponible', () async {
    h.transport.rpc = (method, params) => switch (method) {
      'session.resume' => {
        ...result('session-resume'),
        'session_id': 'a1b2c3d4',
        'running': true,
      },
      'session.history' => {
        'count': 1,
        'messages': [
          {'role': 'user', 'text': 'première demande', 'row_id': 42},
        ],
      },
      'session.events.since' => const RpcFail(-32601),
      'session.interrupt' => {'status': 'interrupted'},
      _ => null,
    };
    await h.repository.selectProfile(const ProfileKey('travail'));
    await conversation.resync(key);
    expect(h.repository.snapshot.selectedProfile, isNot(draft.profile));
    expect(outbox.canStop(draft.key), isTrue);
    await outbox.stop(draft.key);
    expect(calls(), 1);
    expect(outbox.stopStatus(draft.key)!.state, StopState.requested);
    expect(h.transport.frames.last['params'], {
      'session_id': 'a1b2c3d4',
      'profile': draft.profile.value,
    });
  });

  test('message.start dupliqué : demande acceptée reste requested', () async {
    await outbox.stop(draft.key);
    final target = conversation.stopTarget(key);
    emit('message.start', {}, 1);
    await settle();
    expect(conversation.stopTarget(key), target);
    expect(conversation.projection(key).turns, 1);
    expect(outbox.stopStatus(draft.key)!.state, StopState.requested);
    expect(calls(), 1);
  });

  test(
    'lecture arrêt échouée : restauration réessayée sans second RPC',
    () async {
      await outbox.stop(draft.key);
      await outbox.dispose();
      outbox = OutboxRepository(
        db,
        gateway: h.repository,
        conversation: conversation,
      );
      // Une indisponibilité transitoire de la table rend la lecture impossible.
      await db.execute('ALTER TABLE outbox_stops RENAME TO pending_stops');
      await expectLater(outbox.draft(draft.key), throwsA(anything));
      expect(outbox.stopStatus(draft.key), isNull);
      await db.execute('ALTER TABLE pending_stops RENAME TO outbox_stops');
      await outbox.draft(draft.key);
      expect(outbox.stopStatus(draft.key)!.state, StopState.unknown);
      h.transport.rpc = (method, params) => method == 'session.resume'
          ? {
              ...result('session-resume'),
              'session_id': 'a1b2c3d4',
              'running': true,
            }
          : {'status': 'interrupted'};
      await outbox.resume(key);
      expect(outbox.canStop(draft.key), isFalse);
      await outbox.stop(draft.key);
      expect(calls(), 1);
    },
  );

  test(
    'coupure pendant attente : aucun arrêt sur une socket ultérieure',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final lock = db.transaction((t) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final stopping = outbox.stop(draft.key);
      await h.transport.sockets.last.drop();
      await settle();
      release.complete();
      await lock;
      await stopping;
      expect(calls(), 0);
      expect(outbox.stopStatus(draft.key)!.state, StopState.stale);
    },
  );

  test('coupure après transmission : issue inconnue, aucun renvoi à la reconnexion', () async {
    response = const RpcDrop();
    await outbox.stop(draft.key);
    expect(outbox.stopStatus(draft.key)!.state, StopState.unknown);
    final sockets = h.transport.sockets.length;
    await until(() => h.delays.isNotEmpty);
    h.delays.last.complete();
    await until(() => h.transport.sockets.length > sockets);
    await settle();
    expect(calls(), 1);
  });

  test(
    'deux vues retrouvent la même intention ; autre session sans effet',
    () async {
      final same = await outbox.openContinuation(
        draft.connection,
        draft.profile,
        draft.storedSessionId!,
      );
      final other = await outbox.openContinuation(
        draft.connection,
        draft.profile,
        'autre-session',
      );
      expect(same.key, draft.key);
      await Future.wait([
        outbox.stop(same.key),
        outbox.stop(draft.key),
        outbox.stop(other.key),
      ]);
      expect(calls(), 1);
      expect(outbox.stopStatus(other.key), isNull);
    },
  );

  test('réponse invalide explicite ; projection reste en cours', () async {
    response = {'status': 'ok'};
    await outbox.stop(draft.key);
    expect(
      outbox.stopStatus(draft.key)!.errorCode,
      'contract.invalid_response',
    );
    expect(conversation.projection(key).workState, WorkState.running);
  });

  test('décodeur interruption refuse une réponse invalide', () {
    expect(() => HermesRpc.interrupted({'status': 'ok'}), throwsA(anything));
    expect(HermesRpc.interrupted({'status': 'not_interrupted'}), isFalse);
  });

  testWidgets('commande 48 dp, clavier et texte 200 %, brouillon intact', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'texte conservé');
    var pressed = 0;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2),
            viewInsets: EdgeInsets.only(bottom: 240),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Composer(
                    controller: controller,
                    stopping: true,
                    onStop: () {
                      pressed++;
                    },
                  ),
                  const Text(Content.stopReminder),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final button = find.byTooltip(Content.stop);
    expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    expect(pressed, 1);
    await tester.showKeyboard(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(pressed, 2);
    expect(controller.text, 'texte conservé');
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets(
    'DraftView réelle : arrêt, annonce unique, terminal, clavier et captures',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      final accents = ProfileAccents(h.repository);
      h.transport.rpc = (method, params) => switch (method) {
        'session.resume' => {
          ...result('session-resume'),
          'session_id': 'a1b2c3d4',
          'running': true,
        },
        'session.history' => {
          'count': 1,
          'messages': [
            {'role': 'user', 'text': 'première demande', 'row_id': 42},
          ],
        },
        'session.events.since' => const RpcFail(-32601),
        'session.interrupt' => {'status': 'interrupted'},
        _ => null,
      };
      final vm = DraftViewModel(
        outbox: outbox,
        gateway: h.repository,
        conversation: conversation,
        key: draft.key,
      );
      Future<void> pumpIO() async {
        for (var i = 0; i < 12; i++) {
          await tester.pump();
          await tester.runAsync(settle);
        }
      }

      await pumpIO();
      Future<void> mount(
        Brightness brightness, {
        double scale = 1,
        double keyboard = 0,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(null, brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: keyboard),
                disableAnimations: true,
              ),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: DraftView(
              create: () => vm,
              accents: accents,
              continuation: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final reminder = tester.element(find.text(Content.stopReminder));
        expect(MediaQuery.disableAnimationsOf(reminder), isTrue);
        expect(
          DefaultTextStyle.of(reminder).style.color,
          buildTheme(null, brightness).textTheme.bodyMedium!.color,
        );
      }

      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory(
            '_bmad-output/implementation-artifacts/story-3-5-verification',
          )..createSync(recursive: true);
          await File('${directory.path}/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.runAsync(() async {
        final font = FontLoader('Inter')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File('assets/fonts/inter-400.ttf').readAsBytesSync(),
              ),
            ),
          );
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytesSync(),
              ),
            ),
          );
        await icons.load();
      });
      await mount(Brightness.light);
      expect(find.bySemanticsLabel(Content.stop), findsOneWidget);
      expect(find.text(Content.stopReminder), findsOneWidget);
      await capture('conversation-light');
      await tester.tap(find.byTooltip(Content.stop));
      await pumpIO();
      await tester.pump();
      expect(find.text(Content.stopRequested), findsOneWidget);
      expect(tester.widget<Composer>(find.byType(Composer)).onStop, isNull);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.liveRegion == true &&
              w.child is! SizedBox,
        ),
        findsWidgets,
      );
      await mount(Brightness.dark);
      await capture('conversation-dark-requested');
      await mount(Brightness.dark, scale: 2, keyboard: 260);
      await tester.ensureVisible(find.byTooltip(Content.stop));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await capture('conversation-dark-keyboard-200');
      emit('message.complete', {'status': 'interrupted'}, 2);
      await pumpIO();
      await mount(Brightness.light);
      expect(find.text(Content.workStopped), findsOneWidget);
      expect(find.byTooltip(Content.stop), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'brouillon conservé',
      );
      await capture('conversation-confirmed');
      await tester.pumpWidget(const SizedBox());
      await pumpIO();
      accents.dispose();
      semantics.dispose();
    },
  );
}
