import '../nutrition/nutrition_math.dart';
import 'energy_out.dart';
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
    required this.activeEnergy,
    required this.usingHealthData,
    required this.calorieTarget,
    required this.computedCalorieTarget,
    required this.proteinTarget,
    required this.satFatCap,
  });

  final DateTime date;
  final double consumedCalories;
  final double consumedProtein;
  final double consumedSatFat;

  /// Resting metabolic rate (kcal/day).
  final double bmr;

  /// Measured energy burned so far today (resting + active), shown as "Burn".
  /// The calorie budget is built separately on a full day's resting energy —
  /// see [calorieTarget].
  final double expenditure;

  /// Measured active energy burned (kcal) when [usingHealthData] is true.
  final double activeEnergy;

  /// True when expenditure is BMR + measured active energy (HealthKit),
  /// false when it falls back to the profile estimate.
  final bool usingHealthData;

  final double calorieTarget;

  /// The auto-computed calorie target (budget burn + goal adjustment), ignoring
  /// any manual override — shown as reference in Settings.
  final double computedCalorieTarget;

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
  /// When [energyOut] is provided, the budget uses a full day's resting energy
  /// (BMR) + measured active energy, while [expenditure] reports the actual burn
  /// so far (measured resting + active); otherwise both fall back to the
  /// profile's estimated TDEE.
  factory DailySummary.compute({
    required DateTime date,
    required List<FoodEntry> entries,
    required UserProfile profile,
    EnergyOut? energyOut,
  }) {
    var cal = 0.0, pro = 0.0, sat = 0.0;
    for (final e in entries) {
      cal += e.calories;
      pro += e.proteinG;
      sat += e.satFatG;
    }

    final bmr = NutritionMath.mifflinStJeorBmr(profile);
    // The budget is always a full day's resting energy (BMR) + the active
    // energy burned (measured via Apple Health, or 0 when there's no reading
    // yet / it isn't connected). It stays stable through the day and grows as
    // you move — no activity-multiplier estimate.
    final active = energyOut?.activeEnergy ?? 0;
    final budgetBase = bmr + active;
    // "Burn so far": measured resting to date + active when Health has data,
    // else the resting baseline (BMR).
    final expenditure = energyOut != null
        ? (energyOut.restingEnergy ?? bmr) + active
        : bmr;
    final usingHealth = energyOut != null;

    final computedCal = NutritionMath.calorieTarget(
      expenditure: budgetBase,
      goal: profile.goal,
    );
    final computedProtein = NutritionMath.proteinTargetG(profile);
    final computedSatFat = NutritionMath.satFatCapG(calorieTarget: computedCal);
    return DailySummary(
      date: date,
      consumedCalories: cal,
      consumedProtein: pro,
      consumedSatFat: sat,
      bmr: bmr,
      expenditure: expenditure,
      activeEnergy: active,
      usingHealthData: usingHealth,
      // Calorie target = burn + a goal gap (override, else the goal's default
      // adjustment). Protein / sat-fat overrides are absolute. The computed
      // values stay available (computedCalorieTarget) for the Settings reference.
      calorieTarget: budgetBase +
          (profile.calorieGoalOverride ?? profile.goal.calorieAdjustment),
      computedCalorieTarget: computedCal,
      proteinTarget: profile.proteinTargetOverride ?? computedProtein,
      satFatCap: profile.satFatTargetOverride ?? computedSatFat,
    );
  }
}
