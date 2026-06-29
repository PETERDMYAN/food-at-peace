import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_key_store.dart';
import '../data/auth_client.dart';
import '../data/beans_client.dart';
import '../data/claude_vision_client.dart';
import '../data/analytics_service.dart';
import '../data/circle_client.dart';
import '../data/food_photo_analyzer.dart';
import '../data/meal_photos.dart';
import '../data/meal_photo_store.dart';
import '../data/food_repository.dart';
import '../data/health_service.dart';
import '../data/iap_service.dart';
import '../data/notification_service.dart';
import '../data/posts_client.dart';
import '../data/profile_repository.dart';
import '../data/session_store.dart';
import '../data/weather_service.dart';
import '../data/weight_repository.dart';
import '../models/daily_summary.dart';
import '../models/energy_out.dart';
import '../models/bean_transaction.dart';
import '../models/circle_post.dart';
import '../models/food_entry.dart';
import '../models/friend.dart';
import '../models/meal_type.dart';
import '../models/reminder.dart';
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
    unawaited(ref.read(mealPhotosProvider).delete(id)); // reclaim its photo
  }

  /// Toggle "take daily" (recurring supplement/staple) on an existing entry —
  /// e.g. from the Today list or the post-save prompt.
  Future<void> setRecurring(String id, bool value) async {
    final now = DateTime.now();
    state = [
      for (final e in state)
        if (e.id == id) e.copyWith(recurring: value, updatedAt: now) else e,
    ];
    await ref.read(foodRepositoryProvider).saveAll(state);
  }

  /// Remove an entry from the photo "Food story" only — it stays in the log,
  /// Today totals and Trends (NOT a tombstone). Syncs via [hiddenFromStory].
  Future<void> hideFromStory(String id) async {
    final now = DateTime.now();
    state = [
      for (final e in state)
        if (e.id == id) e.copyWith(hiddenFromStory: true, updatedAt: now) else e,
    ];
    await ref.read(foodRepositoryProvider).saveAll(state);
  }

  /// Delete a single day's occurrence of a **recurring** entry: skip it on
  /// [date] only, keeping the daily series on every other day. (A one-off entry
  /// uses [remove] instead.) Syncs via [FoodEntry.skippedDates].
  Future<void> skipOccurrence(String id, DateTime date) async {
    final key = FoodEntry.dayKey(date);
    final now = DateTime.now();
    state = [
      for (final e in state)
        if (e.id == id && !e.skippedDates.contains(key))
          e.copyWith(skippedDates: [...e.skippedDates, key], updatedAt: now)
        else
          e,
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
      FoodEntriesNotifier.new,
    );

/// The day currently shown on the Today screen (date-only, no time).
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void set(DateTime d) => state = dateOnly(d);
  void goToToday() => state = dateOnly(DateTime.now());
  void shiftDays(int days) => state = dateOnly(state.add(Duration(days: days)));
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

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

  /// Pulls sex, age (from date of birth), height and weight from Apple Health
  /// and updates the profile when they differ. Runs on launch / resume /
  /// connect / manual "Sync now" so the profile tracks Health "daily".
  /// Returns what Health provided (null per field when unavailable) so callers
  /// like onboarding can prefill; no-op result when Health isn't connected.
  Future<HealthBodyReads> refreshFromHealth() async {
    const none = (sex: null, age: null, heightCm: null, weightKg: null);
    if (!ref.read(healthConnectedProvider)) return none;
    final service = ref.read(healthServiceProvider);
    if (!service.isSupported) return none;
    final sex = await service.readSex();
    final age = await service.readAge();
    final heightCm = await service.readHeightCm();
    final weightKg = await service.readLatestWeightKg();
    var next = state;
    // Sex / age come from read-only Health characteristics — never clobber a
    // manual edit (it would just revert on the next refresh).
    if (!next.sexManuallySet && sex != null && sex != next.sex) {
      next = next.copyWith(sex: sex);
    }
    if (!next.ageManuallySet && age != null && age != next.age) {
      next = next.copyWith(age: age);
    }
    if (heightCm != null && (heightCm - next.heightCm).abs() > 0.5) {
      next = next.copyWith(heightCm: heightCm);
    }
    if (weightKg != null && (weightKg - next.weightKg).abs() > 0.1) {
      next = next.copyWith(weightKg: weightKg);
    }
    // Health supplied the full body picture → the profile is reliable, so
    // automatic target calculation can be offered.
    if (!next.isConfigured &&
        age != null &&
        heightCm != null &&
        weightKg != null) {
      next = next.copyWith(isConfigured: true);
    }
    if (!identical(next, state)) await save(next);
    await ref.read(healthSyncProvider.notifier).markSynced();
    return (sex: sex, age: age, heightCm: heightCm, weightKg: weightKg);
  }
}

/// What a Health profile refresh managed to read (null = unavailable).
typedef HealthBodyReads = ({
  Sex? sex,
  int? age,
  double? heightCm,
  double? weightKg,
});

/// When the profile was last refreshed from Apple Health (null = never).
/// Persisted so the Settings card can show it across launches.
class HealthSyncNotifier extends Notifier<DateTime?> {
  static const _prefsKey = 'health_last_sync_ms';

