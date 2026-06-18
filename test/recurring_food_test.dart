// "Take daily" (recurring) entries: logged once, they count on every day from
// their start onward (a supplement), while one-off entries stay on their day.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/models/food_entry.dart';
import 'package:food_at_peace/src/models/meal_type.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodEntry _e(String id, DateTime ts, {bool recurring = false}) => FoodEntry(
  id: id,
  name: id,
  calories: 10,
  proteinG: 1,
  satFatG: 0,
  mealType: MealType.snack,
  timestamp: ts,
  recurring: recurring,
);

void main() {
  test('recurring round-trips through JSON; defaults to false', () {
    final r = FoodEntry.fromJson(_e('x', DateTime(2026, 6, 18), recurring: true).toJson());
    expect(r.recurring, isTrue);
    final legacy = _e('y', DateTime(2026, 6, 18)).toJson()..remove('recurring');
    expect(FoodEntry.fromJson(legacy).recurring, isFalse);
  });

  test('a recurring entry shows every day from its start; one-off only its day',
      () async {
    final today = dateOnly(DateTime.now());
    final daily = _e('daily', today.subtract(const Duration(days: 3)), recurring: true);
    final oneOff = _e('oneoff', today);

    SharedPreferences.setMockInitialValues({
      'food_entries_v1': jsonEncode([daily.toJson(), oneOff.toJson()]),
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);

    Set<String> idsOn(DateTime d) {
      c.read(selectedDateProvider.notifier).set(d);
      return c.read(entriesForSelectedDayProvider).map((e) => e.id).toSet();
    }

    // Today: both the daily and today's one-off.
    expect(idsOn(today), {'daily', 'oneoff'});
    // Yesterday: the daily counts, the one-off does not.
    expect(idsOn(today.subtract(const Duration(days: 1))), {'daily'});
    // Before the daily started: neither.
    expect(idsOn(today.subtract(const Duration(days: 4))), <String>{});
  });
}
