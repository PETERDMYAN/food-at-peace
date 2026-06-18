// Active-energy source priority: the pure summing rule (preferred source wins
// when present, else combine) and the persisted preference provider.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/data/health_service.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const points = <ActiveEnergyPoint>[
    (source: 'Garmin Connect', kcal: 500),
    (source: 'Apple Watch', kcal: 480),
    (source: 'Garmin Connect', kcal: 120),
  ];

  test('null preference combines all sources', () {
    expect(sumActiveEnergy(points, null), 1100);
  });

  test('a preferred source that has data wins (only its points count)', () {
    expect(sumActiveEnergy(points, 'Garmin Connect'), 620);
    expect(sumActiveEnergy(points, 'Apple Watch'), 480);
  });

  test('a preferred source with no data falls back to combining all', () {
    expect(sumActiveEnergy(points, 'Fitbit'), 1100);
  });

  test('energySourcePriority persists and clears', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);

    expect(c.read(energySourcePriorityProvider), isNull); // Automatic
    await c.read(energySourcePriorityProvider.notifier).set('Garmin Connect');
    expect(c.read(energySourcePriorityProvider), 'Garmin Connect');
    expect(prefs.getString('energy_source_priority'), 'Garmin Connect');

    await c.read(energySourcePriorityProvider.notifier).set(null);
    expect(c.read(energySourcePriorityProvider), isNull);
    expect(prefs.getString('energy_source_priority'), isNull);
  });
}