  @override
  DateTime? build() {
    final ms = ref.read(sharedPreferencesProvider).getInt(_prefsKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> markSynced() async {
    final now = DateTime.now();
    state = now;
    await ref
        .read(sharedPreferencesProvider)
        .setInt(_prefsKey, now.millisecondsSinceEpoch);
  }
}

final healthSyncProvider = NotifierProvider<HealthSyncNotifier, DateTime?>(
  HealthSyncNotifier.new,
);

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile>(
  ProfileNotifier.new,
);

/// Entries for the selected day, newest first. A one-off entry shows on its own
/// day; a [FoodEntry.recurring] one (a daily supplement/staple) shows on every
/// day from its start ([timestamp]) onward — logged once, counted daily.
final entriesForSelectedDayProvider = Provider<List<FoodEntry>>((ref) {
  final all = ref.watch(foodEntriesProvider);
  final date = ref.watch(selectedDateProvider);
  // Recurring entries sort by their time-of-day ON the viewed date, so a daily
  // supplement lands in its natural slot each day (not pinned to its start day).
  DateTime slot(FoodEntry e) => e.recurring
      ? DateTime(date.year, date.month, date.day, e.timestamp.hour,
          e.timestamp.minute, e.timestamp.second)
      : e.timestamp;
  final list =
      all.where((e) {
        if (e.deleted) return false;
        return e.recurring
            // every day since it started, minus any occurrences deleted for a day
            ? !date.isBefore(dateOnly(e.timestamp)) && !e.skippedOn(date)
            : isSameDay(e.timestamp, date);
      }).toList()
        ..sort((a, b) => slot(b).compareTo(slot(a)));
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

final claudeVisionClientProvider = Provider<ClaudeVisionClient>(
  (ref) => ClaudeVisionClient(),
);

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

final apiKeyProvider = NotifierProvider<ApiKeyNotifier, String?>(
  ApiKeyNotifier.new,
);

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

final authClientProvider = Provider<AuthClient>(
  (ref) => AuthClient(baseUrl: proxyBaseUrl),
);

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
    final (session, name) = await ref
        .read(authClientProvider)
        .signInWithApple();
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

final authProvider = NotifierProvider<AuthNotifier, Session?>(AuthNotifier.new);

// ---- Phase 2: HealthKit calories-out ----

final healthServiceProvider = Provider<HealthService>(
  (ref) => createHealthService(),
);

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

final healthConnectedProvider = NotifierProvider<HealthConnectedNotifier, bool>(
  HealthConnectedNotifier.new,
);

/// The user's preferred active-energy source (a HealthKit source name like
/// "Garmin Connect"); null = Automatic (combine all sources). Persisted, so the
/// choice sticks; changing it re-pulls [energyOutProvider].
class EnergySourcePriorityNotifier extends Notifier<String?> {
  static const _prefsKey = 'energy_source_priority';

  @override
  String? build() {
    final v = ref.read(sharedPreferencesProvider).getString(_prefsKey);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> set(String? source) async {
    state = (source == null || source.isEmpty) ? null : source;
    final prefs = ref.read(sharedPreferencesProvider);
    if (state == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, state!);
    }
  }
}

final energySourcePriorityProvider =
    NotifierProvider<EnergySourcePriorityNotifier, String?>(
      EnergySourcePriorityNotifier.new,
    );

/// The selectable data sources writing active energy to Apple Health (e.g.
/// "Garmin Connect", "Apple Watch"). Empty when unsupported / not connected.
final energySourcesProvider = FutureProvider<List<String>>((ref) async {
  final connected = ref.watch(healthConnectedProvider);
  if (!connected) return const [];
  return ref.read(healthServiceProvider).energySources();
});

/// Measured "calories out" for the selected day (null when unsupported,
/// not connected, or no data). Honors the preferred active-energy source.
final energyOutProvider = FutureProvider<EnergyOut?>((ref) async {
  final connected = ref.watch(healthConnectedProvider);
  if (!connected) return null;
  final date = ref.watch(selectedDateProvider);
  final preferred = ref.watch(energySourcePriorityProvider);
  return ref
      .read(healthServiceProvider)
      .readEnergyOut(date, preferredSource: preferred);
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

final weatherServiceProvider = Provider<WeatherService>(
  (ref) => WeatherService(),
);

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

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

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
      await ref
          .read(profileProvider.notifier)
          .save(profile.copyWith(weightKg: kg));
    }
    if (ref.read(healthConnectedProvider)) {
      unawaited(ref.read(healthServiceProvider).writeWeight(kg, now));
    }
  }

  void reload() =>
      state = ref.read(weightRepositoryProvider).loadAll()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
}

final weightEntriesProvider =
    NotifierProvider<WeightEntriesNotifier, List<WeightEntry>>(
      WeightEntriesNotifier.new,
    );

/// Non-deleted food entries (tombstones hidden), for list UIs like History.
final visibleFoodEntriesProvider = Provider<List<FoodEntry>>(
  (ref) => ref.watch(foodEntriesProvider).where((e) => !e.deleted).toList(),
);

/// Non-deleted weight readings (tombstones hidden), newest first.
final visibleWeightEntriesProvider = Provider<List<WeightEntry>>(
  (ref) => ref.watch(weightEntriesProvider).where((e) => !e.deleted).toList(),
);

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

final onboardingCompleteProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

// ---- Daily food-logging reminders ----

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

/// The master on/off for meal reminders. Persisted in prefs (default off —
/// opt-in, and we never schedule before the OS grants permission). Toggling on
/// requests permission and flips on only if granted; the widget layer then
/// schedules the (localized) reminders. Off cancels everything.
class RemindersEnabledNotifier extends Notifier<bool> {
  static const _prefsKey = 'reminders_enabled';

  // Default ON — a new user gets daily meal reminders out of the box. The intent
  // is independent of the OS notification permission: if iOS hasn't granted it,
  // the "turn on notifications" CTA prompts (see [NotifyPermissionCta]).
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_prefsKey) ?? true;

  /// Turn the meal-reminders **intent** on (persisted) and ask the OS for
  /// notification permission. The intent stays on even if permission is denied,
  /// so the CTA can prompt later; returns whether the OS granted it so the caller
  /// can (re)schedule.
  Future<bool> enable() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_prefsKey, true);
    return ref.read(notificationServiceProvider).requestPermission();
  }

  Future<void> disable() async {
    state = false;
    await ref.read(sharedPreferencesProvider).setBool(_prefsKey, false);
    await ref.read(notificationServiceProvider).cancelAll();
  }
}

final remindersEnabledProvider =
    NotifierProvider<RemindersEnabledNotifier, bool>(
      RemindersEnabledNotifier.new,
    );

/// The user's configured meal reminders (defaults on first run). Persisted as
/// JSON; mutating it re-persists. Rescheduling the OS notifications after a
/// change is the caller's job (it needs the l10n for the copy) via
/// [rescheduleReminders].
class RemindersNotifier extends Notifier<List<Reminder>> {
  static const _prefsKey = 'reminders_v1';

  @override
  List<Reminder> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_prefsKey);
    if (raw == null || raw.isEmpty) return Reminder.defaults();
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list) Reminder.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      return Reminder.defaults();
    }
  }

  Future<void> _persist() async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_prefsKey, jsonEncode([for (final r in state) r.toJson()]));
  }

  Future<void> add(MealType meal, int hour, int minute) async {
    final id = 'r${DateTime.now().microsecondsSinceEpoch}';
    state = [
      ...state,
      Reminder(id: id, meal: meal, hour: hour, minute: minute),
    ];
    await _persist();
  }

  Future<void> setTime(String id, int hour, int minute) async {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(hour: hour, minute: minute) else r,
    ];
    await _persist();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(enabled: enabled) else r,
    ];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = [
      for (final r in state)
        if (r.id != id) r,
    ];
    await _persist();
  }
}

