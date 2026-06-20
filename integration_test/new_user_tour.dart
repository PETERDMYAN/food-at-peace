// HONEST new-user walkthrough for a screen recording: a genuine fresh user with
// NO account (no Sign in with Apple — the sim can't, and we deliberately don't),
// nothing seeded. Shows the real first-run state: onboarding, then the Circle
// where Eva (the coach) is followed by default but Roro (the creator) is only
// "Suggested to follow" — his stories/feed are NOT available until you connect —
// plus the "turn on iOS notifications" prompt (reminders + circle default on).
//   flutter test integration_test/new_user_tour.dart -d <sim-udid>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/app.dart';
import 'package:food_at_peace/src/data/health_service.dart';
import 'package:food_at_peace/src/data/meal_photos.dart';
import 'package:food_at_peace/src/data/profile_photo.dart';
import 'package:food_at_peace/src/models/energy_out.dart';
import 'package:food_at_peace/src/models/food_entry.dart';
import 'package:food_at_peace/src/models/session.dart';
import 'package:food_at_peace/src/models/user_profile.dart';
import 'package:food_at_peace/src/models/workout_summary.dart';
import 'package:food_at_peace/src/providers/providers.dart';

// Signed OUT the whole time — we never log in / use any Apple ID.
class _NoAuth extends AuthNotifier {
  @override
  Session? build() => null;
}

// Health is device-local (not an account); fake it so onboarding flows, exposing
// sex + age the way the app reads HealthKit characteristics.
class _FakeHealth implements HealthService {
  @override
  bool get isSupported => true;
  @override
  Future<bool> requestPermissions() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return true;
  }
  @override
  Future<bool> hasPermissions() async => false;
  @override
  Future<Sex?> readSex() async => Sex.male;
  @override
  Future<int?> readAge() async => 31;
  @override
  Future<double?> readHeightCm() async => null;
  @override
  Future<double?> readLatestWeightKg() async => null;
  @override
  Future<EnergyOut?> readEnergyOut(DateTime day, {String? preferredSource}) async => null;
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

Future<void> beat(WidgetTester t, int ms) async {
  var e = 0;
  while (e < ms) {
    await t.pump(const Duration(milliseconds: 60));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    e += 60;
  }
}

Future<void> tapContinue(WidgetTester t) async {
  await t.tap(find.widgetWithText(FilledButton, 'Continue').hitTestable());
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('honest new user tour', (t) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final mealDir = Directory.systemTemp.createTempSync('tour_meal');
    final profDir = Directory.systemTemp.createTempSync('tour_prof');
    final profileFile = File('${profDir.path}/p.jpg');

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mealPhotosProvider.overrideWithValue(MealPhotos(mealDir)),
          profilePhotoFileProvider.overrideWithValue(profileFile),
          weatherProvider.overrideWith((ref) async => null),
          authProvider.overrideWith(_NoAuth.new),
          healthServiceProvider.overrideWithValue(_FakeHealth()),
          // Fresh device: iOS hasn't granted notifications, so the CTA shows.
          notificationsAllowedProvider.overrideWith((ref) async => false),
        ],
        child: const FoodAtPeaceApp(),
      ),
    );
    await beat(t, 2400);

    // ── Onboarding (no login — type the name) ───────────────────────────────
    await t.enterText(find.byType(TextField).first, 'Peter');
    await beat(t, 900);
    FocusManager.instance.primaryFocus?.unfocus();
    await beat(t, 600);
    await tapContinue(t);
    await beat(t, 1000);
    await t.tap(find.byIcon(Icons.trending_down).hitTestable());
    await beat(t, 1000);
    await tapContinue(t);
    await beat(t, 900);
    await t.tap(find.widgetWithText(FilledButton, 'Connect Apple Health').hitTestable());
    await beat(t, 1600);
    await tapContinue(t);
    await beat(t, 1600); // reminders page — shows the "allow notifications" + why
    await tapContinue(t);
    await beat(t, 1000);
    await t.enterText(find.widgetWithText(TextField, 'Height'), '178');
    await beat(t, 500);
    await t.enterText(find.widgetWithText(TextField, 'Weight'), '74');
    await beat(t, 500);
    FocusManager.instance.primaryFocus?.unfocus();
    await beat(t, 700);
    await t.tap(find.widgetWithText(FilledButton, 'Get started').hitTestable());
    await beat(t, 3000);

    // ── Circle tab: the genuine fresh state ─────────────────────────────────
    await t.tap(find.byIcon(Icons.groups_outlined).first);
    await beat(t, 2400); // strip (You + Eva + Add) + notification CTA + feed

    // Eva is available by default — open her 3-day story.
    await t.tap(find.text('Eva').first);
    await beat(t, 1900);
    final sz = t.view.physicalSize / t.view.devicePixelRatio;
    final right = Offset(sz.width * 0.8, sz.height * 0.5);
    await t.tapAt(right);
    await beat(t, 1500);
    await t.tapAt(right);
    await beat(t, 1500);
    await t.tap(find.byIcon(Icons.close).first); // close the story via the X
    await beat(t, 1400);

    // Manage circle — Roro is only "Suggested to follow" (not connected), so his
    // stories/feed are not available yet.
    await t.tap(find.byIcon(Icons.group_outlined).first);
    await beat(t, 2000);
    final scroll = find.byType(Scrollable).first;
    await t.drag(scroll, const Offset(0, -360));
    await beat(t, 1800);
    await t.drag(scroll, const Offset(0, -320));
    await beat(t, 1800);
  });
}
