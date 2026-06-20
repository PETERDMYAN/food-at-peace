// Real follow→feed→like→story loop on the ISOLATED v2 backend (production
// untouched). A throwaway "Peter" viewer onboards, follows the real Roro account
// (seeded on v2 with his actual meals), opens Roro's feed, likes a post, then
// views Roro's story. Auth is a minted v2 session token (no Apple login).
//   flutter test integration_test/follow_roro_tour.dart -d <sim> --dart-define-from-file=dart_defines.json
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

// Pass a minted v2 viewer session token at run time:
//   --dart-define=VIEWER_TOKEN=<token>
const _viewerToken = String.fromEnvironment('VIEWER_TOKEN');

class _ViewerAuth extends AuthNotifier {
  @override
  Session? build() => Session(
        token: _viewerToken, userId: 'apple:v2viewer4', email: 'peter@demo',
        expiresAt: DateTime.now().add(const Duration(hours: 4)));
}

class _FakeHealth implements HealthService {
  @override
  bool get isSupported => true;
  @override
  Future<bool> requestPermissions() async { await Future<void>.delayed(const Duration(milliseconds: 400)); return true; }
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
  Future<bool> writeFood(FoodEntry e) async => true;
  @override
  Future<bool> writeWeight(double kg, DateTime w) async => true;
  @override
  Future<bool> writeHeight(double cm) async => true;
}

Future<void> beat(WidgetTester t, int ms) async {
  var e = 0;
  while (e < ms) { await t.pump(const Duration(milliseconds: 80)); await Future<void>.delayed(const Duration(milliseconds: 80)); e += 80; }
}
Future<void> tapContinue(WidgetTester t) async =>
    t.tap(find.widgetWithText(FilledButton, 'Continue').hitTestable());

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('follow roro tour', (t) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final mealDir = Directory.systemTemp.createTempSync('fr_meal');
    final profDir = Directory.systemTemp.createTempSync('fr_prof');
    await t.pumpWidget(ProviderScope(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      mealPhotosProvider.overrideWithValue(MealPhotos(mealDir)),
      profilePhotoFileProvider.overrideWithValue(File('${profDir.path}/p.jpg')),
      weatherProvider.overrideWith((ref) async => null),
      authProvider.overrideWith(_ViewerAuth.new),
      healthServiceProvider.overrideWithValue(_FakeHealth()),
    ], child: const FoodAtPeaceApp()));
    await beat(t, 2600);

    // Onboarding (type name; no Apple login).
    await t.enterText(find.byType(TextField).first, 'Peter');
    await beat(t, 800);
    FocusManager.instance.primaryFocus?.unfocus();
    await beat(t, 500);
    await tapContinue(t); await beat(t, 900);
    await t.tap(find.byIcon(Icons.trending_down).hitTestable()); await beat(t, 900);
    await tapContinue(t); await beat(t, 800);
    await t.tap(find.widgetWithText(FilledButton, 'Connect Apple Health').hitTestable()); await beat(t, 1500);
    await tapContinue(t); await beat(t, 1200);
    await tapContinue(t); await beat(t, 900);
    await t.enterText(find.widgetWithText(TextField, 'Height'), '178'); await beat(t, 500);
    await t.enterText(find.widgetWithText(TextField, 'Weight'), '74'); await beat(t, 500);
    FocusManager.instance.primaryFocus?.unfocus(); await beat(t, 600);
    await t.tap(find.widgetWithText(FilledButton, 'Get started').hitTestable());
    await beat(t, 3200);

    // Circle tab — Roro not here yet (not followed).
    await t.tap(find.byIcon(Icons.groups_outlined).first);
    await beat(t, 2600);

    // Open Manage circle → follow Roro (real connect on v2).
    await t.tap(find.byIcon(Icons.group_outlined).first);
    await beat(t, 1800);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -340));
    await beat(t, 1200);
    await t.tap(find.widgetWithText(FilledButton, 'Follow').hitTestable());
    await beat(t, 3200); // connect + feed invalidate
    // Back to the Circle tab.
    await t.tap(find.byTooltip('Back').hitTestable());
    await beat(t, 3000); // feed now includes Roro's posts

    // Like one of Roro's posts (scroll the reaction row into view first).
    final heart = find.text('❤️').first;
    await t.ensureVisible(heart);
    await beat(t, 1200);
    await t.tap(heart, warnIfMissed: false);
    await beat(t, 2200);

    // Open Roro's story (his shared meals).
    await t.drag(find.byType(Scrollable).first, const Offset(0, 420));
    await beat(t, 1200);
    await t.tap(find.text('Roro').first);
    await beat(t, 2200);
    final sz = t.view.physicalSize / t.view.devicePixelRatio;
    await t.tapAt(Offset(sz.width * 0.8, sz.height * 0.5));
    await beat(t, 1800);
    await t.tapAt(Offset(sz.width * 0.8, sz.height * 0.5));
    await beat(t, 1800);
  });
}
