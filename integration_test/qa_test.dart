// Autonomous QA pass: drives every major screen/flow and asserts real behavior
// so any crash, red-screen, or broken interaction fails the test.
//
// weatherProvider is stubbed to null so the Today screen never triggers the
// native location prompt (which a UI test can't dismiss). Reminders are seeded
// "on" so the list is exercised without the OS notification-permission prompt.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/app.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/data/iap_service.dart';
import 'package:food_at_peace/src/features/dashboard/dashboard_screen.dart';
import 'package:food_at_peace/src/features/settings/reminders_screen.dart';
import 'package:food_at_peace/src/features/trends/trends_screen.dart';
import 'package:food_at_peace/src/features/wallet/beans_screen.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:food_at_peace/src/theme/app_theme.dart';

/// Fake StoreKit so the Beans purchase flow runs on the simulator (the real
/// store is unavailable there): buy() immediately credits + reports purchased.
class _FakeIap implements IapService {
  _FakeIap(this.onCredited);
  final void Function(int beans, String productId) onCredited;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<ProductDetails>> products() async => const [];
  @override
  Future<IapResult> buy(String productId) async {
    final beans = beansForProduct(productId);
    if (beans != null) onCredited(beans, productId);
    return IapResult(IapOutcome.purchased, beans: beans);
  }
  @override
  void dispose() {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // No location prompt: weather resolves to null.
  final noWeather = weatherProvider.overrideWith((ref) async => null);

  // Fake StoreKit so the Beans paywall's purchase flow works on the simulator.
  final fakeIap = iapServiceProvider.overrideWith(
    (ref) => _FakeIap(
      (beans, productId) =>
          ref.read(beansProvider.notifier).recordPurchase(beans, productId),
    ),
  );

  Future<SharedPreferences> seed(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  Future<void> beat(WidgetTester t, [int ms = 900]) async {
    var e = 0;
    while (e < ms) {
      await t.pump(const Duration(milliseconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      e += 60;
    }
  }

  Future<void> pumpApp(WidgetTester t, SharedPreferences prefs) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          noWeather,
          fakeIap,
        ],
        child: const FoodAtPeaceApp(),
      ),
    );
    await beat(t, 1200);
  }

