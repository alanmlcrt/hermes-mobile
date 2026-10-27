import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
// Le mock Pigeon officiel du SDK ne requiert aucun projet réel.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:hermes_mobile/data/firebase_notification_client.dart';
import 'package:hermes_mobile/models/notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/firebase_messaging');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  int authorization = 1;
  bool failRegistration = false;
  int registrations = 0;
  setUpAll(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });
  setUp(() {
    authorization = 1;
    failRegistration = false;
    registrations = 0;
    messenger.setMockMethodCallHandler(
      const MethodChannel('hermes/notifications'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'Messaging#setAutoInitEnabled') {
        return {'isAutoInitEnabled': false};
      }
      if (call.method == 'Messaging#getNotificationSettings' ||
          call.method == 'Messaging#requestPermission') {
        return {
          'authorizationStatus': authorization,
          'alert': 1,
          'announcement': 1,
          'badge': 1,
          'carPlay': 1,
          'lockScreen': 1,
          'notificationCenter': 1,
          'showPreviews': 1,
          'timeSensitive': 1,
          'criticalAlert': 1,
          'sound': 1,
          'providesAppNotificationSettings': 1,
        };
      }
      if (call.method == 'Messaging#register') {
        registrations++;
        if (failRegistration) {
          throw PlatformException(
            code: 'synthetic-registration-failed',
            message: 'private provider detail',
          );
        }
        await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('Messaging#onRegistered', 'synthetic-fcm-token'),
          ),
          (_) {},
        );
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('hermes/notifications'),
      null,
    );
  });
  test(
    'plateforme configurée, token autorisé donne ready sans réenregistrement',
    () async {
      final client = FirebaseNotificationClient();
      await client.initialize();
      expect(client.availability, NotificationAvailability.ready);
      expect(await client.token(), 'synthetic-fcm-token');
      expect(registrations, 1);
      await client.dispose();
    },
  );
  test('permission refusée ne lance pas register', () async {
    authorization = 0;
    final client = FirebaseNotificationClient();
    await client.initialize();
    expect(client.availability, NotificationAvailability.denied);
    expect(await client.token(), isNull);
    expect(registrations, 0);
    await client.dispose();
  });
  test(
    'erreur registration devient unavailable sans exception fournisseur',
    () async {
      failRegistration = true;
      final client = FirebaseNotificationClient();
      await client.initialize();
      expect(client.availability, NotificationAvailability.unavailable);
      expect(await client.token(), isNull);
      await client.dispose();
    },
  );
  test('toucher : handler posé avant Firebase, id validé, lancement consommé', () async {
    Object? launch = 'subscription-launch-0000000';
    messenger.setMockMethodCallHandler(
      const MethodChannel('hermes/notifications'),
      (call) async {
        if (call.method != 'takeOpened') return null;
        final id = launch;
        launch = null;
        return id;
      },
    );
    // Sans `initialize()` : le canal fonctionne même sans Firebase.
    final client = FirebaseNotificationClient();
    final opened = <String>[];
    final subscription = client.opened.listen(opened.add);
    Future<void> native(Object? id) => messenger.handlePlatformMessage(
      'hermes/notifications',
      const StandardMethodCodec().encodeMethodCall(MethodCall('opened', id)),
      (_) {},
    );
    await native('subscription-hot-00000000000');
    await native('invalide avec espaces');
    await native(42);
    await pumpEventQueue();
    expect(opened, ['subscription-hot-00000000000']);
    expect(await client.takeOpened(), 'subscription-launch-0000000');
    expect(await client.takeOpened(), isNull);
    launch = '../chemin';
    expect(await client.takeOpened(), isNull);
    await subscription.cancel();
    await client.dispose();
  });
}
