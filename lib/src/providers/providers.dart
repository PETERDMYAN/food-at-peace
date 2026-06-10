import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_key_store.dart';
import '../data/auth_client.dart';
import '../data/claude_vision_client.dart';
import '../data/food_photo_analyzer.dart';
import '../data/food_repository.dart';
import '../data/health_service.dart';
import '../data/profile_repository.dart';
import '../data/session_store.dart';
import '../data/weather_service.dart';
import '../data/weight_repository.dart';
import '../models/daily_summary.dart';
import '../models/energy_out.dart';
import '../models/food_entry.dart';
import '../models/session.dart';
import '../models/user_profile.dart';
import '../models/weather.dart';
import '../models/weight_entry.dart';
import '../models/workout_summary.dart';

/// Overridden in `main()` with the loaded SharedPreferences instance (and in
/// tests with a mock).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final foodRepositoryProvider = Provider<FoodRepository>(
  (ref) => SharedPrefsFoodRepository(ref.watch(sharedPreferencesProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(sharedPreferencesProvider)),
);

/// Holds every food entry; persists on each change.
class FoodEntriesNotifier extends Notifier<List<FoodEntry>> {
  @override
  List<FoodEntry> build() => ref.read(foodRepositoryProvider).loadAll();

  Future<void> add(FoodEntry entry) async {
    final stamped = entry.copyWith(updatedAt: DateTime.now());
    state = [...state, stamped];
    await ref.read(foodRepositoryProvider).saveAll(state);
    // Mirror the entry into Apple Health (best-effort) when connected.
    if (ref.read(healthConnectedProvider)) {
      unawaited(ref.read(healthServiceProvider).writeFood(stamped));
    }
  }

  /// Soft delete: keep a tombstone (deleted=true) so the removal syncs to other
  /// devices instead of the entry "resurrecting" on the next pull.
  Future<void> remove(String id) async {
    final now = DateTime.now();
    state = [
      for (final e in state)
        if (e.id == id) e.copyWith(deleted: true, updatedAt: now) else e,
    ];
    await ref.read(foodRepositoryProvider).saveAll(state);
  }

  Future<void> update(FoodEntry entry) async {
    final stamped = entry.copyWith(updatedAt: DateTime.now());
    state = [
      for (final e in state)
        if (e.id == stamped.id) stamped else e,
    ];
    await ref.read(foodRepositoryProvider).saveAll(state);
  }

  /// Re-reads from storage — used by the sync engine after merging server changes.
  void reload() => state = ref.read(foodRepositoryProvider).loadAll();
}

final foodEntriesProvider =
    NotifierProvider<FoodEntriesNotifier, List<FoodEntry>>(
        FoodEntriesNotifier.new);

/// The day currently shown on the Today screen (date-only, no time).
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void set(DateTime d) => state = dateOnly(d);
  void goToToday() => state = dateOnly(DateTime.now());
  void shiftDays(int days) => state = dateOnly(state.add(Duration(days: days)));
}

final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime>(SelectedDateNotifier.new);

/// The user's profile; persists on save.
class ProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() => ref.read(profileRepositoryProvider).load();

  Future<void> save(UserProfile profile) async {
    final stamped = profile.copyWith(updatedAt: DateTime.now());
    state = stamped;
    await ref.read(profileRepositoryProvider).save(stamped);
  }

  void reload() => state = ref.read(profileRepositoryProvider).load();

  /// Pulls age (from date of birth), height and weight from Apple Health and
  /// updates the profile when they differ. Runs on launch / resume / connect so
  /// the profile tracks Health "daily". No-op when Health isn't connected.
  Future<void> refreshFromHealth() async {
    if (!ref.read(healthConnectedProvider)) return;
    final service = ref.read(healthServiceProvider);
    if (!service.isSupported) return;
    final age = await service.readAge();
    final heightCm = await service.readHeightCm();
    final weightKg = await service.readLatestWeightKg();
    var next = state;
    if (age != null && age != next.age) {
      next = next.copyWith(age: age);
    }
    if (heightCm != null && (heightCm - next.heightCm).abs() > 0.5) {
      next = next.copyWith(heightCm: heightCm);
    }
    if (weightKg != null && (weightKg - next.weightKg).abs() > 0.1) {
      next = next.copyWith(weightKg: weightKg);
    }
    if (!identical(next, state)) await save(next);
  }
}

final profileProvider =
    NotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);

/// Entries for the selected day, newest first.
final entriesForSelectedDayProvider = Provider<List<FoodEntry>>((ref) {
  final all = ref.watch(foodEntriesProvider);
  final date = ref.watch(selectedDateProvider);
  final list = all
      .where((e) => !e.deleted && isSameDay(e.timestamp, date))
      .toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return list;
});

