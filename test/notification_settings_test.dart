import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/ui/components/notification_settings.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';

import 'notification_repository_test.dart' show Device;

void main() {
  setUp(() => NotificationSettings.disabledProfiles.clear());

  testWidgets(
    'toggle simple sans explication ; permission relue au retour système',
    (tester) async {
      final device = Device()..value = null;
      addTearDown(device.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(children: [NotificationSettings(device: device)]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text(Content.notificationPrerequisites), findsNothing);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      device.value = 'permission-now-granted';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(device.reads, greaterThan(0));
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    },
  );

  testWidgets('activer le toggle demande la permission, profil sans plugin grisé', (
    tester,
  ) async {
    final device = _Asking();
    addTearDown(device.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: [NotificationSettings(device: device)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(device.requested, 1);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );

    // Profil sans plugin : toggle grisé (onChanged == null).
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [NotificationSettings(device: device, hasPlugin: false)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final disabledTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(disabledTile.value, isFalse);
    expect(disabledTile.onChanged, isNull);
  });

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
        final device = Device()..value = null;
        addTearDown(device.dispose);
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
                    children: [NotificationSettings(device: device)],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final toggle = find.byType(SwitchListTile);
        await tester.ensureVisible(toggle);
        expect(find.text(Content.notifications), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
}

/// Permission accordée seulement sur demande explicite.
class _Asking extends Device {
  _Asking() {
    value = null;
  }
  int requested = 0;
  @override
  Future<String?> token({bool requestPermission = false}) async {
    if (requestPermission) {
      requested++;
      value = 'granted-token';
    }
    return super.token(requestPermission: requestPermission);
  }
}
