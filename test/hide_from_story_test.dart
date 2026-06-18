// Deleting a page from the photo "Food story" must NOT delete the food-log entry
// — it only hides it from the story (hiddenFromStory), so Today/Trends keep it.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/models/food_entry.dart';
import 'package:food_at_peace/src/models/meal_type.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('hiddenFromStory round-trips; defaults to false', () {
    final e = FoodEntry(
      id: 'a',
      name: 'a',
      calories: 1,
      proteinG: 0,
      satFatG: 0,
      mealType: MealType.snack,
      timestamp: DateTime(2026, 6, 18),
      hiddenFromStory: true,
    );
    expect(FoodEntry.fromJson(e.toJson()).hiddenFromStory, isTrue);
    final legacy = e.toJson()..remove('hiddenFromStory');
    expect(FoodEntry.fromJson(legacy).hiddenFromStory, isFalse);
  });

  test('hideFromStory keeps the log entry (not a tombstone)', () async {
    final today = dateOnly(DateTime.now());
    final entry = FoodEntry(
      id: 'meal1',
      name: 'Salmon poke bowl',
      calories: 540,
      proteinG: 38,
      satFatG: 5,
      mealType: MealType.lunch,
      timestamp: today.add(const Duration(hours: 12)),
    );
    SharedPreferences.setMockInitialValues({
      'food_entries_v1': jsonEncode([entry.toJson()]),
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);

    await c.read(foodEntriesProvider.notifier).hideFromStory('meal1');

    final stored = c.read(foodEntriesProvider).firstWhere((e) => e.id == 'meal1');
    expect(stored.deleted, isFalse, reason: 'the log entry must NOT be deleted');
    expect(stored.hiddenFromStory, isTrue);
    // Still counted in the day's log / totals.
    final logIds = c.read(entriesForSelectedDayProvider).map((e) => e.id);
    expect(logIds, contains('meal1'));
  });
}
