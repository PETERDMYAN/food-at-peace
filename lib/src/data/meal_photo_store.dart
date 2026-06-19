import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'meal_photos.dart';

/// Client for the durable per-user meal-photo store (`/photo/*`). The full-res
/// original lives in S3 (no expiry); the app uploads + downloads it via presigned
/// URLs (so a big photo never hits the proxy's request limit). The downloaded
/// original is cached into [MealPhotos] so the Food story renders it like a
/// locally-taken photo. All best-effort: a failure just falls back to the synced
/// thumbnail, never blocks the user.
class MealPhotoStore {
  MealPhotoStore({
    required this.baseUrl,
    required this.photos,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final MealPhotos photos;
  final http.Client _http;

  String get _base =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  Map<String, String> _auth(String token) => {'authorization': 'Bearer $token'};

  /// Upload the full-resolution original for [entryId] to S3 (presigned PUT).
  /// No-op on any failure — the synced thumbnail still covers display.
  Future<void> uploadFullRes(
    String entryId,
    Uint8List bytes,
    String token, {
    String mediaType = 'image/jpeg',
  }) async {
    if (_base.isEmpty || token.isEmpty) return;
    try {
      final signed = await _http.post(
        Uri.parse('$_base/photo/put-url'),
        headers: {..._auth(token), 'content-type': 'application/json'},
        body: jsonEncode({'entryId': entryId, 'mediaType': mediaType}),
      );
      if (signed.statusCode != 200) return;
      final url = (jsonDecode(signed.body) as Map)['url'] as String?;
      if (url == null) return;
      await _http.put(
        Uri.parse(url),
        headers: {'content-type': mediaType},
        body: bytes,
      );
    } catch (_) {
      // best-effort
    }
  }

  /// Ensure the full-res original for [entryId] is in the local cache, pulling it
  /// from S3 if missing. Returns true if a local file is available afterwards.
  Future<bool> ensureLocal(String entryId, String token) async {
    final file = File(photos.pathFor(entryId));
    if (await file.exists()) return true;
    if (_base.isEmpty || token.isEmpty) return false;
    try {
      final signed = await _http.post(
        Uri.parse('$_base/photo/get-urls'),
        headers: {..._auth(token), 'content-type': 'application/json'},
        body: jsonEncode({
          'entryIds': [entryId],
        }),
      );
      if (signed.statusCode != 200) return false;
      final urls = (jsonDecode(signed.body) as Map)['urls'] as Map?;
      final url = urls?[entryId] as String?;
      if (url == null) return false;
      final resp = await _http.get(Uri.parse(url));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return false;
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Best-effort remote delete (when the user deletes the meal).
  Future<void> deleteRemote(String entryId, String token) async {
    if (_base.isEmpty || token.isEmpty) return;
    try {
      await _http.post(
        Uri.parse('$_base/photo/delete'),
        headers: {..._auth(token), 'content-type': 'application/json'},
        body: jsonEncode({'entryId': entryId}),
      );
    } catch (_) {
      // best-effort
    }
  }
}