final remindersProvider = NotifierProvider<RemindersNotifier, List<Reminder>>(
  RemindersNotifier.new,
);

// ---- Beans (in-app credit) ----

/// Wallet state: the Beans ledger (newest first). Balance is derived from the
/// ledger so it can never drift out of sync.
class BeansState {
  const BeansState({required this.ledger});

  final List<BeanTransaction> ledger;

  int get balance => ledger.fold(0, (sum, t) => sum + t.amount);

  /// You need at least one Bean to scan a photo.
  bool get canAnalyze => balance > 0;

  BeansState copyWith({List<BeanTransaction>? ledger}) =>
      BeansState(ledger: ledger ?? this.ledger);
}

/// The Beans wallet. Grants [BeanPricing.signupGrant] free Beans once on first
/// launch; spends one per photo analysis; records purchases/refunds.
///
/// The ledger is persisted locally (shared_preferences) and, when signed in,
/// reconciled with the account's **server ledger** (`/beans`) on sign-in and
/// after each append ([_syncBeans]) so a balance follows the user across devices
/// and survives a reinstall. Real purchases go through [recordPurchase];
/// [purchasePack] is a legacy local-credit stub. StoreKit **receipt validation**
/// (`/iap/validate`) is still a planned follow-up (`TODO.md` §2).
class BeansNotifier extends Notifier<BeansState> {
  static const _ledgerKey = 'beans_ledger_v1';
  static const _grantedKey = 'beans_granted';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  BeansState build() {
    // Rebuild when auth changes so signing in triggers a server reconcile.
    ref.watch(authProvider);
    final raw = _prefs.getString(_ledgerKey);
    var ledger = <BeanTransaction>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        ledger = [
          for (final e in jsonDecode(raw) as List)
            BeanTransaction.fromJson(e as Map<String, dynamic>),
        ];
      } catch (_) {}
    }
    // First launch → grant the free Beans, exactly once.
    if (!(_prefs.getBool(_grantedKey) ?? false)) {
      ledger = [_grant(), ...ledger];
      _prefs.setBool(_grantedKey, true);
      _prefs.setString(_ledgerKey, _encode(ledger));
    }
    // Signed in → pull the account's server ledger (and push what's local) so a
    // balance bought on another device follows the account here. Deferred: it
    // mutates state, which can't happen during build().
    if (_online) Future.microtask(_syncBeans);
    return BeansState(ledger: ledger);
  }

  bool get _online {
    final token = ref.read(authProvider)?.token;
    return proxyBaseUrl.isNotEmpty && token != null && token.isNotEmpty;
  }

  BeanTransaction _grant() => BeanTransaction(
    id: _id('grant'),
    type: BeanTxnType.signupGrant,
    amount: BeanPricing.signupGrant,
    timestamp: DateTime.now(),
  );

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  String _encode(List<BeanTransaction> l) =>
      jsonEncode([for (final t in l) t.toJson()]);

  Future<void> _append(BeanTransaction txn) async {
    state = state.copyWith(ledger: [txn, ...state.ledger]);
    await _prefs.setString(_ledgerKey, _encode(state.ledger));
    // Push the new transaction to the account's server ledger (best-effort) so
    // a purchase/spend follows the user across devices.
    if (_online) unawaited(_syncBeans());
  }

  /// Best-effort reconcile of the local ledger with the account's server ledger.
  /// `POST /beans` uploads our transactions and returns the account's full
  /// ledger (append-only, idempotent by id), so Beans bought on one device show
  /// up on another; the per-device signup grant is collapsed to one
  /// ([mergeBeansLedgers]). Never throws — a failure just keeps the local ledger.
  Future<void> _syncBeans() async {
    final token = ref.read(authProvider)?.token;
    if (token == null || token.isEmpty || proxyBaseUrl.isEmpty) return;
    try {
      final server = await ref
          .read(beansClientProvider)
          .push(token, state.ledger);
      final merged = mergeBeansLedgers(server, state.ledger);
      if (!_sameLedger(merged, state.ledger)) {
        state = state.copyWith(ledger: merged);
      }
      await _prefs.setString(_ledgerKey, _encode(merged));
    } catch (_) {
      // best-effort; keep the local ledger on any network/parse failure
    }
  }

  static bool _sameLedger(List<BeanTransaction> a, List<BeanTransaction> b) {
    if (a.length != b.length) return false;
    final ids = a.map((t) => t.id).toSet();
    return b.every((t) => ids.contains(t.id));
  }

  /// Spend one Bean on a photo analysis. Returns false (without spending) if
  /// there aren't enough Beans.
  Future<bool> spendOnPhoto(String dishNote) async {
    if (state.balance < BeanPricing.costPerPhoto) return false;
    await _append(
      BeanTransaction(
        id: _id('spend'),
        type: BeanTxnType.spend,
        amount: -BeanPricing.costPerPhoto,
        timestamp: DateTime.now(),
        note: dishNote.isEmpty ? null : dishNote,
      ),
    );
    return true;
  }

  /// DEV STUB — credits [beans] locally for [sgd]. Still used by the paywall
  /// until the StoreKit switchover; real purchases go through [recordPurchase].
  Future<void> purchasePack(int beans, double sgd) => _append(
    BeanTransaction(
      id: _id('buy'),
      type: BeanTxnType.purchase,
      amount: beans,
      timestamp: DateTime.now(),
      priceSgd: sgd,
    ),
  );

  /// Credit a verified StoreKit purchase to the ledger — called by the IAP flow
  /// ([IapService]) when `in_app_purchase` reports the consumable as purchased.
  Future<void> recordPurchase(int beans, String productId) => _append(
    BeanTransaction(
      id: _id('buy'),
      type: BeanTxnType.purchase,
      amount: beans,
      timestamp: DateTime.now(),
      priceSgd: BeanPricing.sgdForBeans(beans),
      // No note: the row already shows "Top-up · <price>" — the internal
      // StoreKit product ID isn't meaningful to the user.
    ),
  );

  /// Credit a completed StoreKit purchase. When we have the receipt + an account,
  /// validate it server-side (`/iap/validate`), which credits the Beans
  /// server-side (idempotent + cross-device, after Apple confirms the receipt) —
  /// then adopt the returned ledger. Falls back to a local credit when validation
  /// isn't available (no receipt / signed out / the shared secret isn't set yet)
  /// so a paid purchase always lands. Called by the IAP flow.
  Future<void> creditPurchase(int beans, String productId, String receipt) async {
    // Owner-dashboard beans-sold + revenue are recorded SERVER-SIDE on receipt
    // validation (`iap.py`), so they reflect real money once and can't be faked
    // by the client. No client-side 'purchase' event is emitted here.
    final token = ref.read(authProvider)?.token;
    if (receipt.isNotEmpty &&
        token != null &&
        token.isNotEmpty &&
        proxyBaseUrl.isNotEmpty) {
      final ledger = await ref
          .read(beansClientProvider)
          .validateIap(token, receipt, productId);
      if (ledger != null) {
        final merged = mergeBeansLedgers(ledger, state.ledger);
        state = state.copyWith(ledger: merged);
        await _prefs.setString(_ledgerKey, _encode(merged));
        return;
      }
    }
    await recordPurchase(beans, productId);
  }
}

