import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/app.dart';
import 'package:food_at_peace/src/providers/providers.dart';

void main() {
  testWidgets('app boots to the Today dashboard', (tester) async {
    // A tall surface so the whole scrolling dashboard (incl. the empty state)
    // is laid out, rather than lazily skipped below the default 600px fold.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A returning user has already onboarded → boots straight to the dashboard.
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const FoodAtPeaceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Unique chrome on the Today screen: the greeting header + the FAB.
    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('Add food'), findsOneWidget);

    // Navigation destinations (labels may also appear in off-stage app bars).
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Trends'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    // Empty state before anything is logged.
    expect(find.textContaining('Nothing logged yet'), findsOneWidget);
  });

  testWidgets('first run shows onboarding (not the dashboard)', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // No onboarding flag → first run → onboarding gate.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const FoodAtPeaceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Add food'), findsNothing);
  });
}
