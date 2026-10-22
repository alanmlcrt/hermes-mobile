import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/connection_repository.dart';
import 'package:hermes_mobile/data/hermes_adapter.dart';
import 'package:hermes_mobile/main.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/connection_gateway.dart';
import 'package:hermes_mobile/models/companion_background.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/ui/components/profile_companion_panel.dart';
import 'package:hermes_mobile/ui/components/companion_background_editor.dart';
import 'package:hermes_mobile/ui/content.dart';

import 'support/connection_fakes.dart';

void main() {
  Future<(_BackgroundAppGateway, _AppBackgrounds)> openBackgroundApp(
    WidgetTester tester,
  ) async {
    final gateway = _BackgroundAppGateway();
    final store = _AppBackgrounds();
    await tester.pumpWidget(
      MainApp(
        gateway: gateway,
        outbox: _ProfilesOutbox(),
        conversation: MemoryConversation(),
        backgrounds: store,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProfileCompanionPanel), findsOneWidget);
    await tester.tap(find.text(Content.backgroundTitle));
    await tester.pumpAndSettle();
    return (gateway, store);
  }

  testWidgets(
    'MainApp : injection, aperçu isolé, confirmation SQLite puis réouverture et abandon',
    (tester) async {
      final (_, store) = await openBackgroundApp(tester);
      await tester.tap(find.text(Content.mintSky));
      await tester.pump();
      CompanionPalette panelPalette() => tester
          .widget<ProfileCompanionPanel>(
            find.byType(ProfileCompanionPanel, skipOffstage: false),
          )
          .palette;
      expect(panelPalette(), CompanionPalette.lavenderPeach);
      expect(store.writes, 0);
      await tester.tap(find.text(Content.backgroundApply));
      await tester.pump();
      expect(store.writes, 1);
      expect(panelPalette(), CompanionPalette.lavenderPeach);
      expect(find.byType(CompanionBackgroundEditor), findsOneWidget);
      store.pending.complete();
      await tester.pumpAndSettle();
      expect(panelPalette(), CompanionPalette.mintSky);
      await tester.tap(find.text(Content.backgroundTitle));
      await tester.pumpAndSettle();
      expect(
        find.text('${Content.mintSky} — ${Content.backgroundSelected}'),
        findsOneWidget,
      );
      await tester.tap(find.text(Content.roseLilac));
      await tester.tap(find.text(Content.backgroundCancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Content.backgroundTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Content.roseLilac));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(panelPalette(), CompanionPalette.mintSky);
      expect(store.writes, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  for (final fail in [false, true]) {
    testWidgets(
      'MainApp attend écriture avant fermeture gateway, échec=$fail',
      (tester) async {
        final (gateway, store) = await openBackgroundApp(tester);
        await tester.tap(find.text(Content.backgroundApply));
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(gateway.disposed, isFalse);
        if (fail) {
          store.pending.completeError(StateError('SQLite failure'));
        } else {
          store.pending.complete();
        }
        await tester.pumpAndSettle();
        expect(gateway.disposed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final brightness in Brightness.values) {
    testWidgets('MainApp suit le thème du téléphone ($brightness)', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        MainApp(
          gateway: Harness().repository,
          outbox: MemoryOutbox(),
          conversation: MemoryConversation(),
        ),
      );
      await tester.pumpAndSettle();

      final label = find.text(Content.connectTitle);
      expect(label, findsOneWidget);
      expect(Theme.of(tester.element(label)).brightness, brightness);
    });
  }

  testWidgets(
    'retour au premier plan hors ligne : reconnect, jamais en ligne',
    (tester) async {
      final h = Harness();
      final gateway = _Counting(h);
      await tester.runAsync(() async {
        await gateway.confirmOrigin(
          parseOrigin('http://desktop.example.ts.net:9119'),
        );
        await gateway.authenticate('<SYNTHETIC_PASSWORD>');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpWidget(
        MainApp(
          gateway: gateway,
          outbox: MemoryOutbox(),
          conversation: MemoryConversation(),
        ),
      );
      final restored = gateway.reconnects;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(gateway.pings, 1); // connecté : un ping, pas de reconnexion
      expect(gateway.reconnects, restored);
      await tester.runAsync(() async {
        await h.transport.sockets.last.drop();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      expect(gateway.snapshot.link, isNot(LinkState.connected));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(gateway.reconnects, restored + 1);
      await tester.runAsync(() => gateway.dispose());
    },
  );

  testWidgets('retour au premier plan : ping en échec reconnecte ; occupé ou '
      'non authentifié, rien', (tester) async {
    final h = Harness();
    final gateway = _Counting(h);
    await tester.runAsync(() async {
      await gateway.confirmOrigin(
        parseOrigin('http://desktop.example.ts.net:9119'),
      );
      await gateway.authenticate('<SYNTHETIC_PASSWORD>');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpWidget(
      MainApp(
        gateway: gateway,
        outbox: MemoryOutbox(),
        conversation: MemoryConversation(),
      ),
    );
    final base = gateway.reconnects;
    gateway.busy = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(gateway.pings, 0);
    gateway.busy = false;
    gateway.pingFails = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(gateway.pings, 1);
    expect(gateway.reconnects, base + 1);
    // Jamais authentifié : aucune action.
    final idle = _Counting(h);
    await tester.pumpWidget(
      MainApp(
        gateway: idle,
        outbox: MemoryOutbox(),
        conversation: MemoryConversation(),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(idle.pings + idle.reconnects, 0);
    await tester.runAsync(() => gateway.dispose());
  });
}

class _ProfilesOutbox extends MemoryOutbox {
  @override
  Future<Draft> openNewDraft(
    ConnectionKey connection,
    ProfileKey profile,
  ) async => throw StateError('Stay on profiles');
}

class _AppBackgrounds implements CompanionBackgroundStore {
  var palette = CompanionPalette.lavenderPeach;
  var writes = 0;
  final pending = Completer<void>();
  @override
  Future<CompanionPalette> read(CompanionBackgroundIdentity identity) async =>
      palette;
  @override
  Future<void> save(
    CompanionBackgroundIdentity identity,
    CompanionPalette value,
  ) async {
    writes++;
    await pending.future;
    palette = value;
  }
}

class _BackgroundAppGateway implements ConnectionGateway {
  bool disposed = false;
  @override
  final snapshot = ConnectionSnapshot(
    connection: Connection(
      key: const ConnectionKey('same'),
      origin: parseOrigin('https://one.example'),
    ),
    selectedProfile: const ProfileKey('Main'),
    profiles: const [Profile(key: ProfileKey('Main'), label: 'Principal')],
    profilesState: ProfilesState.ready,
    authenticated: true,
  );
  @override
  Stream<ConnectionSnapshot> get snapshots => const Stream.empty();
  @override
  Future<void> restore() async {}
  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Counting extends ConnectionRepository {
  _Counting(Harness h)
    : super(
        adapter: HermesAdapter(h.transport),
        store: h.store,
        secrets: h.secrets,
        delay: (_) => Completer<void>().future, // la reprise automatique attend
      );
  int reconnects = 0;
  int pings = 0;
  bool pingFails = false;
  bool busy = false;
  @override
  ConnectionSnapshot get snapshot =>
      busy ? super.snapshot.copyWith(busy: true) : super.snapshot;
  @override
  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = rpcTimeout,
  }) async {
    expect(method, 'gateway.ping');
    pings++;
    if (pingFails) throw const AppError('rpc.uncertain');
    return {'ok': true};
  }

  @override
  Future<void> restore() => Future.value(); // l'état est posé par le test
  @override
  Future<void> reconnect() {
    reconnects++;
    return Future.value();
  }
}