/// HTTP client for the server-side Beans ledger (`/beans`). No-op target when no
/// proxy is configured (the notifier only calls it when signed in + online).
final beansClientProvider = Provider<BeansClient>(
  (ref) => BeansClient(baseUrl: proxyBaseUrl),
);

final beansProvider = NotifierProvider<BeansNotifier, BeansState>(
  BeansNotifier.new,
);

/// StoreKit IAP for the Bean packs; a completed purchase credits the wallet via
/// [BeansNotifier.creditPurchase] (which validates the receipt server-side when
/// it can). Lazily created on first read.
final iapServiceProvider = Provider<IapService>((ref) {
  final service = StoreKitIapService(
    onCredited: (beans, productId, receipt) =>
        ref.read(beansProvider.notifier).creditPurchase(beans, productId, receipt),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Live StoreKit product details (localized prices) for the Bean packs, keyed by
/// product ID. Empty when the store is unavailable (e.g. on the simulator).
final beanProductsProvider = FutureProvider<Map<String, ProductDetails>>((
  ref,
) async {
  final list = await ref.read(iapServiceProvider).products();
  return {for (final p in list) p.id: p};
});

// ---- Circles of Food (friends) ----

/// A random 8-character default @handle for a new account: lowercase letters +
/// digits, guaranteed to contain at least one of each, matching the backend rule
/// `^[a-z0-9_]{2,20}$`. Users can change it later in the profile dialog. Pass a
/// seeded [Random] in tests.
String generateRandomHandle([Random? random]) {
  final rng = random ?? Random();
  const letters = 'abcdefghijklmnopqrstuvwxyz';
  const digits = '0123456789';
  const all = '$letters$digits';
  final chars = <String>[
    letters[rng.nextInt(letters.length)], // ≥1 letter
    digits[rng.nextInt(digits.length)], // ≥1 digit
    for (var i = 0; i < 6; i++) all[rng.nextInt(all.length)],
  ]..shuffle(rng);
  return chars.join();
}

/// The user's "Circle of Food": connected friends + pending invites (incoming /
/// outgoing).
///
/// When signed in (and a proxy is configured) this is backed by the real
/// `/circle/*` API — invites/acceptance and privacy-gated friend trends come
/// from the server. Signed out, it falls back to a local, seeded list so the
/// feature still works offline and in tests. (A handle-management screen — show
/// / edit your own @handle — is a planned follow-up; for now a handle is
/// derived from the profile name on first online use.)
class CircleNotifier extends Notifier<List<Friend>> {
  static const _key = 'circle_v1';
  static const _seededKey = 'circle_seeded';
  static const _handleSetKey = 'circle_handle_set';
  static const _myHandleKey = 'circle_my_handle';
  static const _roroFollowedKey = 'circle_roro_autofollowed';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  String? get _token => ref.read(authProvider)?.token;
  bool get _online {
    final t = _token;
    return proxyBaseUrl.isNotEmpty && t != null && t.isNotEmpty;
  }

  @override
  List<Friend> build() {
    // Rebuild when auth changes: sign in → switch to the backend; out → local.
    ref.watch(authProvider);
    _dropLegacySeededFriends();
    if (_online) {
      // Defer: _refresh()/_ensureHandle write myCircleHandleProvider, which must
      // not happen during this build (Riverpod asserts), so the circle would
      // never load on launch for a returning user with a handle already set.
      Future.microtask(_refresh);
    }
    // No mock seed: a real (esp. signed-out) user starts with an empty circle —
    // just You + Eva + Add — never fake friends.
    return _loadLocal() ?? const [];
  }

  /// One-time cleanup for users upgrading from a build that seeded sample friends
  /// (Mia/Jay/Sara/Ben) for the signed-out state. Strip those ids from the cache
  /// so nobody keeps seeing fake friends, and clear the legacy "seeded" flag.
  static const _seedIds = {'f_mia', 'f_jay', 'f_sara', 'f_ben'};
  void _dropLegacySeededFriends() {
    if (!(_prefs.getBool(_seededKey) ?? false)) return;
    _prefs.remove(_seededKey);
    final local = _loadLocal();
    if (local == null) return;
    final cleaned = local.where((f) => !_seedIds.contains(f.id)).toList();
    if (cleaned.length != local.length) _prefs.setString(_key, _encode(cleaned));
  }

  // ---- local (offline / cache) store ----

  String _encode(List<Friend> l) => jsonEncode([for (final f in l) f.toJson()]);

  Future<void> _save() => _prefs.setString(_key, _encode(state));

  List<Friend>? _loadLocal() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          Friend.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      return null;
    }
  }

  List<Friend> get connected =>
      state.where((f) => f.status == FriendStatus.connected).toList();
  List<Friend> get incoming =>
      state.where((f) => f.status == FriendStatus.incoming).toList();

  // ---- backend (signed in) ----

  /// Ensure a handle is claimed on the backend, and that the **same** handle is
  /// recovered across reinstalls / new devices.
  ///
  /// Order matters: the server is the source of truth. After a reinstall the
  /// local prefs are wiped, so we first ask the backend what handle this Apple
  /// account already owns and adopt it verbatim — that's how `@yourhandle`
  /// survives "delete app → sign back in" so friends keep finding you. Only a
  /// genuinely new account (the server has no handle) is assigned a **random
  /// 8-character** handle and claims it (retried on a clash). Idempotent via
  /// [_handleSetKey].
  Future<void> _ensureHandle(CircleClient client, String token) async {
    // Steady state: already known locally → just publish it, no network.
    if (_prefs.getBool(_handleSetKey) ?? false) {
      final saved = _prefs.getString(_myHandleKey);
      if (saved != null) ref.read(myCircleHandleProvider.notifier).set(saved);
      return;
    }
    // Fresh install / new device: recover the handle the account already owns.
    String? serverHandle;
    try {
      serverHandle = await client.myHandle(token);
    } catch (_) {
      // Transient network error — do NOT claim a fresh handle blindly (that
      // could change a returning user's handle). Retry on the next refresh.
      return;
    }
    if (serverHandle != null && serverHandle.isNotEmpty) {
      await _claimLocally(serverHandle);
      return;
    }
    // New account: assign a random 8-char handle (or honour an offline-chosen
    // one) and claim it; on a clash, try fresh randoms so it stays unique.
    final name = ref.read(profileProvider).name;
    final chosen = _prefs.getString(_myHandleKey);
    var handle = chosen ?? generateRandomHandle();
    var code = await client.register(token, handle, name: name);
    // Only an auto-assigned (not user-chosen) handle is regenerated on a clash —
    // exceedingly rare for an 8-char alphanumeric.
    var tries = 0;
    while (code == 409 && chosen == null && tries < 5) {
      handle = generateRandomHandle();
      code = await client.register(token, handle, name: name);
      tries++;
    }
    if (code == 200) await _claimLocally(handle);
  }

  /// Persist + publish the viewer's own handle (prefs + reactive provider).
  Future<void> _claimLocally(String handle) async {
    await _prefs.setString(_myHandleKey, handle);
    await _prefs.setBool(_handleSetKey, true);
    ref.read(myCircleHandleProvider.notifier).set(handle);
  }

  /// Set (or change) the user's own @handle so friends can add them. Validated
  /// locally, stored immediately (works offline), and registered with the
  /// backend when signed in — reporting a clash so the UI can prompt for
  /// another. Mirrors the server's handle rules.
  Future<SetHandleResult> setHandle(String raw) async {
    final handle = raw.trim().replaceAll('@', '').toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{2,20}$').hasMatch(handle)) {
      return SetHandleResult.invalid;
    }
    if (_online) {
      try {
        final code = await ref
            .read(circleClientProvider)
            .register(_token!, handle, name: ref.read(profileProvider).name);
        if (code == 409) return SetHandleResult.taken;
        if (code != 200) return SetHandleResult.error;
      } catch (_) {
        return SetHandleResult.error;
      }
    }
    await _prefs.setString(_myHandleKey, handle);
    await _prefs.setBool(_handleSetKey, true);
    ref.read(myCircleHandleProvider.notifier).set(handle);
    if (_online) await _refresh();
    return SetHandleResult.ok;
  }

  /// Push the viewer's current display name to the Circle directory so
  /// connected friends see the up-to-date name. The friend list reads each
  /// friend's live me-card name server-side, so re-registering the *current*
  /// handle with the new name is all that's needed on a rename. Best-effort;
  /// a no-op when signed out or before a handle is claimed.
  Future<void> syncCircleName() async {
    if (!_online) return;
    final handle = _prefs.getString(_myHandleKey);
    if (handle == null || handle.isEmpty) return;
    try {
      await ref
          .read(circleClientProvider)
          .register(_token!, handle, name: ref.read(profileProvider).name);
    } catch (_) {
      // Best-effort — the next refresh / handle change will retry.
    }
  }

  Future<void> _refresh() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final client = ref.read(circleClientProvider);
    try {
      await _ensureHandle(client, token);
      state = await client.list(token);
      await _save(); // cache for the next cold start
      // Auto-follow the creator's official account (@roro) once, so a brand-new
      // account's feed isn't empty — they immediately see Roro's shared meals.
      if (await _ensureRoroFollowed(client, token)) {
        state = await client.list(token);
        await _save();
        ref.invalidate(circleFeedProvider); // re-fetch so Roro's posts show now
      }
    } catch (_) {
      // Keep showing the cached list on a transient failure.
    }
  }

  /// One-time, best-effort auto-follow of the creator's official @roro account so
  /// a new user's circle + feed has real content from day one (they immediately
  /// see Roro's shared meals). A later deliberate unfollow sticks (the flag stays
  /// set). Skips Roro's own account and no-ops if already connected. Returns true
  /// if it newly connected, so the caller re-lists.
  Future<bool> _ensureRoroFollowed(CircleClient client, String token) async {
    if (_prefs.getBool(_roroFollowedKey) ?? false) return false;
    final tag = '@$kRoroHandle';
    final already = state.any((f) =>
        f.status == FriendStatus.connected && f.handle.toLowerCase() == tag);
    if (already || _prefs.getString(_myHandleKey) == kRoroHandle) {
      await _prefs.setBool(_roroFollowedKey, true);
      return false;
    }
    try {
      await client.connect(token, kRoroHandle);
      await _prefs.setBool(_roroFollowedKey, true);
      return true;
    } catch (_) {
      return false; // transient — retry on the next launch/refresh
    }
  }

  /// Send an invite by @handle.
  Future<void> invite(String handle) async {
    if (_online) {
      final token = _token!;
      final client = ref.read(circleClientProvider);
      try {
        await _ensureHandle(client, token);
        await client.invite(token, handle.trim());
        await _refresh();
      } catch (_) {}
      return;
    }
    // Offline: optimistic local outgoing invite.
    final h = handle.trim().replaceAll('@', '');
    if (h.isEmpty) return;
    final name = h[0].toUpperCase() + (h.length > 1 ? h.substring(1) : '');
    state = [
      ...state,
      Friend(
        id: 'f_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        handle: '@$h',
        status: FriendStatus.outgoing,
      ),
    ];
    await _save();
  }

  /// Connect directly from a tapped invite link/QR — both sides become
  /// connected immediately (the inviter consented by sharing the link). Returns
  /// the new friend's display name (or `@handle`) on success. Throws
  /// [CircleException] with a user-facing message on failure (online path).
  Future<String?> connect(String handle) async {
    final h = handle.trim().replaceAll('@', '').toLowerCase();
    if (h.isEmpty) throw CircleException('That invite link is invalid.');
    if (_online) {
      final token = _token!;
      final client = ref.read(circleClientProvider);
      await _ensureHandle(client, token);
      final name = await client.connect(token, h);
      await _refresh();
      // A new connection changes who's in the feed → refresh it so the friend's
      // shared meals appear right away (not only after a manual pull-to-refresh).
      ref.invalidate(circleFeedProvider);
      return name ?? '@$h';
    }
    // Offline: optimistic local connected friend so the flow still demos. The
    // official @roro is a REAL account whose meals come from the feed, so never
    // fabricate a mock trend for him (that's the "fake metrics" users saw when
    // tapping his story) — add a plain entry; the strip sources his real photo +
    // posts from the feed.
    if (!state.any((f) => f.handle == '@$h')) {
      final display = h[0].toUpperCase() + (h.length > 1 ? h.substring(1) : '');
      final id = 'f_${DateTime.now().microsecondsSinceEpoch}';
      state = [
        ...state,
        h == kRoroHandle
            ? Friend(
                id: id,
                name: display,
                handle: '@$h',
                status: FriendStatus.connected,
              )
            : Friend.sample(
                id: id,
                name: display,
                handle: '@$h',
                status: FriendStatus.connected,
                seed: h.hashCode,
              ),
      ];
      await _save();
    }
    return '@$h';
  }

  /// Accept an incoming invite — they become connected (with their trend).
  Future<void> accept(String id) async {
    if (_online) {
      try {
        await ref.read(circleClientProvider).respond(_token!, id, 'accept');
        await _refresh();
        ref.invalidate(circleFeedProvider); // new connection → refresh the feed
      } catch (_) {}
      return;
    }
    state = [
      for (final f in state)
        if (f.id == id)
          (f.adherence7d.isEmpty
              ? Friend.sample(
                  id: f.id,
                  name: f.name,
                  handle: f.handle,
                  status: FriendStatus.connected,
                  seed: f.id.hashCode,
                )
              : f.copyWith(status: FriendStatus.connected))
        else
          f,
    ];
    await _save();
  }

  Future<void> remove(String id) async {
    if (_online) {
      try {
        await ref.read(circleClientProvider).remove(_token!, id);
        await _refresh();
      } catch (_) {}
      return;
    }
    state = [
      for (final f in state)
        if (f.id != id) f,
    ];
    await _save();
  }
}