/// The computed summary (targets + remaining) for the selected day.
/// Incorporates measured "calories out" from HealthKit when available.
final dailySummaryProvider = Provider<DailySummary>((ref) {
  final entries = ref.watch(entriesForSelectedDayProvider);
  final profile = ref.watch(profileProvider);
  final date = ref.watch(selectedDateProvider);
  final energyOut = ref.watch(energyOutProvider).asData?.value;
  return DailySummary.compute(
    date: date,
    entries: entries,
    profile: profile,
    energyOut: energyOut,
  );
});

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ---- Phase 3: Claude vision photo analysis ----

final apiKeyStoreProvider = Provider<ApiKeyStore>((ref) => ApiKeyStore());

final claudeVisionClientProvider =
    Provider<ClaudeVisionClient>((ref) => ClaudeVisionClient());

/// The AWS vision proxy, baked in at build time via
/// --dart-define=PROXY_BASE_URL=… and --dart-define=PROXY_APP_TOKEN=… (empty
/// when not provided). The proxy holds the Anthropic key server-side, so the
/// app ships no Claude secret on the default path — a URL plus a revocable
/// token are not the key.
const String proxyBaseUrl = String.fromEnvironment('PROXY_BASE_URL');
const String proxyAppToken = String.fromEnvironment('PROXY_APP_TOKEN');

/// The user's own Anthropic API key (null/empty = not set), loaded from secure
/// storage. Optional: when set, photo analysis calls Anthropic directly with
/// it; otherwise the app uses the proxy.
class ApiKeyNotifier extends Notifier<String?> {
  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final stored = await ref.read(apiKeyStoreProvider).read();
    state = (stored != null && stored.trim().isNotEmpty) ? stored.trim() : null;
  }

  Future<void> save(String key) async {
    final trimmed = key.trim();
    await ref.read(apiKeyStoreProvider).write(trimmed);
    state = trimmed;
  }

  Future<void> clear() async {
    await ref.read(apiKeyStoreProvider).delete();
    state = null;
  }
}

final apiKeyProvider =
    NotifierProvider<ApiKeyNotifier, String?>(ApiKeyNotifier.new);

bool hasApiKey(String? key) => key != null && key.trim().isNotEmpty;

/// Picks how to analyze a food photo: the user's own key → Anthropic directly;
/// otherwise the AWS proxy. Null when neither is configured (no user key and no
/// proxy URL baked in), so the UI can explain that scanning is unavailable.
final foodPhotoAnalyzerProvider = Provider<FoodPhotoAnalyzer?>((ref) {
  final userKey = ref.watch(apiKeyProvider);
  if (hasApiKey(userKey)) {
    return DirectAnalyzer(ref.watch(claudeVisionClientProvider), userKey!);
  }
  if (proxyBaseUrl.isNotEmpty) {
    return ProxyAnalyzer(baseUrl: proxyBaseUrl, appToken: proxyAppToken);
  }
  return null;
});

// ---- Accounts: Sign in with Apple ----

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

final authClientProvider =
    Provider<AuthClient>((ref) => AuthClient(baseUrl: proxyBaseUrl));

