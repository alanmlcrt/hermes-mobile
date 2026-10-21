import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/features/connection/connection_view.dart';
import 'package:hermes_mobile/features/connection/connection_view_model.dart';
import 'package:hermes_mobile/data/storage/secret_store.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/ui/content.dart';

import 'support/connection_fakes.dart';

void main() {
  for (final input in [
    null,
    'https://edited.example',
    'hermes-mobile://pair?url=https%3A%2F%2Fincoming.example',
  ]) {
    testWidgets('restauration tardive préserve saisie et lien : $input', (
      tester,
    ) async {
      final h = Harness();
      h.store.delayedRead = Completer<Connection?>();
      final vm = ConnectionViewModel(h.repository);
      addTearDown(() async {
        vm.dispose();
        final done = h.repository.dispose();
        await tester.pump();
        await done;
      });
      unawaited(h.repository.restore());
      final incoming = input?.startsWith('hermes-mobile:') == true
          ? input
          : null;
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectionView(
            viewModel: vm,
            incomingLink: incoming,
            onAuthenticated: () {},
          ),
        ),
      );
      if (input != null && incoming == null) {
        await tester.enterText(find.byType(TextField).first, input);
      }
      h.store.delayedRead!.complete(
        Connection(
          key: ConnectionKey.create(),
          origin: parseOrigin('https://saved.example'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        input ?? 'https://saved.example',
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'échec restauration : reprise avec coffre sans ressaisie mot de passe',
    (tester) async {
      final h = Harness();
      final key = ConnectionKey.create();
      h.store.value = Connection(
        key: key,
        origin: parseOrigin('https://saved.example'),
      );
      await h.secrets.write(key, SecretUsage.password, '<SYNTHETIC_PASSWORD>');
      h.transport.unreachable = true;
      await h.repository.restore();
      final vm = ConnectionViewModel(h.repository);
      addTearDown(() async {
        vm.dispose();
        final done = h.repository.dispose();
        await tester.pump();
        await done;
      });
      var navigations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectionView(
            viewModel: vm,
            onAuthenticated: () => navigations++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(Content.passwordLabel), findsNothing);
      expect(find.text(Content.retry), findsOneWidget);
      h.transport.unreachable = false;
      await tester.tap(find.text(Content.retry));
      await tester.pumpAndSettle();
      expect(navigations, 1);
      expect(h.repository.snapshot.authenticated, isTrue);
      expect(h.transport.active, 1);
    },
  );
}
