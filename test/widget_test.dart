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

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const FoodAtPeaceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Unique chrome on the Today screen.
    expect(find.text('Food at Peace'), findsOneWidget);
    expect(find.text('Add food'), findsOneWidget);

    // Navigation destinations (labels may also appear in off-stage app bars).
    expect(find.text('Today'), findsWidgets);
    expect(find.text('History'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    // Empty state before anything is logged.
    expect(find.textContaining('Nothing logged yet'), findsOneWidget);
  });
}
