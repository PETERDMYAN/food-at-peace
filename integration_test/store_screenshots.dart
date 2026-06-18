// App Store screenshot generator (NOT shipped; dev tooling only).
//
// Seeds a rich, configured account (profile, several days of meals, a Beans
// ledger, a Circle feed with hosted photos), forces a locale, and walks the key
// screens. When each screen is settled it pings the host capture server
// (`/tmp/fap_shots/shotserver.py`) on 127.0.0.1, which grabs the *device* screen
// via `simctl io screenshot` — so the clean 9:41 status bar is included and the
// images are exactly 1320 × 2868 (iPhone 6.9").
//
//   LOCALE=en|zh  →  which language to render.
//
// Run (one locale per invocation, against a booted iPhone 17 Pro Max):
//   flutter test integration_test/store_screenshots.dart -d <udid> \
//     --dart-define=LOCALE=en
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart' show ProductDetails;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/data/health_service.dart';
import 'package:food_at_peace/src/data/meal_photos.dart';
import 'package:food_at_peace/src/data/profile_photo.dart';
import 'package:food_at_peace/src/data/sync_engine.dart';
import 'package:food_at_peace/src/features/add/add_entry_screen.dart';
import 'package:food_at_peace/src/features/circle/circle_feed_screen.dart';
import 'package:food_at_peace/src/features/home/home_shell.dart';
import 'package:food_at_peace/src/features/settings/data_sources_screen.dart';
import 'package:food_at_peace/src/features/settings/reminders_screen.dart';
import 'package:food_at_peace/src/features/wallet/beans_screen.dart';
import 'package:food_at_peace/src/models/bean_transaction.dart';
import 'package:food_at_peace/src/models/circle_post.dart';
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
const _shotPort = int.fromEnvironment('SHOT_PORT', defaultValue: 8099);

// Hosted demo food photos (catbox, unlisted) for the Circle feed.
const _photoFish = 'https://files.catbox.moe/r1t9y1.jpg';
const _photoPasta = 'https://files.catbox.moe/36sgmo.jpg';
const _photoRice = 'https://files.catbox.moe/8ulvy6.jpg';

bool get _zh => _loc == 'zh';

String _s(String en, String zh) => _zh ? zh : en;

/// Signed-in session so the Circle feed renders (no real network — the feed +
/// beans providers are overridden / offline).
class _DemoAuth extends AuthNotifier {
  @override
  Session? build() => Session(
    token: 'shots-token',
    userId: 'apple:shots',
    email: 'eva@icloud.com',
    expiresAt: DateTime.now().add(const Duration(hours: 6)),
  );
}

/// A no-op sync engine that reports a clean "just synced" state, so the Settings
/// account card shows "Last synced 9:41" instead of a failed-network error (the
/// fake session can't reach a real backend).
class _CleanSync extends SyncEngine {
  @override
  SyncState build() =>
      SyncState(phase: SyncPhase.idle, lastSyncedAt: DateTime.now());
}

/// Forces the Circle-activity toggle to a fixed state for the before/after shot.
class _FixedCircleNotify extends CircleNotifyNotifier {
  _FixedCircleNotify(this.value);
  final bool value;
  @override
  bool build() => value;
}

/// Health is irrelevant for screenshots — report unsupported so nothing tries to
/// touch the (absent) HealthKit on the sim.
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
  Future<List<String>> energySources() async =>
      const ['Garmin Connect', 'Apple Watch', 'Eva’s iPhone'];
  @override
  Future<List<WorkoutSummary>> readWorkouts(DateTime day) async => const [];
  @override
  Future<bool> writeFood(FoodEntry entry) async => true;
  @override
  Future<bool> writeWeight(double kg, DateTime when) async => true;
  @override
  Future<bool> writeHeight(double cm) async => true;
}

/// Pump for [ms] real milliseconds so animations / network images settle in the
/// captured frame (pumpAndSettle would hang on the weather loop + image
/// spinners).
Future<void> beat(WidgetTester t, int ms) async {
  var e = 0;
  while (e < ms) {
    await t.pump(const Duration(milliseconds: 80));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    e += 80;
  }
}

