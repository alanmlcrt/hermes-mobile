import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

import '../models/notifications.dart';

const notificationSetupTimeout = Duration(seconds: 4);

/// Configuration native facultative, sans faux token ni options générées.
class FirebaseNotificationClient implements NotificationClient {
  /// Le canal écoute avant `Firebase.initializeApp` : l'ouverture par
  /// notification fonctionne même sans Firebase configuré.
  FirebaseNotificationClient() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'opened') throw MissingPluginException();
      if (isSessionId(call.arguments) && !_opened.isClosed) {
        _opened.add(call.arguments as String);
      }
      return null;
    });
  }
  static const _channel = MethodChannel('hermes/notifications');

  /// Sans écouteur, les touchers attendent : un seul abonné, celui de l'app.
  final _opened = StreamController<String>();
  FirebaseMessaging? _messaging;
  StreamSubscription<RemoteMessage>? _messages;
  StreamSubscription<String>? _registration;
  final _rotations = StreamController<String>.broadcast();
  String? _token;
  NotificationAvailability _availability =
      NotificationAvailability.unconfigured;
  @override
  NotificationAvailability get availability => _availability;
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
      await _messaging!.setAutoInitEnabled(false);
      // Jeton d'enregistrement FCM (cible `token` de HTTP v1). L'API 17
      // register/onRegistered rend un FID et n'a jamais abouti sur le
      // téléphone réel (essai 5.5) : on garde getToken/onTokenRefresh.
      // ignore: deprecated_member_use
      _registration = _messaging!.onTokenRefresh.listen((token) {
        if (_token == token) return;
        _token = token;
        _rotations.add(token);
      });
      await _channel.invokeMethod<void>('createChannel');
      _messages = FirebaseMessaging.onMessage.listen((message) {
        // Reconstruire le libellé générique, sans afficher du texte reçu.
        final data = message.data;
        if (data.length == 2 &&
            data.keys.toSet().containsAll({'sessionId', 'outcome'}) &&
            isSessionId(data['sessionId']) &&
            {'succeeded', 'failed', 'stopped'}.contains(data['outcome'])) {
          unawaited(
            _channel.invokeMethod<void>('show', data).catchError((_) {}),
          );
        }
      });
      await token();
    } catch (_) {
      _availability = NotificationAvailability.unconfigured;
    }
  }

  @override
  Stream<String> get rotations => _rotations.stream;
  @override
  Stream<String> get opened => _opened.stream;
  @override
  Future<String?> takeOpened() async {
    try {
      final id = await _channel.invokeMethod<Object?>('takeOpened');
      return isSessionId(id) ? id as String : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> token({bool requestPermission = false}) async {
    final messaging = _messaging;
    if (messaging == null) return null;
    try {
      if (requestPermission) {
        // La boîte de dialogue attend Alanc : aucun délai ici, sinon une
        // réponse après trois secondes passait pour un token indisponible.
        final settings = await messaging.requestPermission();
        if (settings.authorizationStatus != AuthorizationStatus.authorized) {
          _availability = NotificationAvailability.denied;
          return null;
        }
        await messaging.setAutoInitEnabled(true);
      }
      // Premier enregistrement GMS parfois lent sur un vrai téléphone.
      return await _acquire(messaging).timeout(const Duration(seconds: 10));
    } catch (_) {
      _availability = NotificationAvailability.unavailable;
      return null;
    }
  }

  Future<String?> _acquire(FirebaseMessaging messaging) async {
    try {
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        _availability = NotificationAvailability.denied;
        return null;
      }
      // ignore: deprecated_member_use
      _token ??= await messaging.getToken();
      if (_token == null) throw StateError('token');
      _availability = NotificationAvailability.ready;
      return _token;
    } catch (_) {
      _availability = NotificationAvailability.unavailable;
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    await _messages?.cancel();
    await _registration?.cancel();
    await _rotations.close();
    _channel.setMethodCallHandler(null);
    unawaited(_opened.close());
  }
}
