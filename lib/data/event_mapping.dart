import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/timeline.dart';

enum EventEffect {
  turnStart,
  textDelta,
  interim,
  terminal,
  activity,

  /// Question ou autorisation de Hermes ouverte (`server.clarify`,
  /// `server.approval`) ou close (`request.cancel`).
  intervention,
  ignore,
}

/// Résultat du mapping d'un événement : jamais de détail inventé.
class MappedEvent {
  const MappedEvent(
    this.effect, {
    this.workState,
    this.activityKind,
    this.activityStarted = false,
    this.activityCompleted = false,
    this.activityDetails = const {},
  });
  final EventEffect effect;
  final WorkState? workState;
  final ActivityKind? activityKind;
  final bool activityStarted;
  final bool activityCompleted;
  final Map<String, Object?> activityDetails;
}

/// Table déclarative `contracts/event-mapping.json`, décodée sans Flutter.
class EventMapping {
  EventMapping(Map<String, dynamic> json)
    : _events = Map<String, dynamic>.from(json['events'] as Map),
      _fallback = json['fallback'] as String;

  static const asset = 'contracts/event-mapping.json';

  static Future<EventMapping> load() async => EventMapping(
    jsonDecode(await rootBundle.loadString(asset)) as Map<String, dynamic>,
  );

  final Map<String, dynamic> _events;
  final String _fallback;

  /// Type absent de la table → entrée de repli (`unknown`).
  MappedEvent map(String type, Map<String, dynamic> payload) {
    final entry = Map<String, dynamic>.from(
      (_events[type] ?? _events[_fallback]) as Map,
    );
    final effect = EventEffect.values.byName(entry['effect'] as String);
    var work = _work(entry['workState']);
    if (effect == EventEffect.terminal) {
      final statuses = entry['statusMap'];
      if (statuses is Map) {
        // Statut absent ou inconnu : jamais présumé réussi.
        work = _work(statuses[payload['status']]) ?? WorkState.unknown;
      }
    }
    return MappedEvent(
      effect,
      workState: work,
      activityKind: entry['activityKind'] == null
          ? null
          : ActivityKind.decode(entry['activityKind']),
      activityStarted: entry['activityPhase'] == 'start',
      activityCompleted: entry['activityPhase'] == 'complete',
      activityDetails: type == 'tool.start' || type == 'tool.complete'
          ? ActivityDetailFields.decode(payload)
          : const {},
    );
  }

  static WorkState? _work(Object? name) =>
      name is String ? WorkState.values.byName(name) : null;
}
