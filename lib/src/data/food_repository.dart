import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/food_entry.dart';

/// Storage for food entries. Reads are synchronous (the data is small and
/// already in memory); writes persist asynchronously.
///
/// This interface is deliberately storage-agnostic so we can swap the
/// shared_preferences implementation for Drift/SQLite later without touching
/// the UI or providers.
abstract class FoodRepository {
  List<FoodEntry> loadAll();
  Future<void> saveAll(List<FoodEntry> entries);
}

/// Default implementation: a JSON blob in shared_preferences.
class SharedPrefsFoodRepository implements FoodRepository {
  SharedPrefsFoodRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'food_entries_v1';

  @override
  List<FoodEntry> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => FoodEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveAll(List<FoodEntry> entries) {
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    return _prefs.setString(_key, raw);
  }
}

/// In-memory implementation for tests and the web preview.
class InMemoryFoodRepository implements FoodRepository {
  InMemoryFoodRepository([List<FoodEntry>? seed]) : _entries = [...?seed];

  List<FoodEntry> _entries;

  @override
  List<FoodEntry> loadAll() => List.unmodifiable(_entries);

  @override
  Future<void> saveAll(List<FoodEntry> entries) async {
    _entries = [...entries];
  }
}
