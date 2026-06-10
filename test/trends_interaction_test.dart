import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/data/food_repository.dart';
import 'package:food_at_peace/src/features/trends/trends_screen.dart';
import 'package:food_at_peace/src/models/food_entry.dart';
import 'package:food_at_peace/src/models/meal_type.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:food_at_peace/src/theme/app_theme.dart';

void main() {
  testWidgets('tapping the Trends chart reveals a day callout with value + target',
      (tester) async {
    // Tall surface so all three charts lay out fully.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Seed every day in the window with the same calories, so any bar the tap
    // lands on yields a deterministic callout value.
    final today = DateTime.now();
    final entries = [
      for (var i = 0; i < 30; i++)
        FoodEntry(
          id: 'e$i',
          name: 'Meal',
          calories: 1234,
          proteinG: 50,
          satFatG: 5,
          mealType: MealType.lunch,
          timestamp: DateTime(today.year, today.month, today.day)
              .subtract(Duration(days: i))
              .add(const Duration(hours: 12)),
          updatedAt: today,
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          foodRepositoryProvider.overrideWithValue(
            InMemoryFoodRepository(entries),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TrendsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No callout until the user interacts (the chart shows no inline values).
    expect(find.text('1234 kcal'), findsNothing);

    // Tap inside the Calories chart's plot area.
    final caloriesTitle = find.text('Calories');
    expect(caloriesTitle, findsOneWidget);
    final titleCenter = tester.getCenter(caloriesTitle);
    await tester.tapAt(Offset(600, titleCenter.dy + 100));
    await tester.pumpAndSettle();

    // Callout shows the day's actual value and the target.
    expect(find.text('1234 kcal'), findsOneWidget);
    expect(find.textContaining('Target'), findsWidgets);
  });
}
