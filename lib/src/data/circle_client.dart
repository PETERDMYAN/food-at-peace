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

  /// The viewer's own claimed handle (bare, no leading `@`) as the **server**
  /// knows it, or null if this account hasn't claimed one yet. The server is the
  /// source of truth, so a fresh install / new device can recover the *exact*
  /// handle the account already owns instead of re-deriving (and possibly
  /// changing) it. Parsed from the `me` field of the same `/circle/list` payload.
  Future<String?> myHandle(String token) async {
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
    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final me = j['me'];
    if (me is Map) {
      final h = (me['handle'] as String?)?.replaceFirst('@', '').trim();
      if (h != null && h.isNotEmpty) return h;
    }
    return null;
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

  /// Register this device's APNs token so the server can push friend-meal /
  /// request / reaction alerts. Idempotent server-side (deduped by token).
  Future<int> registerDevice(String token, String deviceToken) =>
      _post(token, '/circle/register-device', {'token': deviceToken});

  /// One-tap mutual connect from an invite link/QR. The inviter consented by
  /// sharing the link, so this connects both sides immediately. Idempotent.
  /// Returns the connected friend's display name (or the handle) for the toast.
  Future<String?> connect(String token, String handle) async {
    final http.Response resp;
    try {
      resp = await _http.post(
        Uri.parse('$_base/circle/connect'),
        headers: _headers(token),
        body: jsonEncode({'handle': handle}),
      );
    } catch (_) {
      throw CircleException('Network error — check your connection.');
    }
    if (resp.statusCode != 200) throw CircleException(_messageFrom(resp));
    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    return (j['name'] as String?) ?? (j['handle'] as String?);
  }

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
