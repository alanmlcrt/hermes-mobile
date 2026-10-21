// Contrôle des frontières d'imports (architecture MVVM légère) :
// - lib/models n'importe pas Flutter ;
// - lib/features n'importe pas lib/data (relatif ou package:hermes_mobile/data/).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _directive = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

/// Retourne la liste des violations pour un fichier [path] (relatif à la
/// racine du package, séparateurs `/`) de contenu [source].
List<String> importViolations(String path, String source) {
  final violations = <String>[];
  final inModels = path.startsWith('lib/models/');
  final inFeatures = path.startsWith('lib/features/');
  if (!inModels && !inFeatures) return violations;

  for (final match in _directive.allMatches(source)) {
    final target = match.group(1)!;
    if (inModels &&
        (target.startsWith('package:flutter/') || target == 'dart:ui')) {
      violations.add('$path importe "$target" (lib/models ne doit pas importer Flutter)');
    }
    if (inFeatures && _resolvesToData(path, target)) {
      violations.add('$path importe "$target" (lib/features ne doit pas importer lib/data)');
    }
  }
  return violations;
}

bool _resolvesToData(String path, String target) {
  if (target.startsWith('package:')) {
    return target.startsWith('package:hermes_mobile/data/');
  }
  if (target.contains(':')) return false; // dart:, autres schémas
  final resolved = Uri.parse(path).resolve(target).path;
  return resolved.startsWith('lib/data/');
}

void main() {
  group('importViolations (sources en mémoire)', () {
    test('modèle propre : aucune violation', () {
      expect(
        importViolations('lib/models/x.dart', "import 'dart:collection';\n"),
        isEmpty,
      );
    });

    test('modèle impur : fichier et import cités', () {
      final v = importViolations(
        'lib/models/x.dart',
        "import 'package:flutter/foundation.dart';\n",
      );
      expect(v, hasLength(1));
      expect(v.single, contains('lib/models/x.dart'));
      expect(v.single, contains('package:flutter/foundation.dart'));
    });

    test('vue fautive : import relatif vers data/', () {
      final v = importViolations(
        'lib/features/profiles/profiles_view.dart',
        "import '../../data/connection_repository.dart';\n",
      );
      expect(v, hasLength(1));
      expect(v.single, contains('lib/features/profiles/profiles_view.dart'));
      expect(v.single, contains('../../data/connection_repository.dart'));
    });

    test('vue fautive : import package:hermes_mobile/data/', () {
      final v = importViolations(
        'lib/features/x.dart',
        'import "package:hermes_mobile/data/x.dart";\n',
      );
      expect(v, hasLength(1));
      expect(v.single, contains('package:hermes_mobile/data/x.dart'));
    });

    test('modèle impur : dart:ui compte comme import Flutter', () {
      final v = importViolations('lib/models/x.dart', "import 'dart:ui';\n");
      expect(v, hasLength(1));
      expect(v.single, contains('dart:ui'));
    });

    test('vue fautive : export vers data/', () {
      expect(
        importViolations('lib/features/x.dart', "export '../data/x.dart';\n"),
        hasLength(1),
      );
    });

    test('vue propre : models et ui autorisés', () {
      expect(
        importViolations(
          'lib/features/x.dart',
          "import 'package:flutter/material.dart';\n"
              "import 'package:hermes_mobile/models/profile.dart';\n"
              "import '../ui/tokens.dart';\n",
        ),
        isEmpty,
      );
    });
  });

  test('lib/ respecte les frontières d\'imports', () {
    final violations = <String>[];
    for (final dir in ['lib/models', 'lib/features']) {
      final d = Directory(dir);
      expect(d.existsSync(), isTrue, reason: '$dir est absent');
      for (final f in d.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final path = f.path.replaceAll(r'\', '/');
        violations.addAll(importViolations(path, f.readAsStringSync()));
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
