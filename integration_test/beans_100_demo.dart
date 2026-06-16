// Screen-recordable walkthrough of an in-app **100-Bean recharge**. Runs on the
// simulator with a faked StoreKit (the real store can't run on a sim): open the
// wallet on the 100-Bean welcome grant, tap "Top up", pick the 100-Bean pack,
// then watch the balance jump 100 → 200 and the purchase land in the history.
//
// The one step this can't show is Apple's native payment sheet (Face ID /
// password) — that only appears on a physical device in the sandbox. Here the
// faked store stands in for that moment and reports the consumable as purchased,
// which is exactly what the production StoreKit path does
// (`StoreKitIapService` → `recordPurchase`).
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

/// Fake StoreKit so the purchase resolves on the simulator. The short delay
/// stands in for the beat where Apple's payment sheet would be on a real
/// device; then it credits the Beans and reports `purchased` — the same hook
/// the live `StoreKitIapService` fires from `purchaseStream`.
class _FakeIap implements IapService {
  _FakeIap(this.onCredited);
  final void Function(int beans, String productId) onCredited;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<ProductDetails>> products() async => const [];
  @override
  Future<IapResult> buy(String productId) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final beans = beansForProduct(productId);
    if (beans != null) onCredited(beans, productId);
    return IapResult(IapOutcome.purchased, beans: beans);
  }
  @override
  void dispose() {}
}

/// Pump for [ms] real milliseconds so animations/toasts render in the recording.
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

  testWidgets('Recharge 100 Beans walkthrough', (t) async {
    // Fresh wallet → the 100-Bean welcome grant lands on first build.
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

    // ── Step 1 — the wallet opens on the 100-Bean welcome grant ──────────────
    expect(find.text('100'), findsOneWidget); // balance hero
    expect(find.text('Welcome bonus'), findsOneWidget); // grant row in history
    await beat(t, 1900); // hold the starting balance

    // ── Step 2 — tap "Top up" → the paywall (Bean packs + prices) slides up ──
    await t.tap(find.text('Top up'));
    await beat(t, 2300); // hold the paywall so every pack/price is readable
    expect(find.text('100 Beans'), findsWidgets); // the pack we'll buy

    // ── Step 3 — pick the 100-Bean pack ──────────────────────────────────────
    // On a device this is where Apple's payment sheet (Face ID / password)
    // appears; the faked store stands in for it, then reports `purchased`.
    await t.tap(find.text('100 Beans').hitTestable());
    await beat(t, 2400); // sheet closes, toast confirms, balance updates

    // ── Step 4 — balance jumped 100 → 200; the purchase is in the history ────
    expect(find.text('200'), findsOneWidget); // 100 grant + 100 bought
    await beat(t, 1400);
    await t.ensureVisible(find.text('Top-up').first);
    expect(find.text('Top-up'), findsWidgets);
    await beat(t, 2800); // hold the final state for the recording
  });
}
