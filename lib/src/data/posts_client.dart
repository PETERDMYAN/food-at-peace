import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/circle_post.dart';

class PostsException implements Exception {
  PostsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// HTTP client for the Circle photo feed (`/circle/post|feed|react`),
/// authenticated with the app session token.
class PostsClient {
  PostsClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  String get _base =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  Map<String, String> _headers(String token, {bool json = true}) => {
    if (json) 'content-type': 'application/json',
    'authorization': 'Bearer $token',
  };

  /// Share a scanned food photo to the circle (lives 3 days).
  Future<void> post({
    required Uint8List imageBytes,
    required String mediaType,
    required String name,
    required int calories,
    required String token,
  }) async {
    final resp = await _http.post(
      Uri.parse('$_base/circle/post'),
      headers: _headers(token),
      body: jsonEncode({
        'image': base64Encode(imageBytes),
        'mediaType': mediaType,
        'name': name,
        'calories': calories,
      }),
    );
    if (resp.statusCode != 200) throw PostsException(_messageFrom(resp));
  }

  /// The viewer's circle feed: their friends' + own active posts.
  Future<List<CirclePost>> feed(String token) async {
    final resp = await _http.get(
      Uri.parse('$_base/circle/feed'),
      headers: _headers(token, json: false),
    );
    if (resp.statusCode != 200) throw PostsException(_messageFrom(resp));
    return _parseFeed(resp);
  }

  /// The public official-creator feed — no account needed (the shared app token
  /// only), used when signed out so a new user still sees real photos in the
  /// circle before logging in. Same `/circle/feed` route, app-token auth.
  Future<List<CirclePost>> officialFeed(String appToken) async {
    final resp = await _http.get(
      Uri.parse('$_base/circle/feed'),
      headers: {'x-app-token': appToken},
    );
    if (resp.statusCode != 200) throw PostsException(_messageFrom(resp));
    return _parseFeed(resp);
  }

  List<CirclePost> _parseFeed(http.Response resp) {
    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final p in (j['posts'] as List? ?? const []))
        CirclePost.fromJson((p as Map).cast<String, dynamic>()),
    ];
  }

  /// Toggle an emoji reaction on a post; returns the viewer's resulting emoji
  /// (null if cleared).
  Future<String?> react({
    required String postId,
    required String emoji,
    required String token,
  }) async {
    final resp = await _http.post(
      Uri.parse('$_base/circle/react'),
      headers: _headers(token),
      body: jsonEncode({'postId': postId, 'emoji': emoji}),
    );
    if (resp.statusCode != 200) throw PostsException(_messageFrom(resp));
    return (jsonDecode(utf8.decode(resp.bodyBytes)) as Map)['myReaction']
        as String?;
  }

  String _messageFrom(http.Response r) {
    try {
      final err = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['error'];
      if (err is Map && err['message'] is String) return err['message'] as String;
    } catch (_) {}
    return 'Circle feed request failed. Please try again.';
  }
}
