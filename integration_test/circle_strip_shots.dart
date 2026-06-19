// Capture the Circle strip states after the UX pass: the notification CTA,
// Roro positioned left of the Add icon, story "seen" rings, and the Manage
// screen's consistent "Unfollow" wording. Device-rendered via the shotserver.
//
//   flutter test integration_test/circle_strip_shots.dart -d <sim-udid>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/data/meal_photos.dart';
import 'package:food_at_peace/src/data/profile_photo.dart';
import 'package:food_at_peace/src/features/circle/circle_strip.dart';
import 'package:food_at_peace/src/models/session.dart';
import 'package:food_at_peace/src/models/friend.dart';
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

class _DemoAuth extends AuthNotifier {
  @override
  Session? build() => Session(
    token: 'shots',
    userId: 'apple:shots',
    email: 'eva@icloud.com',
    expiresAt: DateTime(2031),
  );
}

/// Roro (official, @roro) + one real peer (Peter), both connected.
class _DemoCircle extends CircleNotifier {
  @override
  List<Friend> build() => const [
    Friend(id: 'u_roro', name: 'Roro', handle: '@roro', status: FriendStatus.connected),
    Friend(
      id: 'u_peter',
      name: 'Peter',
      handle: '@peter',
      status: FriendStatus.connected,
      streakDays: 5,
      adherence7d: [60, 72, 81, 76, 90, 85, 88],
      todayKcal: 1200,
      targetKcal: 1800,
    ),
  ];
}

Widget _host({required bool notifAllowed, required SharedPreferences prefs}) {
  // Empty temp stores → no profile photo (person icon), no meal photos.
  final mealDir = Directory.systemTemp.createTempSync('fap_circle_meal');
  final profileFile = File(
    '${Directory.systemTemp.createTempSync('fap_circle_prof').path}/p.jpg',
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      mealPhotosProvider.overrideWithValue(MealPhotos(mealDir)),
      profilePhotoFileProvider.overrideWithValue(profileFile),
      authProvider.overrideWith(_DemoAuth.new),
      circleProvider.overrideWith(_DemoCircle.new),
      notificationsAllowedProvider.overrideWith((ref) async => notifAllowed),
    ],
    child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: SingleChildScrollView(child: CircleStrip()),
        ),
      ),
    ),
  ),
  );
}

Future<SharedPreferences> _seedPrefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'circle_notify_enabled': true,
  });
  return SharedPreferences.getInstance();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('strip with notification CTA + Roro left of Add + unseen rings', (
    t,
  ) async {
    final prefs = await _seedPrefs();
    await t.pumpWidget(_host(notifAllowed: false, prefs: prefs));
    await beat(t, 1400);
    await shot(t, 'circle-after-strip'); // CTA + Roro-left-of-add + unseen rings

    // Open "You" story → close → the ring turns grey (seen).
    await t.tap(find.text('You'));
    await beat(t, 900);
    if (find.byIcon(Icons.close).evaluate().isNotEmpty) {
      await t.tap(find.byIcon(Icons.close));
    }
    await beat(t, 800);
    await shot(t, 'circle-after-seen'); // You ring now grey
  });

  testWidgets('strip without the CTA (notifications already allowed)', (t) async {
    final prefs = await _seedPrefs();
    await t.pumpWidget(_host(notifAllowed: true, prefs: prefs));
    await beat(t, 1400);
    await shot(t, 'circle-before-nocta'); // baseline: no CTA card
  });
}
