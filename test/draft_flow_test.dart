import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes_mobile/features/conversation/draft_view.dart';
import 'package:hermes_mobile/features/conversation/draft_view_model.dart';
import 'package:hermes_mobile/main.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/ui/content.dart';

import 'support/connection_fakes.dart';

/// Requêtes connues de l'Epic 1 ; toute autre (session, envoi) est interdite.
const _epic1Paths = {
  '/auth/password-login',
  '/auth/native/refresh',
  '/api/profiles',
  '/api/auth/ws-ticket',
};

/// Lancement réel : nouveau repository sur le stockage d'une connexion faite.
Future<Harness> _launched({
  int profilesStatus = 200,
  ProfileKey? choice,
}) async {
  final previous = Harness();
  await previous.connect();
  if (choice != null) await previous.repository.selectProfile(choice);
  final h = Harness();
  h.store.value = previous.store.value;
  h.secrets.values.addAll(previous.secrets.values);
  h.transport.profilesStatus = profilesStatus;
  return h;
}

String _location(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last))
        .routerDelegate
        .currentConfiguration
        .uri
        .toString();

void main() {
  testWidgets(
    'ouverture authentifiée : /draft du profil par défaut, saisie enregistrée, '
    'même brouillon à la relance, aucune requête de session',
    (tester) async {
      final h = await _launched();
      final outbox = MemoryOutbox();
      await tester.pumpWidget(MainApp(gateway: h.repository, outbox: outbox, conversation: MemoryConversation()));
      await tester.pumpAndSettle();
      final draft = outbox.drafts.values.single;
      expect(draft.profile.value, 'default');
      expect(_location(tester), '/draft/${draft.key.value}');
      expect(find.text(Content.draftProfile('Principal (default)')), findsOne);
      await tester.enterText(find.byType(TextField), '/cmd abc 🚀');
      await tester.pumpAndSettle();
      expect(outbox.drafts[draft.key]!.body, '/cmd abc 🚀');
      // Arrière-plan puis retour : écran et texte inchangés.
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(_location(tester), '/draft/${draft.key.value}');
      expect(find.text('/cmd abc 🚀'), findsOne);
      // Relance : nouvelle app, même stockage.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final relaunched = Harness();
      relaunched.store.value = h.store.value;
      relaunched.secrets.values.addAll(h.secrets.values);
      await tester.pumpWidget(
        MainApp(gateway: relaunched.repository, outbox: outbox, conversation: MemoryConversation()),
      );
      await tester.pumpAndSettle();
      expect(outbox.drafts, hasLength(1));
      expect(_location(tester), '/draft/${draft.key.value}');
      expect(find.text('/cmd abc 🚀'), findsOne);
      for (final h in [h, relaunched]) {
        for (final request in h.transport.requests) {
          expect(_epic1Paths, contains(request.uri.path));
        }
      }
      // Lien vers « Mes profils ».
      await tester.tap(find.text(Content.profilesTitle));
      await tester.pumpAndSettle();
      expect(find.text('Travail (travail)'), findsOne);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('aucun profil : écran des profils, aucun brouillon', (
    tester,
  ) async {
    final h = await _launched(profilesStatus: 500);
    final outbox = MemoryOutbox();
    await tester.pumpWidget(MainApp(gateway: h.repository, outbox: outbox, conversation: MemoryConversation()));
    await tester.pumpAndSettle();
    expect(find.text(Content.profilesError), findsOne);
    expect(outbox.drafts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ouverture du brouillon impossible : écran des profils', (
    tester,
  ) async {
    final h = await _launched();
    final outbox = MemoryOutbox()..failOpen = true;
    await tester.pumpWidget(MainApp(gateway: h.repository, outbox: outbox, conversation: MemoryConversation()));
    await tester.pumpAndSettle();
    expect(_location(tester), '/');
    expect(find.text('Principal (default)'), findsOne);
    expect(outbox.drafts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choix mémorisé et découverte échouée : brouillon du choix', (
    tester,
  ) async {
    final h = await _launched(
      profilesStatus: 500,
      choice: const ProfileKey('travail'),
    );
    final outbox = MemoryOutbox();
    await tester.pumpWidget(MainApp(gateway: h.repository, outbox: outbox, conversation: MemoryConversation()));
    await tester.pumpAndSettle();
    final draft = outbox.drafts.values.single;
    expect(draft.profile, const ProfileKey('travail'));
    expect(_location(tester), '/draft/${draft.key.value}');
    expect(tester.takeException(), isNull);
  });

  testWidgets('authentification refusée sur le brouillon : connexion', (
    tester,
  ) async {
    final h = await _launched();
    // Sans socket ouverte : sa fermeture resterait en attente dans la zone
    // de test simulée.
    h.transport.ticketStatus = 500;
    final outbox = MemoryOutbox();
    await tester.pumpWidget(MainApp(gateway: h.repository, outbox: outbox, conversation: MemoryConversation()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'gardé');
    await tester.pumpAndSettle();
    h.transport.profilesStatus = 401;
    h.transport.refreshStatus = 401;
    h.transport.loginStatus = 401;
    unawaited(h.repository.refreshProfiles());
    await tester.pumpAndSettle();
    expect(h.repository.snapshot.authenticated, isFalse);
    expect(find.text(Content.connectTitle), findsOne);
    expect(outbox.drafts.values.single.body, 'gardé');
    expect(tester.takeException(), isNull);
  });

  for (final (name, failRead, code) in [
    ('lecture échouée', true, 'storage.unavailable'),
    ('brouillon inconnu', false, 'draft.not_found'),
  ]) {
    testWidgets('$name : message, aucun champ de saisie', (tester) async {
      final h = Harness();
      final outbox = MemoryOutbox()..failRead = failRead;
      final draft = await outbox.openNewDraft(
        ConnectionKey.create(),
        const ProfileKey('p'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DraftView(
            create: () => DraftViewModel(
              outbox: outbox,
              gateway: h.repository,
              conversation: MemoryConversation(),
              key: failRead ? draft.key : const DraftKey('inconnu'),
            ),
            onOpenProfiles: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(Content.error(code)), findsOne);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  Future<(Harness, MemoryOutbox, DraftKey)> openDraft(
    WidgetTester tester, {
    Map<String, dynamic>? ready,
  }) async {
    final h = await _launched();
    if (ready != null) h.transport.ready = ready;
    final outbox = MemoryOutbox();
    await tester.pumpWidget(MainApp(gateway: h.repository, outbox: outbox, conversation: MemoryConversation()));
    await tester.pumpAndSettle();
    return (h, outbox, outbox.drafts.keys.single);
  }

  Finder sendButton() => find.widgetWithText(FilledButton, Content.send);
  bool sendEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(sendButton()).onPressed != null;

  testWidgets('envoi actif : texte saisi, connecté, tour terminé', (
    tester,
  ) async {
    final (_, outbox, key) = await openDraft(tester);
    expect(sendEnabled(tester), isFalse);
    expect(find.text(Content.sendEmpty), findsOne);
    await tester.enterText(find.byType(TextField), 'ma demande');
    await tester.pumpAndSettle();
    expect(sendEnabled(tester), isTrue);
    await tester.tap(sendButton());
    await tester.pumpAndSettle();
    expect(outbox.sent, [key]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tour en cours : saisie enregistrée, bouton désactivé et raison', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final (_, outbox, key) = await openDraft(tester);
    await tester.enterText(find.byType(TextField), 'première');
    outbox.setStatus(key, const SendStatus(turnActive: true));
    await tester.pumpAndSettle();
    expect(sendEnabled(tester), isFalse);
    expect(find.text(Content.turnActive), findsOne);
    await tester.enterText(find.byType(TextField), 'seconde en cours');
    await tester.pumpAndSettle();
    expect(outbox.drafts[key]!.body, 'seconde en cours');
    expect(sendEnabled(tester), isFalse);
    expect(
      tester.getSemantics(find.text(Content.turnActive)),
      matchesSemantics(label: Content.turnActive, isLiveRegion: true),
    );
    outbox.setStatus(key, const SendStatus());
    await tester.pumpAndSettle();
    expect(sendEnabled(tester), isTrue);
    semantics.dispose();
  });

  testWidgets('envoi en cours puis résultat incertain : annoncé, explicite', (
    tester,
  ) async {
    final (_, outbox, key) = await openDraft(tester);
    await tester.enterText(find.byType(TextField), 'texte');
    outbox.setStatus(key, const SendStatus(state: OperationState.sending));
    await tester.pumpAndSettle();
    expect(find.text(Content.sending), findsOne);
    expect(sendEnabled(tester), isFalse);
    outbox.setStatus(
      key,
      const SendStatus(state: OperationState.unknown, errorCode: 'send.unknown'),
    );
    await tester.pumpAndSettle();
    expect(find.text(Content.error('send.unknown')), findsOne);
    expect(find.text('texte'), findsOne);
    // Un nouvel envoi n'est possible que par action explicite.
    expect(sendEnabled(tester), isTrue);
    expect(outbox.sent, isEmpty);
  });

  for (final typedMore in [false, true]) {
    testWidgets(
      typedMore
          ? 'acceptée avec saisie plus récente : texte conservé'
          : 'acceptée : saisie envoyée retirée de l’écran',
      (tester) async {
        final (_, outbox, key) = await openDraft(tester);
        await tester.enterText(find.byType(TextField), 'abc');
        await tester.pumpAndSettle();
        await tester.tap(sendButton());
        await tester.pumpAndSettle();
        if (typedMore) {
          await tester.enterText(find.byType(TextField), 'abc suite');
          await tester.pumpAndSettle();
        } else {
          // Le stockage a vidé la version envoyée (révision identique).
          await outbox.saveText(key, '');
        }
        outbox.setStatus(key, const SendStatus(state: OperationState.accepted));
        await tester.pumpAndSettle();
        expect(find.text(Content.sendAccepted), findsOne);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          typedMore ? 'abc suite' : '',
        );
      },
    );
  }

  testWidgets('dialecte canonique : envoi désactivé, capacité absente dite', (
    tester,
  ) async {
    final (h, outbox, _) = await openDraft(
      tester,
      ready: fixture('gateway-ready'),
    );
    await tester.enterText(find.byType(TextField), 'texte');
    await tester.pumpAndSettle();
    expect(find.text(Content.sendCapabilityMissing), findsOne);
    expect(sendEnabled(tester), isFalse);
    expect(outbox.sent, isEmpty);
    expect(h.transport.frames.where((f) => f['id'] != 'capabilities'), isEmpty);
  });

  testWidgets('texte 200 % : état d’envoi lisible sans débordement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final (_, outbox, key) = await openDraft(tester);
    outbox.setStatus(
      key,
      const SendStatus(state: OperationState.unknown, errorCode: 'send.unknown'),
    );
    await tester.pumpAndSettle();
    expect(find.text(Content.error('send.unknown')), findsOne);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(375, 700), const Size(700, 375)]) {
    testWidgets('200 %, lecteur d\'écran, clavier, échec d\'écriture ($size)', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      final h = await _launched();
      final outbox = MemoryOutbox();
      await tester.pumpWidget(MainApp(gateway: h.repository, outbox: outbox, conversation: MemoryConversation()));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      expect(
        tester.getSemantics(find.bySemanticsLabel(Content.composerLabel)),
        matchesSemantics(
          label: Content.composerLabel,
          isTextField: true,
          isMultiline: true,
          isFocusable: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      final send = find.ancestor(
        of: find.text(Content.send),
        matching: find.byType(Semantics),
      );
      expect(
        tester.getSemantics(send.first),
        isSemantics(
          label: Content.send,
          hint: Content.sendEmpty,
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      outbox.failSave = true;
      await tester.enterText(field, 'texte précieux');
      await tester.pumpAndSettle();
      expect(
        find.text(
          '${Content.error('storage.unavailable')} ${Content.draftKept}',
        ),
        findsOne,
      );
      expect(find.text('texte précieux'), findsOne);
      // Une écriture réussie efface le message.
      outbox.failSave = false;
      await tester.enterText(field, 'texte sauvé');
      await tester.pumpAndSettle();
      expect(
        find.text(
          '${Content.error('storage.unavailable')} ${Content.draftKept}',
        ),
        findsNothing,
      );
      expect(outbox.drafts.values.single.body, 'texte sauvé');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
