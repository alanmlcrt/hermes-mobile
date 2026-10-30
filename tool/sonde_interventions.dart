// Sonde de la story 6.1 : questions, autorisations, messages pendant le
// travail et fichiers résultats, sur un profil de test dédié.
//
// dart run tool/sonde_interventions.dart <profil-de-test> <journal.jsonl>
//
// HERMES_URL et HERMES_PASSWORD viennent de l'environnement. Le journal brut
// contient le texte des échanges : il reste hors du dépôt, seules des
// fixtures anonymisées en sont tirées.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hermes_mobile/data/hermes_adapter.dart';

const _turnTimeout = Duration(minutes: 4);

late IOSink _log;
late GatewaySocket _socket;
final _pending = <String, Completer<Map>>{};
final _turnEnded = <String, Completer<void>>{};
var _sequence = 0;
var _onFrame = (Map frame) {};

void _write(String direction, Object? frame) => _log.writeln(
  jsonEncode({
    'at': DateTime.now().toUtc().toIso8601String(),
    'dir': direction,
    'frame': frame,
  }),
);

void _send(Map<String, dynamic> frame) {
  _write('out', frame);
  _socket.send(frame);
}

Future<Map> _call(String method, Map<String, dynamic> params) {
  final id = 'sonde-${++_sequence}';
  final done = _pending[id] = Completer<Map>();
  _send({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
  return done.future.timeout(const Duration(seconds: 60));
}

Future<void> _turn(String runtime, String text) async {
  final ended = _turnEnded[runtime] = Completer<void>();
  final submitted = await _call(
    'prompt.submit',
    HermesRpc.submitParams(runtime, text),
  );
  stdout.writeln('  prompt.submit -> ${submitted['status']}');
  await ended.future.timeout(_turnTimeout, onTimeout: () {
    stdout.writeln('  fin de tour non reçue');
  });
}

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage : <profil-de-test> <journal.jsonl> [autorisation]');
    exitCode = 64;
    return;
  }
  final env = Platform.environment;
  final origin = Uri.parse(env['HERMES_URL']!);
  final transport = IoHermesTransport();
  final adapter = HermesAdapter(transport);
  _log = File(args[1]).openWrite();
  try {
    final tokens = await adapter.login(origin, env['HERMES_PASSWORD']!);
    final profiles = await adapter.profiles(origin, tokens.access);
    final profile = profiles.singleWhere((p) => p.key.value == args[0]);
    if (profile.isDefault) throw StateError('profil par défaut refusé');
    _socket = await adapter.socket(origin, tokens.access);
    final ready = Completer<void>();
    _socket.messages.listen((raw) {
      final frame = raw is String ? jsonDecode(raw) : raw;
      if (frame is! Map) return;
      _write('in', frame);
      final params = frame['params'];
      if (frame['method'] == 'event' && params is Map) {
        final type = params['type'];
        if (type == 'gateway.ready' && !ready.isCompleted) ready.complete();
        if (type == 'message.complete' || type == 'error') {
          final done = _turnEnded[params['session_id']];
          if (done != null && !done.isCompleted) done.complete();
        }
      } else if (frame['method'] != null && frame['id'] != null) {
        stdout.writeln('  requête serveur : ${frame['method']}');
      }
      final id = frame['id'];
      if (frame['method'] == null && _pending.containsKey(id)) {
        _pending.remove(id)!.complete(frame);
      }
      _onFrame(frame);
    });
    await ready.future.timeout(const Duration(seconds: 20));

    stdout.writeln('client.capabilities');
    stdout.writeln(
      '  ${await _call('client.capabilities', {'server_requests': true})}',
    );
    stdout.writeln('gateway.capabilities');
    stdout.writeln('  ${await _call('gateway.capabilities', {})}');

    final created = await _call(
      'session.create',
      HermesRpc.createParams(profile.key, 'sonde-6-1-${DateTime.now().millisecondsSinceEpoch}'),
    );
    final runtime = HermesRpc.created(
      Map<String, dynamic>.from(created['result'] as Map),
    ).runtime;

    // Réponses aux requêtes serveur : une précision, puis un refus.
    _onFrame = (frame) {
      final method = frame['method'];
      final id = frame['id'];
      if (method == null || id == null || method == 'event') return;
      final params = frame['params'] as Map;
      if (method == 'clarify') {
        final answers = {
          for (final q in params['questions'] as List)
            (q as Map)['qid'] as String: 'bleu',
        };
        _send({
          'jsonrpc': '2.0',
          'id': id,
          'result': {'answers': answers, 'outcome': 'submitted'},
        });
      } else if (method == 'approval') {
        _send({
          'jsonrpc': '2.0',
          'id': id,
          'result': {'choice': 'deny'},
        });
      }
    };

    if (args.length == 3 && args[2] == 'autorisation') {
      // Le mode « smart » du profil approuve seul : passage temporaire en
      // « manual » sur le seul profil de test, rétabli ensuite.
      Future<Object?> mode([String? profileKey]) async => ((await _call(
        'config.get',
        {'key': 'approvals.mode', if (profileKey != null) 'profile': profileKey},
      ))['result'] as Map?)?['value'];
      final before = await mode(profile.key.value);
      final otherBefore = await mode();
      stdout.writeln('  mode test=$before, défaut=$otherBefore');
      if (before is! String) throw StateError('mode du profil illisible');
      await _call('config.set', {
        'key': 'approvals.mode',
        'value': 'manual',
        'profile': profile.key.value,
      });
      stdout.writeln('  après : test=${await mode(profile.key.value)}, '
          'défaut=${await mode()}');
      try {
        await _turn(
          runtime,
          'Test technique. Lance exactement cette commande dans le terminal, '
          'sans la modifier : `rm -rf /tmp/sonde-6-1-inexistant`\n'
          'Puis dis-moi si elle a été autorisée.',
        );
        await _call('approval.pending', {'session_id': runtime});
      } finally {
        await _call('config.set', {
          'key': 'approvals.mode',
          'value': '$before',
          'profile': profile.key.value,
        });
        stdout.writeln('  rétabli : test=${await mode(profile.key.value)}, '
            'défaut=${await mode()}');
      }
      return;
    }

    stdout.writeln('1. question (clarify)');
    await _turn(
      runtime,
      'Test technique. Utilise obligatoirement ton outil clarify pour me '
      'demander ma couleur préférée (choix : rouge, bleu), puis répète ma '
      'réponse en un mot.',
    );

    stdout.writeln('2. autorisation (commande dangereuse refusée)');
    await _turn(
      runtime,
      'Test technique. Lance exactement cette commande dans le terminal, sans '
      'la modifier : `rm -rf /tmp/sonde-6-1-inexistant`\n'
      'Puis dis-moi si elle a été autorisée.',
    );

    stdout.writeln('3. fichier résultat');
    await _turn(
      runtime,
      'Test technique. Crée un petit fichier texte sonde-6-1.txt contenant '
      '« ok » et transmets-le-moi comme fichier joint, comme tu le ferais '
      'pour un utilisateur sur messagerie.',
    );

    stdout.writeln('4. message pendant le travail');
    final ended = _turnEnded[runtime] = Completer<void>();
    await _call(
      'prompt.submit',
      HermesRpc.submitParams(
        runtime,
        'Test technique. Dans le terminal, lance : sleep 20 && echo fini . '
        'Puis résume en une phrase.',
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 8));
    final steer = await _call(
      'prompt.submit',
      HermesRpc.submitParams(runtime, 'Ajoute le mot BANANE à ta réponse.'),
    );
    stdout.writeln('  second prompt.submit -> $steer');
    await ended.future.timeout(_turnTimeout, onTimeout: () {});
    await Future<void>.delayed(const Duration(seconds: 30));

    stdout.writeln('session.history');
    await _call('session.history', HermesRpc.historyParams(runtime));
  } finally {
    await _log.flush();
    await _log.close();
    transport.close();
    exit(exitCode);
  }
}
