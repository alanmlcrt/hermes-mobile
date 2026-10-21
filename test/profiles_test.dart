import 'package:flutter/material.dart';

import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/features/profiles/profiles_view.dart';
import 'package:hermes_mobile/features/profiles/profiles_view_model.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';

import 'support/connection_fakes.dart';

void main() {
  testWidgets(
    'profils à 200 %, sélection accessible, actualisation, erreur et vide distincts',
    (tester) async {
      tester.view.physicalSize = const Size(375, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = Harness();
      await h.connect();
      final vm = ProfilesViewModel(h.repository);
      addTearDown(() async {
        vm.dispose();
        final closed = h.repository.dispose();
        await tester.pump();
        await closed;
      });
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(null, Brightness.light),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: ProfilesView(viewModel: vm, onChangeServer: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Travail (travail)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Travail (travail)'));
      await tester.pumpAndSettle();
      final selected = tester.getSemantics(find.text('Travail (travail)'));
      expect(
        selected.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(selected.label, contains('Travail (travail)'));
      h.transport.profilesStatus = 500;
      await vm.refresh();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(Content.profilesError),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(Content.profilesError), findsOneWidget);
      expect(find.text(Content.emptyProfiles), findsNothing);
      h.transport.profilesStatus = 200;
      h.transport.profiles = fixture('profiles-empty');
      await vm.refresh();
      await tester.pumpAndSettle();
      expect(find.text(Content.emptyProfiles), findsOneWidget);
      expect(find.text(Content.profilesError), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
