import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/connection.dart';

import 'support/connection_fakes.dart';

class ManualDeadline implements Timer {
  ManualDeadline(this.callback);
  final void Function() callback;
  bool active = true;
  void fire() {
    if (active) {
      active = false;
      callback();
    }
  }

  @override
  void cancel() => active = false;
  @override
  bool get isActive => active;
  @override
  int get tick => active ? 0 : 1;
}

Future<void> withDeadlines(Future<void> Function(List<ManualDeadline>) body) {
  final timers = <ManualDeadline>[];
  return runZoned(
    () => body(timers),
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        if (duration != const Duration(seconds: 15)) {
          return parent.createTimer(zone, duration, callback);
        }
        final timer = ManualDeadline(callback);
        timers.add(timer);
        return timer;
      },
    ),
  );
}

void main() {
  for (final password in ['<SYNTHETIC_REFUSED>', '']) {
    test(
      'réauthentification refusée ou vide invalide ancienne session : ${password.isEmpty}',
      () async {
        final h = Harness();
        addTearDown(h.repository.dispose);
        await h.connect();
        h.transport.loginStatus = 401;
        await h.repository.authenticate(password);
        expect(h.repository.snapshot.authenticated, isFalse);
        expect(h.repository.snapshot.link, LinkState.offline);
        expect(h.transport.active, 0);
        expect(
          h.repository.snapshot.error!.code,
          password.isEmpty ? 'auth.password_required' : 'auth.refused',
        );
      },
    );
  }
  test(
    'refus final pendant actualisation invalide auth et ferme socket',
    () async {
      final h = Harness();
      addTearDown(h.repository.dispose);
      await h.connect();
      h.transport.profilesStatus = 401;
      h.transport.refreshStatus = 401;
      h.transport.loginStatus = 401;
      await h.repository.refreshProfiles();
      expect(h.repository.snapshot.authenticated, isFalse);
      expect(h.repository.snapshot.link, LinkState.offline);
      expect(h.transport.active, 0);
      expect(h.repository.snapshot.error!.code, 'auth.refused');
    },
  );
  test(
    'connexion ne crée aucune socket après refus final des profils',
    () async {
      final h = Harness();
      addTearDown(h.repository.dispose);
      h.transport.profilesStatus = 401;
      await h.connect();
      expect(h.transport.ticketCount, 0);
      expect(h.transport.sockets, isEmpty);
      expect(h.repository.snapshot.authenticated, isFalse);
      expect(h.repository.snapshot.busy, isFalse);
      expect(h.repository.snapshot.link, LinkState.offline);
    },
  );
  for (final failure in ['secret', 'sqlite']) {
    test('changement origine avec échec $failure reste déconnecté', () async {
      final h = Harness();
      addTearDown(h.repository.dispose);
      await h.connect();
      final requests = h.transport.requests.length;
      h.secrets.failClear = failure == 'secret';
      h.store.failSave = failure == 'sqlite';
      await h.repository.confirmOrigin(parseOrigin('https://new.example'));
      expect(h.repository.snapshot.link, LinkState.offline);
      expect(h.repository.snapshot.authenticated, isFalse);
      expect(h.transport.active, 0);
      expect(h.transport.requests.length, requests);
      expect(h.repository.snapshot.error!.code, 'storage.unavailable');
    });
  }
  test(
    'RPC 5035 ferme immédiatement, borne retries et ignore callbacks doublés',
    () async {
      final h = Harness();
      addTearDown(h.repository.dispose);
      h.transport.rpcError = 5035;
      await h.connect();
      await Future<void>.delayed(Duration.zero);
      expect(h.transport.active, 0);
      for (var attempt = 0; attempt < 3; attempt++) {
        expect(h.delays.length, attempt + 1);
        h.delays[attempt].complete();
        await Future<void>.delayed(Duration.zero);
        expect(h.transport.active, 0);
      }
      expect(h.delays, hasLength(3));
      expect(h.repository.snapshot.link, LinkState.offline);
      expect(h.transport.maximumActive, 1);
    },
  );
  test(
    'capacités sans réponse expirent et permettent reprise explicite',
    () => withDeadlines((timers) async {
      final h = Harness();
      addTearDown(h.repository.dispose);
      h.transport.silentRpc = true;
      await h.connect();
      expect(timers.where((timer) => timer.isActive), hasLength(1));
      timers.singleWhere((timer) => timer.isActive).fire();
      await Future<void>.delayed(Duration.zero);
      expect(
        h.repository.snapshot.error!.code,
        'contract.capabilities_timeout',
      );
      expect(h.transport.active, 0);
      expect(h.delays, hasLength(1));
      h.transport.silentRpc = false;
      await h.repository.reconnect();
      await Future<void>.delayed(Duration.zero);
      expect(h.repository.snapshot.link, LinkState.connected);
      expect(timers.every((timer) => !timer.isActive), isTrue);
      expect(h.transport.maximumActive, 1);
    }),
  );
  test(
    'délai capacités annulé lors de fermeture',
    () => withDeadlines((timers) async {
      final h = Harness();
      addTearDown(h.repository.dispose);
      h.transport.silentRpc = true;
      await h.connect();
      await h.repository.confirmOrigin(parseOrigin('https://new.example'));
      expect(timers.every((timer) => !timer.isActive), isTrue);
      for (final timer in timers) {
        timer.fire();
      }
      expect(h.delays, isEmpty);
    }),
  );
  for (final result in [
    <String, dynamic>{},
    {'per_session_exclusive_submit': 'false'},
  ]) {
    test('capacité malformée reste non vérifiée : $result', () async {
      final h = Harness();
      addTearDown(h.repository.dispose);
      h.transport.rpcResult = result;
      await h.connect();
      await Future<void>.delayed(Duration.zero);
      expect(
        h.repository.snapshot.capabilities
            .singleWhere((c) => c.name == 'per_session_exclusive_submit')
            .state,
        CapabilityState.unverified,
      );
      expect(h.repository.snapshot.error!.code, 'contract.invalid_response');
    });
  }
  test(
    'réponse malformée ne conserve pas une ancienne capacité confirmée',
    () async {
      final h = Harness();
      addTearDown(h.repository.dispose);
      await h.connect();
      await Future<void>.delayed(Duration.zero);
      h.transport.sockets.single.controller.add({
        'id': 'capabilities',
        'result': {},
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        h.repository.snapshot.capabilities
            .singleWhere((c) => c.name == 'per_session_exclusive_submit')
            .state,
        CapabilityState.unverified,
      );
      expect(h.repository.snapshot.error!.code, 'contract.invalid_response');
    },
  );
}
