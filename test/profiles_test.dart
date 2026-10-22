import 'package:flutter/material.dart';

import 'dart:async';

import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/features/profiles/profiles_view.dart';
import 'package:hermes_mobile/features/profiles/profiles_view_model.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/connection_gateway.dart';
import 'package:hermes_mobile/models/companion_background.dart';
import 'package:hermes_mobile/ui/components/companion_background_editor.dart';
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

class BackgroundGateway implements ConnectionGateway {
  @override
  ConnectionSnapshot snapshot = profileState();
  final updates = StreamController<ConnectionSnapshot>.broadcast(sync: true);
  @override
  Stream<ConnectionSnapshot> get snapshots => updates.stream;
  void show(ConnectionSnapshot value) {
    snapshot = value;
    updates.add(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DelayedBackgrounds implements CompanionBackgroundStore {
  final reads = <(CompanionBackgroundIdentity, Completer<CompanionPalette>)>[];
  final writes =
      <(CompanionBackgroundIdentity, CompanionPalette, Completer<void>)>[];
  @override
  Future<CompanionPalette> read(CompanionBackgroundIdentity id) {
    final c = Completer<CompanionPalette>();
    reads.add((id, c));
    return c.future;
  }

  @override
  Future<void> save(CompanionBackgroundIdentity id, CompanionPalette palette) {
    final c = Completer<void>();
    writes.add((id, palette, c));
    return c.future;
  }
}

void main() {
  test(
    'background : A vers B vers A ignore la fin de l’ancienne édition',
    () async {
      final gateway = BackgroundGateway();
      final store = DelayedBackgrounds();
      final vm = ProfilesViewModel(gateway, backgrounds: store);
      store.reads.last.$2.complete(CompanionPalette.lavenderPeach);
      await Future<void>.delayed(Duration.zero);
      final write = vm.saveBackground(
        vm.backgroundIdentity!,
        CompanionPalette.roseLilac,
      );
      gateway.show(profileState(selected: secondProfile.key));
      gateway.show(profileState());
      store.reads.last.$2.complete(CompanionPalette.mintSky);
      await Future<void>.delayed(Duration.zero);
      var notifications = 0;
      vm.addListener(() => notifications++);
      store.writes.single.$3.complete();
      await write;
      expect(vm.palette, CompanionPalette.mintSky);
      expect(notifications, 0);
      store.reads[1].$2.complete(CompanionPalette.lavenderPeach);
      await Future<void>.delayed(Duration.zero);
      vm.dispose();
      await gateway.updates.close();
    },
  );
  test('background : lectures obsolètes, retry, identité origine et écriture attachée à sa cible', () async {
    final gateway = BackgroundGateway();
    final store = DelayedBackgrounds();
    final vm = ProfilesViewModel(gateway, backgrounds: store);
    expect(vm.backgroundLoading, isTrue);
    final first = vm.backgroundIdentity!;
    gateway.show(profileState(selected: secondProfile.key));
    store.reads[0].$2.complete(CompanionPalette.roseLilac);
    await Future<void>.delayed(Duration.zero);
    expect(vm.palette, CompanionPalette.lavenderPeach);
    expect(vm.backgroundLoading, isTrue);
    store.reads[1].$2.completeError(StateError('read failed'));
    await Future<void>.delayed(Duration.zero);
    expect(vm.backgroundError, isTrue);
    final retry = vm.loadBackground();
    store.reads.last.$2.complete(CompanionPalette.mintSky);
    await retry;
    expect(vm.backgroundError, isFalse);
    expect(vm.palette, CompanionPalette.mintSky);
    final target = vm.backgroundIdentity!;
    final write = vm.saveBackground(target, CompanionPalette.roseLilac);
    gateway.show(
      ConnectionSnapshot(
        connection: Connection(
          key: target.connection,
          origin: parseOrigin('https://other.example'),
        ),
        selectedProfile: target.profile,
        profiles: const [firstProfile, secondProfile],
        profilesState: ProfilesState.ready,
      ),
    );
    expect(vm.backgroundIdentity, isNot(target));
    expect(vm.backgroundIdentity!.connection, target.connection);
    store.reads.last.$2.complete(CompanionPalette.lavenderPeach);
    store.writes.single.$3.complete();
    await write;
    expect(store.writes.single.$1, target);
    expect(vm.palette, CompanionPalette.lavenderPeach);
    expect(first.profile, firstProfile.key);
    gateway.show(profileState(selected: null));
    expect(vm.backgroundIdentity, isNull);
    vm.dispose();
    await gateway.updates.close();
  });

  testWidgets(
    'background : lecture bloquante et édition abandonnée au changement de serveur',
    (tester) async {
      final gateway = BackgroundGateway();
      final store = DelayedBackgrounds();
      final vm = ProfilesViewModel(gateway, backgrounds: store);
      await tester.pumpWidget(
        MaterialApp(
          home: ProfilesView(viewModel: vm, onChangeServer: () {}),
        ),
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, Content.backgroundTitle),
            )
            .onPressed,
        isNull,
      );
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(find.bySemanticsLabel(Content.backgroundLoading), findsOneWidget);
      semantics.dispose();
      store.reads.single.$2.completeError(StateError('failed'));
      await tester.pumpAndSettle();
      expect(find.text(Content.backgroundReadError), findsOneWidget);
      await tester.tap(find.text(Content.backgroundRetry));
      await tester.pump();
      store.reads.last.$2.complete(CompanionPalette.mintSky);
      await tester.pumpAndSettle();
      final activate = tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, Content.backgroundTitle),
          )
          .onPressed!;
      activate();
      activate();
      await tester.pumpAndSettle();
      expect(
        find.byType(CompanionBackgroundEditor, skipOffstage: false),
        findsOneWidget,
      );
      gateway.show(
        ConnectionSnapshot(
          connection: Connection(
            key: const ConnectionKey('one'),
            origin: parseOrigin('https://different.example'),
          ),
          selectedProfile: firstProfile.key,
          profiles: const [firstProfile],
          profilesState: ProfilesState.ready,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CompanionBackgroundEditor), findsNothing);
      expect(store.writes, isEmpty);
      store.reads.last.$2.complete(CompanionPalette.roseLilac);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Content.backgroundTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Content.mintSky));
      await tester.tap(find.text(Content.backgroundApply));
      await tester.pump();
      expect(store.writes, hasLength(1));
      expect(store.writes.single.$1.origin, 'https://different.example');
      gateway.show(profileState(selected: null));
      await tester.pumpAndSettle();
      expect(find.byType(CompanionBackgroundEditor), findsNothing);
      store.writes.single.$3.complete();
      await tester.pump();
      expect(vm.backgroundIdentity, isNull);
      expect(vm.palette, CompanionPalette.lavenderPeach);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      await gateway.updates.close();
    },
  );
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
      await tester.scrollUntilVisible(
        find.text(Content.refreshingProfiles),
        100,
      );
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
      await tester.ensureVisible(find.text('Travail (travail)'));
      await tester.pumpAndSettle();
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
