import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/connection_repository.dart';
import 'package:hermes_mobile/data/hermes_adapter.dart';
import 'package:hermes_mobile/data/storage/secret_store.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/profile.dart';

import 'support/connection_fakes.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.repository.dispose());
  test('origine/lien invalide : refus avant réseau et persistance', () async {
    for (final input in [
      '',
      'http://ts.net:9119',
      'http://localhost',
      'http://foo.ts.net.evil',
      'https://user:secret@example.com',
      'https://example.com/path',
      'https://example.com?token=secret',
      'https://example.com#',
      'https://example.com?',
      'ftp://example.com',
      'hermes-mobile://pair?url=https%3A%2F%2Fexample.com&password=secret',
      'hermes-mobile://pair?url=https%3A%2F%2Fexample.com&url=https%3A%2F%2Fevil.com',
      'hermes-mobile://pair/path?url=https%3A%2F%2Fexample.com',
    ]) {
      expect(() => parseOrigin(input), throwsA(isA<AppError>()), reason: input);
    }
    expect(h.store.writes, 0);
    expect(h.transport.requests, isEmpty);
    expect(
      parseOrigin('hermes-mobile://pair?url=http%3A%2F%2Fhost.ts.net%3A9119')
          .toString(),
      'http://host.ts.net:9119',
    );
    expect(
      parseOrigin('https://example.com/').toString(),
      'https://example.com',
    );
  });
  test(
    'login JSON, cookies, profils et défaut serveur sans mutation globale',
    () async {
      await h.connect();
      expect(h.repository.snapshot.link, LinkState.connected);
      expect(
        h.repository.snapshot.selectedProfile,
        const ProfileKey('default'),
      );
      final login = h.transport.requests.first;
      expect(login.body, {
        'provider': 'basic',
        'username': 'hermes',
        'password': '<SYNTHETIC_PASSWORD>',
        'next': '',
      });
      expect(login.bearer, isNull);
      expect(
        h.transport.requests
            .where((r) => r.uri.path == '/api/profiles')
            .single
            .bearer,
        '<SYNTHETIC_ACCESS>',
      );
      expect(
        h.transport.requests.any((r) => r.uri.path == '/api/profiles/active'),
        isFalse,
      );
      expect(
        h.secrets.values.keys.every(
          (key) => key.startsWith('${h.store.value!.key.value}/'),
        ),
        isTrue,
      );
      expect(
        () => h.repository.snapshot.profiles.clear(),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'refresh refusé : relogin depuis coffre, nouveau ticket, socket unique',
    () async {
      await h.connect();
      h.transport.refreshStatus = 401;
      await Future.wait([
        h.repository.reconnect(),
        h.repository.reconnect(),
        h.repository.refreshProfiles(),
      ]);
      expect(h.transport.maximumActive, 1);
      expect(h.transport.active, 1);
      expect(h.transport.ticketCount, 3);
      expect(
        h.transport.requests.where((r) => r.uri.path == '/auth/password-login'),
        hasLength(3),
      );
      expect(h.repository.snapshot.link, LinkState.connected);
    },
  );
  test(
    'redémarrage : connexion et choix explicite restaurés depuis stockage',
    () async {
      await h.connect();
      await h.repository.selectProfile(const ProfileKey('travail'));
      await h.repository.dispose();
      final restored = ConnectionRepository(
        adapter: HermesAdapter(h.transport),
        store: h.store,
        secrets: h.secrets,
      );
      addTearDown(restored.dispose);
      await restored.restore();
      expect(restored.snapshot.selectedProfile, const ProfileKey('travail'));
      expect(restored.snapshot.link, LinkState.connected);
    },
  );
  test('changement origine : ferme socket et efface credentials avant tout réseau, UUID stable', () async {
    await h.connect();
    final key = h.store.value!.key;
    await h.repository.selectProfile(const ProfileKey('travail'));
    final requests = h.transport.requests.length;
    await h.repository.confirmOrigin(parseOrigin('https://new.example.com'));
    expect(h.transport.active, 0);
    expect(h.secrets.values, isEmpty);
    expect(h.store.value!.key, key);
    expect(h.store.value!.selectedProfile, isNull);
    expect(h.transport.requests, hasLength(requests));
    h.transport.beforeRequest = () {
      expect(h.transport.active, 0);
      expect(h.secrets.operations, contains('clear'));
      expect(h.transport.requests.length, requests);
      h.transport.beforeRequest = null;
    };
    await h.repository.authenticate('<SYNTHETIC_NEW_PASSWORD>');
    expect(h.repository.snapshot.link, LinkState.connected);
  });
  test(
    'transport, auth, méthode absente et redirection ont des codes distincts',
    () async {
      await h.repository.confirmOrigin(parseOrigin('https://example.com'));
      h.transport.loginStatus = 401;
      await h.repository.authenticate('SYNTHETIC');
      expect(h.repository.snapshot.error!.code, 'auth.refused');
      expect(h.repository.snapshot.error!.retryable, isFalse);
      h.transport.loginStatus = 404;
      await h.repository.authenticate('SYNTHETIC');
      expect(h.repository.snapshot.error!.code, 'contract.method_missing');
      h.transport.loginStatus = 302;
      await h.repository.authenticate('SYNTHETIC');
      expect(h.repository.snapshot.error!.code, 'transport.redirect');
      h.transport.unreachable = true;
      await h.repository.authenticate('SYNTHETIC');
      expect(h.repository.snapshot.error!.code, 'transport.unreachable');
      expect(h.repository.snapshot.error!.retryable, isTrue);
      expect(
        h.repository.snapshot.error.toString(),
        isNot(contains('PASSWORD')),
      );
    },
  );
  test(
    'profils loading, empty, error, refreshing ; aucun défaut inventé',
    () async {
      final states = <ProfilesState>[];
      final sub = h.repository.snapshots.listen(
        (s) => states.add(s.profilesState),
      );
      addTearDown(sub.cancel);
      await h.connect();
      await h.repository.refreshProfiles();
      h.transport.profiles = fixture('profiles-empty');
      await h.repository.refreshProfiles();
      expect(h.repository.snapshot.profilesState, ProfilesState.empty);
      expect(h.repository.snapshot.selectedProfile, isNull);
      h.transport.profilesStatus = 500;
      await h.repository.refreshProfiles();
      expect(h.repository.snapshot.profilesState, ProfilesState.error);
      expect(
        states,
        containsAll([
          ProfilesState.loading,
          ProfilesState.ready,
          ProfilesState.refreshing,
          ProfilesState.empty,
          ProfilesState.error,
        ]),
      );
      h.transport.profilesStatus = 200;
      h.transport.profiles = {
        'profiles': [
          {'name': 'CaseSensitive', 'is_default': false},
        ],
      };
      await h.repository.refreshProfiles();
      expect(h.repository.snapshot.selectedProfile, isNull);
    },
  );
  test('choix explicite local prioritaire au défaut et conservé après actualisation', () async {
    await h.connect();
    await h.repository.selectProfile(const ProfileKey('travail'));
    await h.repository.refreshProfiles();
    expect(h.repository.snapshot.selectedProfile, const ProfileKey('travail'));
    expect(h.store.value!.selectedProfile, const ProfileKey('travail'));
    expect(
      h.transport.requests
          .where((r) => r.method == 'POST')
          .every(
            (r) =>
                r.uri.path.startsWith('/auth/') ||
                r.uri.path == '/api/auth/ws-ticket',
          ),
      isTrue,
    );
  });
  test(
    'capacités requises absentes ou non vérifiées gardent acceptation ouverte',
    () async {
      expect(h.repository.snapshot.acceptanceOpen, isTrue);
      h.transport.ready = {
        'method': 'event',
        'params': {'type': 'gateway.ready', 'payload': {}},
      };
      h.transport.profilesStatus = 404;
      await h.connect();
      final caps = h.repository.snapshot.capabilities;
      expect(
        caps.singleWhere((c) => c.name == 'profiles').state,
        CapabilityState.absent,
      );
      expect(
        caps.singleWhere((c) => c.name == 'replay_epoch').state,
        CapabilityState.absent,
      );
      expect(
        caps.singleWhere((c) => c.name == 'file.attach').state,
        CapabilityState.unverified,
      );
      expect(h.repository.snapshot.acceptanceOpen, isTrue);
    },
  );
  test(
    'socket perdue : resynchronisation, retries bornés puis hors ligne',
    () async {
      await h.connect();
      final states = <LinkState>[];
      final sub = h.repository.snapshots.listen((s) => states.add(s.link));
      addTearDown(sub.cancel);
      await h.transport.sockets.last.drop();
      await Future<void>.delayed(Duration.zero);
      expect(h.repository.snapshot.link, LinkState.resyncing);
      h.transport.unreachable = true;
      for (var attempt = 0; attempt < 3; attempt++) {
        expect(h.delays.length, attempt + 1);
        h.delays[attempt].complete();
        await Future<void>.delayed(Duration.zero);
      }
      expect(h.delays, hasLength(3));
      expect(h.repository.snapshot.link, LinkState.offline);
      expect(states, containsAll([LinkState.resyncing, LinkState.offline]));
      expect(h.transport.maximumActive, 1);
    },
  );
  test(
    'une succession de sockets ouvertes puis perdues reste bornée',
    () async {
      await h.connect();
      for (var attempt = 0; attempt < 3; attempt++) {
        await h.transport.sockets.last.drop();
        await Future<void>.delayed(Duration.zero);
        h.delays[attempt].complete();
        await Future<void>.delayed(Duration.zero);
        expect(h.repository.snapshot.link, LinkState.connected);
      }
      await h.transport.sockets.last.drop();
      await Future<void>.delayed(Duration.zero);
      expect(h.delays, hasLength(3));
      expect(h.repository.snapshot.link, LinkState.offline);
      expect(h.transport.maximumActive, 1);
    },
  );
  test('retry périmé ne reconnecte pas une ancienne origine', () async {
    await h.connect();
    await h.transport.sockets.last.drop();
    await Future<void>.delayed(Duration.zero);
    await h.repository.confirmOrigin(
      parseOrigin('https://another.example.com'),
    );
    final count = h.transport.requests.length;
    h.delays.single.complete();
    await Future<void>.delayed(Duration.zero);
    expect(h.transport.requests.length, count);
    expect(h.repository.snapshot.authenticated, isFalse);
    expect(h.secrets.values, isEmpty);
  });
  test('méthode RPC absente : fonction visible et message dédié', () async {
    h.transport.missingRpc = true;
    await h.connect();
    await Future<void>.delayed(Duration.zero);
    expect(h.repository.snapshot.error!.code, 'contract.method_missing');
    expect(
      h.repository.snapshot.capabilities
          .singleWhere((c) => c.name == 'per_session_exclusive_submit')
          .state,
      CapabilityState.absent,
    );
  });
  test(
    'cookies HTTPS préfixés et relogin sans RT efface le jeton obsolète',
    () async {
      await h.connect();
      h.transport.loginCookies = [
        '__Host-hermes_session_at=<SYNTHETIC_NEW_ACCESS>; Path=/; Secure; HttpOnly',
      ];
      await h.repository.authenticate('<SYNTHETIC_PASSWORD>');
      final key = h.store.value!.key;
      expect(await h.secrets.read(key, SecretUsage.refreshToken), isNull);
      expect(
        await h.secrets.read(key, SecretUsage.accessToken),
        '<SYNTHETIC_NEW_ACCESS>',
      );
      expect(h.repository.snapshot.link, LinkState.connected);
    },
  );
  test('clé UUID v4 et usage coffre', () async {
    expect(
      ConnectionKey.create().value,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    await h.connect();
    expect(
      await h.secrets.read(h.store.value!.key, SecretUsage.password),
      '<SYNTHETIC_PASSWORD>',
    );
  });
}