/// Outcome of [CircleNotifier.setHandle].
enum SetHandleResult { ok, taken, invalid, error }

/// The user's own Circle @handle (bare, no leading @), or null if unset.
/// Backed by prefs; written through [CircleNotifier] so the UI reacts.
class MyCircleHandleNotifier extends Notifier<String?> {
  @override
  String? build() {
    final h = ref
        .read(sharedPreferencesProvider)
        .getString(CircleNotifier._myHandleKey);
    return (h == null || h.isEmpty) ? null : h;
  }

  void set(String? handle) {
    state = (handle == null || handle.isEmpty) ? null : handle;
  }
}

final myCircleHandleProvider =
    NotifierProvider<MyCircleHandleNotifier, String?>(
      MyCircleHandleNotifier.new,
    );

final circleClientProvider = Provider<CircleClient>(
  (ref) => CircleClient(baseUrl: proxyBaseUrl),
);

final circleProvider = NotifierProvider<CircleNotifier, List<Friend>>(
  CircleNotifier.new,
);

// ---- Official Circle accounts (first-party, not peer friends) ----
// Eva is the built-in AI coach, shown as a followable member (her daily lesson +
// a tip card). Roro is the creator's REAL @handle, only ever *recommended* to
// follow (opt-in via the normal one-tap connect — never auto-followed, so no
// data-sharing happens without the user choosing it).

