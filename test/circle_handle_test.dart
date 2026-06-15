import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/src/models/session.dart';
import 'package:food_at_peace/src/providers/providers.dart';

/// Signed-out auth that never touches secure storage (which has no plugin in a
/// `flutter test` run) — keeps the Circle on its offline/local path.
class _NoAuth extends AuthNotifier {
  @override
  Session? build() => null;
}

void main() {
  Future<ProviderContainer> makeContainer([Map<String, Object> seed = const {}]) async {
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

  test('myCircleHandleProvider is null until a handle is set', () async {
    final c = await makeContainer();
    expect(c.read(myCircleHandleProvider), isNull);
  });

  test('myCircleHandleProvider reads a previously stored handle', () async {
    final c = await makeContainer({'circle_my_handle': 'jaylim'});
    expect(c.read(myCircleHandleProvider), 'jaylim');
  });

  test('setHandle validates, normalizes, stores, and publishes (offline)', () async {
    final c = await makeContainer();
    final notifier = c.read(circleProvider.notifier);

    expect(await notifier.setHandle('a'), SetHandleResult.invalid);
    expect(await notifier.setHandle('bad handle!'), SetHandleResult.invalid);

    expect(await notifier.setHandle('@MiaTan'), SetHandleResult.ok);
    expect(c.read(myCircleHandleProvider), 'miatan'); // @ stripped + lowercased
  });
}
