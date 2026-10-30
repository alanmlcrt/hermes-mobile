import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/connection_fakes.dart';

Map<String, dynamic> contract(String name) =>
    jsonDecode(File('contracts/$name.json').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  test(
    'outils : contrat documentaire et fixtures explicitement synthétiques',
    () {
      final evidence = contract('capabilities')['activityEvents'];
      expect(evidence['actual'], 'unverified');
      expect(evidence['fixtures'], 'synthetic');
      expect(evidence['families'], ['tool', 'unknown']);
      for (final name in ['tool-start', 'tool-complete']) {
        final payload = fixture(name)['params']['payload'];
        expect(payload['tool_id'], 'SYNTHETIC_TOOL_1');
        expect(payload['name'], 'SYNTHETIC');
      }
      final start = fixture('tool-start')['params']['payload'];
      final end = fixture('tool-complete')['params']['payload'];
      expect(start['args']['dry_run'], false);
      expect(start['args']['limit'], 0);
      expect(end['result']['error'], isA<String>());
      expect(end['result']['output'], contains('[truncated]'));
      expect(end['inline_diff'], '- avant\n+ après');
    },
  );
  test('payload gateway.ready conforme aux champs requis et types du schéma embarqué', () {
    final document = contract('openrpc');
    bool matches(Object? value, Map schema) {
      if (schema.containsKey(r'$ref')) {
        final name = (schema[r'$ref'] as String).split('/').last;
        return matches(value, document['components']['schemas'][name] as Map);
      }
      if (schema['anyOf'] case final List variants) {
        return variants.any((variant) => matches(value, variant as Map));
      }
      final validType = switch (schema['type']) {
        'object' => value is Map,
        'string' => value is String,
        'boolean' => value is bool,
        'null' => value == null,
        'integer' => value is int,
        'array' => value is List,
        _ => true,
      };
      if (!validType) return false;
      if (value is Map) {
        final required = schema['required'] as List? ?? [];
        if (required.any((key) => !value.containsKey(key))) return false;
        final properties = schema['properties'] as Map? ?? {};
        for (final entry in value.entries) {
          final child = properties[entry.key];
          if (child is Map && !matches(entry.value, child)) return false;
          if (child == null && schema['additionalProperties'] == false) {
            return false;
          }
          if (child == null &&
              schema['additionalProperties'] is Map &&
              !matches(entry.value, schema['additionalProperties'] as Map)) {
            return false;
          }
        }
      }
      return true;
    }

    final notification = (document['x-notifications'] as List).singleWhere(
      (n) => n['name'] == 'gateway.ready',
    );
    final schema = notification['params'][0]['schema'] as Map;
    final payload = fixture('gateway-ready')['params']['payload'] as Map;
    expect(matches(payload, schema), isTrue);
    expect(matches(Map.of(payload)..remove('skin'), schema), isFalse);
    expect(matches({...payload, 'skin': []}, schema), isFalse);
    expect(matches({...payload, 'change_events': 'true'}, schema), isFalse);
    expect(matches({...payload, 'replay_epoch': 42}, schema), isFalse);
  });
  test(
    'provenance officielle épinglée et capacités documentaires distinctes',
    () {
      final release = contract('release');
      expect(release['tag'], 'v0.22.2');
      expect(release['commit'], '9e01b44dd23978f9ff40b7837467f3a9f1582130');
      expect(
        release['baseTagCommit'],
        'd923a5eb487a17c0a68801bba9ef0f56c81040a8',
      );
      expect(release['evidence'], 'documentary');
      expect(release['realAcceptance'], 'open');
      expect(release['fixtures'], 'synthetic');
      expect(release['installedBuild'], 'observed-health');
      final openrpc = contract('openrpc');
      expect(openrpc['openrpc'], '1.3.2');
      expect(openrpc['x-provenance']['kind'], 'excerpt');
      expect(openrpc['x-provenance']['commit'], release['commit']);
      expect(openrpc['methods'], hasLength(13));
      expect(
        (openrpc['x-notifications'] as List).map((n) => n['name']),
        containsAll([
          'gateway.ready',
          'message.start',
          'message.delta',
          'message.complete',
          'message.interim',
          'error',
          'session.info',
          'status.update',
          'sessions.changed',
          'session.title',
        ]),
      );
      void checkRefs(Object? value) {
        if (value is List) {
          for (final item in value) {
            checkRefs(item);
          }
        } else if (value is Map) {
          for (final entry in value.entries) {
            if (entry.key == r'$ref') {
              Object? target = openrpc;
              for (final segment
                  in (entry.value as String).substring(2).split('/')) {
                expect(target, isA<Map>());
                target = (target as Map)[segment];
                expect(target, isNotNull, reason: entry.value as String);
              }
            } else {
              checkRefs(entry.value);
            }
          }
        }
      }

      checkRefs(openrpc);
      final rpcNames = (openrpc['methods'] as List)
          .map((m) => m['name'])
          .toSet();
      final methods = contract('methods');
      for (final method in methods['rpc'] as List) {
        expect(rpcNames, contains(method['name']));
        expect(method['source'], isNotEmpty);
      }
      expect(methods['sourceRoot'], contains(release['commit'] as String));
      final capabilities = contract('capabilities')['capabilities'] as List;
      expect(
        capabilities.every(
          (c) =>
              c['actual'] == 'unverified' ||
              // Une valeur réelle ne vient que d'une mesure datée et sourcée.
              (c['evidence'] == 'install-measured' &&
                  DateTime.tryParse(c['measuredAt'] as String? ?? '') != null &&
                  (c['source'] as String? ?? '').isNotEmpty),
        ),
        isTrue,
      );
      final harness = Harness();
      addTearDown(harness.repository.dispose);
      // Capacités mesurées en 6.1 mais pas encore suivies par l'app (6.4).
      const notTracked = {'steer', 'result_download'};
      expect(
        harness.repository.snapshot.capabilities.map((c) => c.name),
        capabilities
            .map((c) => c['name'])
            .where((name) => !notTracked.contains(name)),
      );
      expect(
        harness.repository.snapshot.capabilities
            .where((c) => c.required)
            .map((c) => c.name),
        capabilities.where((c) => c['required'] == true).map((c) => c['name']),
      );
    },
  );
  test('mapping des fixtures et type inconnu explicite', () {
    final mapping = contract('event-mapping');
    final events = mapping['events'] as Map;
    expect(events['unknown']['activityKind'], 'unknown');
    for (final file in Directory(
      'contracts/fixtures',
    ).listSync().whereType<File>()) {
      final value = jsonDecode(file.readAsStringSync());
      if (value['method'] != 'event') continue;
      final type = value['params']['type'];
      final mapped = events[type] ?? events[mapping['fallback']];
      expect(mapped['terminal'], isA<bool>());
      expect(mapped.containsKey('workState'), isTrue);
      expect(mapped.containsKey('activityKind'), isTrue);
    }
  });
  test('fixtures sans secret réel ni origine privée', () {
    void scan(Object? value, [String key = '']) {
      if (value is Map) {
        for (final entry in value.entries) {
          scan(entry.value, entry.key as String);
        }
      } else if (value is List) {
        for (final item in value) {
          scan(item, key);
        }
      } else if (value is String) {
        if (RegExp(r'^(password|access_token|refresh_token|ticket)$')
            .hasMatch(key)) {
          expect(value, startsWith('<SYNTHETIC_'));
        }
        if (key == 'cookies') expect(value, contains('=<SYNTHETIC_'));
        expect(
          RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.').hasMatch(value),
          isFalse,
        );
        expect(value, isNot(contains('Bearer ')));
      }
    }

    for (final file in Directory(
      'contracts/fixtures',
    ).listSync().whereType<File>()) {
      scan(jsonDecode(file.readAsStringSync()));
    }
  });
  test(
    'limites de fichiers : catégories complètes et aucune valeur non mesurée',
    () {
      final fileLimits = contract('file-limits');
      expect(fileLimits['schemaVersion'], 1);
      expect([
        'unmeasured',
        'install-measured',
      ], contains(fileLimits['evidence']));
      final measured = fileLimits['evidence'] == 'install-measured';
      final install = fileLimits['install'] as Map;
      expect(install['profile'], 'dedicated-test-profile');
      if (measured) {
        expect(install['build'], isA<String>());
        expect(install['build'], isNotEmpty);
        expect(install['measuredAt'], isA<String>());
        expect(DateTime.tryParse(install['measuredAt'] as String), isNotNull);
        expect(install['finishedAt'], isA<String>());
        final started = DateTime.parse(install['measuredAt'] as String);
        final finished = DateTime.parse(install['finishedAt'] as String);
        expect(finished.isBefore(started), isFalse);
      } else {
        expect(install['build'], isNull);
        expect(install['measuredAt'], isNull);
        expect(install['finishedAt'], isNull);
      }

      final corpus = fileLimits['corpus'] as Map;
      expect(corpus['tracked'], isFalse);
      expect(corpus['complete'], isA<bool>());
      expect(
        corpus['location'],
        '_bmad-output/implementation-artifacts/corpus-pieces-jointes/',
      );
      final categories = (corpus['categories'] as List)
          .map((entry) => (entry as Map)['category'] as String)
          .toList();
      expect(categories, ['text', 'image', 'pdf', 'office']);

      final limits = fileLimits['limits'] as Map;
      expect(limits.keys.length, categories.length);
      expect(limits.keys, containsAll(categories));
      final unverified = (fileLimits['unverified'] as List).cast<String>();
      expect(unverified.toSet().length, unverified.length);
      expect(
        unverified.contains('corpus.complete'),
        corpus['complete'] != true,
      );

      for (final category in categories) {
        final limit = limits[category] as Map;
        final maxBytes = limit['maxBytes'];
        final maxCount = limit['maxCount'];
        expect(maxBytes, anyOf(isNull, isA<int>()));
        expect(maxCount, anyOf(isNull, isA<int>()));
        if (maxBytes is int) expect(maxBytes, greaterThan(0));
        if (maxCount is int) expect(maxCount, greaterThan(0));
        expect(limit['maxBytesVerified'], isA<bool>());
        expect(limit['maxCountVerified'], isA<bool>());
        if (limit['maxBytesVerified'] != true) expect(maxBytes, isNull);
        if (limit['maxCountVerified'] != true) expect(maxCount, isNull);
        expect(
          limit['verified'],
          limit['maxBytesVerified'] == true ||
              limit['maxCountVerified'] == true,
        );
        expect(
          unverified.contains('limits.$category.maxBytes'),
          limit['maxBytesVerified'] != true,
        );
        expect(
          unverified.contains('limits.$category.maxCount'),
          limit['maxCountVerified'] != true,
        );
        final threshold = limit['threshold'] as Map;
        for (final key in ['bytes', 'count']) {
          expect([
            'not-measured',
            'lower-bound',
            'between',
          ], contains(threshold[key]));
        }
        final observed = limit['observed'] as Map;
        for (final key in [
          'acceptedBytes',
          'refusedBytes',
          'acceptedCounts',
          'refusedCounts',
          'unverifiedBytes',
          'unverifiedCounts',
          'mediaTypes',
          'receipts',
        ]) {
          expect(observed[key], isA<List>(), reason: '$category.$key');
        }
        final acceptedBytes = (observed['acceptedBytes'] as List).cast<int>();
        final refusedBytes = (observed['refusedBytes'] as List).cast<int>();
        int? ceiling;
        for (final bytes in refusedBytes) {
          if (ceiling == null || bytes < ceiling) ceiling = bytes;
        }
        final acceptable = acceptedBytes
            .where((bytes) => ceiling == null || bytes < ceiling)
            .toList();
        final expectedMax = acceptable.isEmpty
            ? null
            : acceptable.reduce((a, b) => a > b ? a : b);
        expect(maxBytes, expectedMax, reason: '$category.maxBytes');
        expect(limit['evidence'], isA<List>());
        if (maxBytes is int) {
          expect(limit['evidence'], isNotEmpty);
          for (final entry in (limit['evidence'] as List).cast<Map>()) {
            expect(entry['bytes'], lessThanOrEqualTo(maxBytes));
            expect(entry['count'], isA<int>());
          }
        } else {
          expect(limit['evidence'], isEmpty);
        }
        for (final receipt in (observed['receipts'] as List).cast<String>()) {
          expect(const {
            'history-attached-context',
            'history-image-reference',
          }, contains(receipt.split(':').last));
        }
        if (!measured) {
          for (final entry in observed.entries) {
            expect(entry.value, isEmpty, reason: '$category.${entry.key}');
          }
          expect(limit['evidence'], isEmpty);
        }
      }

      final transports = fileLimits['transports'] as Map;
      expect(transports.keys.toSet(), {
        'file.attach',
        'rest.image-upload',
        'image.attach_bytes',
      });
      for (final entry in transports.entries) {
        final transport = entry.value as Map;
        expect(['pinned', 'outside-pinned'], contains(transport['contract']));
        expect(transport['parameters'], isA<List>());
        expect([
          'present',
          'absent',
          'unverified',
        ], contains(transport['status']));
        if (!measured) {
          expect(transport['status'], 'unverified');
          expect(transport['proof'], isNull);
        } else if (transport['status'] == 'present') {
          expect(unverified, isNot(contains('transports.${entry.key}')));
          final proof = transport['proof'] as Map;
          expect(proof['pieces'], isA<int>());
          expect(proof['pieces'], greaterThan(0));
          expect(proof['repetitions'], isA<int>());
          expect(proof['repetitions'], greaterThan(0));
          expect(proof['attempts'], isA<int>());
          expect(
            proof['attempts'],
            greaterThanOrEqualTo(proof['pieces'] as int),
          );
          expect(
            proof['attempts'],
            lessThanOrEqualTo(
              (proof['pieces'] as int) * (proof['repetitions'] as int),
            ),
          );
          for (final key in [
            'accepted',
            'refused',
            'unverified',
            'absent',
            'partial',
            'received',
          ]) {
            expect(proof[key], isA<int>(), reason: '${entry.key}.$key');
            expect(proof[key], greaterThanOrEqualTo(0));
          }
          expect(
            (proof['accepted'] as int) +
                (proof['refused'] as int) +
                (proof['unverified'] as int) +
                (proof['absent'] as int),
            proof['pieces'],
            reason: '${entry.key}: catégories mutuellement exclusives',
          );
          expect(
            proof['received'],
            greaterThanOrEqualTo(proof['accepted'] as int),
          );
          expect(proof['receipts'], isA<List>());
          expect(
            proof['accepted'],
            greaterThan(0),
            reason: '${entry.key}: present exige un reçu accepté',
          );
        } else {
          expect(unverified, contains('transports.${entry.key}'));
          final proof = transport['proof'];
          if (proof is Map) expect(proof['accepted'], 0);
        }
      }

      final jpegProofs =
          (transports['image.attach_bytes'] as Map)['supplementalProofs']
              as List;
      expect(jpegProofs, hasLength(1));
      final jpegProof = jpegProofs.single as Map;
      expect(jpegProof['mediaType'], 'image/jpeg');
      expect(jpegProof['profile'], 'dedicated-test-profile');
      expect(jpegProof['build'], install['build']);
      expect(jpegProof['pieces'], 2);
      expect(jpegProof['repetitions'], 3);
      expect(jpegProof['attempts'], 6);
      expect(jpegProof['accepted'], 2);
      expect(jpegProof['received'], 6);
      expect(jpegProof['distinctExactReceipts'], 6);
      expect(jpegProof['bytes'], [3383, 20965448]);
      expect(
        jpegProof['ceilingMeaning'],
        'largest-accepted-tested; local-app-policy',
      );
      expect(jpegProof['serverMaximumMeasured'], isFalse);
      final corpusManifest = jsonDecode(
        File(
          '_bmad-output/implementation-artifacts/verification-jpeg/corpus.json',
        ).readAsStringSync(),
      ) as List;
      expect(
        (jpegProof['fixtures'] as List)
            .map((fixture) => (fixture as Map)['sha256'])
            .toList(),
        corpusManifest.map((fixture) => (fixture as Map)['sha256']).toList(),
      );
      expect(
        (limits['image'] as Map)['observed']['mediaTypes'],
        contains('image/jpeg'),
      );
      expect(
        ((limits['image'] as Map)['evidence'] as List)
            .where((e) => (e as Map)['mediaType'] == 'image/jpeg')
            .length,
        2,
      );

      final vision = fileLimits['vision'] as Map;
      expect(vision['profile'], anyOf(isNull, 'dedicated-test-profile'));
      expect(vision['analyzesImages'], anyOf(isNull, isA<bool>()));
      expect(
        unverified.contains('vision.analyzesImages'),
        vision['analyzesImages'] == null,
      );
      expect(unverified.contains('vision.model'), vision['model'] == null);

      final fileAttach =
          (contract('capabilities')['capabilities'] as List).singleWhere(
            (entry) => entry['name'] == 'file.attach',
          ) as Map;
      final fileAttachTransport = transports['file.attach'] as Map;
      if (fileAttach['actual'] != 'unverified') {
        expect(measured, isTrue);
        expect(['present', 'absent'], contains(fileAttach['actual']));
        expect(fileAttach['actual'], fileAttachTransport['status']);
        expect(fileAttach['evidence'], 'install-measured');
        expect(fileAttach['measuredAt'], install['measuredAt']);
        expect(fileAttach['source'], 'contracts/file-limits.json');
      } else if (measured) {
        expect(fileAttachTransport['status'], 'unverified');
      }
    },
  );
  test('limites de fichiers sans chemin, identifiant ni secret', () {
    final fileLimits = contract('file-limits');
    void scan(Object? value, [String key = '']) {
      if (value is Map) {
        for (final entry in value.entries) {
          expect(
            const {
              'path',
              'filePath',
              'fileName',
              'name',
              'token',
              'password',
              'secret',
            },
            isNot(contains(entry.key)),
            reason: 'champ interdit : ${entry.key}',
          );
          scan(entry.value, entry.key as String);
        }
      } else if (value is List) {
        for (final item in value) {
          scan(item, key);
        }
      } else if (value is String) {
        expect(
          RegExp(r'(^|[^\w])[A-Za-z]:[\\/]').hasMatch(value),
          isFalse,
          reason: key,
        );
        expect(
          RegExp(r'(^|[^\w])/(home|Users|root)/').hasMatch(value),
          isFalse,
          reason: key,
        );
        expect(value, isNot(contains('file://')), reason: key);
        expect(RegExp(r'Bearer\s').hasMatch(value), isFalse, reason: key);
        expect(
          RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.').hasMatch(value),
          isFalse,
          reason: key,
        );
        expect(
          RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').hasMatch(value),
          isFalse,
          reason: key,
        );
        expect(value, isNot(contains('hermes_session')), reason: key);
      }
    }

    scan(fileLimits);
    final corpus = fileLimits['corpus'] as Map;
    expect(corpus['location'], startsWith('_bmad-output/'));
    expect(corpus['location'], isNot(startsWith('/')));
    expect((fileLimits['install'] as Map)['profile'], 'dedicated-test-profile');
    expect(
      (fileLimits['vision'] as Map)['profile'],
      anyOf(isNull, 'dedicated-test-profile'),
    );
  });
}
