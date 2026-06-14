import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/food_analysis.dart';
import 'claude_vision_client.dart';

/// Turns a food photo into a [FoodAnalysis]. Two implementations:
/// [DirectAnalyzer] (the user brought their own Anthropic key — call Anthropic
/// directly) and [ProxyAnalyzer] (the default — call our AWS proxy, which holds
/// the key server-side). Both throw [ClaudeApiException] on failure so the UI
/// can handle them the same way.
abstract class FoodPhotoAnalyzer {
  /// [lang] is the app's selected locale code ('en' / 'zh'); when set, the AI
  /// writes the human-readable fields (name, items, portion, notes) in that
  /// language. Null/'en' keeps the default English output.
  Future<FoodAnalysis> analyze({
    required Uint8List imageBytes,
    required String mediaType,
    String? lang,
  });
}

/// Bring-your-own-key path: delegates to [ClaudeVisionClient] with the key the
/// user saved in Settings.
class DirectAnalyzer implements FoodPhotoAnalyzer {
  DirectAnalyzer(this._client, this._apiKey);

  final ClaudeVisionClient _client;
  final String _apiKey;

  @override
  Future<FoodAnalysis> analyze({
    required Uint8List imageBytes,
    required String mediaType,
    String? lang,
  }) {
    return _client.analyze(
      apiKey: _apiKey,
      imageBytes: imageBytes,
      mediaType: mediaType,
      lang: lang,
    );
  }
}

/// Default path: POSTs the photo to the AWS vision proxy, which holds the
/// Anthropic key. The proxy returns the flat `log_food` tool input, so we
/// deserialize straight into a [FoodAnalysis]. On failure it returns
/// `{"error": {"message": "…"}}`; we surface that message verbatim (the proxy
/// already crafts user-appropriate copy for the no-key path).
class ProxyAnalyzer implements FoodPhotoAnalyzer {
  ProxyAnalyzer({
    required this.baseUrl,
    required this.appToken,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String appToken;
  final http.Client _http;

  Uri get endpoint {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$base/analyze');
  }

  @override
  Future<FoodAnalysis> analyze({
    required Uint8List imageBytes,
    required String mediaType,
    String? lang,
  }) async {
    final http.Response resp;
    try {
      resp = await _http.post(
        endpoint,
        headers: {'content-type': 'application/json', 'x-app-token': appToken},
        body: jsonEncode({
          'image': base64Encode(imageBytes),
          'mediaType': mediaType,
          // Omitted when null so the request shape is unchanged for callers
          // that don't pass a locale (and the backend defaults to English).
          'lang': ?lang,
        }),
      );
    } catch (_) {
      throw ClaudeApiException('Network error — check your connection.');
    }

    if (resp.statusCode != 200) {
      throw _proxyError(resp.statusCode, resp.body);
    }
    return FoodAnalysis.fromToolInput(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }
}

/// Surfaces the proxy's `{"error": {"message": …}}` body as a
/// [ClaudeApiException]. Unlike [ClaudeApiException.fromResponse], it does not
/// rewrite the message by status code — the proxy owns the wording so the
/// no-key path never tells the user to "check it in Settings".
ClaudeApiException _proxyError(int statusCode, String body) {
  String message;
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final err = json['error'];
    message = (err is Map && err['message'] is String)
        ? err['message'] as String
        : 'Analysis failed. Please try again.';
  } catch (_) {
    message = 'Analysis failed. Please try again.';
  }
  return ClaudeApiException(message, statusCode: statusCode);
}
