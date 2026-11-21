import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bezpiecznik/ratunek/detect/normalize.dart';

void main() {
  final raw = jsonDecode(
          File('test/ratunek/detect/normalize_vectors.json').readAsStringSync())
      as Map<String, dynamic>;
  final vectors = (raw['vectors'] as List).cast<Map<String, dynamic>>();

  test('has at least 25 shared vectors', () {
    expect(vectors.length, greaterThanOrEqualTo(25));
  });

  for (final v in vectors) {
    test('normalizePl(${jsonEncode(v['input'])})', () {
      expect(normalizePl(v['input'] as String), v['expected']);
    });
  }

  test('idempotent', () {
    for (final v in vectors) {
      final once = normalizePl(v['input'] as String);
      expect(normalizePl(once), once);
    }
  });
}
