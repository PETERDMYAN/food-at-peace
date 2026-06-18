// A real (signed-out) user must NOT see seeded sample friends, and anyone
// upgrading from a build that seeded them gets those stripped from the cache.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/models/friend.dart';
import 'package:food_at_peace/src/models/session.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoAuth extends AuthNotifier {
  @override
  Session? build() => null; // signed out → Circle's local path
}

Future<ProviderContainer> makeContainer(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authProvider.overrideWith(_NoAuth.new),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

String _encode(List<Friend> l) => jsonEncode([for (final f in l) f.toJson()]);

void main() {
  test('a brand-new signed-out user has an EMPTY circle (no fake friends)', () async {
    final c = await makeContainer(const {});
    expect(c.read(circleProvider), isEmpty);
    // And we did not write a seed flag / cache behind their back.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('circle_seeded'), isNull);
  });

  test('upgraders keep no seeded friends — legacy seed is stripped', () async {
    final c = await makeContainer({
      'circle_seeded': true,
      'circle_v1': _encode(Friend.seed()), // Mia/Jay/Sara/Ben
    });
    expect(
      c.read(circleProvider),
      isEmpty,
      reason: 'the 4 legacy sample friends must be removed',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('circle_seeded'), isNull, reason: 'flag cleared');
  });

  test('migration keeps a real friend but drops the seeded ones', () async {
    final real = Friend.sample(
      id: 'srv_real',
      name: 'Real Person',
      handle: '@real',
      status: FriendStatus.connected,
      seed: 9,
    );
    final c = await makeContainer({
      'circle_seeded': true,
      'circle_v1': _encode([...Friend.seed(), real]),
    });
    final ids = c.read(circleProvider).map((f) => f.id).toList();
    expect(ids, ['srv_real']);
  });
}
