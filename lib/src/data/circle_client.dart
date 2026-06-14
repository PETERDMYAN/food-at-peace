import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/friend.dart';

/// Thrown when a Circle backend call fails, carrying the server's user-facing
/// message (e.g. "That handle is taken.").
class CircleException implements Exception {
  CircleException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// HTTP client for the Circle of Food backend (`/circle/*`), authenticated with
/// the app session token. Pure transport — the notifier owns state/caching.
class CircleClient {
  CircleClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  String get _base =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  Map<String, String> _headers(String token) => {
    'content-type': 'application/json',
    'authorization': 'Bearer $token',
  };

  /// The viewer's friends across all statuses (connected/incoming/outgoing),
  /// flattened into [Friend]s (connected ones carry a trend snapshot).
  Future<List<Friend>> list(String token) async {
    final http.Response resp;
    try {
      resp = await _http.get(
        Uri.parse('$_base/circle/list'),
        headers: _headers(token),
      );
    } catch (_) {
      throw CircleException('Network error — check your connection.');
    }
    if (resp.statusCode != 200) throw CircleException(_messageFrom(resp));
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    return [
      for (final key in const ['connected', 'incoming', 'outgoing'])
        for (final f in (j[key] as List? ?? const []))
          Friend.fromJson((f as Map).cast<String, dynamic>()),
    ];
  }

  /// Claims (or updates) the viewer's unique @handle. Returns the server's
  /// status code so the caller can retry on a 409 (handle taken).
  Future<int> register(String token, String handle, {String? name}) => _post(
    token,
    '/circle/register',
    {'handle': handle, 'name': ?name},
  );

  Future<int> invite(String token, String handle) =>
      _post(token, '/circle/invite', {'handle': handle});

  Future<int> respond(String token, String userId, String action) =>
      _post(token, '/circle/respond', {'userId': userId, 'action': action});

  Future<int> remove(String token, String userId) =>
      _post(token, '/circle/remove', {'userId': userId});

  Future<int> _post(String token, String path, Map<String, dynamic> body) async {
    final http.Response resp;
    try {
      resp = await _http.post(
        Uri.parse('$_base$path'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
    } catch (_) {
      throw CircleException('Network error — check your connection.');
    }
    // 409 (handle taken) is surfaced as a status code, not an exception, so the
    // caller can retry with a different handle; other non-200s throw.
    if (resp.statusCode == 409) return 409;
    if (resp.statusCode != 200) throw CircleException(_messageFrom(resp));
    return 200;
  }

  String _messageFrom(http.Response r) {
    try {
      final err = (jsonDecode(r.body) as Map)['error'];
      if (err is Map && err['message'] is String) return err['message'] as String;
    } catch (_) {}
    return 'Circle request failed. Please try again.';
  }
}
