// Screen-recordable **Beans top-up** walkthrough. Runs on the simulator with a
// faked StoreKit (the real store can't run on a sim):
//   1. open the wallet on the 100-Bean welcome grant
//   2. Top up → pick the 100-Bean pack → a spinner shows while the purchase is in
//      flight (the buy feels instant-but-busy, not frozen) → balance 100 → 200
//   3. reopen Top up and tap the title 10× to reveal the hidden 1-Bean pack
//      (a dev top-up shortcut) → buy it → balance 200 → 201
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/data/iap_service.dart';
import 'package:food_at_peace/src/features/wallet/beans_screen.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:food_at_peace/src/theme/app_theme.dart';

/// Fake StoreKit. The ~1.2s delay stands in for Apple's payment sheet so the
/// in-flight spinner is clearly visible, then it credits the Beans + reports
/// purchased (the same hook the live StoreKitIapService fires).
class _FakeIap implements IapService {
  _FakeIap(this.onCredited);
  final void Function(int beans, String productId) onCredited;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<ProductDetails>> products() async => const [];
  @override
  Future<IapResult> buy(String productId) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final beans = beansForProduct(productId);
    if (beans != null) onCredited(beans, productId);
    return IapResult(IapOutcome.purchased, beans: beans);
  }
  @override
  void dispose() {}
}

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

  testWidgets('Beans top-up + hidden pack walkthrough', (t) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    final fakeIap = iapServiceProvider.overrideWith(
      (ref) => _FakeIap(
        (beans, productId) =>
            ref.read(beansProvider.notifier).recordPurchase(beans, productId),
      ),
    );

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          fakeIap,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BeansScreen(),
        ),
      ),
    );
    await beat(t, 1800);

    // ── Wallet opens on the 100-Bean welcome grant ──────────────────────────
    expect(find.text('100'), findsOneWidget);
    await beat(t, 1500);

    // ── Top up → 100-Bean pack → spinner while buying → balance 200 ─────────
    await t.tap(find.text('Top up'));
    await beat(t, 2000);
    expect(find.text('100 Beans'), findsWidgets);
    await t.tap(find.text('100 Beans').hitTestable());
    await beat(t, 2600); // ~1.2s spinner, then the sheet closes + balance updates
    expect(find.text('200'), findsOneWidget);
    await beat(t, 2000);

    // ── Reopen Top up, tap the title 10× to reveal the hidden 1-Bean pack ────
    await t.tap(find.text('Top up'));
    await beat(t, 1600);
    for (var i = 0; i < 10; i++) {
      await t.tap(find.text('Top up Beans'));
      await beat(t, 160);
    }
    await beat(t, 1400);
    expect(find.text('1 Beans'), findsOneWidget); // hidden pack revealed
    await beat(t, 1600);
    await t.tap(find.text('1 Beans').hitTestable());
    await beat(t, 2200);
    expect(find.text('201'), findsOneWidget); // 200 + the 1-Bean pack
    await beat(t, 2600);
  });
}