/// The current signed-in [Session] (null = signed out). Loads from secure
/// storage on build; [signIn] runs the native Apple flow + backend exchange.
class AuthNotifier extends Notifier<Session?> {
  @override
  Session? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final store = ref.read(sessionStoreProvider);
    final session = await store.read();
    if (session == null) return;
    if (session.isExpired) {
      await store.delete(); // drop an expired token
    } else {
      state = session;
    }
  }

  /// Native Sign in with Apple → backend exchange → persist. Throws
  /// [SignInCancelled] or [AuthException]; the UI handles both.
  Future<void> signIn() async {
    final (session, name) =
        await ref.read(authClientProvider).signInWithApple();
    await ref.read(sessionStoreProvider).write(session);
    state = session;
    // Apple only shares the name on first sign-in — persist it on the profile
    // (which syncs to the backend) so the greeting works on every device.
    if (name != null && name.isNotEmpty) {
      final profile = ref.read(profileProvider);
      if (profile.name != name) {
        await ref
            .read(profileProvider.notifier)
            .save(profile.copyWith(name: name));
      }
    }
  }

  Future<void> signOut() async {
    await ref.read(sessionStoreProvider).delete();
    state = null;
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, Session?>(AuthNotifier.new);

// ---- Phase 2: HealthKit calories-out ----

final healthServiceProvider =
    Provider<HealthService>((ref) => createHealthService());

/// Whether health access has been granted. Once the user connects we remember
/// it in prefs — iOS never reveals read-authorization status, so without this
/// the app would forget the connection on every launch.
class HealthConnectedNotifier extends Notifier<bool> {
  static const _prefsKey = 'health_connected';

  @override
  bool build() {
    final remembered =
        ref.read(sharedPreferencesProvider).getBool(_prefsKey) ?? false;
    if (!remembered) _check();
    return remembered;
  }

  Future<void> _check() async {
    final service = ref.read(healthServiceProvider);
    if (!service.isSupported) return;
    if (await service.hasPermissions()) state = true;
  }

  Future<bool> connect() async {
    final service = ref.read(healthServiceProvider);
    if (!service.isSupported) return false;
    final granted = await service.requestPermissions();
    state = granted;
    if (granted) {
      await ref.read(sharedPreferencesProvider).setBool(_prefsKey, true);
      // Pull age / height / weight from Health right away.
      unawaited(ref.read(profileProvider.notifier).refreshFromHealth());
    }
    return granted;
  }
}

final healthConnectedProvider =
    NotifierProvider<HealthConnectedNotifier, bool>(
        HealthConnectedNotifier.new);

/// Measured "calories out" for the selected day (null when unsupported,
/// not connected, or no data).
final energyOutProvider = FutureProvider<EnergyOut?>((ref) async {
  final connected = ref.watch(healthConnectedProvider);
  if (!connected) return null;
  final date = ref.watch(selectedDateProvider);
  return ref.read(healthServiceProvider).readEnergyOut(date);
});

/// Most recent body weight (kg) from Apple Health, e.g. a Garmin/Fitdays scale.
/// Null when unsupported, not connected, or no data.
final latestWeightProvider = FutureProvider<double?>((ref) async {
  final connected = ref.watch(healthConnectedProvider);
  if (!connected) return null;
  return ref.read(healthServiceProvider).readLatestWeightKg();
});

/// Workouts recorded on the selected day (e.g. Garmin activities), longest
/// first. Empty when unsupported, not connected, or no data.
final workoutsProvider = FutureProvider<List<WorkoutSummary>>((ref) async {
  final connected = ref.watch(healthConnectedProvider);
  if (!connected) return const [];
  final date = ref.watch(selectedDateProvider);
  return ref.read(healthServiceProvider).readWorkouts(date);
});

// ---- Weather (local, for the Today header) ----

final weatherServiceProvider =
    Provider<WeatherService>((ref) => WeatherService());

/// Current local weather (null when location is denied/unavailable or offline).
/// Resolved once per app session; refreshable via `ref.invalidate`.
final weatherProvider = FutureProvider<Weather?>(
  (ref) => ref.read(weatherServiceProvider).current(),
);

// ---- App language ----

/// App language override: null = follow the iOS system language; otherwise a
/// forced locale ('en' or 'zh'). Persisted in prefs.
class LocaleNotifier extends Notifier<Locale?> {
  static const _prefsKey = 'app_locale';

  @override
  Locale? build() {
    final code = ref.read(sharedPreferencesProvider).getString(_prefsKey);
    return (code == null || code.isEmpty) ? null : Locale(code);
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

// ---- Weight log ----

final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) => WeightRepository(ref.watch(sharedPreferencesProvider)),
);

/// The user's logged weight readings, newest first; persists on each change.
class WeightEntriesNotifier extends Notifier<List<WeightEntry>> {
  @override
  List<WeightEntry> build() {
    return ref.read(weightRepositoryProvider).loadAll()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Logs a new weight (kg): saves it, updates the profile weight so targets
  /// recalc, and mirrors it to Apple Health (best-effort) when connected.
  Future<void> add(double kg) async {
    final now = DateTime.now();
    final entry = WeightEntry(
      id: now.microsecondsSinceEpoch.toString(),
      kg: kg,
      timestamp: now,
      updatedAt: now,
    );
    state = [entry, ...state];
    await ref.read(weightRepositoryProvider).saveAll(state);

    final profile = ref.read(profileProvider);
    if (profile.weightKg != kg) {
      await ref.read(profileProvider.notifier).save(profile.copyWith(weightKg: kg));
    }
    if (ref.read(healthConnectedProvider)) {
      unawaited(ref.read(healthServiceProvider).writeWeight(kg, now));
    }
  }

  void reload() => state = ref.read(weightRepositoryProvider).loadAll()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
}

final weightEntriesProvider =
    NotifierProvider<WeightEntriesNotifier, List<WeightEntry>>(
        WeightEntriesNotifier.new);

/// Non-deleted food entries (tombstones hidden), for list UIs like History.
final visibleFoodEntriesProvider = Provider<List<FoodEntry>>(
    (ref) => ref.watch(foodEntriesProvider).where((e) => !e.deleted).toList());

/// Non-deleted weight readings (tombstones hidden), newest first.
final visibleWeightEntriesProvider = Provider<List<WeightEntry>>(
    (ref) => ref.watch(weightEntriesProvider).where((e) => !e.deleted).toList());

// ---- Onboarding ----

/// Whether the first-run onboarding has been completed. Persisted so it only
/// shows once. Kept separate from `profile.isConfigured` so a signed-out user
/// who skips the flow still isn't sent back through it.
class OnboardingNotifier extends Notifier<bool> {
  static const _prefsKey = 'onboarding_complete';

  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_prefsKey) ?? false;

  Future<void> complete() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_prefsKey, true);
  }
}

final onboardingCompleteProvider =
    NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
