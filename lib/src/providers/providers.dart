import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_key_store.dart';
import '../data/claude_vision_client.dart';
import '../data/food_repository.dart';
import '../data/profile_repository.dart';
import '../models/daily_summary.dart';
import '../models/food_entry.dart';
import '../models/user_profile.dart';

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
final dailySummaryProvider = Provider<DailySummary>((ref) {
  final entries = ref.watch(entriesForSelectedDayProvider);
  final profile = ref.watch(profileProvider);
  final date = ref.watch(selectedDateProvider);
  return DailySummary.compute(date: date, entries: entries, profile: profile);
});

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ---- Phase 3: Claude vision photo analysis ----

final apiKeyStoreProvider = Provider<ApiKeyStore>((ref) => ApiKeyStore());

final claudeVisionClientProvider =
    Provider<ClaudeVisionClient>((ref) => ClaudeVisionClient());

/// The Anthropic API key (null/empty = not set). Loaded from secure storage.
class ApiKeyNotifier extends Notifier<String?> {
  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    state = await ref.read(apiKeyStoreProvider).read();
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
