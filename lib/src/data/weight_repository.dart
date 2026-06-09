import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/weight_entry.dart';

/// Persists the user's logged weight history in shared preferences.
class WeightRepository {
  WeightRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'weight_entries';

  List<WeightEntry> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => WeightEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAll(List<WeightEntry> entries) => _prefs.setString(
    _key,
    jsonEncode(entries.map((e) => e.toJson()).toList()),
  );
}
