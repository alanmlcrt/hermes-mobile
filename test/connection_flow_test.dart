import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hermes_mobile/main.dart';
import 'package:hermes_mobile/features/connection/connection_view.dart';
import 'package:hermes_mobile/features/connection/connection_view_model.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';

import 'support/connection_fakes.dart';

void main() {
  testWidgets(
    'lien Android reçu par le routeur exige confirmation du nouveau serveur',
    (tester) async {
      final h = Harness();
      await tester.pumpWidget(
        MainApp(gateway: h.repository, outbox: MemoryOutbox(), conversation: MemoryConversation()),
      );
      await tester.pumpAndSettle();
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          const MethodCall('pushRouteInformation', {
            'location':
                'hermes-mobile://pair?url=http%3A%2F%2Fandroid.ts.net%3A9119',
            'state': null,
          }),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.text(Content.confirmOrigin), findsOneWidget);
      expect(find.text('http://android.ts.net:9119'), findsOneWidget);
      expect(h.transport.requests, isEmpty);
      expect(h.store.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'confirmation avant réseau et persistance puis connexion et profils',
    (tester) async {
      final h = Harness();
      await tester.pumpWidget(
        MainApp(gateway: h.repository, outbox: MemoryOutbox(), conversation: MemoryConversation()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'http://desktop.ts.net:9119',
      );
      await tester.tap(find.text(Content.reviewOrigin));
      await tester.pumpAndSettle();
      expect(h.transport.requests, isEmpty);
      expect(h.store.writes, 0);
      expect(find.text(Content.passwordLabel), findsNothing);
      await tester.tap(find.text(Content.confirmOrigin));
      await tester.pumpAndSettle();
      expect(h.store.writes, 1);
      expect(h.transport.requests, isEmpty);
      await tester.enterText(
        find.byType(TextField).last,
        '<SYNTHETIC_PASSWORD>',
      );
      await tester.ensureVisible(find.text(Content.signIn));
      await tester.tap(find.text(Content.signIn));
      await tester.pumpAndSettle();
      expect(
        find.text(Content.profilesTitle),
        findsOneWidget,
        reason:
            'auth=${h.repository.snapshot.authenticated}, busy=${h.repository.snapshot.busy}, '
            'error=${h.repository.snapshot.error}, requests=${h.transport.requests.map((r) => r.uri.path).toList()}',
      );
      // Accueil : nouvelle conversation sur le profil par défaut.
      expect(
        find.text(Content.draftProfile('Principal (default)')),
        findsOneWidget,
      );
      await tester.tap(find.text(Content.profilesTitle));
      await tester.pumpAndSettle();
      expect(find.text('Principal (default)'), findsOneWidget);
      expect(find.text(ConnectionLabels.connected), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('deep link prérempli exige confirmation ; invalide sans réseau', (
    tester,
  ) async {
    final h = Harness();
    final vm = ConnectionViewModel(h.repository);
    addTearDown(() async {
      vm.dispose();
      final closed = h.repository.dispose();
      await tester.pump();
      await closed;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectionView(
          viewModel: vm,
          incomingLink:
              'hermes-mobile://pair?url=http%3A%2F%2Fdesktop.ts.net%3A9119',
          onAuthenticated: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(Content.confirmOrigin), findsOneWidget);
    expect(h.store.writes, 0);
    expect(h.transport.requests, isEmpty);
    await tester.enterText(
      find.byType(TextField).first,
      'https://secret@example.com',
    );
    await tester.tap(find.text(Content.reviewOrigin));
    await tester.pumpAndSettle();
    expect(
      find.text(Content.error('connection.invalid_origin')),
      findsOneWidget,
    );
    expect(find.text(Content.confirmOrigin), findsNothing);
    expect(h.store.writes, 0);
  });
  for (final size in [const Size(375, 700), const Size(700, 375)]) {
    testWidgets(
      'formulaire à 200 %, mouvement réduit, clavier et erreur ($size)',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final h = Harness();
        final vm = ConnectionViewModel(h.repository);
        addTearDown(() async {
          vm.dispose();
          final closed = h.repository.dispose();
          await tester.pump();
          await closed;
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(null, Brightness.dark),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                  viewInsets: const EdgeInsets.only(bottom: 200),
                ),
                child: ConnectionView(viewModel: vm, onAuthenticated: () {}),
              ),
            ),
          ),
        );
        await tester.enterText(
          find.byType(TextField).first,
          'https://desktop.example.com',
        );
        await tester.ensureVisible(find.text(Content.reviewOrigin));
        await tester.tap(find.text(Content.reviewOrigin));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(Content.confirmOrigin));
        await tester.tap(find.text(Content.confirmOrigin));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextField).last);
        await tester.enterText(
          find.byType(TextField).last,
          '<SYNTHETIC_PASSWORD>',
        );
        h.transport.loginStatus = 401;
        await tester.ensureVisible(find.text(Content.signIn));
        await tester.tap(find.text(Content.signIn));
        await tester.pumpAndSettle();
        expect(find.text(Content.error('auth.refused')), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller!
              .text,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
