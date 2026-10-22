import 'package:flutter/material.dart';

import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/features/profiles/profiles_view.dart';
import 'package:hermes_mobile/features/profiles/profiles_view_model.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/ui/components/profile_companion_panel.dart';
import 'package:hermes_mobile/ui/components/rabbit_companion.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';
import 'package:hermes_mobile/ui/tokens.dart';

import 'support/connection_fakes.dart';

class SnapshotProfiles extends ProfilesViewModel {
  SnapshotProfiles(super.gateway);
  ConnectionSnapshot value = ConnectionSnapshot();
  @override
  ConnectionSnapshot get snapshot => value;
  void show(ConnectionSnapshot next) {
    value = next;
    notifyListeners();
  }
}

const firstProfile = Profile(key: ProfileKey('first'), label: 'Principal');
const secondProfile = Profile(key: ProfileKey('second'), label: 'Travail');

ConnectionSnapshot profileState({
  String server = 'one',
  ProfileKey? selected = const ProfileKey('first'),
  List<Profile> profiles = const [firstProfile, secondProfile],
  ProfilesState state = ProfilesState.ready,
}) => ConnectionSnapshot(
  connection: Connection(
    key: ConnectionKey(server),
    origin: Uri.parse('https://$server.example'),
  ),
  selectedProfile: selected,
  profiles: profiles,
  profilesState: state,
);

