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
      expect(capabilities.every((c) => c['actual'] == 'unverified'), isTrue);
      final harness = Harness();
      addTearDown(harness.repository.dispose);
      expect(
        harness.repository.snapshot.capabilities.map((c) => c.name),
        capabilities.map((c) => c['name']),
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
}