/// The creator's real Circle @handle, surfaced under "Suggested to follow".
const String kRoroHandle = 'roro';

/// The second official account's @handle ("Eva"). A DISTINCT account from Roro —
/// her photo/text posts are surfaced in the feed (server-side) and badged
/// "Official" the same way Roro's are.
const String kEvaHandle = 'eva';

/// True when [handle] (with or without a leading @) is one of the official
/// accounts (Roro or Eva), so the feed/strip can show the verified badge.
bool isOfficialHandle(String? handle) {
  final h = (handle ?? '').replaceFirst('@', '').toLowerCase();
  return h == kRoroHandle || h == kEvaHandle;
}

/// Whether the user follows Eva (the built-in AI coach). Default **true** — she's
/// part of a new circle. Unfollowing hides her story; she then appears under
/// "Suggested" to re-follow. Persisted.
class EvaFollowedNotifier extends Notifier<bool> {
  static const _key = 'eva_followed';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_key) ?? true;

  Future<void> setFollowed(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final evaFollowedProvider = NotifierProvider<EvaFollowedNotifier, bool>(
  EvaFollowedNotifier.new,
);

/// Whether the user has deliberately **unfollowed** the official @roro. Mirrors
/// [evaFollowedProvider] so the official account is unfollowable the same way Eva
/// is — even signed out (where there's no friend-graph edge): set this and the
/// strip, feed, and Manage all hide him; clear it to re-follow. Persisted.
class RoroHiddenNotifier extends Notifier<bool> {
  static const _key = 'circle_roro_hidden';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> setHidden(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final roroHiddenProvider = NotifierProvider<RoroHiddenNotifier, bool>(
  RoroHiddenNotifier.new,
);

/// True once the user is mutually connected to the creator's account (@roro), so
/// the "Suggested: Roro" recommendation can hide itself. Also true when the
/// viewer **is** the creator (their own handle is @roro) — never suggest someone
/// follow themselves. False once they deliberately unfollow ([roroHiddenProvider]).
final followsRoroProvider = Provider<bool>((ref) {
  final mine = ref.watch(myCircleHandleProvider)?.toLowerCase();
  if (mine == kRoroHandle) return true;
  if (ref.watch(roroHiddenProvider)) return false; // deliberately unfollowed
  final target = '@$kRoroHandle';
  final inGraph = ref.watch(circleProvider).any(
    (f) => f.status == FriendStatus.connected &&
        f.handle.toLowerCase() == target,
  );
  if (inGraph) return true;
  // The official @roro feed is shown to everyone — including signed-out users —
  // and the strip surfaces him from it (see circle_strip `_officialRoro`). If his
  // posts are present the user effectively follows him, so keep the follow-state
  // consistent with what's actually on screen (no "you don't follow Roro" while
  // his story + feed are right there).
  final feed = ref.watch(circleFeedProvider).asData?.value ?? const <CirclePost>[];
  return feed.any((p) => (p.authorHandle ?? '').toLowerCase() == kRoroHandle);
});

// ---- Circle photo feed (share a scanned meal; friends react) ----

/// Emoji reactions offered in the circle feed.
const List<String> circleReactionEmojis = ['👍', '❤️', '😋', '🔥', '👏'];

final postsClientProvider = Provider<PostsClient>(
  (ref) => PostsClient(baseUrl: proxyBaseUrl),
);

/// Durable full-res meal-photo store (S3 via presigned URLs). Uploads the
/// original on save; hydrates the local cache for the Food story on a new
/// device / after a reinstall. Best-effort; falls back to the synced thumbnail.
final mealPhotoStoreProvider = Provider<MealPhotoStore>(
  (ref) => MealPhotoStore(
    baseUrl: proxyBaseUrl,
    photos: ref.read(mealPhotosProvider),
  ),
);

/// The viewer's circle feed (their friends' + own active posts). Empty when
/// signed out or no proxy is configured.
final circleFeedProvider = FutureProvider<List<CirclePost>>((ref) async {
  if (proxyBaseUrl.isEmpty) return const [];
  final token = ref.watch(authProvider)?.token;
  final client = ref.read(postsClientProvider);
  // Signed in → your personal feed (friends' + your own posts). Signed out → the
  // public official-creator feed (shared app token) so a brand-new user still
  // sees real photos in the circle before logging in.
  if (token != null && token.isNotEmpty) return client.feed(token);
  if (proxyAppToken.isEmpty) return const [];
  return client.officialFeed(proxyAppToken);
});

/// The comment threads visible to the viewer for one post — every commenter's
/// thread if they own the post, otherwise just their own private thread (empty
/// until they comment). Keyed by (postId, authorId) so a post's comment sheet
/// refetches only that post. Empty when signed out / no proxy.
// Not autoDispose: the comments stay cached after the sheet closes, so reopening
// is instant (the sheet shows the cached threads, then silently refreshes).
final postCommentsProvider =
    FutureProvider.family<CircleComments, ({String postId, String authorId})>((
  ref,
  arg,
) async {
  final token = ref.watch(authProvider)?.token;
  if (proxyBaseUrl.isEmpty || token == null || token.isEmpty) {
    return const CircleComments();
  }
  return ref.read(postsClientProvider).comments(
        postId: arg.postId,
        postAuthorId: arg.authorId,
        token: token,
      );
});

/// Posts the viewer has locally hidden via Report or Unfollow. Persisted so a
/// reported/blocked post stays gone across launches even though the feed itself
/// is server-driven. Apple Guideline 1.2 (UGC safety): reported content must
/// disappear for the reporter immediately, and blocking a user must hide them.
class HiddenPostsNotifier extends Notifier<Set<String>> {
  static const _key = 'circle_hidden_posts';

  @override
  Set<String> build() {
    final raw = ref.read(sharedPreferencesProvider).getStringList(_key);
    return raw == null ? <String>{} : raw.toSet();
  }

  Future<void> hide(String postId) async {
    if (postId.isEmpty || state.contains(postId)) return;
    state = {...state, postId};
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, state.toList());
  }
}

final hiddenPostsProvider =
    NotifierProvider<HiddenPostsNotifier, Set<String>>(HiddenPostsNotifier.new);

/// Story keys ("you:…", "eva:…") the user has already viewed, so the strip shows
/// a grey "seen" ring instead of the colourful one (Instagram-style). The key
/// embeds the content (newest meal + count / the day's Eva lesson), so fresh
/// content resets the ring to unseen.
class SeenStoriesNotifier extends Notifier<Set<String>> {
  static const _key = 'circle_seen_stories';

  @override
  Set<String> build() {
    final raw = ref.read(sharedPreferencesProvider).getStringList(_key);
    return raw == null ? <String>{} : raw.toSet();
  }

  Future<void> markSeen(String key) async {
    if (key.isEmpty || state.contains(key)) return;
    state = {...state, key};
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, state.toList());
  }
}

final seenStoriesProvider =
    NotifierProvider<SeenStoriesNotifier, Set<String>>(SeenStoriesNotifier.new);

/// Whether to notify the user when a friend shares a meal. Managed alongside the
/// food reminders (same notification permission + service). **On by default**;
/// the OS notification permission is requested lazily the first time there's real
/// circle activity (see `home_shell._checkCircleActivity`). Persisted once the
/// user toggles it, so an explicit "off" sticks.
class CircleNotifyNotifier extends Notifier<bool> {
  static const _prefsKey = 'circle_notify_enabled';

  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_prefsKey) ?? true;

  /// Turn the circle-activity **intent** on (persisted) and ask the OS for
  /// notification permission. Like meal reminders, the intent is independent of
  /// the grant — it stays on even if denied so the CTA can prompt later; returns
  /// whether the OS granted it.
  Future<bool> enable() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_prefsKey, true);
    return ref.read(notificationServiceProvider).requestPermission();
  }

  Future<void> disable() async {
    state = false;
    await ref.read(sharedPreferencesProvider).setBool(_prefsKey, false);
  }
}

