import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/connection_repository.dart';
import 'package:hermes_mobile/data/hermes_adapter.dart';
import 'package:hermes_mobile/main.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/connection_gateway.dart';
import 'package:hermes_mobile/ui/content.dart';

import 'support/connection_fakes.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('MainApp suit le thème du téléphone ($brightness)', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        MainApp(gateway: Harness().repository, outbox: MemoryOutbox(), conversation: MemoryConversation()),
      );
      await tester.pumpAndSettle();

      final label = find.text(Content.connectTitle);
      expect(label, findsOneWidget);
      expect(Theme.of(tester.element(label)).brightness, brightness);
    });
  }

  testWidgets('retour au premier plan hors ligne : reconnect, jamais en ligne',
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
  });

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