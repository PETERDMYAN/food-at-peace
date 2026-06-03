import '../nutrition/nutrition_math.dart';
import 'food_entry.dart';
import 'user_profile.dart';

/// The computed picture for a single day: what was consumed, the targets,
/// and how much quota is left for calories, protein, and saturated fat.
class DailySummary {
  const DailySummary({
    required this.date,
    required this.consumedCalories,
    required this.consumedProtein,
    required this.consumedSatFat,
    required this.bmr,
    required this.expenditure,
    required this.calorieTarget,
    required this.proteinTarget,
    required this.satFatCap,
  });

  final DateTime date;
  final double consumedCalories;
  final double consumedProtein;
  final double consumedSatFat;

  /// Resting metabolic rate (kcal/day).
  final double bmr;

  /// Total energy expenditure (kcal/day). Estimated in Phase 1.
  final double expenditure;

  final double calorieTarget;
  final double proteinTarget;
  final double satFatCap;

  /// How much you can still eat / still need. Negative = over budget.
  double get caloriesRemaining => calorieTarget - consumedCalories;
  double get proteinRemaining => proteinTarget - consumedProtein;
  double get satFatRemaining => satFatCap - consumedSatFat;

  bool get isOverCalories => consumedCalories > calorieTarget;
  bool get isOverSatFat => consumedSatFat > satFatCap;
  bool get hitProtein => consumedProtein >= proteinTarget;

  double get calorieProgress => _progress(consumedCalories, calorieTarget);
  double get proteinProgress => _progress(consumedProtein, proteinTarget);
  double get satFatProgress => _progress(consumedSatFat, satFatCap);

  static double _progress(double value, double target) {
    if (target <= 0) return 0;
    return (value / target).clamp(0.0, 1.0);
  }

  /// Builds a summary from a day's [entries] and the user's [profile].
  factory DailySummary.compute({
    required DateTime date,
    required List<FoodEntry> entries,
    required UserProfile profile,
  }) {
    var cal = 0.0, pro = 0.0, sat = 0.0;
    for (final e in entries) {
      cal += e.calories;
      pro += e.proteinG;
      sat += e.satFatG;
    }
    final bmr = NutritionMath.mifflinStJeorBmr(profile);
    final tdee = NutritionMath.estimatedTdee(profile);
    final calTarget =
        NutritionMath.calorieTarget(expenditure: tdee, goal: profile.goal);
    return DailySummary(
      date: date,
      consumedCalories: cal,
      consumedProtein: pro,
      consumedSatFat: sat,
      bmr: bmr,
      expenditure: tdee,
      calorieTarget: calTarget,
      proteinTarget: NutritionMath.proteinTargetG(profile),
      satFatCap: NutritionMath.satFatCapG(calorieTarget: calTarget),
    );
  }
}
