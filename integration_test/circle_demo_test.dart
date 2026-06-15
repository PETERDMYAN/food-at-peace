// Screen-recordable walkthrough of "Circle of Food": the circle strip on Trends,
// a friend's privacy-gated trend, accepting a request, and the new "your @handle"
// flow (set / shown with copy). Runs on the offline/seeded path so it works on a
// simulator (the signed-in backend path needs a real Apple ID).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/app.dart';
import 'package:food_at_peace/src/providers/providers.dart';

Future<void> beat(WidgetTester t, int ms) async {
  var e = 0;
  while (e < ms) {
    await t.pump(const Duration(milliseconds: 60));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    e += 60;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final noWeather = weatherProvider.overrideWith((ref) async => null);

  testWidgets('Circle of Food walkthrough', (t) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs), noWeather],
        child: const FoodAtPeaceApp(),
      ),
    );
    await beat(t, 1600);

    // → Trends tab: the "Your circle" strip (seeded friends + a request).
    await t.tap(find.byIcon(Icons.insights_outlined).hitTestable());
    await beat(t, 1700);
    expect(find.text('Your circle'), findsOneWidget);

    // The invite sheet → set your own @handle, then invite a friend by handle.
    await t.tap(find.text('Add').first);
    await beat(t, 1400);
    await t.tap(find.text('Set your handle').hitTestable());
    await beat(t, 1200);
    await t.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'peteryan',
    );
    await beat(t, 900);
    await t.tap(find.widgetWithText(FilledButton, 'Save').hitTestable());
    await beat(t, 2000);
    expect(find.text('@peteryan'), findsOneWidget); // your handle, with copy + edit

    // Invite someone by their handle (closes the sheet). The sheet now also
    // shows the QR/share card, so scroll the manual field + button into view.
    await t.ensureVisible(find.byType(TextField).first);
    await beat(t, 600);
    await t.enterText(find.byType(TextField).first, 'alexlim');
    await beat(t, 800);
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Send invite'));
    await beat(t, 400);
    await t.tap(find.widgetWithText(FilledButton, 'Send invite').hitTestable());
    await beat(t, 1800);

    // A pending request → accept it.
    await t.tap(find.text('Requests (1)'));
    await beat(t, 1600);
    await t.tap(find.text('Accept').hitTestable());
    await beat(t, 1600);
    await t.pageBack();
    await beat(t, 1200);

    // A connected friend's privacy-gated trend …
    await t.tap(find.text('Mia Tan').first);
    await beat(t, 2600);
    expect(find.text('On-target · last 7 days'), findsOneWidget);

    // … then remove them from the circle (confirm dialog).
    await t.tap(find.widgetWithText(TextButton, 'Remove from circle').hitTestable());
    await beat(t, 1100);
    await t.tap(find.widgetWithText(FilledButton, 'Remove from circle').hitTestable());
    await beat(t, 1700);
    expect(find.text('Mia Tan'), findsNothing);
  });
}