final circleNotifyProvider = NotifierProvider<CircleNotifyNotifier, bool>(
  CircleNotifyNotifier.new,
);

/// Whether to be pushed when a friend **comments on / replies to / @-mentions**
/// you in the Circle. Independent of the friend-meal toggle. Persisted locally
/// AND synced to the server (which gates the comment push), so muting actually
/// stops the notification rather than just hiding a local switch. Default on.
class CommentNotifyNotifier extends Notifier<bool> {
  static const _prefsKey = 'comment_notify_enabled';

  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_prefsKey) ?? true;

  Future<bool> enable() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_prefsKey, true);
    await _sync(true);
    return ref.read(notificationServiceProvider).requestPermission();
  }

  Future<void> disable() async {
    state = false;
    await ref.read(sharedPreferencesProvider).setBool(_prefsKey, false);
    await _sync(false);
  }

  /// Best-effort push of the preference to the server (gates comment pushes).
  /// Silent on failure — re-synced on the next toggle.
  Future<void> _sync(bool comments) async {
    final token = ref.read(authProvider)?.token;
    if (token == null || token.isEmpty || proxyBaseUrl.isEmpty) return;
    try {
      await ref
          .read(circleClientProvider)
          .setNotifyPrefs(token, comments: comments);
    } catch (_) {
      /* best-effort — server defaults to ON, so a missed mute retries next toggle */
    }
  }
}

final commentNotifyProvider = NotifierProvider<CommentNotifyNotifier, bool>(
  CommentNotifyNotifier.new,
);

/// Whether the OS currently permits notifications (a status check, no prompt).
/// Drives the "turn on notifications" call-to-action: defaulting the in-app
/// circle-notify toggle on is meaningless if iOS notifications are off, so we
/// surface a strong CTA when this is false. Refresh after requesting permission
/// or when the app resumes (the user may have changed it in iOS Settings).
final notificationsAllowedProvider = FutureProvider<bool>(
  (ref) => ref.read(notificationServiceProvider).hasPermission(),
);

