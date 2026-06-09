import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/models/daily_summary.dart';
import 'package:food_at_peace/src/models/energy_out.dart';
import 'package:food_at_peace/src/models/user_profile.dart';

void main() {
  // BMR(male, 30y, 175cm, 75kg) = 1698.75 kcal.
  const male = UserProfile(
    sex: Sex.male,
    age: 30,
    heightCm: 175,
    weightKg: 75,
    activity: ActivityLevel.moderate,
    goal: Goal.maintain,
  );

  test('uses BMR + measured active energy when health data is present', () {
    final summary = DailySummary.compute(
      date: DateTime(2026, 1, 1),
      entries: const [],
      profile: male,
      energyOut: EnergyOut(activeEnergy: 500, asOf: DateTime(2026, 1, 1, 12)),
    );
    expect(summary.usingHealthData, isTrue);
    expect(summary.activeEnergy, 500);
    expect(summary.expenditure, closeTo(1698.75 + 500, 0.01));
    expect(summary.calorieTarget, closeTo(2198.75, 0.01)); // maintain
  });

  test('falls back to estimated TDEE when no health data', () {
    final summary = DailySummary.compute(
      date: DateTime(2026, 1, 1),
      entries: const [],
      profile: male,
    );
    expect(summary.usingHealthData, isFalse);
    expect(summary.activeEnergy, 0);
    expect(summary.expenditure, closeTo(1698.75 * 1.55, 0.01));
  });

  test('lose goal subtracts 500 from measured expenditure', () {
    final summary = DailySummary.compute(
      date: DateTime(2026, 1, 1),
      entries: const [],
      profile: male.copyWith(goal: Goal.lose),
      energyOut: EnergyOut(activeEnergy: 300, asOf: DateTime(2026, 1, 1, 9)),
    );
    // expenditure = 1698.75 + 300 = 1998.75; lose => -500 => 1498.75
    expect(summary.calorieTarget, closeTo(1498.75, 0.01));
  });

  test('manual target overrides win; computed target stays for reference', () {
    final summary = DailySummary.compute(
      date: DateTime(2026, 1, 1),
      entries: const [],
      profile: male.copyWith(
        calorieGoalOverride: 2000,
        proteinTargetOverride: 150,
        satFatTargetOverride: 25,
      ),
    );
    // Effective targets use the overrides...
    expect(summary.calorieTarget, 2000);
    expect(summary.proteinTarget, 150);
    expect(summary.satFatCap, 25);
    expect(summary.caloriesRemaining, 2000); // nothing eaten
    // ...while the auto-computed target stays available for the reference text.
    expect(summary.computedCalorieTarget, closeTo(1698.75 * 1.55, 0.01));
  });

  test('budget uses full-day BMR even when a device reports partial resting', () {
    final summary = DailySummary.compute(
      date: DateTime(2026, 1, 1),
      entries: const [],
      profile: male, // BMR 1698.75, maintain
      energyOut: EnergyOut(
        activeEnergy: 373,
        restingEnergy: 1411, // measured resting burned so far (partial day)
        asOf: DateTime(2026, 1, 1, 21),
      ),
    );
    // Burn reflects what's actually been spent so far: measured resting + active.
    expect(summary.expenditure, closeTo(1411 + 373, 0.01));
    // Budget is built on a full day's resting (BMR), not the partial measured
    // resting, + the active energy burned.
    expect(summary.calorieTarget, closeTo(1698.75 + 373, 0.01));
    // Calories left follows the budget.
    expect(summary.caloriesRemaining, closeTo(1698.75 + 373, 0.01));
  });
}
