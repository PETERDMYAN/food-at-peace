import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/models/daily_summary.dart';
import 'package:food_at_peace/src/models/food_entry.dart';
import 'package:food_at_peace/src/models/meal_type.dart';
import 'package:food_at_peace/src/models/user_profile.dart';
import 'package:food_at_peace/src/nutrition/nutrition_math.dart';

void main() {
  const male = UserProfile(
    sex: Sex.male,
    age: 30,
    heightCm: 175,
    weightKg: 75,
    activity: ActivityLevel.moderate,
    goal: Goal.maintain,
  );

  group('Mifflin-St Jeor BMR', () {
    test('male example', () {
      // 10*75 + 6.25*175 - 5*30 + 5 = 1698.75
      expect(NutritionMath.mifflinStJeorBmr(male), closeTo(1698.75, 0.01));
    });

    test('female is 166 kcal lower than male for same body', () {
      final female = male.copyWith(sex: Sex.female);
      final diff = NutritionMath.mifflinStJeorBmr(male) -
          NutritionMath.mifflinStJeorBmr(female);
      expect(diff, closeTo(166, 0.01)); // +5 vs -161
    });
  });

  test('TDEE applies the activity multiplier', () {
    expect(
      NutritionMath.estimatedTdee(male),
      closeTo(1698.75 * 1.55, 0.01),
    );
  });

  group('calorie target by goal', () {
    test('maintain == expenditure', () {
      expect(NutritionMath.calorieTarget(expenditure: 2000, goal: Goal.maintain),
          2000);
    });
    test('lose subtracts 500', () {
      expect(NutritionMath.calorieTarget(expenditure: 2000, goal: Goal.lose),
          1500);
    });
    test('gain adds 400', () {
      expect(NutritionMath.calorieTarget(expenditure: 2000, goal: Goal.gain),
          2400);
    });
  });

  test('protein target is 1.6 g/kg', () {
    expect(NutritionMath.proteinTargetG(male), closeTo(120, 0.01));
  });

  test('saturated-fat cap is 10% of calories / 9', () {
    expect(NutritionMath.satFatCapG(calorieTarget: 1800), closeTo(20, 0.01));
  });

  group('DailySummary.compute', () {
    FoodEntry entry(double cal, double pro, double sat) => FoodEntry(
          id: '$cal-$pro-$sat',
          name: 'x',
          calories: cal,
          proteinG: pro,
          satFatG: sat,
          mealType: MealType.lunch,
          timestamp: DateTime(2026, 1, 1),
        );

    test('sums entries and computes remaining', () {
      final summary = DailySummary.compute(
        date: DateTime(2026, 1, 1),
        entries: [entry(500, 30, 5), entry(300, 10, 2)],
        profile: male,
      );
      expect(summary.consumedCalories, 800);
      expect(summary.consumedProtein, 40);
      expect(summary.consumedSatFat, 7);
      expect(summary.proteinRemaining, closeTo(80, 0.01)); // 120 - 40
      expect(summary.caloriesRemaining,
          closeTo(summary.calorieTarget - 800, 0.01));
    });

    test('empty day has zero consumed and full quota remaining', () {
      final summary = DailySummary.compute(
        date: DateTime(2026, 1, 1),
        entries: const [],
        profile: male,
      );
      expect(summary.consumedCalories, 0);
      expect(summary.caloriesRemaining, summary.calorieTarget);
      expect(summary.calorieProgress, 0);
    });
  });
}
