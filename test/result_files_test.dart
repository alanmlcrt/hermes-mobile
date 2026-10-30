import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/storage/result_files.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('hermes-results-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('segments sûrs gardés, tout identifiant dangereux haché', () {
    expect(ResultFiles.segment('abc-123'), 'abc-123');
    expect(ResultFiles.segment('../secret'), isNot(contains('/')));
    expect(ResultFiles.segment('../secret'), isNot(contains('..')));
    expect(
      ResultFiles.segment('../secret'),
      sha256.convert(utf8.encode('../secret')).toString(),
    );
    expect(ResultFiles.segment('a/b'), isNot(contains('/')));
    expect(ResultFiles.segment(''), hasLength(64));
  });

  test('copie rangée sous results, jamais sous le nom du serveur', () async {
    final files = ResultFiles(root: () async => root);
    final key = const TimelineKey(
      ConnectionKey('c-1'),
      ProfileKey('default'),
      'session/../x',
    );
    final file = await files.file(key, 'rapport.pdf');
    expect(
      file.path,
      '${root.path}/results/c-1/default/'
      '${ResultFiles.segment('session/../x')}/${ResultFiles.segment('rapport.pdf')}',
    );
    expect(file.path, isNot(contains('..')));
    expect(file.path, isNot(contains('rapport.pdf')));
  });

  test('remove supprime la copie et le fragment partiel', () async {
    final files = ResultFiles(root: () async => root);
    final key = const TimelineKey(
      ConnectionKey('c-1'),
      ProfileKey('default'),
      's-1',
    );
    final file = await files.file(key, 'cle');
    await file.parent.create(recursive: true);
    await file.writeAsString('complet');
    final part = File('${file.path}.part');
    await part.writeAsString('partiel');
    await files.remove(key, 'cle');
    expect(await file.exists(), isFalse);
    expect(await part.exists(), isFalse);
    // Absente : remove ne lève pas.
    await files.remove(key, 'cle');
  });
}
