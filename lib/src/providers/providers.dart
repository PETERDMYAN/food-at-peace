import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_key_store.dart';
import '../data/claude_vision_client.dart';
import '../data/food_repository.dart';
import '../data/health_service.dart';
import '../data/profile_repository.dart';
import '../data/weight_repository.dart';
import '../models/daily_summary.dart';
import '../models/energy_out.dart';
import '../models/food_entry.dart';
import '../models/user_profile.dart';
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
    state = [...state, entry];
    await ref.read(foodRepositoryProvider).saveAll(state);
    // Mirror the entry into Apple Health (best-effort) when connected.
    if (ref.read(healthConnectedProvider)) {
      unawaited(ref.read(healthServiceProvider).writeFood(entry));
    }
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await ref.read(foodRepositoryProvider).saveAll(state);
  }

  Future<void> update(FoodEntry entry) async {
    state = [
      for (final e in state)
        if (e.id == entry.id) entry else e,
    ];
    await ref.read(foodRepositoryProvider).saveAll(state);
  }
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
    state = profile;
    await ref.read(profileRepositoryProvider).save(profile);
  }
}

final profileProvider =
    NotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);

/// Entries for the selected day, newest first.
final entriesForSelectedDayProvider = Provider<List<FoodEntry>>((ref) {
  final all = ref.watch(foodEntriesProvider);
  final date = ref.watch(selectedDateProvider);
  final list = all.where((e) => isSameDay(e.timestamp, date)).toList()
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

/// A key baked in at build time via --dart-define=ANTHROPIC_API_KEY=… (empty
/// when not provided). Lets the app analyze photos without anyone pasting a key
/// in Settings; a key saved in Settings still takes precedence.
const String bakedInApiKey = String.fromEnvironment('ANTHROPIC_API_KEY');

/// The Anthropic API key (null/empty = not set). Prefers a user-saved key from
/// secure storage, then falls back to the built-in [bakedInApiKey].
class ApiKeyNotifier extends Notifier<String?> {
  @override
  String? build() {
    _load();
    return bakedInApiKey.isNotEmpty ? bakedInApiKey : null;
  }

  Future<void> _load() async {
    final stored = await ref.read(apiKeyStoreProvider).read();
    if (stored != null && stored.trim().isNotEmpty) {
      state = stored.trim();
    } else if (bakedInApiKey.isNotEmpty) {
      state = bakedInApiKey;
    } else {
      state = null;
    }
  }

  Future<void> save(String key) async {
    final trimmed = key.trim();
    await ref.read(apiKeyStoreProvider).write(trimmed);
    state = trimmed;
  }

  Future<void> clear() async {
    await ref.read(apiKeyStoreProvider).delete();
    state = bakedInApiKey.isNotEmpty ? bakedInApiKey : null;
  }
}

final apiKeyProvider =
    NotifierProvider<ApiKeyNotifier, String?>(ApiKeyNotifier.new);

bool hasApiKey(String? key) => key != null && key.trim().isNotEmpty;

/// True when the active key is the built-in one (no user key saved).
bool isBuiltInApiKey(String? key) =>
    bakedInApiKey.isNotEmpty && key == bakedInApiKey;

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
    final entry =
        WeightEntry(id: now.microsecondsSinceEpoch.toString(), kg: kg, timestamp: now);
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
}

final weightEntriesProvider =
    NotifierProvider<WeightEntriesNotifier, List<WeightEntry>>(
        WeightEntriesNotifier.new);