RabbitPainter rabbitPose(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((widget) => widget.painter)
    .whereType<RabbitPainter>()
    .single;

void main() {
  testWidgets(
    'profils : suspension hors viewport, route et arrière-plan, libellé long accessible',
    (tester) async {
      tester.view.physicalSize = const Size(375, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = Harness();
      final vm = SnapshotProfiles(h.repository);
      const longProfile = Profile(
        key: ProfileKey('first'),
        label: 'Un libellé métier de profil particulièrement long à lire intégralement',
      );
      vm.show(profileState(profiles: [longProfile]));
      addTearDown(() async {
        vm.dispose();
        final closed = h.repository.dispose();
        await tester.pump();
        await closed;
      });
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: buildTheme(null, Brightness.dark),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: ProfilesView(viewModel: vm, onChangeServer: () {}),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(RabbitCompanion));
      await tester.pump();
      expect(rabbitPose(tester).tickled, isTrue);
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      await tester.pump();
      // Le ListView peut éliminer l'enfant ; aucun ticker ne doit survivre.
      if (find.byType(RabbitCompanion).evaluate().isNotEmpty) {
        expect(rabbitPose(tester).tickled, isFalse);
        expect(rabbitPose(tester).gaze, 0);
      }
      expect(
        find.text(
          Content.profileName(longProfile.label, longProfile.key.value),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text(Content.changeServer), -200);
      await tester.pump();
      expect(find.text(Content.changeServer).hitTestable(), findsOneWidget);
      scrollable.position.jumpTo(0);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byType(RabbitCompanion));
      await tester.pump();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Autre surface')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(RabbitTokens.rest + RabbitTokens.travel);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(rabbitPose(tester).tickled, isFalse);
      expect(rabbitPose(tester).gaze, 0);
      await tester.tap(find.byType(RabbitCompanion));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(rabbitPose(tester).tickled, isFalse);
      await tester.pump(RabbitTokens.rest + RabbitTokens.travel);
      expect(rabbitPose(tester).gaze, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(rabbitPose(tester).gaze, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Otc suit la sélection vérifiée, chargement stable et aucun profil inventé',
    (tester) async {
      final h = Harness();
      final vm = SnapshotProfiles(h.repository);
      addTearDown(() async {
        vm.dispose();
        final closed = h.repository.dispose();
        await tester.pump();
        await closed;
      });
      vm.show(profileState());
      await tester.pumpWidget(
        MaterialApp(
          home: ProfilesView(viewModel: vm, onChangeServer: () {}),
        ),
      );
      await tester.pump();
      expect(find.text(Content.companionName), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(ProfileCompanionPanel)).dy,
        lessThan(tester.getTopLeft(find.text(ConnectionLabels.offline)).dy),
      );
      expect(
        tester.widget<RabbitCompanion>(find.byType(RabbitCompanion)).size,
        RabbitTokens.large,
      );
      final rect = tester.getRect(find.byType(ProfileCompanionPanel));
      vm.show(profileState(profiles: [], state: ProfilesState.refreshing));
      await tester.pump();
      expect(tester.getRect(find.byType(ProfileCompanionPanel)), rect);
      expect(find.text('Principal (first)'), findsNothing);
      expect(find.text(Content.refreshingProfiles), findsOneWidget);
      vm.show(profileState(profiles: [], state: ProfilesState.empty));
      await tester.pump();
      expect(find.byType(RabbitCompanion), findsNothing);
      expect(find.text(Content.emptyProfiles), findsOneWidget);
      for (final state in [
        profileState(selected: null),
        profileState(selected: const ProfileKey('unknown')),
        profileState(
          selected: const ProfileKey('unknown'),
          profiles: [],
          state: ProfilesState.loading,
        ),
        profileState(server: 'two', profiles: [], state: ProfilesState.loading),
      ]) {
        vm.show(state);
        await tester.pump();
        expect(find.byType(RabbitCompanion), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'changement de profil et serveur repart au repos ; pause et surface masquée',
    (tester) async {
      final h = Harness();
      final vm = SnapshotProfiles(h.repository);
      addTearDown(() async {
        vm.dispose();
        final closed = h.repository.dispose();
        await tester.pump();
        await closed;
      });
      vm.show(profileState());
      Widget host({bool active = true, bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(800, 600),
            disableAnimations: reduced,
          ),
          child: ProfilesView(
            viewModel: vm,
            active: active,
            onChangeServer: () {},
          ),
        ),
      );
      await tester.pumpWidget(host());
      await tester.pump();
      for (final next in [
        profileState(selected: secondProfile.key),
        profileState(server: 'two', selected: secondProfile.key),
      ]) {
        await tester.tap(find.byType(RabbitCompanion));
        await tester.pump(const Duration(milliseconds: 200));
        expect(rabbitPose(tester).tickled, isTrue);
        final previous = tester.state(find.byType(RabbitCompanion));
        vm.show(next);
        await tester.pump();
        await tester.pump();
        expect(
          tester.state(find.byType(RabbitCompanion)),
          isNot(same(previous)),
        );
        expect(rabbitPose(tester).tickled, isFalse);
        expect(rabbitPose(tester).gaze, 0);
        expect(find.text(Content.companionName), findsOneWidget);
      }
      final semantics = tester.ensureSemantics();
      await tester.tap(find.text(Content.pauseCompanion));
      await tester.pump();
      expect(find.bySemanticsLabel(Content.resumeCompanion), findsOneWidget);
      await tester.pump(RabbitTokens.rest + RabbitTokens.travel);
      expect(rabbitPose(tester).gaze, 0);
      await tester.tap(find.text(Content.resumeCompanion));
      await tester.pump();
      await tester.tap(find.byType(RabbitCompanion));
      await tester.pump();
      await tester.pumpWidget(host(reduced: true));
      await tester.pump();
      expect(rabbitPose(tester).tickled, isFalse);
      expect(rabbitPose(tester).gaze, 0);
      await tester.pumpWidget(host(active: false));
      await tester.pump();
      await tester.pump(RabbitTokens.rest + RabbitTokens.travel);
      expect(rabbitPose(tester).gaze, 0);
      expect(
        tester.widget<RabbitCompanion>(find.byType(RabbitCompanion)).active,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  testWidgets(
    'panneau : noms absents ou longs, thèmes et 200 % en portrait et paysage',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      for (final brightness in Brightness.values) {
        for (final size in [const Size(375, 700), const Size(700, 375)]) {
          tester.view.physicalSize = size;
          for (final name in [
            null,
            '   ',
            'Un très long nom de compagnon qui doit rester intégralement lisible',
          ]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: buildTheme(null, brightness),
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: const TextScaler.linear(2),
                      disableAnimations: true,
                    ),
                    child: ListView(
                      children: [ProfileCompanionPanel(name: name)],
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            final display = name == null || name.trim().isEmpty
                ? Content.companionFallback
                : name;
            expect(find.text(display), findsOneWidget);
            await tester.ensureVisible(find.byType(RabbitCompanion));
            await tester.pump();
            await tester.pump();
            expect(
              find.bySemanticsLabel(
                RegExp(RegExp.escape(Content.tickleCompanion(display))),
              ),
              findsOneWidget,
            );
            final text = tester.widget<Text>(find.text(display));
            expect(text.maxLines, isNull);
            await tester.ensureVisible(find.text(Content.pauseCompanion));
            await tester.pump();
            await tester.tap(find.text(Content.pauseCompanion));
            await tester.pump();
            expect(find.text(Content.resumeCompanion), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
      semantics.dispose();
    },
  );
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
