import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

import '../models/notifications.dart';

const notificationSetupTimeout = Duration(seconds: 4);

/// Configuration native facultative, sans faux token ni options générées.
class FirebaseNotificationClient implements NotificationClient {
  static const _channel = MethodChannel('hermes/notifications');
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
      _registration = _messaging!.onRegistered.listen((token) {
        if (_token == token) return;
        _token = token;
        _rotations.add(token);
      });
      await _channel.invokeMethod<void>('createChannel');
      _messages = FirebaseMessaging.onMessage.listen((message) {
        // Reconstruire le libellé générique, sans afficher du texte reçu.
        final data = message.data;
        if (data.length == 2 &&
            data.keys.toSet().containsAll({'subscriptionId', 'outcome'}) &&
            RegExp(r'^[A-Za-z0-9_-]{22,128}$')
                .hasMatch(data['subscriptionId'] ?? '') &&
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
  Future<String?> token({bool requestPermission = false}) async {
    try {
      return await _acquire(requestPermission)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      _availability = NotificationAvailability.unavailable;
      return null;
    }
  }

  Future<String?> _acquire(bool requestPermission) async {
    final messaging = _messaging;
    if (messaging == null) return null;
    try {
      final settings = requestPermission
          ? await messaging.requestPermission()
          : await messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        _availability = NotificationAvailability.denied;
        return null;
      }
      if (requestPermission) await messaging.setAutoInitEnabled(true);
      if (_token == null) {
        final next = Completer<String>();
        final subscription = _rotations.stream.listen((value) {
          if (!next.isCompleted) next.complete(value);
        });
        try {
          await messaging.register().timeout(const Duration(seconds: 3));
          _token = await next.future.timeout(const Duration(seconds: 3));
        } finally {
          await subscription.cancel();
        }
      }
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
  }
}
