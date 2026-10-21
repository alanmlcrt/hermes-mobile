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
      await tester.pumpWidget(MainApp(gateway: h.repository, outbox: outbox));
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
        MainApp(gateway: relaunched.repository, outbox: outbox),
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
    await tester.pumpWidget(MainApp(gateway: h.repository, outbox: outbox));
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
    await tester.pumpWidget(MainApp(gateway: h.repository, outbox: outbox));
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
    await tester.pumpWidget(MainApp(gateway: h.repository, outbox: outbox));
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
    await tester.pumpWidget(MainApp(gateway: h.repository, outbox: outbox));
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
      await tester.pumpWidget(MainApp(gateway: h.repository, outbox: outbox));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      expect(
        tester.getSemantics(field),
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
          hint: Content.sendUnavailable,
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
