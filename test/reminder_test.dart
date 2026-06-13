import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/models/meal_type.dart';
import 'package:food_at_peace/src/models/reminder.dart';

void main() {
  group('Reminder.defaults', () {
    test('are breakfast 8:00, lunch 12:00, dinner 19:00, snack 22:00', () {
      final d = Reminder.defaults();
      expect(d.map((r) => (r.meal, r.hour, r.minute)).toList(), [
        (MealType.breakfast, 8, 0),
        (MealType.lunch, 12, 0),
        (MealType.dinner, 19, 0),
        (MealType.snack, 22, 0),
      ]);
    });

    test('have the three meals on and the late snack off', () {
      final byMeal = {for (final r in Reminder.defaults()) r.meal: r.enabled};
      expect(byMeal[MealType.breakfast], isTrue);
      expect(byMeal[MealType.lunch], isTrue);
      expect(byMeal[MealType.dinner], isTrue);
      expect(byMeal[MealType.snack], isFalse);
    });
  });

  test('JSON round-trips all fields', () {
    const r = Reminder(
      id: 'r1',
      meal: MealType.dinner,
      hour: 18,
      minute: 30,
      enabled: false,
    );
    final back = Reminder.fromJson(r.toJson());
    expect(back.id, r.id);
    expect(back.meal, r.meal);
    expect(back.hour, r.hour);
    expect(back.minute, r.minute);
    expect(back.enabled, r.enabled);
  });

  test('copyWith changes only the given fields', () {
    const r = Reminder(id: 'r1', meal: MealType.lunch, hour: 12, minute: 0);
    final moved = r.copyWith(hour: 13, minute: 15, enabled: false);
    expect(moved.id, 'r1');
    expect(moved.meal, MealType.lunch);
    expect(moved.hour, 13);
    expect(moved.minute, 15);
    expect(moved.enabled, isFalse);
  });
}
