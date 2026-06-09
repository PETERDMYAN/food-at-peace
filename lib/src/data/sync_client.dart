import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sync_record.dart';
import 'auth_client.dart'; // reuse AuthException

/// Thrown when the session token is rejected (expired / invalid). The caller
/// should sign the user out.
class SessionExpired implements Exception {}

/// The parsed `/sync` response: the server's clock plus the records changed
/// since the client's cursor.
class SyncPullResult {
  const SyncPullResult({
    required this.serverTimeMs,
    required this.food,
    required this.weight,
    required this.profile,
  });

  final int serverTimeMs;
  final List<SyncRecord> food;
  final List<SyncRecord> weight;
  final SyncRecord? profile;
}

/// Talks to the backend `/sync` endpoint (see `backend/src/sync.py`): pushes the
/// records the client changed since [sinceMs], returns everything the server has
/// changed since then. Pure HTTP — unit-tested with a mock client.
class SyncClient {
  SyncClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Uri get endpoint {
    final base =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$base/sync');
  }

  Future<SyncPullResult> sync({
    required String token,
    required int sinceMs,
    required List<SyncRecord> food,
    required List<SyncRecord> weight,
    SyncRecord? profile,
  }) async {
    final http.Response resp;
    try {
      resp = await _http.post(
        endpoint,
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'since': sinceMs,
          'changes': {
            'food': [for (final r in food) r.toJson()],
            'weight': [for (final r in weight) r.toJson()],
            'profile': profile?.toJson(),
          },
        }),
      );
    } catch (_) {
      throw AuthException('Network error — check your connection.');
    }

    if (resp.statusCode == 401) throw SessionExpired();
    if (resp.statusCode != 200) throw _syncError(resp.statusCode, resp.body);

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final changes =
        (json['changes'] as Map?)?.cast<String, dynamic>() ?? const {};
    List<SyncRecord> recs(String key) => ((changes[key] as List?) ?? const [])
        .map((e) => SyncRecord.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final profileJson = changes['profile'];
    return SyncPullResult(
      serverTimeMs: (json['serverTime'] as num?)?.toInt() ?? 0,
      food: recs('food'),
      weight: recs('weight'),
      profile: profileJson is Map
          ? SyncRecord.fromJson(profileJson.cast<String, dynamic>())
          : null,
    );
  }
}

AuthException _syncError(int statusCode, String body) {
  String message;
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final err = json['error'];
    message = (err is Map && err['message'] is String)
        ? err['message'] as String
        : 'Sync failed. Please try again.';
  } catch (_) {
    message = 'Sync failed. Please try again.';
  }
  return AuthException(message, statusCode: statusCode);
}
