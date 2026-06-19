// Focused capture for the Beans paywall purchase states (before/after the IAP
// feedback fix). Runs on a booted simulator; a tiny shotserver on 127.0.0.1:8099
// grabs the real device screen (so fonts render). A slow fake IAP holds the
// in-flight state long enough to capture it.
//
//   flutter test integration_test/iap_shots_test.dart -d <sim-udid>
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/data/iap_service.dart';
import 'package:food_at_peace/src/features/wallet/beans_screen.dart';
import 'package:food_at_peace/src/models/bean_transaction.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:food_at_peace/src/theme/app_theme.dart';

const _shotPort = int.fromEnvironment('SHOT_PORT', defaultValue: 8099);

Future<void> beat(WidgetTester t, int ms) async {
  var e = 0;
  while (e < ms) {
    await t.pump(const Duration(milliseconds: 80));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    e += 80;
  }
}

/// Pump until [f] matches (or [maxMs] elapses) — robust to the live binding's
/// real-clock timing, so we shoot a state the instant it appears.
Future<void> waitFor(WidgetTester t, Finder f, {int maxMs = 5000}) async {
  var e = 0;
  while (e < maxMs && f.evaluate().isEmpty) {
    await t.pump(const Duration(milliseconds: 60));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    e += 60;
  }
}

Future<void> shot(WidgetTester t, String name, {int settle = 900}) async {
  await beat(t, settle);
  try {
    final c = HttpClient();
    final req = await c.getUrl(Uri.parse('http://127.0.0.1:$_shotPort/shot/$name'));
    final resp = await req.close();
    await resp.drain();
    c.close();
  } catch (_) {}
  await beat(t, 300);
}

/// Holds the purchase in flight ~1.6s so the in-flight state can be captured,
/// then credits + reports purchased.
class _SlowIap implements IapService {
  _SlowIap(this.onCredited);
  final void Function(int beans, String productId) onCredited;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<ProductDetails>> products() async => const [];
  @override
  Future<IapResult> buy(String productId) async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final beans = beansForProduct(productId);
    if (beans != null) onCredited(beans, productId);
    return IapResult(IapOutcome.purchased, beans: beans);
  }
  @override
  void dispose() {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('beans paywall purchase states', (t) async {
    final grant = BeanTransaction(
      id: 'grant1',
      type: BeanTxnType.signupGrant,
      amount: 100,
      timestamp: DateTime(2026, 6, 1, 9, 41),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'beans_granted': true,
      'beans_ledger_v1': jsonEncode([grant.toJson()]),
    });
    final prefs = await SharedPreferences.getInstance();

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iapServiceProvider.overrideWith(
            (ref) => _SlowIap(
              (beans, productId) => ref
                  .read(beansProvider.notifier)
                  .recordPurchase(beans, productId),
            ),
          ),
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
    await beat(t, 1200);

    // Open the paywall.
    await t.tap(find.text('Top up'));
    await beat(t, 900);
    await shot(t, 'iap-01-packs');

    // Tap a pack -> capture the in-flight processing state the moment it shows
    // (buy() holds ~1.1s, so there's ample time).
    await t.tap(find.text('200 Beans'));
    await waitFor(t, find.textContaining('Processing'));
    await shot(t, 'iap-02-processing', settle: 120);

    // buy() resolves -> the success view appears (balance already updated);
    // shoot it immediately, before its ~1.5s auto-close.
    await waitFor(t, find.textContaining('Added'));
    await shot(t, 'iap-03-success', settle: 0);

    // Let the auto-close fire so no Timer is left pending.
    await beat(t, 2400);
    await t.pumpAndSettle();
  });
}
