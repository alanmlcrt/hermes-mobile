import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/models/timeline.dart';

import 'contracts_test.dart' show contract;

void main() {
  final mapping = EventMapping(contract('event-mapping'));

  test('chaque événement des fixtures a un effet connu', () {
    final expected = {
      'message.start': EventEffect.turnStart,
      'message.delta': EventEffect.textDelta,
      'message.interim': EventEffect.interim,
      'message.complete': EventEffect.terminal,
      'error': EventEffect.terminal,
      'tool.start': EventEffect.activity,
      'tool.complete': EventEffect.activity,
      'gateway.ready': EventEffect.ignore,
      'future.synthetic': EventEffect.activity, // repli : type absent
    };
    var seen = 0;
    for (final file in Directory(
      'contracts/fixtures',
    ).listSync().whereType<File>()) {
      final value = jsonDecode(file.readAsStringSync());
      if (value['method'] != 'event') continue;
      final params = value['params'] as Map;
      final payload = Map<String, dynamic>.from(params['payload'] as Map);
      final mapped = mapping.map(params['type'] as String, payload);
      expect(mapped.effect, expected[params['type']], reason: file.path);
      seen++;
    }
    expect(seen, 11); // dont deux gateway.ready et deux message.complete
  });

  test('statut de message.complete et repli inconnu', () {
    WorkState? work(Object? status) =>
        mapping.map('message.complete', {'status': status}).workState;
    expect(work('complete'), WorkState.succeeded);
    expect(work('error'), WorkState.failed);
    expect(work('interrupted'), WorkState.stopped);
    expect(work('autre'), WorkState.unknown);
    expect(work(null), WorkState.unknown);
    final unknown = mapping.map('foo.bar', {});
    expect(unknown.effect, EventEffect.activity);
    expect(unknown.activityKind, ActivityKind.unknown);
    expect(mapping.map('error', {}).workState, WorkState.failed);
  });

  test('début et fin proviennent du mapping, jamais du nom ou emoji', () {
    final start = mapping.map('tool.start', {'name': 'browser', 'emoji': '🌍'});
    final end = mapping.map('tool.complete', {});
    expect(start.activityKind, ActivityKind.tool);
    expect(start.activityStarted, isTrue);
    expect(start.activityCompleted, isFalse);
    expect(end.activityStarted, isFalse);
    expect(end.activityCompleted, isTrue);
    expect(end.workState, isNull);
    expect(mapping.map('mcp.browser', {}).activityKind, ActivityKind.unknown);
  });

  test('le fichier de mapping est déclaré en asset', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains(EventMapping.asset),
    );
  });

  test('toutes les familles fictives restent sans association serveur', () {
    for (final kind in ActivityKind.values) {
      final payload = {
        'name': kind.name,
        'emoji': '💻',
        'args': {'family': kind.name},
      };
      expect(
        mapping.map('future.${kind.name}', payload).activityKind,
        ActivityKind.unknown,
      );
      for (final event in ['tool.start', 'tool.complete']) {
        expect(mapping.map(event, payload).activityKind, ActivityKind.tool);
      }
    }
  });
}
