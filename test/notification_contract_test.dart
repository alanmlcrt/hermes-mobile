import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/models/timeline.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _maps(Object? value) =>
    (value as List).cast<Map<String, dynamic>>();

Object? _resolve(Map<String, dynamic> root, String pointer) {
  Object? current = root;
  for (final part in pointer.split('/').where((part) => part.isNotEmpty)) {
    if (current is! Map) return null;
    current = current[part.replaceAll('~1', '/').replaceAll('~0', '~')];
  }
  return current;
}

String? _refName(Object? node) {
  if (node is Map && node[r'$ref'] is String) {
    return (node[r'$ref'] as String).split('/').last;
  }
  return null;
}

bool _allowsType(Map<String, dynamic> node, String type) {
  if (node['type'] == type) return true;
  final variants = node['anyOf'];
  if (variants is List) {
    return variants.any((variant) => variant is Map && variant['type'] == type);
  }
  return false;
}

void _expectNoPersonalText(String text, String source) {
  expect(
    RegExp(r'(^|[^\w])[A-Za-z]:[\\/]').hasMatch(text),
    isFalse,
    reason: '$source : chemin Windows absolu',
  );
  expect(
    RegExp(r'(^|[^\w])/(home|Users|root)/').hasMatch(text),
    isFalse,
    reason: '$source : chemin personnel POSIX',
  );
  expect(
    RegExp(r'-----BEGIN').hasMatch(text),
    isFalse,
    reason: '$source : clé privée',
  );
  expect(
    RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.').hasMatch(text),
    isFalse,
    reason: '$source : JWT',
  );
  expect(
    RegExp(r'Bearer\s').hasMatch(text),
    isFalse,
    reason: '$source : bearer littéral',
  );
  expect(
    RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').hasMatch(text),
    isFalse,
    reason: '$source : adresse électronique',
  );
  expect(
    RegExp(r'AIza[0-9A-Za-z_-]{35}').hasMatch(text),
    isFalse,
    reason: '$source : clé API Google',
  );
  expect(
    RegExp(r'ghp_[A-Za-z0-9]{20,}').hasMatch(text),
    isFalse,
    reason: '$source : jeton GitHub',
  );
}

void _scanContractValue(Object? value, String key) {
  if (value is Map) {
    for (final entry in value.entries) {
      final name = entry.key as String;
      expect(
        const {
          'private_key',
          'client_email',
          'password',
          'token',
          'secret',
          'apiKey',
          'serviceAccountKey',
          'authorization',
          'bearerToken',
        },
        isNot(contains(name)),
        reason: 'champ interdit : $name',
      );
      _scanContractValue(entry.value, name);
    }
  } else if (value is List) {
    for (final item in value) {
      _scanContractValue(item, key);
    }
  } else if (value is String) {
    _expectNoPersonalText(value, key);
    expect(value.toUpperCase(), isNot(contains('TBD')), reason: key);
    expect(value.toUpperCase(), isNot(contains('TODO')), reason: key);
  }
}