/// Fetch bytes from [url] (the hosted demo photos) for seeding local images.
/// Returns null on any failure so the harness still runs offline.
Future<List<int>?> _fetch(String url) async {
  try {
    final c = HttpClient();
    final req = await c.getUrl(Uri.parse(url));
    final resp = await req.close();
    final bytes = <int>[];
    await for (final chunk in resp) {
      bytes.addAll(chunk);
    }
    c.close();
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}

/// Ask the host server to capture the current device screen into `out/<name>.png`.
Future<void> shot(WidgetTester t, String name, {int settle = 1400}) async {
  await beat(t, settle);
  try {
    final c = HttpClient();
    final req = await c.getUrl(Uri.parse('http://127.0.0.1:$_shotPort/shot/$name'));
    final resp = await req.close();
    await resp.drain();
    c.close();
  } catch (_) {}
  await beat(t, 500);
}

FoodEntry _e(
  String id,
  String name,
  double cal,
  double p,
  double sf,
  MealType meal,
  DateTime ts, {
  FoodSource source = FoodSource.manual,
  bool recurring = false,
}) => FoodEntry(
  id: id,
  name: name,
  calories: cal,
  proteinG: p,
  satFatG: sf,
  mealType: meal,
  timestamp: ts,
  source: source,
  updatedAt: ts,
  recurring: recurring,
);

List<FoodEntry> _seedEntries() {
  final now = DateTime.now();
  DateTime at(int dayBack, int hour, int min) =>
      DateTime(now.year, now.month, now.day, hour, min)
          .subtract(Duration(days: dayBack));

  final yogurt = _s('Greek yogurt & berries', '希腊酸奶配莓果');
  final poke = _s('Salmon poke bowl', '三文鱼盖饭');
  final chicken = _s('Chicken & veg', '鸡胸配时蔬');
  final shake = _s('Protein shake', '蛋白奶昔');
  final toast = _s('Avocado toast', '牛油果吐司');
  final rice = _s('Chicken fried rice', '鸡肉炒饭');
  final pasta = _s('Pesto pasta', '青酱意面');

  final vitamin = _s('Vitamin D + Omega-3', '维生素D + 鱼油');
  final out = <FoodEntry>[];
  // Today: 920 kcal eaten of a ~1344 budget → ~424 left, protein meets 96 g.
  out.addAll([
    // A "Take daily" supplement, started 5 days ago — shows every day with a
    // Daily badge, counted automatically (no re-logging). Timed latest so the
    // badge sits at the top of the list for the screenshot.
    _e('sup-vd', vitamin, 15, 1, 1, MealType.snack, at(5, 14, 30), recurring: true),
    _e('t-bf', yogurt, 220, 18, 2, MealType.breakfast, at(0, 8, 20)),
    _e('t-sn', shake, 160, 40, 1, MealType.snack, at(0, 12, 10)),
    // Newest today entry + a (seeded) photo → the food story opens on it.
    _e('t-ln', poke, 540, 38, 5, MealType.lunch, at(0, 13, 40), source: FoodSource.photo),
  ]);
  // Six prior days: balanced "good" days (1190 kcal / 98 g protein, on target)
  // and a couple of indulgent ones (1460 kcal / 62 g) so the trend reads ~5/7.
  for (var d = 1; d <= 6; d++) {
    final good = d % 3 != 0; // indulgent on days 3 and 6
    if (good) {
      out.addAll([
        _e('p$d-b', yogurt, 220, 18, 2, MealType.breakfast, at(d, 8, 30)),
        _e('p$d-l', poke, 540, 38, 5, MealType.lunch, at(d, 12, 30)),
        _e('p$d-d', chicken, 430, 42, 4, MealType.dinner, at(d, 19, 0)),
      ]);
    } else {
      out.addAll([
        _e('p$d-b', toast, 320, 12, 3, MealType.breakfast, at(d, 8, 30)),
        _e('p$d-l', rice, 520, 28, 6, MealType.lunch, at(d, 12, 30)),
        _e('p$d-d', pasta, 620, 22, 8, MealType.dinner, at(d, 19, 0)),
      ]);
    }
  }
  return out;
}

List<BeanTransaction> _seedBeans() {
  final now = DateTime.now();
  return [
    BeanTransaction(id: 'b1', type: BeanTxnType.purchase, amount: 500, timestamp: now.subtract(const Duration(hours: 2)), note: _s('Top-up', '充值'), priceSgd: 9.48),
    BeanTransaction(id: 'b2', type: BeanTxnType.spend, amount: -1, timestamp: now.subtract(const Duration(hours: 5)), note: _s('Salmon poke bowl', '三文鱼盖饭')),
    BeanTransaction(id: 'b3', type: BeanTxnType.spend, amount: -1, timestamp: now.subtract(const Duration(days: 1, hours: 3)), note: _s('Pesto pasta', '青酱意面')),
    BeanTransaction(id: 'b4', type: BeanTxnType.purchase, amount: 200, timestamp: now.subtract(const Duration(days: 2)), note: _s('Top-up', '充值'), priceSgd: 3.99),
    BeanTransaction(id: 'b5', type: BeanTxnType.spend, amount: -1, timestamp: now.subtract(const Duration(days: 2, hours: 2)), note: _s('Chicken fried rice', '鸡肉炒饭')),
    BeanTransaction(id: 'b6', type: BeanTxnType.signupGrant, amount: 100, timestamp: now.subtract(const Duration(days: 3))),
  ];
}

List<CirclePost> _seedFeed() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    CirclePost(
      postId: 'f1',
      authorId: 'friend-eva',
      authorName: _s('Eva', '林薇'),
      name: _s('Sea bass & greens', '鲈鱼配时蔬'),
      calories: 520,
      createdAt: now - 3600 * 1000,
      photoUrl: _photoFish,
      reactions: const {'❤️': 3, '😋': 2, '🔥': 1},
    ),
    CirclePost(
      postId: 'f2',
      authorId: 'apple:shots',
      authorName: _s('You', '你'),
      name: _s('Pesto pasta', '青酱意面'),
      calories: 620,
      createdAt: now - 5 * 3600 * 1000,
      photoUrl: _photoPasta,
      mine: true,
      reactions: const {'❤️': 2, '😋': 1},
      reactors: [
        CircleReactor(name: _s('Peter', '陈昊'), emoji: '❤️'),
        CircleReactor(name: _s('Mia', '小敏'), emoji: '😋'),
      ],
    ),
    CirclePost(
      postId: 'f3',
      authorId: 'friend-peter',
      authorName: _s('Peter', '陈昊'),
      name: _s('Chicken fried rice', '鸡肉炒饭'),
      calories: 480,
      createdAt: now - 8 * 3600 * 1000,
      photoUrl: _photoRice,
      reactions: const {'👍': 2, '❤️': 1},
      myReaction: '❤️',
    ),
  ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots — $_loc', (t) async {
    final profile = const UserProfile(
      sex: Sex.female,
      age: 29,
      heightCm: 168,
      weightKg: 60,
      activity: ActivityLevel.moderate,
      goal: Goal.maintain,
      isConfigured: true,
      name: 'Eva',
    );

    // Seed photos by fetching the hosted demo images used by the Circle feed.
    final mealPhotos = MealPhotos(
      Directory.systemTemp.createTempSync('fap_shots_meal'),
    );
    final profileFile = File(
      '${Directory.systemTemp.createTempSync('fap_shots_profile').path}/profile.jpg',
    );
    final fish = await _fetch(_photoFish);
    final pasta = await _fetch(_photoPasta);
    if (pasta != null) profileFile.writeAsBytesSync(pasta);
    // The newest entry (t-ln) carries ONLY a synced thumbnail — no local file —
    // exactly like an entry pulled from the cloud onto a fresh device. This is
    // the case the fix addresses: the food story shows the photo from the thumb.
    final fishThumb =
        fish != null ? encodeMealThumb(Uint8List.fromList(fish)) : null;
    final entries = [
      for (final e in _seedEntries())
        e.id == 't-ln' ? e.copyWith(photoThumb: fishThumb) : e,
    ];

    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_complete': true,
      'app_locale': _loc,
      'user_profile_v1': jsonEncode(profile.toJson()),
      'food_entries_v1': jsonEncode([for (final e in entries) e.toJson()]),
      'beans_granted': true,
      'beans_ledger_v1': jsonEncode([for (final b in _seedBeans()) b.toJson()]),
      'reminders_enabled': false,
      // Health connected + a chosen active-energy source, for the Data Sources shot.
      'health_connected': true,
      'energy_source_priority': 'Garmin Connect',
    });
    final prefs = await SharedPreferences.getInstance();

    final baseOverrides = [
      sharedPreferencesProvider.overrideWithValue(prefs),
      weatherProvider.overrideWith(
        (ref) async => const Weather(tempC: 30, code: 1, isDay: true),
      ),
      healthServiceProvider.overrideWithValue(_NoHealth()),
      mealPhotosProvider.overrideWithValue(mealPhotos),
      profilePhotoFileProvider.overrideWithValue(profileFile),
      circleFeedProvider.overrideWith((ref) async => _seedFeed()),
      // No live StoreKit on the sim → show the indicative SGD prices (the
      // sim's storefront would otherwise return USD).
      beanProductsProvider.overrideWith(
        (ref) async => const <String, ProductDetails>{},
      ),
    ];
    final signedInOverrides = [
      ...baseOverrides,
      authProvider.overrideWith(_DemoAuth.new),
      syncEngineProvider.overrideWith(_CleanSync.new),
    ];

    // Each mount keys the MaterialApp uniquely so pumpWidget builds a FRESH
    // Navigator — otherwise Flutter reuses the same Navigator element and any
    // route pushed on top (e.g. the paywall modal sheet) bleeds into the next
    // screen. The ProviderScope sits outside the key, so seeded state persists.
    var mountSeq = 0;
    Future<void> mount(Widget home, {bool signedIn = true}) async {
      mountSeq += 1;
      await t.pumpWidget(
        ProviderScope(
          overrides: signedIn ? signedInOverrides : baseOverrides,
          child: MaterialApp(
            key: ValueKey('mount-$mountSeq'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            locale: Locale(_loc),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          ),
        ),
      );
      await beat(t, 1600);
    }

    // One signed-in HomeShell mount drives the three tabbed screens (Today,
    // Trends, Settings) — a single mount is reliable; re-mounting HomeShell is
    // not. Circle / Beans / Add are pushed as their own screens afterward.

    // ── 1) Today (rings + macros + meals) ──────────────────────────────
    await mount(const HomeShell());
    await shot(t, '01-today', settle: 2600);

    // ── 1b) Tap a Today item → the "Take daily" sheet ──────────────────
    final tapItem = find.text(_s('Salmon poke bowl', '三文鱼盖饭'));
    if (tapItem.evaluate().isNotEmpty) {
      await t.tap(tapItem.first);
      await shot(t, '13-daily-sheet', settle: 1400);
      await t.tapAt(const Offset(200, 60)); // tap the scrim to dismiss
      await beat(t, 700);
    }

    // ── 2) Trends (tap the Trends nav destination) ─────────────────────
    await t.tap(find.byIcon(Icons.insights_outlined).first);
    await shot(t, '02-trends', settle: 2400);

    // ── 2b) Eva's daily-lesson story (full-screen, tap her avatar) ─────
    await t.tap(find.text('Eva').first);
    await shot(t, '09-eva-story', settle: 1800);
    await t.tap(find.byIcon(Icons.close)); // close the full-screen story
    await beat(t, 700);

    // ── 2c) Your food story (full-screen, tap "You") — photo-led, caption ─
    await t.tap(find.text(_loc == 'zh' ? '你' : 'You').first);
    await shot(t, '10-food-story', settle: 2200);
    // ── 2d) Delete-from-story confirm (the 7-day archive control) ──────
    final del = find.byIcon(Icons.delete_outline);
    if (del.evaluate().isNotEmpty) {
      await t.tap(del.first);
      await shot(t, '11-story-delete', settle: 1400);
      final cancel = find.text(_s('Cancel', '取消'));
      if (cancel.evaluate().isNotEmpty) await t.tap(cancel.first);
      await beat(t, 500);
    }
    final close = find.byIcon(Icons.close);
    if (close.evaluate().isNotEmpty) await t.tap(close.first); // close story
    await beat(t, 700);

    // ── 3) Settings (profile + targets + clean "Last synced" + Sources) ─
    await t.tap(find.byIcon(Icons.settings_outlined).first);
    await shot(t, '06-settings', settle: 2200);

    // ── 4) Circle feed (friends' shared meals + reactions) ─────────────
    await mount(const CircleFeedScreen());
    await shot(t, '03-circle', settle: 5200); // let the photos download

    // ── 5) Beans wallet (balance + history) ────────────────────────────
    await mount(const BeansScreen());
    await shot(t, '04-beans', settle: 2200);

    // ── 5b) Top-up paywall — shows the new 25-Bean entry pack ───────────
    final topUp = find.text('Top up');
    if (topUp.evaluate().isNotEmpty) {
      await t.tap(topUp.first);
      await shot(t, '07-paywall', settle: 2800);
    }

    // ── 6) Add (manual + photo scan entry) ─────────────────────────────
    await mount(const AddEntryScreen());
    await shot(t, '05-add', settle: 2200);

    // ── 7) Data sources — active-energy source priority ────────────────
    await mount(const DataSourcesScreen());
    await shot(t, '15-data-sources', settle: 1800);

    // ── 8) Circle activity notifications — on by default (before/after) ─
    Future<void> reminders(String name, bool on) async {
      mountSeq += 1;
      await t.pumpWidget(
        ProviderScope(
          // A distinct key per pump → a fresh scope, so adding the circle
          // override doesn't trip Riverpod's "overrides length changed" assert
          // against the previous (un-keyed) scope.
          key: ValueKey('scope-$mountSeq'),
          overrides: [
            ...signedInOverrides,
            circleNotifyProvider.overrideWith(() => _FixedCircleNotify(on)),
          ],
          child: MaterialApp(
            key: ValueKey('mount-$mountSeq'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            locale: Locale(_loc),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const RemindersScreen(),
          ),
        ),
      );
      await beat(t, 1600);
      await t.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await shot(t, name, settle: 1400);
    }

    await reminders('16-circle-off', false);
    await reminders('16-circle-on', true);
  });
}
