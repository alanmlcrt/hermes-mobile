import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/data/storage/result_files.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/result.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'contracts_test.dart' show contract;
import 'support/connection_fakes.dart';

class _Opener implements ResultOpener {
  final calls = <({String path, String? mediaType})>[];
  AppError? error;

  @override
  Future<void> open(String path, String? mediaType) async {
    calls.add((path: path, mediaType: mediaType));
    if (error != null) throw error!;
  }
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Directory resultRoot;
  late Database database;
  late Harness h;
  late _Opener opener;
  late ConversationRepository conversation;
  late ConnectionKey connection;
  late ProfileKey profile;
  late TimelineKey key;
  var started = false;
  final mapping = EventMapping(contract('event-mapping'));

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await settle();
    }
  }

  ConversationRepository repository() => ConversationRepository(
    database,
    gateway: h.repository,
    mapping: mapping,
    downloads: h.repository,
    opener: opener,
    resultFiles: ResultFiles(root: () async => resultRoot),
    timeout: const Duration(seconds: 1),
  );

  Future<void> start() async {
    started = true;
    directory = await Directory.systemTemp.createTemp('hermes-result-flow-');
    resultRoot = await Directory.systemTemp.createTemp('hermes-result-files-');
    database = await openConnectionDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/hermes.sqlite',
    );
    h = Harness();
    await h.connect();
    await settle();
    opener = _Opener();
    connection = h.repository.snapshot.connection!.key;
    profile = h.repository.snapshot.selectedProfile!;
    key = TimelineKey(connection, profile, 'a1b2c3d4');
    conversation = repository();
    conversation.bind(key, 'a1b2c3d4', h.repository.socketGeneration);
    await conversation.load(key);
  }

  /// Nouvelle exécution de l'app : projections mémoire perdues.
  Future<void> restart() async {
    await conversation.dispose();
    conversation = repository();
    conversation.bind(key, 'a1b2c3d4', h.repository.socketGeneration);
    await conversation.load(key);
  }

  tearDown(() async {
    if (!started) return;
    started = false;
    await conversation.dispose();
    await h.repository.dispose();
    await database.close();
    await directory.delete(recursive: true);
    await resultRoot.delete(recursive: true);
  });

  void emit(String type, Map<String, dynamic> payload, int seq) {
    h.transport.sockets.last.controller.add({
      'jsonrpc': '2.0',
      'method': 'event',
      'params': {
        'type': type,
        'session_id': 'a1b2c3d4',
        'payload': payload,
        'seq': seq,
      },
    });
  }

  List<ResultItem> results() =>
      conversation.projection(key).items.whereType<ResultItem>().toList();

  /// `tool.complete` d'un fichier déjà écrit, précédé de son début quand
  /// [withStart] est vrai (les deux formes doivent produire la même carte).
  Future<void> produce(
    String path, {
    String id = 'W',
    String name = 'write_file',
    bool withStart = true,
    int seq = 1,
  }) async {
    final payload = {
      'tool_id': id,
      'name': name,
      'args': {'path': path},
    };
    if (withStart) emit('tool.start', payload, seq++);
    emit('tool.complete', payload, seq);
    await until(() => results().isNotEmpty || seq > 2);
    await settle();
  }

  Future<void> persistResultState(ResultState state) async {
    final row = (await database.query('conversation_timelines')).single;
    final projection = Map<String, dynamic>.from(
      jsonDecode(row['projection'] as String) as Map,
    );
    final items = projection['items'] as List;
    for (final item in items) {
      if (item is Map && item['k'] == 'result') item['state'] = state.name;
    }
    await database.update('conversation_timelines', {
      'projection': jsonEncode(projection),
    });
  }

  test('write_file absolu terminé : carte disponible après l’activité, aucun '
      'téléchargement automatique', () async {
    await start();
    emit('message.start', {}, 1);
    await until(() => conversation.projection(key).turns == 1);
    emit('tool.start', {
      'tool_id': 'W',
      'name': 'write_file',
      'args': {'path': '/home/u/rapport.pdf'},
    }, 2);
    emit('tool.complete', {
      'tool_id': 'W',
      'name': 'write_file',
      'args': {'path': '/home/u/rapport.pdf'},
    }, 3);
    await until(() => results().isNotEmpty);
    await settle();
    final p = conversation.projection(key);
    final activity = p.items.whereType<ActivityItem>().single;
    final result = p.items.whereType<ResultItem>().single;
    expect(p.items.indexOf(result), p.items.indexOf(activity) + 1);
    expect(result.name, 'rapport.pdf');
    expect(result.path, '/home/u/rapport.pdf');
    expect(result.mediaType, 'application/pdf');
    expect(result.state, ResultState.available);
    expect(result.bytes, isNull);
    expect(result.localKey, result.resultKey);
    expect(result.resultKey, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(h.transport.downloads, isEmpty);
    expect(opener.calls, isEmpty);
  });

  test('chemin relatif ou activité non write_file : aucune carte', () async {
    await start();
    emit('message.start', {}, 1);
    await until(() => conversation.projection(key).turns == 1);
    emit('tool.complete', {
      'tool_id': 'W1',
      'name': 'write_file',
      'args': {'path': 'notes.md'},
    }, 2);
    emit('tool.complete', {
      'tool_id': 'W2',
      'name': 'read_file',
      'args': {'path': '/home/u/x.csv'},
    }, 3);
    await until(() => conversation.projection(key).seq == 3);
    await settle();
    expect(results(), isEmpty);
    expect(
      conversation.projection(key).items.whereType<ActivityItem>(),
      hasLength(2),
    );
    expect(h.transport.downloads, isEmpty);
  });

  test(
    'chemin seulement cité dans la réponse : texte intact, aucune carte',
    () async {
      await start();
      emit('message.start', {}, 1);
      emit('message.delta', {'text': 'voir /home/u/x.csv'}, 2);
      await until(() => conversation.projection(key).seq == 2);
      final response = conversation
          .projection(key)
          .items
          .whereType<ResponseItem>()
          .single;
      expect(response.text, 'voir /home/u/x.csv');
      expect(results(), isEmpty);
    },
  );

  test('lecture du fichier écrit : chemin Windows absolu accepté', () async {
    await start();
    emit('message.start', {}, 1);
    await until(() => conversation.projection(key).turns == 1);
    emit('tool.complete', {
      'tool_id': 'W',
      'name': 'write_file',
      'args': {'path': r'C:\Users\alanc\Bureau\plan.txt'},
    }, 2);
    await until(() => results().isNotEmpty);
    final result = results().single;
    expect(result.name, 'plan.txt');
    expect(result.path, r'C:\Users\alanc\Bureau\plan.txt');
    expect(result.mediaType, 'text/plain');
  });

  test('doublon rejoué : une seule carte, même clé stable', () async {
    await start();
    emit('message.start', {}, 1);
    await until(() => conversation.projection(key).turns == 1);
    const payload = {
      'tool_id': 'W',
      'name': 'write_file',
      'args': {'path': '/home/u/rapport.pdf'},
    };
    emit('tool.start', payload, 2);
    emit('tool.complete', payload, 3);
    await until(() => results().isNotEmpty);
    final first = results().single;
    emit('tool.complete', payload, 4);
    await until(() => conversation.projection(key).seq == 4);
    await settle();
    expect(results(), hasLength(1));
    expect(results().single.resultKey, first.resultKey);
    expect(results().single.localKey, first.localKey);
  });

  test('téléchargement : requête authentifiée du fil, copie séparée puis état '
      'téléchargé avec taille et type', () async {
    await start();
    await produce('/home/u/rapport.pdf');
    final card = results().single;
    // Le type de l'extension prime sur un type serveur générique.
    h.transport.downloadMediaType = 'application/octet-stream';
    await conversation.downloadResult(key, card.resultKey);
    expect(results().single.state, ResultState.downloaded);
    expect(results().single.bytes, h.transport.downloadBytes.length);
    expect(results().single.mediaType, 'application/pdf');
    expect(results().single.errorCode, isNull);
    final call = h.transport.downloads.single;
    expect(call.uri.path, '/api/fs/download');
    expect(call.uri.queryParameters, {
      'path': '/home/u/rapport.pdf',
      'profile': profile.value,
      'session_id': 'a1b2c3d4',
    });
    expect(call.bearer, '<SYNTHETIC_ACCESS>');
    expect(opener.calls, isEmpty);
    final target = File(
      '${resultRoot.path}/results/${connection.value}/${profile.value}/'
      'a1b2c3d4/${card.localKey}',
    );
    expect(await target.readAsBytes(), h.transport.downloadBytes);
    expect(await File('${target.path}.part').exists(), isFalse);
  });

  test('taille inconnue : téléchargé sans taille, type conservé', () async {
    await start();
    await produce('/home/u/rapport.pdf');
    final card = results().single;
    h.transport.downloadLengthKnown = false;
    h.transport.downloadMediaType = null;
    await conversation.downloadResult(key, card.resultKey);
    expect(results().single.state, ResultState.downloaded);
    expect(results().single.bytes, isNull);
    expect(results().single.mediaType, 'application/pdf');
    expect(results().single.errorCode, isNull);
  });

  test('extension inconnue : le Content-Type reçu prend le relais', () async {
    await start();
    await produce('/home/u/export');
    final card = results().single;
    expect(card.mediaType, isEmpty);
    h.transport.downloadMediaType = 'application/pdf';
    await conversation.downloadResult(key, card.resultKey);
    expect(results().single.state, ResultState.downloaded);
    expect(results().single.mediaType, 'application/pdf');
  });

  test('404 : échec réessayable sans fichier, puis réessai réussi', () async {
    await start();
    await produce('/home/u/absent.pdf');
    final card = results().single;
    h.transport.downloadError = const AppError('result.missing');
    await conversation.downloadResult(key, card.resultKey);
    expect(results().single.state, ResultState.failed);
    expect(results().single.errorCode, 'result.missing');
    expect(results().single.bytes, isNull);
    final target = await ResultFiles(root: () async => resultRoot)
        .file(key, card.localKey!);
    expect(await target.exists(), isFalse);
    expect(await File('${target.path}.part').exists(), isFalse);
    h.transport.downloadError = null;
    await conversation.downloadResult(key, card.resultKey);
    expect(results().single.state, ResultState.downloaded);
    expect(results().single.errorCode, isNull);
    expect(h.transport.downloads, hasLength(2));
  });

  test('401 : un seul renouvellement, même profil et même session', () async {
    await start();
    await produce('/home/u/rapport.pdf');
    final card = results().single;
    h.transport.downloadErrors.add(const AppError('auth.refused'));
    await conversation.downloadResult(key, card.resultKey);
    expect(results().single.state, ResultState.downloaded);
    expect(h.transport.downloads, hasLength(2));
    for (final call in h.transport.downloads) {
      expect(call.uri.queryParameters, {
        'path': '/home/u/rapport.pdf',
        'profile': profile.value,
        'session_id': 'a1b2c3d4',
      });
    }
    expect(
      h.transport.requests.where((r) => r.uri.path == '/auth/native/refresh'),
      hasLength(1),
    );
    expect(h.transport.downloads.last.bearer, isNotNull);
  });

  test('401 sans renouvellement possible : échec, aucun fichier', () async {
    await start();
    await produce('/home/u/rapport.pdf');
    final card = results().single;
    h.transport.downloadErrors.add(const AppError('auth.refused'));
    h.transport.refreshStatus = 401;
    h.transport.loginStatus = 401;
    await conversation.downloadResult(key, card.resultKey);
    expect(results().single.state, ResultState.failed);
    expect(results().single.errorCode, isNotNull);
    expect(results().single.bytes, isNull);
    expect(h.transport.downloads, hasLength(1));
    final target = await ResultFiles(root: () async => resultRoot)
        .file(key, card.localKey!);
    expect(await target.exists(), isFalse);
    expect(await File('${target.path}.part').exists(), isFalse);
  });

  test('redémarrage : téléchargement interrompu → échec réessayable et partiel '
      'supprimé, copie saine conservée', () async {
    await start();
    await produce('/home/u/rapport.pdf');
    final card = results().single;
    final files = ResultFiles(root: () async => resultRoot);
    final target = await files.file(key, card.localKey!);
    await target.parent.create(recursive: true);
    await File('${target.path}.part').writeAsString('partiel');
    // Le flux d'activité est écrit par lots : laisser le lot partir avant
    // de simuler l'état laissé par une exécution interrompue.
    await Future<void>.delayed(
      ConversationRepository.flushInterval + const Duration(milliseconds: 50),
    );
    await persistResultState(ResultState.downloading);

    await restart();

    final restored = results().single;
    expect(restored.state, ResultState.interrupted);
    expect(restored.errorCode, isNull);
    expect(await target.exists(), isFalse);
    expect(await File('${target.path}.part').exists(), isFalse);
    final row = (await database.query('conversation_timelines')).single;
    final stored = TimelineProjection.fromJson(
      Map<String, Object?>.from(jsonDecode(row['projection'] as String) as Map),
    );
    expect(
      stored.items.whereType<ResultItem>().single.state,
      ResultState.interrupted,
    );
  });

  test('redémarrage : copie téléchargée relue et ouverte', () async {
    await start();
    await produce('/home/u/rapport.pdf');
    final card = results().single;
    h.transport.downloadMediaType = 'application/pdf';
    await conversation.downloadResult(key, card.resultKey);

    await restart();

    expect(results().single.state, ResultState.downloaded);
    expect(results().single.bytes, h.transport.downloadBytes.length);
    await conversation.openResult(key, card.resultKey);
    final opened = opener.calls.single;
    expect(opened.mediaType, 'application/pdf');
    expect(opened.path, contains('/results/'));
    expect(await File(opened.path).readAsBytes(), h.transport.downloadBytes);
  });

  test('copie locale effacée : carte de nouveau disponible', () async {
    await start();
    await produce('/home/u/rapport.pdf');
    final card = results().single;
    await conversation.downloadResult(key, card.resultKey);
    final target = File(
      '${resultRoot.path}/results/${connection.value}/${profile.value}/'
      'a1b2c3d4/${card.localKey}',
    );
    await target.delete();

    await conversation.load(key);

    expect(results().single.state, ResultState.available);
    expect(results().single.errorCode, isNull);
  });

  test(
    'ouverture sans copie locale : erreur claire, carte disponible',
    () async {
      await start();
      await produce('/home/u/rapport.pdf');
      final card = results().single;
      await conversation.downloadResult(key, card.resultKey);
      final target = File(
        '${resultRoot.path}/results/${connection.value}/${profile.value}/'
        'a1b2c3d4/${card.localKey}',
      );
      await target.delete();

      await expectLater(
        conversation.openResult(key, card.resultKey),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'result.unreadable',
          ),
        ),
      );
      expect(results().single.state, ResultState.available);
      expect(opener.calls, isEmpty);
    },
  );

  test('ouverture refusée par la plateforme : état local inchangé', () async {
    await start();
    await produce('/home/u/rapport.pdf');
    final card = results().single;
    await conversation.downloadResult(key, card.resultKey);
    opener.error = const AppError('result.open');

    await expectLater(
      conversation.openResult(key, card.resultKey),
      throwsA(
        isA<AppError>().having((error) => error.code, 'code', 'result.open'),
      ),
    );
    expect(results().single.state, ResultState.downloaded);
  });

  test(
    'carte produite avant le tour : elle rejoint le tour de son activité',
    () async {
      await start();
      final payload = {
        'tool_id': 'W',
        'name': 'write_file',
        'args': {'path': '/home/u/rapport.pdf'},
      };
      emit('tool.start', payload, 1);
      emit('tool.complete', payload, 2);
      await until(() => results().isNotEmpty);
      expect(results().single.turn, 0);

      emit('message.start', const {}, 3);
      await until(
        () =>
            conversation
                .projection(key)
                .items
                .whereType<ResultItem>()
                .single
                .turn ==
            1,
      );
      final items = conversation.projection(key).items;
      expect(items.whereType<ActivityItem>().single.turn, 1);
      expect(items.whereType<ResultItem>().single.turn, 1);
    },
  );

  test('téléchargement en vol : le chargement ne l’interrompt pas et un second '
      'appui ne double pas le transport', () async {
    await start();
    await produce('/home/u/rapport.pdf');
    final card = results().single;
    h.transport.downloadGate = Completer<void>();

    final pending = conversation.downloadResult(key, card.resultKey);
    await until(() => h.transport.downloads.length == 1);
    expect(results().single.state, ResultState.downloading);

    await conversation.load(key);
    expect(results().single.state, ResultState.downloading);

    await conversation.downloadResult(key, card.resultKey);
    expect(h.transport.downloads, hasLength(1));

    h.transport.downloadGate!.complete();
    await pending;
    await settle();
    expect(results().single.state, ResultState.downloaded);
  });
}
