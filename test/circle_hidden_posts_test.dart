// Reporting a post or unfollowing its author hides it locally (Apple
// Guideline 1.2 — flagged content must vanish for the reporter immediately),
// and the hidden set survives a relaunch.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> makeContainer(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('a fresh user has nothing hidden', () async {
    final c = await makeContainer(const {});
    expect(c.read(hiddenPostsProvider), isEmpty);
  });

  test('hiding a post records it and persists to prefs', () async {
    final c = await makeContainer(const {});
    await c.read(hiddenPostsProvider.notifier).hide('p_abc');
    expect(c.read(hiddenPostsProvider), {'p_abc'});

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('circle_hidden_posts'), ['p_abc']);
  });

  test('hidden posts are restored on relaunch', () async {
    final c = await makeContainer(const {
      'circle_hidden_posts': ['p_old', 'p_old2'],
    });
    expect(c.read(hiddenPostsProvider), {'p_old', 'p_old2'});
  });

  test('hiding is idempotent and ignores empty ids', () async {
    final c = await makeContainer(const {});
    final n = c.read(hiddenPostsProvider.notifier);
    await n.hide('p1');
    await n.hide('p1');
    await n.hide('');
    expect(c.read(hiddenPostsProvider), {'p1'});
  });
}
