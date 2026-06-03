import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// Persists the user's profile as a JSON blob in shared_preferences.
class ProfileRepository {
  ProfileRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'user_profile_v1';

  UserProfile load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return UserProfile.defaultProfile;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(UserProfile profile) =>
      _prefs.setString(_key, jsonEncode(profile.toJson()));
}
