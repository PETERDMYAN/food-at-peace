// Paywall behaviour: a purchase in flight blocks a second tap, shows a clear
// full-sheet "Processing…" state, then a success view with the updated balance
// (so it never feels like "nothing happened"); the hidden 1-Bean pack only
// appears after tapping the paywall title 10×.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/data/iap_service.dart';
import 'package:food_at_peace/src/features/wallet/beans_screen.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:food_at_peace/src/theme/app_theme.dart';

/// Counts buy() calls and resolves after a short delay — the in-flight window in
/// which a second tap must be ignored and the "Processing…" view is visible.
class _CountingIap implements IapService {
  _CountingIap(this.onCredited);
  final void Function(int beans, String productId) onCredited;
  int buyCalls = 0;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<ProductDetails>> products() async => const [];
  @override
  Future<IapResult> buy(String productId) async {
    buyCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final beans = beansForProduct(productId);
    if (beans != null) onCredited(beans, productId);
    return IapResult(IapOutcome.purchased, beans: beans);
  }
  @override
  void dispose() {}
}

Future<_CountingIap> _open(WidgetTester t) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  late _CountingIap iap;
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iapServiceProvider.overrideWith((ref) {
          iap = _CountingIap(
            (beans, productId) =>
                ref.read(beansProvider.notifier).recordPurchase(beans, productId),
          );
          return iap;
        }),
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
  await t.pumpAndSettle();
  await t.tap(find.text('Top up')); // open the paywall
  await t.pumpAndSettle();
  return iap;
}

void main() {
  testWidgets('a second tap on a pack mid-purchase is ignored', (t) async {
    final iap = await _open(t);
    // Two quick taps on the same pack before the first resolves.
    await t.tap(find.text('200 Beans'));
    await t.tap(find.text('200 Beans'));
    await t.pump(const Duration(milliseconds: 400)); // let buy() resolve
    expect(iap.buyCalls, 1);
    await t.pump(const Duration(seconds: 2)); // fire the success auto-close timer
    await t.pumpAndSettle();
  });

  testWidgets('shows a Processing view, then a success view with the balance', (
    t,
  ) async {
    await _open(t);
    await t.tap(find.text('200 Beans'));
    await t.pump(const Duration(milliseconds: 100)); // mid-flight
    // The whole sheet is now an unmistakable processing state — not a tiny
    // per-tile spinner — and the packs are gone.
    expect(find.textContaining('Processing'), findsOneWidget);
    expect(find.text('200 Beans'), findsNothing);

    await t.pump(const Duration(milliseconds: 400)); // buy() resolves -> success
    expect(find.textContaining('Added'), findsOneWidget); // "Added 200 Beans"
    expect(find.textContaining('New balance'), findsOneWidget);

    await t.pump(const Duration(seconds: 2)); // auto-close
    await t.pumpAndSettle();
  });

  testWidgets('hidden 1-Bean pack appears only after 10 title taps', (t) async {
    await _open(t);
    expect(find.text('1 Beans'), findsNothing); // hidden by default

    for (var i = 0; i < 10; i++) {
      await t.tap(find.text('Top up Beans')); // the paywall title
    }
    await t.pumpAndSettle();
    expect(find.text('1 Beans'), findsOneWidget); // revealed

    // Buying it credits one Bean locally (100 welcome grant -> 101); the sheet
    // shows success, then auto-closes back to the wallet showing 101.
    await t.tap(find.text('1 Beans'));
    await t.pump(const Duration(seconds: 2)); // buy + success view + auto-close
    await t.pumpAndSettle();
    expect(find.text('101'), findsOneWidget);
  });
}
