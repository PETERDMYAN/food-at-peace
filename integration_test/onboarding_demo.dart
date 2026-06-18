// Screen-recordable first-run **onboarding** walkthrough, driven on a real
// simulator. Sign in with Apple and Apple Health can't authenticate on a sim,
// so both are injected exactly the way the app's own code consumes them:
//   • a fake AuthNotifier whose signIn() mints a session and persists the
//     Apple-supplied name (what the real `AuthClient.signInWithApple` returns);
//   • a fake HealthService that grants permission and exposes a couple of
//     read-only characteristics (sex + age), so connecting Health prefills part
//     of "About you" and the user supplements the rest (height + weight).
//
// Parameterized so the same flow records both users:
//   --dart-define=DEMO_NAME=Eva  --dart-define=DEMO_SEX=female --dart-define=DEMO_AGE=29
//   --dart-define=DEMO_NAME=Peter --dart-define=DEMO_SEX=male  --dart-define=DEMO_AGE=31
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:food_at_peace/app.dart';
import 'package:food_at_peace/src/data/health_service.dart';
import 'package:food_at_peace/src/models/energy_out.dart';
import 'package:food_at_peace/src/models/food_entry.dart';
import 'package:food_at_peace/src/models/session.dart';
import 'package:food_at_peace/src/models/user_profile.dart';
import 'package:food_at_peace/src/models/workout_summary.dart';
import 'package:food_at_peace/src/providers/providers.dart';

const _name = String.fromEnvironment('DEMO_NAME', defaultValue: 'Eva');
const _sex = String.fromEnvironment('DEMO_SEX', defaultValue: 'female');
const _age = int.fromEnvironment('DEMO_AGE', defaultValue: 29);
const _heightCm = String.fromEnvironment('DEMO_HEIGHT', defaultValue: '168');
const _weightKg = String.fromEnvironment('DEMO_WEIGHT', defaultValue: '60');

/// Stands in for `AuthClient.signInWithApple()`: a short beat (the native Apple
/// sheet) then a minted session + the Apple-shared display name on the profile.
class _DemoAuth extends AuthNotifier {
  @override
  Session? build() => null; // signed out at first run

  @override
  Future<void> signIn() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    state = Session(
      token: 'demo-$_name',
      userId: 'apple:demo-$_name',
      expiresAt: DateTime.now().add(const Duration(hours: 4)),
    );
    final p = ref.read(profileProvider);
    await ref.read(profileProvider.notifier).save(p.copyWith(name: _name));
  }
}

/// Grants Health access on the sim and exposes sex + age as read-only
/// characteristics (height/weight left for the user to supplement).
class _FakeHealth implements HealthService {
  @override
  bool get isSupported => true;
  @override
  Future<bool> requestPermissions() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return true;
  }
  @override
  Future<bool> hasPermissions() async => false;
  @override
  Future<Sex?> readSex() async => Sex.values.byName(_sex);
  @override
  Future<int?> readAge() async => _age;
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

Future<void> beat(WidgetTester t, int ms) async {
  var e = 0;
  while (e < ms) {
    await t.pump(const Duration(milliseconds: 60));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    e += 60;
  }
}

/// Advance the flow via the bottom-bar primary button (its label is "Continue"
/// on every page except the last).
Future<void> tapContinue(WidgetTester t) async {
  await t.tap(find.widgetWithText(FilledButton, 'Continue').hitTestable());
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding walkthrough — $_name', (t) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          weatherProvider.overrideWith((ref) async => null),
          authProvider.overrideWith(_DemoAuth.new),
          healthServiceProvider.overrideWithValue(_FakeHealth()),
        ],
        child: const FoodAtPeaceApp(),
      ),
    );
    await beat(t, 2000); // boot → the welcome / name page

    // ── Page 1 — Apple ID: tap "Sign in with Apple"; name lands from Apple ──
    await t.tap(find.byType(SignInWithAppleButton));
    await beat(t, 1800); // the (faked) Apple sheet, then the name populates
    expect(find.textContaining(_name), findsWidgets); // greeting "…, <name>"
    await beat(t, 1200);
    await tapContinue(t);

    // ── Page 2 — Goal: choose "Lose weight" ─────────────────────────────────
    await beat(t, 900);
    await t.tap(find.byIcon(Icons.trending_down).hitTestable());
    await beat(t, 1100);
    await tapContinue(t);

    // ── Page 3 — Apple Health: connect → "Connected" confirmation ───────────
    await beat(t, 900);
    await t.tap(
      find.widgetWithText(FilledButton, 'Connect Apple Health').hitTestable(),
    );
    await beat(t, 1700); // the (faked) Health sheet, then the connected row
    expect(find.byIcon(Icons.check_circle), findsWidgets);
    await beat(t, 1200);
    await tapContinue(t);

    // ── Page 4 — Reminders: leave for later, just continue ──────────────────
    await beat(t, 1300);
    await tapContinue(t);

    // ── Page 5 — About you: sex + age came from Health; supplement the rest ─
    await beat(t, 1000);
    await t.enterText(find.widgetWithText(TextField, 'Height'), _heightCm);
    await beat(t, 600);
    await t.enterText(find.widgetWithText(TextField, 'Weight'), _weightKg);
    await beat(t, 700);
    FocusManager.instance.primaryFocus?.unfocus();
    await beat(t, 700);
    await t.tap(find.widgetWithText(FilledButton, 'Get started').hitTestable());

    // ── Lands on Today — onboarding complete ────────────────────────────────
    await beat(t, 3200);
  });
}
