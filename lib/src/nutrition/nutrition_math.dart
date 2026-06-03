import '../models/user_profile.dart';

/// Pure nutrition calculations. No Flutter, no I/O — fully unit-testable.
///
/// Phase 1 estimates energy expenditure from the profile (BMR × activity).
/// Phase 2 will replace [estimatedTdee] with measured basal + active energy
/// from HealthKit (which includes Garmin data via Apple Health).
class NutritionMath {
  NutritionMath._();

  /// Grams of protein per kg of bodyweight (a common 1.6 g/kg target).
  static const double proteinPerKg = 1.6;

  /// Saturated fat capped at 10% of calories (US Dietary Guidelines).
  static const double satFatCaloriePct = 0.10;

  /// Energy density of fat.
  static const double kcalPerGramFat = 9.0;

  /// Mifflin-St Jeor resting metabolic rate (kcal/day).
  static double mifflinStJeorBmr(UserProfile p) {
    final base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age;
    return base + (p.sex == Sex.male ? 5 : -161);
  }

  /// Estimated total daily energy expenditure = BMR × activity multiplier.
  static double estimatedTdee(UserProfile p) =>
      mifflinStJeorBmr(p) * p.activity.multiplier;

  /// Daily calorie intake target = expenditure + goal adjustment.
  static double calorieTarget({
    required double expenditure,
    required Goal goal,
  }) =>
      expenditure + goal.calorieAdjustment;

  /// Daily protein target in grams.
  static double proteinTargetG(UserProfile p) => proteinPerKg * p.weightKg;

  /// Daily saturated-fat cap in grams, derived from the calorie target.
  static double satFatCapG({required double calorieTarget}) =>
      (satFatCaloriePct * calorieTarget) / kcalPerGramFat;
}
