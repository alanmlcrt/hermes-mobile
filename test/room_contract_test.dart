import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    '8.1 contrat documentaire, références complètes, aucun essai prétendu',
    () {
      final contract = jsonDecode(
        File('contracts/epic-8/methods.json').readAsStringSync(),
      ) as Map;
      expect(contract['status'], 'documentary');
      final methods = contract['methods'] as List;
      expect(methods.any((m) => m['name'] == 'groups.send'), isTrue);
      expect(methods.any((m) => m['name'] == 'groups.discard'), isTrue);
      final schemas = contract['components']['schemas'] as Map;
      void check(Object? value) {
        if (value is Map) {
          final ref = value[r'$ref'];
          if (ref is String) {
            expect(schemas.containsKey(ref.split('/').last), isTrue);
          }
          value.values.forEach(check);
        } else if (value is List) {
          value.forEach(check);
        }
      }

      check(contract);
    },
  );
}