void main() {
  final tracking = _json('contracts/notification-tracking.json');
  final deployment = _json('contracts/notification-deployment.json');
  final mappingJson = _json('contracts/event-mapping.json');
  final methodsJson = _json('contracts/methods.json');
  final openrpc = _json('contracts/openrpc.json');
  final mapping = EventMapping(mappingJson);
  final terminals = _maps(tracking['terminals']);
  final outcomes = terminals.map((entry) => entry['outcome'] as String).toSet();

  final schemas =
      (openrpc['components'] as Map)['schemas'] as Map<String, dynamic>;
  Map<String, dynamic> schema(String name) =>
      schemas[name] as Map<String, dynamic>;
  Map<String, dynamic> property(String schemaName, String name) =>
      (schema(schemaName)['properties'] as Map)[name] as Map<String, dynamic>;
  final rpcMethods = (openrpc['methods'] as List).cast<Map<String, dynamic>>();
  Map<String, dynamic> rpcMethod(String name) =>
      rpcMethods.singleWhere((method) => method['name'] == name);

  Object? trackingReference(String value) {
    expect(
      value,
      startsWith('contracts/notification-tracking.json#'),
      reason: value,
    );
    return _resolve(tracking, value.substring(value.indexOf('#') + 1));
  }

  Object? openrpcReference(String value) {
    expect(value, startsWith('contracts/openrpc.json#'), reason: value);
    return _resolve(openrpc, value.substring(value.indexOf('#') + 1));
  }

  Map<String, dynamic> endpoint(String name) =>
      (tracking['endpoints'] as Map)[name] as Map<String, dynamic>;

  final decisions = _maps(deployment['decisions']);
  final decisionById = {
    for (final decision in decisions) decision['id'] as String: decision,
  };
  final proposals = _maps(deployment['proposed']);
  final proposalById = {
    for (final proposal in proposals) proposal['id'] as String: proposal,
  };
  final gate = deployment['gate'] as Map;
  final validation = deployment['validation'] as Map;
  final blockers = _maps(gate['blockers']);
  final blockerIds = blockers.map((blocker) => blocker['id']).toSet();
  final pending = _maps(validation['pending']);
  final pendingById = {
    for (final entry in pending) entry['id'] as String: entry,
  };

  group('contrat de suivi', () {
    test('schéma v1, provenance et mapping autoritaire', () {
      expect(tracking['schemaVersion'], 1);
      expect(tracking['evidence'], 'documentary');
      final provenance = tracking['provenance'] as Map;
      expect(provenance['kind'], 'documentary');
      expect(provenance['fixtures'], 'synthetic');
      expect(provenance['realAcceptance'], 'open');
      expect(DateTime.tryParse(provenance['decidedAt'] as String), isNotNull);
      expect(
        (provenance['sources'] as List).cast<String>(),
        containsAll([
          'contracts/event-mapping.json',
          'contracts/openrpc.json',
          '_bmad-output/implementation-artifacts/epic-5-context.md',
        ]),
      );
      final reference = tracking['mapping'] as Map;
      expect(reference['path'], 'contracts/event-mapping.json');
      expect(reference['authoritative'], isTrue);
      expect(reference['fallback'], mappingJson['fallback']);
      expect(reference['fixturesDir'], 'contracts/fixtures/');
      expect(reference['terminalRule'], contains('statusMap'));
      expect(reference['terminalRule'], contains('workState'));
    });

    test('trois terminaux résolus, couverture inverse du mapping', () {
      expect(terminals, hasLength(3));
      expect(outcomes, {'succeeded', 'failed', 'stopped'});
      for (final terminal in terminals) {
        final outcome = terminal['outcome'] as String;
        final sources = _maps(terminal['sources']);
        expect(sources, isNotEmpty, reason: outcome);
        for (final source in sources) {
          final event = source['event'] as String;
          final status = source['status'];
          final mapped = mapping.map(event, {'status': ?status});
          expect(mapped.effect, EventEffect.terminal, reason: '$event/$status');
          expect(mapped.workState?.name, outcome, reason: '$event/$status');
          final entry = (mappingJson['events'] as Map)[event] as Map;
          expect(entry['terminal'], isTrue, reason: event);
          expect(entry['effect'], 'terminal', reason: event);
          if (status == null) {
            expect(entry['workState'], outcome, reason: event);
          } else {
            expect(
              (entry['statusMap'] as Map)[status],
              outcome,
              reason: '$event/$status',
            );
          }
        }
        final fixture = _json(terminal['fixture'] as String);
        expect(fixture['method'], 'event');
        final params = fixture['params'] as Map;
        final payload = Map<String, dynamic>.from(params['payload'] as Map);
        final mapped = mapping.map(params['type'] as String, payload);
        expect(
          mapped.workState?.name,
          outcome,
          reason: terminal['fixture'] as String,
        );
        expect(
          sources.map((source) => source['event']).toSet(),
          contains(params['type']),
          reason: terminal['fixture'] as String,
        );
      }

      final failed = terminals.singleWhere(
        (terminal) => terminal['outcome'] == 'failed',
      );
      final correlation = failed['correlation'] as Map;
      expect(correlation['error'], contains('unique'));
      expect(correlation['error'], contains('non notifiée'));
      expect(correlation['rule'], contains('user_row_id'));
      expect(correlation['rule'], contains('sinon il est ignoré'));

      final events = mappingJson['events'] as Map;
      final terminalEvents = events.entries
          .where(
            (entry) =>
                (entry.value as Map)['effect'] == 'terminal' &&
                (entry.value as Map)['terminal'] == true,
          )
          .map((entry) => entry.key as String)
          .toSet();
      final covered = terminals
          .expand((terminal) => _maps(terminal['sources']))
          .map((source) => source['event'] as String)
          .toSet();
      expect(covered, terminalEvents);
      for (final event in terminalEvents) {
        final entry = events[event] as Map;
        final statuses = terminals
            .expand((terminal) => _maps(terminal['sources']))
            .where((source) => source['event'] == event)
            .map((source) => source['status'])
            .toSet();
        if (entry['statusMap'] case final Map statusMap) {
          expect(statuses, statusMap.keys.toSet(), reason: event);
        } else {
          expect(entry['workState'], isNotNull, reason: event);
          expect(statuses, contains(null), reason: event);
        }
      }
    });

    test('un statut absent ou inconnu ne notifie jamais', () {
      expect(mapping.map('message.complete', {}).workState, WorkState.unknown);
      expect(
        mapping.map('message.complete', {'status': 'autre'}).workState,
        WorkState.unknown,
      );
      expect(outcomes, isNot(contains('unknown')));
      for (final event in [
        'message.start',
        'message.delta',
        'message.interim',
        'tool.start',
        'tool.complete',
        'gateway.ready',
        'status.update',
        'session.info',
        'sessions.changed',
        'session.title',
        'unknown',
      ]) {
        expect(
          mapping.map(event, {}).effect,
          isNot(EventEffect.terminal),
          reason: event,
        );
      }
      final nonTerminals = tracking['nonTerminals'] as Map;
      expect(nonTerminals['examples'], contains('tool.complete'));
      expect(nonTerminals['unknownStatus'], contains('unknown'));
    });

    test(
      'payload notification + data, data strict {subscriptionId, outcome}',
      () {
        final payload = tracking['payload'] as Map;
        expect(payload['transport'], 'fcm-http-v1');
        expect(payload['platforms'], ['android']);
        expect(payload['messageKind'], 'notification-and-data');
        expect(payload['dataValueType'], 'string');
        expect(payload['dataFields'], ['subscriptionId', 'outcome']);
        expect(payload.containsKey('dataOnly'), isFalse);
        expect(payload['outcomeValues'], containsAll(outcomes));
        expect((payload['outcomeValues'] as List).toSet(), outcomes);

        final notification = payload['notification'] as Map;
        expect(notification['title'], 'Hermes');
        expect(notification['labelLocation'], 'server-fixed-map');
        expect(notification['clientFallback'], isTrue);
        expect(notification['contentSource'], 'outcome-only');
        final bodies = notification['bodyByOutcome'] as Map;
        expect(bodies.keys.toSet(), outcomes);
        for (final body in bodies.values) {
          expect(body, isA<String>());
          final text = body as String;
          expect(text.trim(), isNotEmpty);
          expect(text, isNot(contains('{')));
          expect(text, isNot(contains('}')));
        }
        expect(
          trackingReference(notification['clientFallbackSource'] as String),
          equals(bodies),
        );

        final android = payload['android'] as Map;
        expect(android['channelId'], 'hermes_turn_complete');
        expect(android['channelCreatedBy'], '5.3');
        expect(android['priority'], 'high');
        expect(android['notificationPriority'], 'high');
        expect(android['ttlSeconds'], inInclusiveRange(1, 172800));
        expect(android['notificationTagTemplate'], contains('subscriptionId'));
        expect(android['notificationTagTemplate'], contains('outcome'));
        expect(android['collapseKeyTemplate'], contains('subscriptionId'));
        expect(android['visibleDuplicates'], 'dedupe-by-tag');

        final forbidden = (payload['forbiddenDataFields'] as List)
            .cast<String>();
        expect(forbidden.toSet(), hasLength(forbidden.length));
        for (final field in [
          'text',
          'title',
          'body',
          'sessionKey',
          'sessionId',
          'session_id',
          'profileKey',
          'profile_id',
          'connectionKey',
          'connection_id',
          'executionId',
          'execution_id',
          'submission_id',
          'user_row_id',
          'path',
          'token',
          'fcmToken',
          'fcm_token',
          'credential',
          'error',
          'message',
        ]) {
          expect(forbidden, contains(field), reason: field);
        }
        final fields = (payload['dataFields'] as List).cast<String>();
        expect(forbidden.toSet().intersection(fields.toSet()), isEmpty);

        bool accepts(Map<String, Object?> value) {
          if (value.keys.any(forbidden.contains)) return false;
          if (value.keys.length != fields.length) return false;
          if (!value.keys.every(fields.contains)) return false;
          return fields.every(value.containsKey);
        }

        final valid = {
          'subscriptionId': 'SYNTHETIC_SUB',
          'outcome': 'succeeded',
        };
        expect(accepts(valid), isTrue);
        expect(accepts({'subscriptionId': 'SYNTHETIC_SUB'}), isFalse);
        expect(accepts({...valid, 'autre': 'x'}), isFalse);
        for (final field in forbidden) {
          expect(accepts({...valid, field: 'x'}), isFalse, reason: field);
        }
      },
    );

    test('registre : token FCM, session et exécution corrélées', () {
      final registry = tracking['registry'] as Map;
      expect(registry['key'], 'subscriptionId');
      expect(registry['generatedBy'], 'mobile');
      expect(registry['format'], 'opaque');
      expect(registry['encoding'], 'base64url');
      expect(registry['minLength'], greaterThanOrEqualTo(22));
      expect(
        registry['maxLength'],
        greaterThanOrEqualTo(registry['minLength']),
      );
      expect(registry['minEntropyBits'], greaterThanOrEqualTo(122));
      expect(registry['createdBefore'], 'prompt.submit');
      expect(registry['nonBlocking'], isTrue);
      expect(
        (registry['states'] as List).cast<String>(),
        containsAll([
          'registered',
          'attached',
          'notified',
          'revoked',
          'expired',
        ]),
      );

      final lifecycle = _maps(registry['lifecycle']);
      expect(
        lifecycle.map((step) => step['state']).toList(),
        containsAllInOrder(['registered', 'attached']),
      );
      final registered = lifecycle.firstWhere(
        (step) => step['state'] == 'registered',
      );
      final attached = lifecycle.firstWhere(
        (step) => step['state'] == 'attached',
      );
      final notified = lifecycle.firstWhere(
        (step) => step['state'] == 'notified',
      );
      expect(registered['when'], 'before-prompt-submit');
      expect(
        (registered['requires'] as List).cast<String>(),
        containsAll(['subscriptionId', 'fcmToken']),
      );
      expect(registered['onFailure'], 'send-proceeds-unfollowed');
      expect(attached['when'], 'after-prompt-submit-accepted');
      expect(
        (attached['requires'] as List).cast<String>(),
        containsAll(['sessionId', 'profile', 'executionId']),
      );
      expect(attached['onFailure'], 'send-proceeds-unfollowed');
      expect(notified['when'], 'terminal-delivered');
      expect(
        (notified['requires'] as List).cast<String>(),
        containsAll(['executionId', 'terminal']),
      );

      final attachment = registry['attachment'] as Map;
      expect(attachment['endpoint'], 'attach');
      expect((attachment['sessionScope'] as List).cast<String>(), [
        'sessionId',
        'profile',
      ]);
      expect(attachment['sessionIdSource'], 'prompt.submit.params.session_id');
      expect(attachment['profileSource'], 'connection.profile');
      expect(attachment['profileNullable'], isTrue);
      expect(
        (attachment['observerWatch'] as List).cast<String>(),
        containsAll(['session.resume', 'session.events.since']),
      );
      expect(attachment['onSessionNotFound'], 'retry-bounded-then-expire');
      expect(attachment['onExpired'], 'no-notification');

      final execution = registry['executionId'] as Map;
      expect(execution['sentToObserverOnAttach'], isTrue);
      expect(execution['inPushPayload'], isFalse);
      expect(execution['oldTerminalPolicy'], contains('antérieur'));
      final attachTime = execution['attachTime'] as Map;
      expect(attachTime['source'], 'prompt.submit.result.user_row_id');
      expect(attachTime['scopedBy'], 'session_id');
      expect(attachTime['composition'], contains('session_id'));
      expect(attachTime['composition'], contains('user_row_id'));
      expect(attachTime['whenMissing'], 'no-attach-no-notification');
      final attachSchema =
          openrpcReference(attachTime['schema'] as String) as Map;
      expect(
        _allowsType(Map<String, dynamic>.from(attachSchema), 'integer'),
        isTrue,
      );
      expect(
        _allowsType(Map<String, dynamic>.from(attachSchema), 'null'),
        isTrue,
      );
      final persistedTurn = property('PersistedTurn', 'user_row_id');
      expect(_allowsType(persistedTurn, 'integer'), isTrue);
      expect(_allowsType(persistedTurn, 'null'), isTrue);
      final submissionId = property('PersistedTurn', 'submission_id');
      expect(_allowsType(submissionId, 'string'), isTrue);
      expect(_allowsType(submissionId, 'null'), isTrue);
      final persistedRefs =
          ((schema('MessageCompletePayload')['properties']
                      as Map)['persisted_turn']
                  as Map)['anyOf']
              as List;
      expect(
        persistedRefs.map(_refName).whereType<String>(),
        contains('PersistedTurn'),
      );

      final terminalMatch = execution['terminalMatch'] as Map;
      expect(terminalMatch['session'], 'event.params.session_id');
      expect(
        terminalMatch['row'],
        'message.complete.payload.persisted_turn.user_row_id',
      );
      expect(
        terminalMatch['optionalStronger'],
        'message.complete.payload.persisted_turn.submission_id',
      );
      expect(terminalMatch['rule'], contains('user_row_id'));
      expect(terminalMatch['rule'], contains('session_id'));

      final submit = rpcMethod('prompt.submit');
      final paramsRef =
          ((submit['params'] as List).single as Map)['schema'] as Map;
      final submitParams =
          schemas[((paramsRef[r'$ref'] as String).split('/').last)]
              as Map<String, dynamic>;
      expect(
        (submitParams['required'] as List).cast<String>(),
        contains('session_id'),
      );
      expect(
        ((submitParams['properties'] as Map)['session_id'] as Map)['type'],
        'string',
      );
      final errorProperties = (schema('ErrorPayload')['properties'] as Map).keys
          .toSet();
      expect(errorProperties, {'message'});

      final deviceToken = registry['deviceToken'] as Map;
      expect(deviceToken['provider'], 'fcm');
      expect(deviceToken['registeredWith'], 'register');
      expect(deviceToken['rotation'], 're-register-same-subscription');
      expect(deviceToken['storage'], 'encrypted-at-rest');
      expect(deviceToken['onePerSubscription'], isTrue);
      expect(deviceToken['inPushPayload'], isFalse);
      expect(deviceToken['inLogs'], isFalse);
      expect(deviceToken['invalidToken'], 'remove-subscription-no-retry');
      expect(deviceToken['requiredForEnvironments'], ['personal']);
      expect(deviceToken['dryRunValue'], 'synthetic-placeholder');

      expect(registry['ttlSeconds'], greaterThan(0));
      expect(
        registry['attachedTtlSeconds'],
        greaterThanOrEqualTo(registry['ttlSeconds'] as int),
      );
      final expiry = registry['expiryByState'] as Map;
      expect(expiry['registered'], 'ttlSeconds');
      expect(expiry['attached'], 'attachedTtlSeconds');
      expect(expiry['notified'], 'retention.notifiedTtlSeconds');
      expect(expiry['revoked'], 'delete-on-revoke');
      expect(registry['revokeOnTerminal'], isFalse);
    });

    test('déduplication, premier terminal gagnant et doublons visibles', () {
      final dedup = tracking['deduplication'] as Map;
      expect(dedup['key'], ['subscriptionId', 'executionId', 'terminal']);
      expect((dedup['terminalValues'] as List).toSet(), outcomes);
      expect(dedup['scope'], 'observer-outbox');
      expect(dedup['persistent'], isTrue);
      expect(dedup['duplicatePolicy'], 'keep-first');
      expect(dedup['perExecutionPolicy'], 'first-terminal-wins');
      expect(dedup['lateTerminalPolicy'], 'ignore-after-notified');
      expect(dedup['providerDuplicatePolicy'], 'dedupe-visible-by-tag');
      expect(dedup['repeatDelivery'], 'at-least-once-until-drop');
      expect(dedup['exactlyOnce'], isFalse);
      expect(tracking['invariants'], contains(contains('premier terminal')));
      expect(
        (tracking['invariants'] as List).join(' ').toLowerCase(),
        isNot(contains('exactement une fois')),
      );
    });

    test('endpoints exacts, corps figés et statuts cohérents', () {
      expect((tracking['endpoints'] as Map)['basePath'], '/v1');
      final names = ['register', 'attach', 'revoke', 'health'];
      for (final name in names) {
        final entry = endpoint(name);
        expect(entry['auth'], 'bearer', reason: name);
        expect(entry['idempotent'], isTrue, reason: name);
        expect(entry['blocking'], isFalse, reason: name);
      }
      expect(endpoint('register')['method'], 'POST');
      expect(endpoint('register')['path'], '/v1/subscriptions');
      expect(endpoint('register')['body'], ['subscriptionId', 'fcmToken']);
      final registerTypes = endpoint('register')['bodyTypes'] as Map;
      expect(registerTypes['subscriptionId'], 'string');
      expect(registerTypes['fcmToken'], 'string');
      expect(endpoint('register')['subscriptionIdFormat'], 'base64url-22-128');
      expect(
        (endpoint('register')['fcmTokenRequiredFor'] as List).cast<String>(),
        contains('personal'),
      );
      expect(
        endpoint('register')['duplicatePolicy'],
        'update-token-return-200',
      );
      expect((endpoint('register')['successStatus'] as List).toSet(), {
        200,
        201,
      });
      expect(
        (endpoint('register')['errorStatus'] as List),
        isNot(contains(409)),
      );

      expect(endpoint('attach')['method'], 'POST');
      expect(
        endpoint('attach')['path'],
        '/v1/subscriptions/{subscriptionId}/attach',
      );
      expect(endpoint('attach')['body'], [
        'sessionId',
        'profile',
        'executionId',
      ]);
      final attachTypes = endpoint('attach')['bodyTypes'] as Map;
      expect(attachTypes['sessionId'], 'string');
      expect(attachTypes['profile'], 'string|null');
      expect(attachTypes['executionId'], 'string');
      expect(endpoint('attach')['duplicatePolicy'], 'return-200');
      expect(endpoint('attach')['acceptedStatus'], 202);
      expect(endpoint('attach')['acceptedMeaning'], isNotEmpty);
      expect((endpoint('attach')['successStatus'] as List), contains(202));
      expect(endpoint('attach')['expiredStatus'], 410);
      expect((endpoint('attach')['errorStatus'] as List), contains(410));
      expect((endpoint('attach')['errorStatus'] as List), isNot(contains(409)));

      expect(endpoint('revoke')['method'], 'DELETE');
      expect(endpoint('revoke')['path'], '/v1/subscriptions/{subscriptionId}');
      expect(endpoint('revoke')['body'], isEmpty);
      expect(endpoint('revoke')['notFoundIsSuccess'], isTrue);
      expect((endpoint('revoke')['errorStatus'] as List), isNot(contains(404)));
      expect((endpoint('revoke')['successStatus'] as List).toSet(), {200, 204});

      expect(endpoint('health')['method'], 'GET');
      expect(endpoint('health')['path'], '/v1/health');
      expect(endpoint('health')['body'], isEmpty);
      expect(endpoint('health')['retry'], 'none');
      expect(endpoint('health')['contract'], '#/health');
      expect(_resolve(tracking, '/health'), tracking['health']);

      final mobile = (tracking['retries'] as Map)['mobile'] as Map;
      final retryStatuses = (mobile['retryOn'] as List)
          .cast<String>()
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
      expect(retryStatuses, containsAll([429, 500, 502, 503, 504]));
      for (final name in names) {
        expect(
          (endpoint(name)['errorStatus'] as List).toSet(),
          containsAll(retryStatuses),
          reason: name,
        );
      }
    });

    test('auth bearer, erreurs bornées, journaux rédigés, retries bornés', () {
      final auth = tracking['auth'] as Map;
      expect(auth['scheme'], 'bearer');
      expect(auth['header'], 'Authorization');
      expect(auth['perEnvironment'], isTrue);
      expect(auth['entropyBits'], greaterThanOrEqualTo(256));
      expect(auth['serverStorage'], 'hash-only');
      expect(auth['hash'], 'sha-256');
      expect(auth['salt'], 'per-credential');
      expect(auth['comparison'], 'constant-time');
      expect(auth['mobileStorage'], 'flutter_secure_storage');
      expect(auth['transport'], 'https');
      expect((auth['requiredFor'] as List).cast<String>().toSet(), {
        'register',
        'attach',
        'revoke',
        'health',
      });
      expect(auth['unauthenticatedResponse'], 401);
      expect(auth['queryStringAllowed'], isFalse);
      expect(auth['logging'], 'redacted');

      final deployedAuth = deployment['auth'] as Map;
      final authCopy =
          trackingReference(deployedAuth['contract'] as String) as Map;
      expect(authCopy, auth);
      expect(
        deployedAuth.keys.where((key) => key != 'contract').toSet(),
        auth.keys.toSet(),
        reason: 'auth : miroir incomplet',
      );
      for (final entry in auth.entries) {
        expect(
          deployedAuth[entry.key],
          entry.value,
          reason: 'auth.${entry.key}',
        );
      }

      final errors = tracking['errors'] as Map;
      expect(errors['shape'], ['code', 'message']);
      final codes = (errors['codes'] as List).cast<String>();
      expect(codes, isNotEmpty);
      expect(codes.toSet(), hasLength(codes.length));
      expect(errors['forbiddenContent'], isTrue);
      expect(
        (errors['neverContains'] as List).cast<String>(),
        containsAll([
          'subscriptionId',
          'executionId',
          'fcmToken',
          'sessionId',
          'profile',
          'content',
          'path',
        ]),
      );
      expect(errors['retryAfterHeader'], 'Retry-After');

      final logging = tracking['logging'] as Map;
      expect(
        (logging['redactHeaders'] as List).cast<String>(),
        contains('Authorization'),
      );
      expect(
        (logging['redactFields'] as List).cast<String>(),
        containsAll([
          'fcmToken',
          'subscriptionId',
          'executionId',
          'sessionId',
          'profile',
        ]),
      );
      expect(
        (logging['redactPathSegments'] as List).cast<String>(),
        contains('subscriptionId'),
      );
      expect(
        (logging['neverLog'] as List).cast<String>(),
        containsAll(['payload', 'content', 'message', 'credentials']),
      );

      final retries = tracking['retries'] as Map;
      final mobile = retries['mobile'] as Map;
      expect(mobile['maxAttempts'], inInclusiveRange(1, 5));
      expect(mobile['deadlineMs'], lessThanOrEqualTo(5000));
      expect(mobile['nonBlocking'], isTrue);
      expect(
        (mobile['backoffMs'] as List).length,
        (mobile['maxAttempts'] as int) - 1,
      );
      expect(
        (mobile['retryOn'] as List).cast<String>(),
        containsAll(['network', '429', '500', '502', '503', '504']),
      );
      expect(
        (mobile['neverRetryOn'] as List).cast<String>(),
        containsAll(['400', '401', '403', '404', '409', '410']),
      );
      final observer = retries['observer'] as Map;
      expect(observer['maxAttempts'], inInclusiveRange(1, 10));
      expect(
        (observer['backoffMs'] as List).length,
        (observer['maxAttempts'] as int) - 1,
      );
      expect(observer['perTerminal'], isTrue);
      expect(observer['sweepIntervalSeconds'], greaterThan(0));
      expect(observer['afterMaxAttempts'], 'keep-in-outbox');
      expect(observer['dropAfterSeconds'], greaterThan(0));
      expect(observer['onDrop'], contains('dropped'));
      expect(observer['providerMayDuplicate'], isTrue);
      expect(observer['invalidToken'], 'remove-subscription-no-retry');
    });

    test('rattrapage par last_seen et rétention bornée', () {
      final catchUp = tracking['catchUp'] as Map;
      expect(catchUp['source'], 'session.events.since');
      expect(catchUp['watermarkField'], 'last_seen');
      expect(
        (catchUp['resultFields'] as List).cast<String>(),
        containsAll(['events', 'latest_seq', 'truncated', 'epoch']),
      );
      expect(catchUp['store'], startsWith('/data/'));
      expect(
        (catchUp['scope'] as List).cast<String>(),
        containsAll(['connection', 'profile', 'sessionId']),
      );
      expect(catchUp['onRestart'], 'replay-from-last_seen');
      expect(catchUp['onTruncated'], 'refetch-session-history');
      expect(catchUp['onEpochChange'], 'reset-and-refetch');
      expect(catchUp['maxReplayEvents'], greaterThan(0));
      expect(catchUp['onMaxReplayEvents'], 'continue-from-last-processed');

      final sinceParams = schema('SessionEventsSinceParams');
      expect(
        (sinceParams['required'] as List).cast<String>(),
        contains('session_id'),
      );
      final sinceProperties = sinceParams['properties'] as Map;
      expect(
        _allowsType(
          Map<String, dynamic>.from(sinceProperties['last_seen'] as Map),
          'integer',
        ),
        isTrue,
      );
      final sinceResult = schema('SessionEventsSinceResult');
      final resultFields = (sinceResult['properties'] as Map).keys.toSet();
      expect(
        resultFields,
        containsAll((catchUp['resultFields'] as List).cast<String>()),
      );

      final retention = tracking['retention'] as Map;
      for (final key in [
        'notifiedTtlSeconds',
        'expiredTtlSeconds',
        'deduplicationTtlSeconds',
        'outboxMaxAgeSeconds',
        'pruneIntervalSeconds',
      ]) {
        expect(retention[key], isA<int>(), reason: key);
        expect(retention[key], greaterThan(0), reason: key);
      }
      expect(retention['cursor'], 'while-session-exists');
      expect(retention['onPrune'], contains('count'));
      expect(
        retention['outboxMaxAgeSeconds'],
        (tracking['retries'] as Map)['observer']['dropAfterSeconds'],
      );
    });

    test('santé authentifiée, seuils et compteurs complets', () {
      final health = tracking['health'] as Map;
      expect(health['path'], endpoint('health')['path']);
      expect(health['auth'], 'bearer');
      expect(health['states'], ['ok', 'degraded']);
      expect(health['forbiddenContent'], isTrue);
      expect(
        (health['responseFields'] as List).cast<String>(),
        containsAll(['state', 'reasons', 'counters', 'version', 'checkedAt']),
      );
      expect(
        (health['counters'] as List).cast<String>(),
        containsAll([
          'pending',
          'attached',
          'outboxPending',
          'delivered',
          'failed',
          'dropped',
          'expired',
          'revoked',
          'invalidToken',
        ]),
      );
      expect(
        (health['forbiddenFields'] as List).cast<String>(),
        containsAll([
          'subscriptionId',
          'executionId',
          'sessionId',
          'profile',
          'text',
          'message',
          'path',
          'token',
          'fcmToken',
          'credential',
        ]),
      );
      expect(health['versionFormat'], 'semver');
      expect(health['checkedAtFormat'], 'RFC3339');

      final reasons = _maps(health['degradedWhen']);
      expect(reasons, isNotEmpty);
      expect(
        reasons.map((reason) => reason['reason']).toSet(),
        containsAll([
          'hermes-unreachable',
          'outbox-backlog',
          'fcm-unavailable',
          'storage-error',
        ]),
      );
      expect(
        reasons.map((reason) => reason['reason']).toSet(),
        hasLength(reasons.length),
      );
      for (final reason in reasons) {
        final id = reason['reason'] as String;
        expect(reason['probe'], isA<String>(), reason: id);
        expect((reason['probe'] as String).trim(), isNotEmpty, reason: id);
        final seconds = reason['thresholdSeconds'];
        final threshold = reason['threshold'];
        expect(
          seconds != null || threshold != null,
          isTrue,
          reason: '$id : aucun seuil',
        );
        if (seconds != null) {
          expect(seconds, isA<int>(), reason: id);
          expect(seconds, greaterThanOrEqualTo(0), reason: id);
        }
        if (threshold != null) {
          expect(threshold, isA<int>(), reason: id);
          expect(threshold, greaterThan(0), reason: id);
        }
      }
      final fcmReason = reasons.singleWhere(
        (reason) => reason['reason'] == 'fcm-unavailable',
      );
      expect(fcmReason['exceptEnvironment'], 'integration');
    });
  });

  group('contrat de déploiement', () {
    test('décisions G3 datées, propriétaires, statuts et sans TBD', () {
      expect(deployment['schemaVersion'], 1);
      expect(deployment['evidence'], 'decision');
      expect(deployment['contract'], 'contracts/notification-tracking.json');

      expect(gate['id'], 'G3');
      expect(gate['crossedBy'], '5.5');
      expect((gate['statusReason'] as String).trim(), isNotEmpty);
      final openBlockers = blockers
          .where((blocker) => blocker['status'] == 'open')
          .toList();
      expect(gate['status'], openBlockers.isEmpty ? 'crossed' : 'open');
      for (final blocker in blockers) {
        final id = blocker['id'] as String;
        expect(blocker['owner'], isNotEmpty, reason: id);
        expect(
          DateTime.tryParse(blocker['date'] as String),
          isNotNull,
          reason: id,
        );
        expect(['open', 'done'], contains(blocker['status']), reason: id);
        if (blocker['status'] == 'open') {
          expect(blocker['deferredTo'], '5.5', reason: id);
          final entry = pendingById[id];
          expect(entry, isNotNull, reason: id);
          expect(entry!['owner'], blocker['owner'], reason: id);
          expect(entry['date'], blocker['date'], reason: id);
          expect(entry['status'], 'deferred', reason: id);
          expect(entry['deferredTo'], blocker['deferredTo'], reason: id);
        }
      }
      expect(blockerIds, isNotEmpty);

      expect(validation['owner'], 'Alanc');
      expect(DateTime.tryParse(validation['date'] as String), isNotNull);
      expect(validation['gate'], gate['status']);
      expect(validation['method'], isNotEmpty);
      for (final check in (validation['checks'] as List).cast<String>()) {
        expect(check.trim(), isNotEmpty);
      }
      final accepted = (validation['accepted'] as List).cast<String>();
      final proposed = (validation['proposed'] as List).cast<String>();
      final observed = (validation['observed'] as List).cast<String>();
      expect(accepted.toSet(), hasLength(accepted.length));
      expect(proposed.toSet(), hasLength(proposed.length));
      expect(observed.toSet(), hasLength(observed.length));

      for (final decision in decisions) {
        final id = decision['id'] as String;
        expect(decision['value'], isA<String>(), reason: id);
        expect((decision['value'] as String).trim(), isNotEmpty, reason: id);
        expect(decision['owner'], isNotEmpty, reason: id);
        expect(
          DateTime.tryParse(decision['date'] as String),
          isNotNull,
          reason: id,
        );
        switch (decision['kind']) {
          case 'decision':
            expect(accepted, contains(id), reason: id);
            expect(decision['status'], 'accepted', reason: id);
            expect(decision['validatedBy'], 'Alanc', reason: id);
            expect(decision['date'], validation['date'], reason: id);
          case 'evidence':
            expect(observed, contains(id), reason: id);
            expect(decision['status'], 'observed', reason: id);
            expect(
              DateTime.tryParse(decision['observedAt'] as String),
              isNotNull,
              reason: id,
            );
            expect(decision['evidence'], isNotEmpty, reason: id);
          default:
            fail('$id : kind inconnu ${decision['kind']}');
        }
      }
      for (final id in accepted) {
        final decision = decisionById[id];
        expect(decision, isNotNull, reason: id);
        expect(decision!['kind'], 'decision', reason: id);
        expect(decision['status'], 'accepted', reason: id);
        expect(decision['validatedBy'], 'Alanc', reason: id);
      }
      for (final id in observed) {
        final decision = decisionById[id];
        expect(decision, isNotNull, reason: id);
        expect(decision!['kind'], 'evidence', reason: id);
        expect(decision['status'], 'observed', reason: id);
      }
      expect(
        proposals.map((proposal) => proposal['id']).toSet(),
        proposed.toSet(),
      );
      for (final id in proposed) {
        final proposal = proposalById[id];
        expect(proposal, isNotNull, reason: id);
        expect(proposal!['status'], 'proposed', reason: id);
        expect(proposal['proposedBy'], isNotEmpty, reason: id);
        expect(proposal['confirmBy'], isNotEmpty, reason: id);
        expect(proposal['owner'], isNotEmpty, reason: id);
        expect(
          DateTime.tryParse(proposal['date'] as String),
          isNotNull,
          reason: id,
        );
        final value = proposal['value'];
        expect(value, isNotNull, reason: id);
        if (value is String) {
          expect(value.trim(), isNotEmpty, reason: id);
        }
      }
      expect(proposalById.keys.toSet(), proposed.toSet());

      final outstanding =
          proposed.isNotEmpty ||
          pending.any((entry) => entry['status'] != 'done') ||
          gate['status'] != 'crossed';
      expect(validation['status'], outstanding ? 'partial' : 'complete');
    });

    test('runtime supervisé, volume /data et exposition tailnet', () {
      final runtime = deployment['runtime'] as Map;
      expect(runtime['kind'], 'home-assistant-add-on');
      expect(runtime['packaging'], 'dedicated-add-on');
      expect(runtime['supervision'], 'home-assistant-supervisor');
      expect(runtime['watchdog'], isTrue);
      expect(runtime['startOnBoot'], isTrue);
      expect(runtime['sourcePath'], 'server/notifier/');
      expect(runtime['sourcePathStatus'], 'planned-for-5.2');
      final volume = runtime['persistentVolume'] as Map;
      expect(volume['path'], '/data');
      expect(volume['survivesRestart'], isTrue);
      expect(volume['survivesUpdate'], isTrue);
      expect(volume['hostPathCommitted'], isFalse);
      expect(
        (volume['contents'] as List).cast<String>(),
        containsAll([
          'subscription-registry',
          'outbox',
          'deduplication',
          'cursor',
        ]),
      );

      final listen = runtime['listen'] as Map;
      expect(listen['bind'], '0.0.0.0');
      expect(listen['bindScope'], 'container');
      expect(listen['port'], proposalById['listen-port']!['value']);
      expect(listen['protocol'], 'http');
      expect(listen['hostPortPublished'], isFalse);
      expect(listen['hostPortPublishPolicy'], 'never');
      expect(listen['status'], 'proposed');
      expect(listen['proposedRef'], 'listen-port');

      final origin = runtime['origin'] as Map;
      expect(origin['scheme'], 'https');
      expect(origin['exposure'], 'tailnet-only');
      expect(origin['exposureEnforcement'], 'tailscale-serve-and-tailnet-acl');
      expect(origin['lanExposed'], isFalse);
      expect(origin['hostPortPublished'], isFalse);
      expect(origin['port'], proposalById['public-port']!['value']);
      expect(origin['upstreamPort'], listen['port']);
      expect(
        origin['tlsTermination'],
        proposalById['tls-termination']!['value'],
      );
      expect(origin['status'], 'accepted');
      expect(origin['technicalStatus'], 'proposed');
      expect(
        (origin['proposedRefs'] as List).cast<String>(),
        containsAll(['public-port', 'tls-termination']),
      );
      expect(origin['hostSource'], 'runtime-configuration');
      expect(origin['hostCommitted'], isFalse);

      final healthCopy = runtime['health'] as Map;
      final healthContract =
          trackingReference(healthCopy['contract'] as String) as Map;
      expect(healthCopy['path'], healthContract['path']);
      expect(healthCopy['auth'], healthContract['auth']);
      expect(healthCopy['states'], healthContract['states']);
    });

    test('accès Hermes en lecture seule, RPC et REST épinglés', () {
      final access = deployment['hermesAccess'] as Map;
      expect(access['mode'], 'read-only');
      expect(access['contract'], 'contracts/openrpc.json');
      expect(access['mapping'], 'contracts/event-mapping.json');
      expect(access['transport'], 'json-rpc-websocket-and-rest');
      expect(access['privateDatabases'], 'never');
      expect(access['submitWork'], isFalse);
      expect(access['interruptWork'], isFalse);
      expect(access['credentialSharedWithMobile'], isFalse);
      expect(access['credentialSource'], 'add-on-options');
      expect(access['network'], 'tailnet-only');
      expect(access['readOnlyCaveat'], contains('session.resume'));

      final allowed = (access['allowedRpc'] as List).cast<String>();
      final forbidden = (access['forbiddenRpc'] as List).cast<String>();
      expect(allowed.toSet(), {
        'gateway.capabilities',
        'session.list',
        'session.status',
        'session.resume',
        'session.history',
        'session.events.since',
      });
      expect(forbidden.toSet(), {
        'session.create',
        'prompt.submit',
        'session.interrupt',
        'session.title',
        'file.attach',
        'client.capabilities',
      });
      expect(allowed.toSet().intersection(forbidden.toSet()), isEmpty);
      final rpcNames = rpcMethods.map((method) => method['name']).toSet();
      for (final name in [...allowed, ...forbidden]) {
        expect(rpcNames, contains(name), reason: name);
      }

      final rest = (access['allowedRest'] as List).cast<String>();
      expect(rest.toSet(), {
        'POST /auth/password-login',
        'POST /auth/native/refresh',
        'POST /api/auth/ws-ticket',
        'GET /api/profiles',
      });
      final documentedRest = (methodsJson['rest'] as List)
          .cast<Map<String, dynamic>>()
          .map((entry) => '${entry['method']} ${entry['path']}')
          .toSet();
      expect(rest.toSet(), documentedRest);
      for (final route in rest) {
        expect(RegExp(r'^(GET|POST) /').hasMatch(route), isTrue, reason: route);
        expect(
          RegExp(r'^(PUT|PATCH|DELETE) ').hasMatch(route),
          isFalse,
          reason: route,
        );
      }
    });

    test('FCM proposé, token référencé et payload identique au suivi', () {
      final fcm = deployment['fcm'] as Map;
      expect(fcm['transport'], 'fcm-http-v1');
      final selected = fcm['selected'] as Map;
      expect(selected['package'], 'firebase_messaging');
      expect(selected['version'], startsWith('17.'));
      expect(selected['firebaseCore'], startsWith('^5.'));
      expect(selected['minSdk'], 24);
      expect(DateTime.tryParse(selected['checkedAt'] as String), isNotNull);
      if (selected['verified'] == true) {
        expect(selected['verifiedBy'], isNotEmpty);
      } else {
        expect(selected['status'], 'proposed-pending-build');
        expect(selected['verifiedBy'], '5.3');
      }
      final proposedVersion = proposalById['fcm-version']!['value'] as String;
      expect(
        proposedVersion,
        'firebase_messaging ${selected['version']} '
        '+ firebase_core ${selected['firebaseCore']}',
      );
      final fallback = fcm['fallback'] as Map;
      expect(fallback['package'], 'firebase_messaging');
      expect(fallback['version'], startsWith('16'));
      expect(fallback['condition'], isNotEmpty);
      expect(fallback['status'], 'documented-not-active');
      expect(DateTime.tryParse(fallback['date'] as String), isNotNull);

      final dryRun = fcm['dryRun'] as Map;
      expect(dryRun['environment'], 'integration');
      expect(dryRun['active'], isTrue);
      expect(dryRun['sendsFcm'], isFalse);
      expect(dryRun['records'], isNotEmpty);
      expect(
        (dryRun['neverRecords'] as List).cast<String>(),
        containsAll([
          'rawSubscriptionId',
          'executionId',
          'content',
          'credentials',
        ]),
      );

      final deviceToken = fcm['deviceToken'] as Map;
      final tokenContract =
          trackingReference(deviceToken['contract'] as String) as Map;
      expect(
        tokenContract,
        equals((tracking['registry'] as Map)['deviceToken']),
      );
      for (final key in [
        'registeredWith',
        'rotation',
        'inPushPayload',
        'inLogs',
      ]) {
        expect(deviceToken[key], tokenContract[key], reason: key);
      }

      final fcmPayload = fcm['payload'] as Map;
      final trackingPayload =
          trackingReference(fcmPayload['contract'] as String) as Map;
      expect(fcmPayload['messageKind'], trackingPayload['messageKind']);
      expect(fcmPayload['dataFields'], trackingPayload['dataFields']);
      expect(
        fcmPayload['notificationLabels'],
        (trackingPayload['notification'] as Map)['labelLocation'],
      );
      final androidRef = (fcm['android'] as Map)['contract'] as String;
      expect(
        androidRef,
        'contracts/notification-tracking.json#/payload/android',
      );
      final androidContract = trackingReference(androidRef) as Map;
      expect(androidContract['channelId'], 'hermes_turn_complete');
      expect(
        androidContract['notificationTagTemplate'],
        contains('subscriptionId'),
      );
      expect(
        (fcm['android'] as Map)['postNotifications'],
        'required-runtime-5.3',
      );
    });

    test('un projet Firebase personnel, un compte hors dépôt, dry-run', () {
      final firebase = deployment['firebase'] as Map;
      final cost = firebase['cost'] as Map;
      expect(cost['plan'], 'spark');
      expect(cost['billingEnabled'], isFalse);
      expect(cost['fcm'], 'no-cost');
      expect(cost['messageQuota'], 'none');
      expect(DateTime.tryParse(cost['checkedAt'] as String), isNotNull);
      expect(cost['source'], startsWith('https://firebase.google.com'));

      final projects = _maps(firebase['projects']);
      expect(projects, hasLength(1));
      final project = projects.single;
      expect(project['scope'], 'personal');
      expect(project['count'], 1);
      expect(project['owner'], 'Alanc');
      expect(DateTime.tryParse(project['recordedAt'] as String), isNotNull);
      expect(['not-created', 'created'], contains(project['status']));
      if (project['status'] == 'created') {
        expect(project['identifier'], isA<String>());
        expect((project['identifier'] as String).trim(), isNotEmpty);
      } else {
        expect(project['identifier'], isNull);
        expect(project['creationDeferredTo'], '5.5');
        expect(blockerIds, contains('firebase-project'));
      }

      final accounts = _maps(firebase['serviceAccounts']);
      expect(accounts, hasLength(1));
      final account = accounts.single;
      expect(account['scope'], 'personal');
      expect(account['count'], 1);
      expect(account['owner'], 'Alanc');
      expect(account['storage'], 'outside-repository');
      expect(account['keyInRepository'], isFalse);
      expect(account['environmentReference'], 'GOOGLE_APPLICATION_CREDENTIALS');
      expect(account['roles'], contains('roles/firebasecloudmessaging.admin'));
      if (account['status'] == 'created') {
        expect(account['identifier'], isA<String>());
      } else {
        expect(account['identifier'], isNull);
        expect(account['creationDeferredTo'], '5.5');
        expect(blockerIds, contains('firebase-service-account'));
      }

      expect(firebase['secretsVersioned'], isFalse);
      final clientConfig = firebase['clientConfig'] as Map;
      expect(['not-created', 'created'], contains(clientConfig['status']));
      expect(clientConfig['generatedBy'], '5.5');
      expect(clientConfig['policy'], contains('hors dépôt'));
      if (clientConfig['status'] == 'not-created') {
        expect(clientConfig['creationDeferredTo'], '5.5');
      }
      final rotation = firebase['rotation'] as Map;
      expect(rotation['owner'], 'Alanc');
      expect(rotation['automated'], isFalse);
      expect(rotation['policy'], isNotEmpty);
      final integration = firebase['integration'] as Map;
      expect(integration['usesFirebase'], isFalse);
      expect(integration['transport'], 'dry-run');
      expect(integration['sendsFcm'], isFalse);
    });

    test('environnements isolés, intégration dry-run verrouillée', () {
      final environments = _maps(deployment['environments']);
      expect(environments, hasLength(3));
      expect(environments.map((environment) => environment['name']).toList(), [
        'fixtures',
        'integration',
        'personal',
      ]);
      for (final environment in environments) {
        expect(environment['isolated'], isTrue);
        expect((environment['credentialRef'] as String).trim(), isNotEmpty);
        expect((environment['registryRef'] as String).trim(), isNotEmpty);
        expect((environment['originRef'] as String).trim(), isNotEmpty);
      }
      for (final key in ['credentialRef', 'registryRef', 'originRef']) {
        expect(
          environments.map((environment) => environment[key]).toSet(),
          hasLength(environments.length),
          reason: key,
        );
      }
      final integration = environments.singleWhere(
        (environment) => environment['name'] == 'integration',
      );
      expect(integration['fcmTransport'], 'dry-run');
      expect(integration['firebaseProject'], isFalse);
      expect(integration['dryRunLocked'], isTrue);
      final fixtures = environments.singleWhere(
        (environment) => environment['name'] == 'fixtures',
      );
      expect(fixtures['fcmTransport'], 'dry-run');
      expect(fixtures['firebaseProject'], isFalse);
      final personal = environments.singleWhere(
        (environment) => environment['name'] == 'personal',
      );
      expect(personal['fcmTransport'], 'fcm-http-v1');
      expect(personal['firebaseProject'], isTrue);
      final projectStatus =
          ((deployment['firebase'] as Map)['projects'] as List)
              .single['status'];
      if (projectStatus == 'created') {
        expect(personal['status'], isNot('blocked-until-firebase'));
      } else {
        expect(personal['status'], 'blocked-until-firebase');
      }
    });
  });

  test('aucun secret, chemin personnel ni promesse exactement une fois', () {
    _scanContractValue(tracking, '');
    _scanContractValue(deployment, '');
    for (final path in [
      'contracts/README.md',
      '_bmad-output/implementation-artifacts/story-5-1-verification/g3-decisions.md',
      '_bmad-output/implementation-artifacts/story-5-1-verification/android-prerequisites.md',
      '_bmad-output/implementation-artifacts/story-5-1-verification/implementation-report.md',
      '_bmad-output/implementation-artifacts/spec-5-1-contrat-suivi-deploiement-observateur.md',
      '_bmad-output/implementation-artifacts/epic-5-context.md',
      '_bmad-output/implementation-artifacts/story-5-1-verification/flutter-analyze.log',
      '_bmad-output/implementation-artifacts/story-5-1-verification/flutter-targeted.log',
      '_bmad-output/implementation-artifacts/story-5-1-verification/flutter-test.log',
    ]) {
      _expectNoPersonalText(File(path).readAsStringSync(), path);
    }

    expect(deployment.containsKey('validatedBy'), isFalse);
    expect((tracking['payload'] as Map).containsKey('dataOnly'), isFalse);
    final dedup = tracking['deduplication'] as Map;
    expect(dedup['exactlyOnce'], isFalse);
    expect(dedup['repeatDelivery'], isNot('exactly-once'));
    expect((deployment['firebase'] as Map)['secretsVersioned'], isFalse);
    expect(
      ((deployment['runtime'] as Map)['origin'] as Map)['hostCommitted'],
      isFalse,
    );
    expect(
      ((deployment['runtime'] as Map)['persistentVolume']
          as Map)['hostPathCommitted'],
      isFalse,
    );
    expect(
      ((deployment['runtime'] as Map)['listen'] as Map)['hostPortPublished'],
      isFalse,
    );
    expect(
      ((deployment['runtime'] as Map)['origin'] as Map)['hostPortPublished'],
      isFalse,
    );
  });
}
