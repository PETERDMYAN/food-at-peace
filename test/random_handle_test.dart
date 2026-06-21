// New accounts get a random 8-char default @handle (lowercase letters + digits,
// a mix of both) — see CircleNotifier._ensureHandle / generateRandomHandle.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/providers/providers.dart';

void main() {
  final eight = RegExp(r'^[a-z0-9]{8}$');
  final backendRule = RegExp(r'^[a-z0-9_]{2,20}$');

  test('is 8 lowercase alphanumerics, always mixing a digit and a letter', () {
    final rng = Random(42);
    for (var i = 0; i < 500; i++) {
      final h = generateRandomHandle(rng);
      expect(eight.hasMatch(h), isTrue, reason: h);
      expect(h.contains(RegExp(r'[0-9]')), isTrue, reason: 'needs a digit: $h');
      expect(h.contains(RegExp(r'[a-z]')), isTrue, reason: 'needs a letter: $h');
      expect(backendRule.hasMatch(h), isTrue); // accepted by the server
    }
  });

  test('a seeded RNG is deterministic', () {
    expect(generateRandomHandle(Random(1)), generateRandomHandle(Random(1)));
  });
}
