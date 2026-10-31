import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

const _pluginPath = 'server/hermes-plugin/hermes-mobile-notify/__init__.py';
const _activityPath =
    'android/app/src/main/kotlin/fr/hermes_mobile/MainActivity.kt';
const _manifestPath = 'android/app/src/main/AndroidManifest.xml';
const _clientPath = 'lib/data/firebase_notification_client.dart';

/// Valeur d'une constante chaîne du plugin (`_NOM = "valeur"`).
String _pyString(String source, String name) {
  final match = RegExp(
    '^${RegExp.escape(name)}\\s*=\\s*"([^"]*)"',
    multiLine: true,
  ).firstMatch(source);
  expect(match, isNotNull, reason: '$_pluginPath : $name introuvable');
  return match!.group(1)!;
}

/// Contenu du premier bloc `{...}` (sans imbrication) qui suit [anchor].
String _pyBlock(String source, String anchor) {
  final start = source.indexOf(anchor);
  expect(start, isNot(-1), reason: '$_pluginPath : $anchor introuvable');
  final open = source.indexOf('{', start);
  final close = source.indexOf('}', open);
  return source.substring(open + 1, close);
}

/// Les f-strings du plugin nomment `session_id` ; le contrat, `sessionId`.
String _template(String fString) =>
    fString.replaceAll('{session_id}', '{sessionId}');

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
  final mapping = _json('contracts/event-mapping.json');
  final payload = tracking['payload'] as Map<String, dynamic>;
  final notification = payload['notification'] as Map<String, dynamic>;
  final bodies = (notification['bodyByOutcome'] as Map).cast<String, String>();
  final android = payload['android'] as Map<String, dynamic>;
  final dataFields = (payload['dataFields'] as List).cast<String>();
  final outcomes = (payload['outcomeValues'] as List).cast<String>();

  final plugin = File(_pluginPath).readAsStringSync();
  final payloadFn = plugin.substring(plugin.indexOf('def _payload('));
  final activity = File(_activityPath).readAsStringSync();
  final manifest = File(_manifestPath).readAsStringSync();

  test('contrat v2 : seul le payload du plugin reste', () {
    expect(tracking.keys.toSet(), {'schemaVersion', 'payload'});
    expect(tracking['schemaVersion'], 2);
    expect(payload['transport'], 'fcm-http-v1');
    expect(payload['platforms'], ['android']);
    expect(payload['messageKind'], 'notification-and-data');
    expect(payload['dataValueType'], 'string');
    expect(dataFields, hasLength(2));
    expect(dataFields.toSet(), {'outcome', 'sessionId'});
  });

  test('issues = terminaux notifiables de event-mapping.json', () {
    final events = mapping['events'] as Map<String, dynamic>;
    final notifiable = <String>{};
    for (final event in events.values.cast<Map<String, dynamic>>()) {
      if (event['effect'] != 'terminal' || event['terminal'] != true) continue;
      final statusMap = event['statusMap'];
      if (statusMap is Map) {
        notifiable.addAll(statusMap.values.cast<String>());
      } else if (event['workState'] is String) {
        notifiable.add(event['workState'] as String);
      }
    }
    expect(notifiable, {'succeeded', 'failed', 'stopped'});
    expect(outcomes, hasLength(notifiable.length));
    expect(outcomes.toSet(), notifiable);
    expect(bodies.keys.toSet(), notifiable);
  });

  test('plugin : titre, libellés, canal, TTL et champs data identiques', () {
    expect(_pyString(plugin, '_TITLE'), notification['title']);
    expect(_pyString(plugin, '_CHANNEL'), android['channelId']);
    expect(_pyString(plugin, '_TTL'), '${android['ttlSeconds']}s');

    final pluginBodies = {
      for (final match in RegExp(
        r'"(\w+)":\s*"([^"]*)"',
      ).allMatches(_pyBlock(plugin, '_BODIES = {')))
        match.group(1)!: match.group(2)!,
    };
    expect(pluginBodies, bodies);

    final dataKeys = RegExp(r'"(\w+)":')
        .allMatches(_pyBlock(payloadFn, '"data":'))
        .map((match) => match.group(1)!)
        .toList();
    expect(dataKeys, hasLength(dataFields.length));
    expect(dataKeys.toSet(), dataFields.toSet());
    expect(
      RegExp(r'"title":\s*_TITLE,\s*"body":\s*_BODIES\[outcome\]')
          .hasMatch(payloadFn),
      isTrue,
      reason: 'le bloc notification doit venir de _TITLE et _BODIES',
    );
  });

  test('plugin : priorité, canal, tag et collapse key selon les gabarits', () {
    final androidBlock = payloadFn.substring(payloadFn.indexOf('"android":'));
    expect(
      RegExp(r'"priority":\s*"([^"]*)"').firstMatch(androidBlock)?.group(1),
      android['priority'],
    );
    expect(RegExp(r'"ttl":\s*_TTL').hasMatch(androidBlock), isTrue);
    expect(RegExp(r'"channel_id":\s*_CHANNEL').hasMatch(androidBlock), isTrue);
    final collapse = RegExp(r'"collapse_key":\s*f"([^"]*)"')
        .firstMatch(androidBlock)
        ?.group(1);
    expect(collapse, isNotNull);
    expect(_template(collapse!), android['collapseKeyTemplate']);
    final tag = RegExp(r'"tag":\s*f"([^"]*)"')
        .firstMatch(androidBlock)
        ?.group(1);
    expect(tag, isNotNull);
    expect(_template(tag!), android['notificationTagTemplate']);
  });

  test('Android : libellés, canal et tag de MainActivity et du manifeste', () {
    for (final entry in bodies.entries) {
      expect(
        activity,
        contains('"${entry.key}" -> "${entry.value}"'),
        reason: '$_activityPath : libellé ${entry.key}',
      );
    }
    expect(activity, contains('val channel = "${android['channelId']}"'));
    expect(
      manifest,
      contains(
        'default_notification_channel_id" '
        'android:value="${android['channelId']}"',
      ),
    );
    final kotlinTag = (android['notificationTagTemplate'] as String)
        .replaceAll('{sessionId}', r'$id')
        .replaceAll('{outcome}', r'$outcome');
    expect(activity, contains('val tag = "$kotlinTag"'));
    for (final field in dataFields) {
      expect(activity, contains('argument<String>("$field")'));
    }
    // Clé lue au toucher (extra FCM posé par Android).
    final sessionField = dataFields.singleWhere((f) => f == 'sessionId');
    expect(activity, contains('EXTRA_SESSION = "$sessionField"'));
  });

  test('client Dart : champs data et issues du contrat', () {
    final client = File(_clientPath).readAsStringSync();
    for (final value in [...dataFields, ...outcomes]) {
      expect(client, contains("'$value'"), reason: '$_clientPath : $value');
    }
  });

  test('aucun champ interdit, payload borné', () {
    final forbidden = (payload['forbiddenDataFields'] as List).cast<String>();
    expect(forbidden, isNot(contains('sessionId')));
    expect(forbidden, isNot(contains('outcome')));
    expect(dataFields.where(forbidden.contains), isEmpty);

    final longest = bodies.values.reduce(
      (a, b) => utf8.encode(a).length >= utf8.encode(b).length ? a : b,
    );
    // Pire cas : sessionId à 256 caractères (borne du plugin et de l'app),
    // jeton FCM d'environ 200 caractères, forme complète de `_payload`.
    final sessionId = 'x' * 256;
    final token = 't' * 200;
    final sample = jsonEncode({
      'message': {
        'token': token,
        'notification': {'title': notification['title'], 'body': longest},
        'data': {'outcome': 'succeeded', 'sessionId': sessionId},
        'android': {
          'priority': android['priority'],
          'ttl': '${android['ttlSeconds']}s',
          'collapse_key': 'hermes:$sessionId',
          'notification': {
            'channel_id': android['channelId'],
            'notification_priority': 'PRIORITY_HIGH',
            'sound': 'default',
            'tag': 'hermes:$sessionId:succeeded',
          },
        },
      },
    });
    expect(
      utf8.encode(sample).length,
      lessThanOrEqualTo(payload['maxBytes'] as int),
    );
  });

  test('aucun secret, chemin personnel ni TBD', () {
    _scanContractValue(tracking, '');
    for (final path in [
      'contracts/README.md',
      'server/hermes-plugin/README.md',
    ]) {
      _expectNoPersonalText(File(path).readAsStringSync(), path);
    }
  });
}
