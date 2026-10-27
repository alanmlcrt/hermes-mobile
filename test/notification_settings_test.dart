import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/notifications.dart';
import 'package:hermes_mobile/ui/components/notification_settings.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';

import 'notification_repository_test.dart' show Device;

class Settings implements NotificationGateway {
  bool configured = false;
  @override
  final Device device = Device()..value = null;
  @override
  Future<ObserverSettings?> settings(ConnectionKey key) async => configured
      ? ObserverSettings(key, Uri.parse('https://observer.test'), false)
      : null;
  @override
  Future<void> configure(ConnectionKey key, Uri origin, String bearer) async =>
      throw const FormatException('private secret');
  @override
  Future<bool> enable(ConnectionKey key) async => false;
  @override
  Future<void> disable(ConnectionKey key) async {}
  @override
  Future<String> health(ConnectionKey key) async => 'degraded';
}

void main() {
  testWidgets(
    'réouverture configurée et permission Android modifiée sans abonnement',
    (tester) async {
      final settings = Settings()..configured = true;
      addTearDown(settings.device.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                NotificationSettings(
                  repository: settings,
                  connection: const ConnectionKey('c'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(Content.observerHealth('unchecked')), findsOneWidget);
      expect(find.text(Content.observerHealth('unconfigured')), findsNothing);
      expect(find.text(Content.notificationDevice('denied')), findsOneWidget);
      settings.device.value = 'permission-now-granted';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(settings.device.reads, greaterThan(0));
      expect(find.text(Content.notificationDevice('ready')), findsOneWidget);
    },
  );
  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    for (final brightness in Brightness.values) {
      testWidgets('Réglages : texte 200 %, $size, $brightness, semantics', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        final settings = Settings();
        addTearDown(settings.device.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(null, brightness),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: Scaffold(
                body: SafeArea(
                  child: ListView(
                    children: [
                      NotificationSettings(
                        repository: settings,
                        connection: const ConnectionKey('c'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(Content.notificationDevice('denied')), findsOneWidget);
        final origin = find.widgetWithText(
          TextFormField,
          Content.observerOrigin,
        );
        await tester.ensureVisible(origin);
        await tester.enterText(origin, 'https://observer.test');
        final bearer = find.widgetWithText(
          TextFormField,
          Content.observerBearer,
        );
        await tester.ensureVisible(bearer);
        await tester.enterText(bearer, 'synthetic-secret');
        final save = find.widgetWithText(
          FilledButton,
          Content.notificationSave,
        );
        await tester.ensureVisible(save);
        expect(
          tester.getSemantics(save),
          matchesSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
            hasFocusAction: true,
            isFocusable: true,
            label: Content.notificationSave,
          ),
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text(Content.notificationConfigError), findsOneWidget);
        expect(find.text('private secret'), findsNothing);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
}
