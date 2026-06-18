// Records the new left/right swipe in the full-screen food story (NOT shipped;
// dev tooling). Seeds a few photo meals, opens the "You" story, and flings
// horizontally so a screen recording shows the gesture moving between pages.
//
//   flutter test integration_test/swipe_demo.dart -d <udid> --dart-define=LOCALE=en
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/data/health_service.dart';
import 'package:food_at_peace/src/data/meal_photos.dart';
import 'package:food_at_peace/src/data/profile_photo.dart';
import 'package:food_at_peace/src/data/sync_engine.dart';
import 'package:food_at_peace/src/features/home/home_shell.dart';
import 'package:food_at_peace/src/models/energy_out.dart';
import 'package:food_at_peace/src/models/food_entry.dart';
import 'package:food_at_peace/src/models/meal_type.dart';
import 'package:food_at_peace/src/models/session.dart';
import 'package:food_at_peace/src/models/user_profile.dart';
import 'package:food_at_peace/src/models/weather.dart';
import 'package:food_at_peace/src/models/workout_summary.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:food_at_peace/src/theme/app_theme.dart';

const _loc = String.fromEnvironment('LOCALE', defaultValue: 'en');
const _photoFish = 'https://files.catbox.moe/r1t9y1.jpg';
const _photoPasta = 'https://files.catbox.moe/36sgmo.jpg';
const _photoRice = 'https://files.catbox.moe/8ulvy6.jpg';

class _DemoAuth extends AuthNotifier {
  @override
  Session? build() => Session(
    token: 'demo',
    userId: 'apple:demo',
    email: 'eva@icloud.com',
    expiresAt: DateTime.now().add(const Duration(hours: 6)),
  );
}

class _CleanSync extends SyncEngine {
  @override
  SyncState build() =>
      SyncState(phase: SyncPhase.idle, lastSyncedAt: DateTime.now());
}

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
  Future<EnergyOut?> readEnergyOut(DateTime day) async => null;
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

Future<List<int>?> _fetch(String url) async {
  try {
    final c = HttpClient();
    final resp = await (await c.getUrl(Uri.parse(url))).close();
    final b = <int>[];
    await for (final chunk in resp) {
      b.addAll(chunk);
    }
    c.close();
    return b.isEmpty ? null : b;
  } catch (_) {
    return null;
  }
}

FoodEntry _e(String id, String name, double cal, MealType meal, DateTime ts,
        {String? thumb}) =>
    FoodEntry(
      id: id,
      name: name,
      calories: cal,
      proteinG: 30,
      satFatG: 6,
      mealType: meal,
      timestamp: ts,
      source: FoodSource.photo,
      updatedAt: ts,
      photoThumb: thumb,
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('swipe demo — food story', (t) async {
    final now = DateTime.now();
    DateTime at(int h, int m) => DateTime(now.year, now.month, now.day, h, m);

    final fish = await _fetch(_photoFish);
    final pasta = await _fetch(_photoPasta);
    final rice = await _fetch(_photoRice);
    String? thumb(List<int>? b) =>
        b != null ? encodeMealThumb(Uint8List.fromList(b)) : null;

    final entries = [
      _e('d1', 'Salmon poke bowl', 540, MealType.lunch, at(13, 40),
          thumb: thumb(fish)),
      _e('d2', 'Pesto pasta', 620, MealType.dinner, at(12, 10),
          thumb: thumb(pasta)),
      _e('d3', 'Chicken fried rice', 480, MealType.lunch, at(9, 30),
          thumb: thumb(rice)),
      _e('d4', 'Greek yogurt & berries', 220, MealType.breakfast, at(8, 0)),
    ];

    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_complete': true,
      'app_locale': _loc,
      'user_profile_v1': jsonEncode(const UserProfile(
        sex: Sex.female,
        age: 29,
        heightCm: 168,
        weightKg: 60,
        activity: ActivityLevel.moderate,
        goal: Goal.maintain,
        isConfigured: true,
        name: 'Eva',
      ).toJson()),
      'food_entries_v1': jsonEncode([for (final e in entries) e.toJson()]),
      'beans_granted': true,
      'reminders_enabled': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final profileFile = File(
      '${Directory.systemTemp.createTempSync('swipe_profile').path}/p.jpg',
    );
    if (pasta != null) profileFile.writeAsBytesSync(pasta);

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          weatherProvider.overrideWith(
            (ref) async => const Weather(tempC: 30, code: 1, isDay: true),
          ),
          healthServiceProvider.overrideWithValue(_NoHealth()),
          mealPhotosProvider.overrideWithValue(
            MealPhotos(Directory.systemTemp.createTempSync('swipe_meal')),
          ),
          profilePhotoFileProvider.overrideWithValue(profileFile),
          authProvider.overrideWith(_DemoAuth.new),
          syncEngineProvider.overrideWith(_CleanSync.new),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          locale: Locale(_loc),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeShell(),
        ),
      ),
    );
    await beat(t, 2200);

    // Trends → open the "You" food story.
    await t.tap(find.byIcon(Icons.insights_outlined).first);
    await beat(t, 1600);
    await t.tap(find.text(_loc == 'zh' ? '你' : 'You').first);
    await beat(t, 1800);

    // Swipe right-to-left to advance, then left-to-right to go back.
    Future<void> swipe(double dx) async {
      await t.fling(find.byType(MaterialApp), Offset(dx, 0), 900);
      await beat(t, 1500);
    }

    await swipe(-320); // → next
    await swipe(-320); // → next
    await swipe(-320); // → next
    await swipe(320); // ← back
    await swipe(320); // ← back
    await beat(t, 1200);
  });
}
