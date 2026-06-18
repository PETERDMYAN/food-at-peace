// Circle activity notifications are ON by default; an explicit "off" persists.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Circle activity defaults ON when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    expect(c.read(circleNotifyProvider), isTrue);
  });

  test('an explicit off is respected (persisted false wins)', () async {
    SharedPreferences.setMockInitialValues({'circle_notify_enabled': false});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    expect(c.read(circleNotifyProvider), isFalse);

    // Re-enabling intent persists too.
    await c.read(circleNotifyProvider.notifier).disable();
    expect(prefs.getBool('circle_notify_enabled'), isFalse);
  });
}
