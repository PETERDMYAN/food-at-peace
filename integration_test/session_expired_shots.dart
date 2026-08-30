// Before/after capture for the "session expired" prompt (1.1.3).
//
// Boots the REAL home shell for a returning user (Eva, a configured profile +
// today's meals) whose stored sign-in has EXPIRED — the situation every June
// sign-in hit on 2026-08-30 when the 60-day tokens ran out.
//   • BEFORE (≤ 1.1.2): the app silently drops the token — nothing on screen
//     tells Eva she's signed out; sync, photo backup and Circle sharing just stop.
//   • AFTER  (1.1.3):  a "Your sign-in expired" card at the top offers Sign in
//     with Apple (or Later).
// Only pre-existing APIs are used here, so the SAME driver runs on both builds.
//
//   SHOT_UDID=<udid> python3 /tmp/fap_shots/shotserver.py 8099 &
//   flutter test integration_test/session_expired_shots.dart -d <udid> \
//     --dart-define=LOCALE=en --dart-define=TAG=before
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/data/health_service.dart';
import 'package:food_at_peace/src/data/meal_photos.dart';
import 'package:food_at_peace/src/data/profile_photo.dart';
import 'package:food_at_peace/src/data/session_store.dart';
import 'package:food_at_peace/src/features/home/home_shell.dart';
import 'package:food_at_peace/src/models/energy_out.dart';
import 'package:food_at_peace/src/models/food_entry.dart';
import 'package:food_at_peace/src/models/meal_type.dart';
import 'package:food_at_peace/src/models/session.dart';
import 'package:food_at_peace/src/models/user_profile.dart';
import 'package:food_at_peace/src/models/workout_summary.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:food_at_peace/src/theme/app_theme.dart';

const _shotPort = int.fromEnvironment('SHOT_PORT', defaultValue: 8099);
const _locale = String.fromEnvironment('LOCALE', defaultValue: 'en');
const _tag = String.fromEnvironment('TAG', defaultValue: 'after');
// EXPIRED=false stores a still-valid session instead → proves the shell renders
// exactly as before when there's nothing to say (no banner, no extra padding).
const _expired = bool.fromEnvironment('EXPIRED', defaultValue: true);

class _NoHealth implements HealthService {
  @override
  bool get isSupported => false;
  @override
  Future<bool> requestPermissions() async => false;
  @override
  Future<bool> hasPermissions() async => false;
  @override
  Future<Sex?> readSex() async => null;
  @override
  Future<int?> readAge() async => null;
  @override
  Future<double?> readHeightCm() async => null;
  @override
  Future<double?> readLatestWeightKg() async => null;
  @override
  Future<EnergyOut?> readEnergyOut(DateTime day, {String? preferredSource}) async =>
      null;
  @override
  Future<List<String>> energySources() async => const [];
  @override
  Future<List<WorkoutSummary>> readWorkouts(DateTime day) async => const [];
  @override
  Future<bool> writeFood(FoodEntry entry) async => true;
  @override
  Future<bool> writeWeight(double kg, DateTime when) async => true;
  @override
  Future<bool> writeHeight(double cm) async => true;
}

/// A Keychain stand-in holding a session that expired two days ago.
class _ExpiredSessionStore extends SessionStore {
  Session? _session = Session(
    token: 'expired-token',
    userId: 'apple:eva',
    email: 'eva@icloud.com',
    expiresAt: _expired
        ? DateTime.now().subtract(const Duration(days: 2))
        : DateTime.now().add(const Duration(days: 30)),
  );

  @override
  Future<Session?> read() async => _session;
  @override
  Future<void> write(Session session) async => _session = session;
  @override
  Future<void> delete() async => _session = null;
}

Future<void> beat(WidgetTester t, int ms) async {
  var e = 0;
  while (e < ms) {
    await t.pump(const Duration(milliseconds: 80));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    e += 80;
  }
}

Future<void> shot(WidgetTester t, String name, {int settle = 1500}) async {
  await beat(t, settle);
  try {
    final c = HttpClient();
    final req =
        await c.getUrl(Uri.parse('http://127.0.0.1:$_shotPort/shot/$name'));
    final resp = await req.close();
    await resp.drain();
    c.close();
  } catch (_) {}
  await beat(t, 300);
}

List<FoodEntry> _todaysMeals() {
  final now = DateTime.now();
  DateTime at(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
  final zh = _locale == 'zh';
  return [
    FoodEntry(
      id: 'fe_oats',
      name: zh ? '燕麦粥配蓝莓' : 'Oats with blueberries',
      calories: 320,
      proteinG: 12,
      satFatG: 1.5,
      mealType: MealType.breakfast,
      timestamp: at(8, 10),
    ),
    FoodEntry(
      id: 'fe_chicken',
      name: zh ? '鸡胸肉沙拉' : 'Grilled chicken salad',
      calories: 480,
      proteinG: 42,
      satFatG: 3,
      mealType: MealType.lunch,
      timestamp: at(12, 45),
    ),
  ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('session expired — $_tag ($_locale)', (t) async {
    final profile = UserProfile(
      sex: Sex.female,
      age: 29,
      heightCm: 165,
      weightKg: 58,
      activity: ActivityLevel.moderate,
      goal: Goal.maintain,
      isConfigured: true,
      name: 'Eva',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_complete': true,
      'app_locale': _locale,
      'user_profile_v1': jsonEncode(profile.toJson()),
      'circle_my_handle': 'eva',
      'food_entries_v1':
          jsonEncode([for (final f in _todaysMeals()) f.toJson()]),
    });
    final prefs = await SharedPreferences.getInstance();
    // main() overrides these with real app-support paths; a signed-in shell
    // reaches them (profile-photo hydration), so the harness must too.
    final mealDir = Directory.systemTemp.createTempSync('fap_sess_meal');
    final profileFile = File(
      '${Directory.systemTemp.createTempSync('fap_sess_prof').path}/p.jpg',
    );

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionStoreProvider.overrideWithValue(_ExpiredSessionStore()),
          mealPhotosProvider.overrideWithValue(MealPhotos(mealDir)),
          profilePhotoFileProvider.overrideWithValue(profileFile),
          weatherProvider.overrideWith((ref) async => null),
          healthServiceProvider.overrideWithValue(_NoHealth()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          locale: Locale(_locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeShell(),
        ),
      ),
    );
    await beat(t, 1800);
    await shot(t, 'session-$_tag-$_locale-today', settle: 1600);

    await t.tap(find.byIcon(Icons.groups_outlined).first);
    await beat(t, 1200);
    await shot(t, 'session-$_tag-$_locale-circle', settle: 1400);
  });
}
