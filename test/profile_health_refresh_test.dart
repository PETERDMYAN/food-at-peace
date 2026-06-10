import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/src/data/health_service.dart';
import 'package:food_at_peace/src/models/energy_out.dart';
import 'package:food_at_peace/src/models/food_entry.dart';
import 'package:food_at_peace/src/models/user_profile.dart';
import 'package:food_at_peace/src/models/workout_summary.dart';
import 'package:food_at_peace/src/providers/providers.dart';

/// A HealthService that reports fixed age/height/weight.
class _FakeHealth implements HealthService {
  _FakeHealth({this.age, this.heightCm, this.weightKg});
  final int? age;
  final double? heightCm;
  final double? weightKg;

  @override
  bool get isSupported => true;
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<bool> hasPermissions() async => true;
  @override
  Future<EnergyOut?> readEnergyOut(DateTime day) async => null;
  @override
  Future<double?> readLatestWeightKg() async => weightKg;
  @override
  Future<int?> readAge() async => age;
  @override
  Future<double?> readHeightCm() async => heightCm;
  @override
  Future<List<WorkoutSummary>> readWorkouts(DateTime day) async => const [];
  @override
  Future<bool> writeFood(FoodEntry entry) async => true;
  @override
  Future<bool> writeWeight(double kg, DateTime when) async => true;
  @override
  Future<bool> writeHeight(double cm) async => true;
}

Future<ProviderContainer> _container(_FakeHealth health) async {
  // health_connected=true so HealthConnectedNotifier reports connected.
  SharedPreferences.setMockInitialValues({'health_connected': true});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      healthServiceProvider.overrideWithValue(health),
    ],
  );
}

void main() {
  test('refreshFromHealth updates height/weight, and age when not manual', () async {
    final c = await _container(
      _FakeHealth(age: 41, heightCm: 182, weightKg: 79),
    );
    addTearDown(c.dispose);

    await c
        .read(profileProvider.notifier)
        .save(UserProfile.defaultProfile.copyWith(age: 30));
    await c.read(profileProvider.notifier).refreshFromHealth();

    final p = c.read(profileProvider);
    expect(p.age, 41); // pulled from Health (not manually set)
    expect(p.heightCm, 182);
    expect(p.weightKg, 79);
  });

  test('refreshFromHealth does NOT overwrite a manually-set age', () async {
    final c = await _container(
      _FakeHealth(age: 41, heightCm: 182, weightKg: 79),
    );
    addTearDown(c.dispose);

    await c.read(profileProvider.notifier).save(
          UserProfile.defaultProfile.copyWith(age: 39, ageManuallySet: true),
        );
    await c.read(profileProvider.notifier).refreshFromHealth();

    final p = c.read(profileProvider);
    expect(p.age, 39); // manual edit preserved
    expect(p.heightCm, 182); // height/weight still sync
    expect(p.weightKg, 79);
  });
}