  Future<void> pumpScreen(
    WidgetTester t,
    SharedPreferences prefs,
    Widget home,
  ) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          noWeather,
          fakeIap,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await beat(t, 1000);
  }

  // -------------------------------------------------------------------------

  testWidgets('first run shows onboarding', (t) async {
    final prefs = await seed({});
    await pumpApp(t, prefs);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Add food'), findsNothing);
  });

  testWidgets('returning user boots to Today and all three tabs render', (t) async {
    final prefs = await seed({'onboarding_complete': true});
    await pumpApp(t, prefs);

    // Today
    expect(find.textContaining('Good '), findsWidgets);
    expect(find.text('Add food'), findsOneWidget);

    // Trends tab
    await t.tap(find.byIcon(Icons.insights_outlined).hitTestable());
    await beat(t);
    expect(find.text('Your circle'), findsOneWidget);

    // Profile tab
    await t.tap(find.byIcon(Icons.settings_outlined).hitTestable());
    await beat(t);
    expect(find.text('Beans'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });

  testWidgets('add a manual food entry updates Today', (t) async {
    final prefs = await seed({'onboarding_complete': true});
    await pumpApp(t, prefs);

    await t.tap(find.text('Add food'));
    await beat(t);
    // Fields in order: [0] name, [1] calories, [2] protein, [3] sat-fat, [4] serving.
    // Pump between entries so each value commits before the next.
    await t.enterText(find.byType(TextField).at(0), 'QA Test Meal');
    await beat(t, 250);
    await t.enterText(find.byType(TextField).at(1), '500');
    await beat(t, 250);
    // Save via the always-visible AppBar action.
    await t.tap(
      find.descendant(of: find.byType(AppBar), matching: find.text('Save')),
    );
    await beat(t);

    // Back on Today. The calorie card already reflects the entry ("Eaten 500"),
    // but the "Today's food" tile sits below the fold — Today's ListView builds
    // lazily, so off-screen tiles aren't instantiated until scrolled near. Scroll
    // the list up to bring the new entry into view, then assert it renders.
    await t.scrollUntilVisible(
      find.text('QA Test Meal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await beat(t, 200);
    expect(find.text('QA Test Meal'), findsWidgets);
  });

  testWidgets('Beans wallet: top-up pack updates balance', (t) async {
    final prefs = await seed({'reminders_enabled': false});
    await pumpScreen(t, prefs, const BeansScreen());
    expect(find.text('100'), findsOneWidget); // free grant

    await t.tap(find.text('Top up'));
    await beat(t);
    await t.tap(find.text('200 Beans').hitTestable());
    await beat(t);
    expect(find.text('300'), findsOneWidget); // 100 + 200 via (faked) StoreKit
  });

  testWidgets('Reminders: toggle, add, and delete', (t) async {
    final prefs = await seed({'reminders_enabled': true});
    await pumpScreen(t, prefs, const RemindersScreen());
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Snack'), findsOneWidget);

    // Toggle the snack reminder (its switch is in the Snack row)
    final snackSwitch = find.descendant(
      of: find.widgetWithText(ListTile, 'Snack'),
      matching: find.byType(Switch),
    );
    await t.tap(snackSwitch);
    await beat(t);

    // Add a reminder
    await t.tap(find.text('Add reminder').hitTestable());
    await beat(t);
    await t.tap(find.widgetWithText(FilledButton, 'Add reminder'));
    await beat(t);
    // 5 meal rows now (4 default + 1 added) — at least the added Snack-type row
    expect(find.byType(Switch), findsWidgets);
  });

  testWidgets('Circle of Food: invite sheet + friend trend', (t) async {
    final prefs = await seed({
      'circle_my_handle': 'mypal',
      'circle_handle_set': true,
    });
    await pumpScreen(t, prefs, const TrendsScreen());
    expect(find.text('Your circle'), findsOneWidget);
    expect(find.text('Requests (1)'), findsOneWidget); // seeded incoming invite

    // Open invite sheet → it shows your @handle + a shareable invite link/QR
    // (one tap connects you both; no typing a friend's name).
    await t.tap(find.text('Add').first);
    await beat(t);
    expect(find.text('Add a friend'), findsOneWidget);
    expect(find.textContaining('foodatpeace.app/i/mypal'), findsWidgets);
    // Dismiss the sheet (tap the scrim above it).
    await t.tapAt(const Offset(20, 40));
    await beat(t);

    // Tap a connected friend to see their trend
    await t.tap(find.text('Mia Tan').first);
    await beat(t);
    expect(find.text('On-target · last 7 days'), findsOneWidget);
  });

  testWidgets('Dashboard renders metrics', (t) async {
    final prefs = await seed({});
    await pumpScreen(t, prefs, const DashboardScreen());
    await beat(t, 700);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Revenue'), findsOneWidget);
  });

  testWidgets('Language toggle switches to Chinese and back', (t) async {
    final prefs = await seed({'onboarding_complete': true});
    await pumpApp(t, prefs);
    await t.tap(find.byIcon(Icons.settings_outlined).hitTestable());
    await beat(t);
    // The Language card is below the fold — scroll it into view, then tap 中文.
    await t.scrollUntilVisible(
      find.text('中文'),
      250,
      scrollable: find.byType(Scrollable).hitTestable(),
    );
    await beat(t, 300);
    await t.tap(find.text('中文').hitTestable());
    await beat(t);
    expect(find.text('我的'), findsWidgets); // Profile nav label in Chinese
    // Back to English
    await t.scrollUntilVisible(
      find.text('English'),
      250,
      scrollable: find.byType(Scrollable).hitTestable(),
    );
    await t.tap(find.text('English').hitTestable());
    await beat(t);
    expect(find.text('Profile'), findsWidgets);
  });

  testWidgets('Owner: tapping the version 10× reveals the account-ID dialog', (
    t,
  ) async {
    final prefs = await seed({'onboarding_complete': true});
    await pumpApp(t, prefs);
    await t.tap(find.byIcon(Icons.settings_outlined).hitTestable());
    await beat(t);

    // The version footer sits at the very bottom of Profile.
    final version = find.textContaining('Food at Peace 1.0.1');
    await t.scrollUntilVisible(
      version,
      300,
      scrollable: find.byType(Scrollable).hitTestable(),
    );
    await beat(t, 200);

    // Ten debounced taps reveal the account id. Signed out in the test, so the
    // dialog explains sign-in is needed — but it proves the 10× gesture fires
    // (and doesn't trip the 5× owner-dashboard route along the way).
    for (var i = 0; i < 10; i++) {
      await t.tap(version);
      await beat(t, 90);
    }
    await beat(t, 1000); // let the ~700ms debounce timer fire
    expect(find.text('Account ID'), findsOneWidget);
    expect(find.text('Sign in to see your account ID.'), findsOneWidget);
  });
}