/// Whether we've already shown the OS notification prompt once. iOS only shows
/// its system prompt the first time, so after that the CTA switches to a
/// one-tap "Open Settings" instead of a prompt that won't reappear.
class NotificationAskedNotifier extends Notifier<bool> {
  static const _key = 'notif_permission_asked';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> markAsked() async {
    if (state) return;
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_key, true);
  }
}

final notificationAskedProvider =
    NotifierProvider<NotificationAskedNotifier, bool>(
      NotificationAskedNotifier.new,
    );

/// A circle "something happened" event the UI turns into a notification + banner.
enum CircleEventKind { request, accepted, posted, reaction }

class CircleEvent {
  const CircleEvent(this.kind, this.name, {this.detail});
  final CircleEventKind kind;
  final String name; // the other person's display name
  final String? detail; // dish name (posted) or emoji (reaction)
}

/// Snapshot of the circle state we compare against between polls.
class CircleSnapshot {
  const CircleSnapshot({
    required this.statuses,
    required this.reactions,
    required this.lastPostMs,
  });
  final Map<String, String> statuses; // userId -> connected|incoming|outgoing
  final Map<String, int> reactions; // my postId -> total reaction count
  final int lastPostMs; // newest friend-post timestamp seen
}

/// Pure: diff the latest circle state against [prev] into notifiable events.
/// [prev] is null on the first ever check (then we only set a baseline, no
/// events — so we never notify for the existing backlog).
({List<CircleEvent> events, CircleSnapshot snapshot}) diffCircleActivity({
  required List<Friend> friends,
  required List<CirclePost> feed,
  required CircleSnapshot? prev,
}) {
  final statuses = {for (final f in friends) f.id: f.status.name};
  final myPosts = feed.where((p) => p.mine);
  final reactions = {
    for (final p in myPosts)
      p.postId: p.reactions.values.fold<int>(0, (a, b) => a + b),
  };
  final maxPostMs = feed
      .where((p) => !p.mine)
      .fold<int>(0, (m, p) => p.createdAt > m ? p.createdAt : m);
  final snapshot = CircleSnapshot(
    statuses: statuses,
    reactions: reactions,
    lastPostMs: maxPostMs > (prev?.lastPostMs ?? 0)
        ? maxPostMs
        : (prev?.lastPostMs ?? 0),
  );
  if (prev == null) return (events: const <CircleEvent>[], snapshot: snapshot);

  final events = <CircleEvent>[];
  // Friend requests received / your requests accepted.
  for (final f in friends) {
    final was = prev.statuses[f.id];
    if (f.status == FriendStatus.incoming && was != 'incoming') {
      events.add(CircleEvent(CircleEventKind.request, f.name));
    } else if (f.status == FriendStatus.connected && was == 'outgoing') {
      events.add(CircleEvent(CircleEventKind.accepted, f.name));
    }
  }
  // Friends' new meals.
  for (final p in freshFriendPosts(feed, prev.lastPostMs)) {
    events.add(CircleEvent(
      CircleEventKind.posted,
      p.authorName ?? p.authorHandle ?? '',
      detail: p.name,
    ));
  }
  // New reactions on your own posts.
  for (final p in myPosts) {
    final now = p.reactions.values.fold<int>(0, (a, b) => a + b);
    if (now > (prev.reactions[p.postId] ?? 0)) {
      final r = p.reactors.isNotEmpty ? p.reactors.last : null;
      events.add(CircleEvent(
        CircleEventKind.reaction,
        r?.name ?? '',
        detail: r?.emoji,
      ));
    }
  }
  return (events: events, snapshot: snapshot);
}

/// Detects circle activity (friend requests, acceptances, friends' meals,
/// reactions on your posts) by diffing `/circle/list` + `/circle/feed` against a
/// stored snapshot. The widget layer turns the events into notifications +
/// in-app banners. Local, no-server-push — instant background delivery is a
/// planned APNs upgrade.
class CircleActivityNotifier extends Notifier<int> {
  static const _snapKey = 'circle_activity_snapshot_v1';

  @override
  int build() => 0;

  Future<List<CircleEvent>> pollActivity() async {
    final token = ref.read(authProvider)?.token;
    if (token == null || token.isEmpty || proxyBaseUrl.isEmpty) return const [];
    final List<Friend> friends;
    final List<CirclePost> feed;
    try {
      friends = await ref.read(circleClientProvider).list(token);
      feed = await ref.read(postsClientProvider).feed(token);
    } catch (_) {
      return const [];
    }
    final prefs = ref.read(sharedPreferencesProvider);
    final prev = _readSnapshot(prefs);
    final result =
        diffCircleActivity(friends: friends, feed: feed, prev: prev);
    await _writeSnapshot(prefs, result.snapshot);
    return result.events;
  }

  CircleSnapshot? _readSnapshot(SharedPreferences prefs) {
    final raw = prefs.getString(_snapKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return CircleSnapshot(
        statuses: (j['statuses'] as Map).map((k, v) => MapEntry('$k', '$v')),
        reactions: (j['reactions'] as Map)
            .map((k, v) => MapEntry('$k', (v as num).toInt())),
        lastPostMs: (j['lastPostMs'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSnapshot(SharedPreferences prefs, CircleSnapshot s) =>
      prefs.setString(
        _snapKey,
        jsonEncode({
          'statuses': s.statuses,
          'reactions': s.reactions,
          'lastPostMs': s.lastPostMs,
        }),
      );
}

/// Pure: friends' posts (not the viewer's own) strictly newer than
/// [lastSeenMs], newest first. The basis for "a friend shared a meal" alerts.
List<CirclePost> freshFriendPosts(List<CirclePost> feed, int lastSeenMs) =>
    feed.where((p) => !p.mine && p.createdAt > lastSeenMs).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

final circleActivityProvider =
    NotifierProvider<CircleActivityNotifier, int>(CircleActivityNotifier.new);

// ---- Owner metrics ----

/// Fire-and-forget product analytics (`open` / `scan` / `purchase` / …) feeding
/// the owner metrics counters (`POST <proxy>/event`). The aggregates are read
/// by the standalone **web dashboard** (`GET <proxy>/metrics`), not the app.
/// No-op when no proxy URL is baked in.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(baseUrl: proxyBaseUrl, appToken: proxyAppToken),
);
