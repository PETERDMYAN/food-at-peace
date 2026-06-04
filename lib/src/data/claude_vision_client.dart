import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/food_analysis.dart';

/// Error from the Anthropic API, with a user-friendly [message].
class ClaudeApiException implements Exception {
  ClaudeApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ClaudeApiException($statusCode): $message';

  factory ClaudeApiException.fromResponse(int statusCode, String body) {
    String apiMessage;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final err = json['error'];
      apiMessage = (err is Map && err['message'] is String)
          ? err['message'] as String
          : 'Request failed ($statusCode).';
    } catch (_) {
      apiMessage = 'Request failed ($statusCode).';
    }
    final friendly = switch (statusCode) {
      401 => 'Invalid API key — check it in Settings.',
      403 => 'This API key lacks access. Check your Anthropic plan/credit.',
      413 => 'That image is too large. Try another photo.',
      429 => 'Rate limited — wait a moment and try again.',
      >= 500 => 'Anthropic service error — try again shortly.',
      _ => apiMessage,
    };
    return ClaudeApiException(friendly, statusCode: statusCode);
  }
}

/// Calls the Anthropic Messages API with a food photo and returns a structured
/// [FoodAnalysis]. Structured output is guaranteed by forcing the `log_food`
/// tool via `tool_choice`.
class ClaudeVisionClient {
  ClaudeVisionClient({http.Client? httpClient, this.model = defaultModel})
      : _http = httpClient ?? http.Client();

  /// Good vision + reasoning at moderate cost. Swap to 'claude-haiku-4-5'
  /// for the cheapest option.
  static const String defaultModel = 'claude-sonnet-4-6';
  static const String toolName = 'log_food';
  static const String _endpoint = 'https://api.anthropic.com/v1/messages';

  final http.Client _http;
  final String model;

  Future<FoodAnalysis> analyze({
    required String apiKey,
    required Uint8List imageBytes,
    required String mediaType,
  }) async {
    final body = buildRequestBody(
      base64Image: base64Encode(imageBytes),
      mediaType: mediaType,
      model: model,
    );

    final http.Response resp;
    try {
      resp = await _http.post(
        Uri.parse(_endpoint),
        headers: {
          'content-type': 'application/json',
          'anthropic-version': '2023-06-01',
          // Allows the call to work from a browser too (harmless on mobile).
          'anthropic-dangerous-direct-browser-access': 'true',
          'x-api-key': apiKey,
        },
        body: jsonEncode(body),
      );
    } catch (_) {
      throw ClaudeApiException('Network error — check your connection.');
    }

    if (resp.statusCode != 200) {
      throw ClaudeApiException.fromResponse(resp.statusCode, resp.body);
    }
    return parseFoodAnalysis(jsonDecode(resp.body) as Map<String, dynamic>);
  }
}

const String _systemPrompt =
    'You are a nutrition estimator. Look at the food photo and estimate the '
    'nutrition for the ENTIRE portion visible. Use typical recipes and serving '
    'sizes, and be realistic. If unsure about the portion, state your '
    'assumption in portionDescription and lower your confidence. Always call '
    'the log_food tool with your best numeric estimate; never refuse to '
    'estimate just because you cannot be exact.';

const String _userPrompt =
    'Estimate the calories, protein, and saturated fat for the food in this '
    'photo, then call log_food.';

/// Builds the Messages API request body. Pure function — unit-tested.
Map<String, dynamic> buildRequestBody({
  required String base64Image,
  required String mediaType,
  required String model,
}) {
  return {
    'model': model,
    'max_tokens': 1024,
    // Stable prefix (tools + system) is cache_control'd; the image is the
    // volatile suffix in messages, so it never breaks the cached prefix.
    'system': [
      {
        'type': 'text',
        'text': _systemPrompt,
        'cache_control': {'type': 'ephemeral'},
      }
    ],
    'tools': [
      {
        'name': ClaudeVisionClient.toolName,
        'description':
            'Record the nutrition estimate for the food shown in the image.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description':
                  'Short name of the dish, e.g. "Chicken Caesar salad".',
            },
            'items': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Main components you identified.',
            },
            'calories': {
              'type': 'number',
              'description':
                  'Estimated total calories (kcal) for the full portion shown.',
            },
            'proteinG': {
              'type': 'number',
              'description':
                  'Estimated grams of protein for the full portion.',
            },
            'satFatG': {
              'type': 'number',
              'description':
                  'Estimated grams of saturated fat for the full portion.',
            },
            'portionDescription': {
              'type': 'string',
              'description':
                  'The portion size you assumed, e.g. "1 bowl (~350 g)".',
            },
            'confidence': {
              'type': 'string',
              'enum': ['low', 'medium', 'high'],
              'description': 'Your confidence in this estimate.',
            },
            'notes': {
              'type': 'string',
              'description': 'Optional caveats or assumptions.',
            },
          },
          'required': [
            'name',
            'calories',
            'proteinG',
            'satFatG',
            'portionDescription',
            'confidence',
          ],
        },
      }
    ],
    'tool_choice': {'type': 'tool', 'name': ClaudeVisionClient.toolName},
    'messages': [
      {
        'role': 'user',
        'content': [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': mediaType,
              'data': base64Image,
            },
          },
          {'type': 'text', 'text': _userPrompt},
        ],
      }
    ],
  };
}

/// Extracts the forced `log_food` tool input from a Messages API response.
/// Pure function — unit-tested.
FoodAnalysis parseFoodAnalysis(Map<String, dynamic> response) {
  final content = response['content'];
  if (content is List) {
    for (final block in content) {
      if (block is Map &&
          block['type'] == 'tool_use' &&
          block['name'] == ClaudeVisionClient.toolName &&
          block['input'] is Map) {
        return FoodAnalysis.fromToolInput(
          (block['input'] as Map).cast<String, dynamic>(),
        );
      }
    }
  }
  final stop = response['stop_reason'];
  throw ClaudeApiException(
    'Claude did not return an estimate (stop reason: $stop). Try another photo.',
  );
}
