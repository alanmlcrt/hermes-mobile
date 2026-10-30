import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/result.dart';
import 'package:hermes_mobile/models/timeline.dart';

void main() {
  test('ResultItem sérialisé puis relu, sans perte ni invention', () {
    const item = ResultItem(
      2,
      resultKey: 'cle',
      path: '/home/u/rapport.pdf',
      name: 'rapport.pdf',
      mediaType: 'application/pdf',
      bytes: 12,
      localKey: 'copie',
      state: ResultState.downloaded,
    );
    final json = item.toJson();
    expect(json['k'], 'result');
    expect(json['resultVersion'], 1);
    final restored = TimelineItem.fromJson(json);
    expect(restored, isA<ResultItem>());
    final result = restored as ResultItem;
    expect(result.turn, 2);
    expect(result.resultKey, 'cle');
    expect(result.path, '/home/u/rapport.pdf');
    expect(result.name, 'rapport.pdf');
    expect(result.mediaType, 'application/pdf');
    expect(result.bytes, 12);
    expect(result.localKey, 'copie');
    expect(result.state, ResultState.downloaded);
    expect(result.errorCode, isNull);
  });

  test('ResultItem relu : champs absents ou invalides jamais repris', () {
    final legacy = ResultItem.fromJson({'k': 'result', 'turn': 1});
    expect(legacy.resultKey, '');
    expect(legacy.path, '');
    expect(legacy.name, '');
    expect(legacy.mediaType, '');
    expect(legacy.bytes, isNull);
    expect(legacy.localKey, isNull);
    expect(legacy.state, ResultState.available);
    expect(legacy.errorCode, isNull);

    final invalid = ResultItem.fromJson({
      'k': 'result',
      'turn': 1,
      'resultVersion': 1,
      'resultKey': 'cle',
      'path': '/x',
      'name': 'x',
      'mediaType': 'text/plain',
      'bytes': -1,
      'state': 'inconnu',
      'errorCode': 42,
    });
    expect(invalid.bytes, isNull);
    expect(invalid.state, ResultState.available);
    expect(invalid.errorCode, isNull);
    expect(ResultState.decode(null), ResultState.available);
  });

  test('chemins absolus de Hermes seulement, jamais URL ni partage', () {
    for (final path in const [
      '/home/u/rapport.pdf',
      '/tmp/x',
      r'C:\Users\alanc\Bureau\plan.txt',
      r'd:\data\a.csv',
      'Z:/dossier/fichier.txt',
    ]) {
      expect(ResultPaths.isAbsolute(path), isTrue, reason: path);
    }
    for (final path in const [
      '',
      '   ',
      'notes.md',
      'dossier/fichier.txt',
      r'.\notes.md',
      r'..\notes.md',
      '~/notes.md',
      '//serveur/partage/x.csv',
      'https://example.test/x.csv',
      'file:///home/u/x.csv',
    ]) {
      expect(ResultPaths.isAbsolute(path), isFalse, reason: path);
    }
  });

  test('nom et type déduits du chemin reçu', () {
    expect(ResultPaths.name('/home/u/rapport.pdf'), 'rapport.pdf');
    expect(ResultPaths.name(r'C:\Users\alanc\Bureau\plan.txt'), 'plan.txt');
    expect(ResultPaths.name('/home/u/'), 'u');
    expect(ResultPaths.name('/'), isNull);
    expect(ResultPaths.name(r'C:\'), isNull);
    expect(ResultPaths.mediaTypeFor('rapport.pdf'), 'application/pdf');
    expect(ResultPaths.mediaTypeFor('notes.txt'), 'text/plain');
    expect(ResultPaths.mediaTypeFor('sans-extension'), '');
  });
}
