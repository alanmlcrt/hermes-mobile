// Garde-fou : aucune valeur visuelle littérale hors des fichiers de tokens et
// de thème (lib/ui/tokens.dart, lib/ui/theme.dart). Heuristique par regex,
// assumée : couleurs, espacements, rayons, élévations, tailles d'icônes et de
// police, durées. La valeur 0 est tolérée.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const allowedFiles = {'lib/ui/tokens.dart', 'lib/ui/theme.dart'};

final _number = RegExp(r'(?<![\w.])(\d+(?:\.\d+)?)(?![\w.])');

/// Motifs dont l'argument entier (jusqu'à la parenthèse fermante) est
/// inspecté à la recherche d'un nombre non nul.
final _argPatterns = <String, RegExp>{
  'EdgeInsets': RegExp(r'\bEdgeInsets\w*\.\w+\(([^)]*)\)'),
  'BorderRadius.circular': RegExp(r'\bBorderRadius\.circular\(([^)]*)\)'),
  'Radius.circular': RegExp(r'\bRadius\.circular\(([^)]*)\)'),
  'Duration': RegExp(r'\bDuration\(([^)]*)\)'),
};

/// Motifs nommés `clé: <nombre>`.
final _namedPatterns = <String, RegExp>{
  'fontSize': RegExp(r'\bfontSize\s*:\s*(\d+(?:\.\d+)?)'),
  'elevation': RegExp(r'\belevation\s*:\s*(\d+(?:\.\d+)?)'),
  'size': RegExp(r'\bsize\s*:\s*(\d+(?:\.\d+)?)'),
  'height': RegExp(r'\bheight\s*:\s*(\d+(?:\.\d+)?)'),
  'width': RegExp(r'\bwidth\s*:\s*(\d+(?:\.\d+)?)'),
};

/// Motifs toujours interdits.
final _colorPatterns = <String, RegExp>{
  'Color(0x': RegExp(r'\bColor\(\s*0x'),
  'Color(<décimal>)': RegExp(r'\bColor\(\s*\d+\s*\)'),
  'Color.from': RegExp(r'\bColor\.from\w+\('),
  'Colors.': RegExp(r'\bColors\.'),
};

bool _isNonZero(String n) => double.parse(n) != 0;

/// Remplace les commentaires `//` par des espaces (longueurs conservées pour
/// garder les numéros de ligne et les positions).
String _stripLineComments(String source) => source.replaceAllMapped(
      RegExp(r'//[^\n]*'),
      (m) => ' ' * m.group(0)!.length,
    );

/// Retourne les violations de [source] (fichier [path], relatif à la racine
/// du package, séparateurs `/`), sous la forme `path:ligne : motif`.
List<String> literalViolations(String path, String source) {
  if (allowedFiles.contains(path)) return const [];
  final code = _stripLineComments(source);
  final hits = <(int, String)>[];

  for (final e in _colorPatterns.entries) {
    for (final m in e.value.allMatches(code)) {
      hits.add((m.start, e.key));
    }
  }
  for (final e in _argPatterns.entries) {
    for (final m in e.value.allMatches(code)) {
      if (_number.allMatches(m.group(1)!).any((n) => _isNonZero(n.group(1)!))) {
        hits.add((m.start, e.key));
      }
    }
  }
  for (final e in _namedPatterns.entries) {
    for (final m in e.value.allMatches(code)) {
      if (_isNonZero(m.group(1)!)) hits.add((m.start, e.key));
    }
  }

  hits.sort((a, b) => a.$1.compareTo(b.$1));
  return [
    for (final (offset, label) in hits)
      '$path:${'\n'.allMatches(code.substring(0, offset)).length + 1} : '
          'littéral visuel « $label » hors des tokens',
  ];
}

void main() {
  group('literalViolations (sources en mémoire)', () {
    const path = 'lib/features/x.dart';

    test('couleur littérale : fichier et ligne cités', () {
      final v = literalViolations(path, "import 'a';\nconst c = Color(0xFF112233);\n");
      expect(v, hasLength(1));
      expect(v.single, startsWith('lib/features/x.dart:2'));
    });

    test('EdgeInsets.all(8) refusé', () {
      expect(literalViolations(path, 'const p = EdgeInsets.all(8);'), hasLength(1));
    });

    test('Duration(milliseconds: 200) refusé', () {
      expect(
        literalViolations(path, 'const d = Duration(milliseconds: 200);'),
        hasLength(1),
      );
    });

    test('autres motifs refusés', () {
      for (final src in [
        'Colors.red',
        'EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 4)',
        'EdgeInsetsDirectional.only(start: 12)',
        'BorderRadius.circular(12)',
        'Radius.circular(4.5)',
        'TextStyle(fontSize: 14)',
        'Card(elevation: 2)',
        'Icon(Icons.add, size: 24)',
        'Color.fromARGB(255, 0, 0, 0)',
        'Color(4278190080)',
        'SizedBox(height: 8)',
        'SizedBox(width: 4)',
      ]) {
        expect(literalViolations(path, src), hasLength(1), reason: src);
      }
    });

    test('0 toléré, tokens acceptés, commentaires ignorés', () {
      expect(
        literalViolations(
          path,
          'EdgeInsets.all(0)\n'
          'Duration(milliseconds: 0)\n'
          'EdgeInsets.all(Spacing.md)\n'
          'Icon(Icons.add, size: IconSizes.md)\n'
          'SizedBox(height: Spacing.sm)\n'
          'SizedBox(width: 0)\n'
          'Duration.zero\n'
          '// EdgeInsets.all(8)\n',
        ),
        isEmpty,
      );
    });

    test('littéral autorisé dans lib/ui/tokens.dart et lib/ui/theme.dart', () {
      const src = 'Color(0xFF112233); EdgeInsets.all(8); '
          'Duration(milliseconds: 200);';
      expect(literalViolations('lib/ui/tokens.dart', src), isEmpty);
      expect(literalViolations('lib/ui/theme.dart', src), isEmpty);
    });
  });

  test('lib/ ne contient aucun littéral visuel hors des tokens', () {
    final d = Directory('lib');
    expect(d.existsSync(), isTrue, reason: 'lib est absent');
    final violations = <String>[];
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      violations.addAll(literalViolations(path, f.readAsStringSync()));
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
