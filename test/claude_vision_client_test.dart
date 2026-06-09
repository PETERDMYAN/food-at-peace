import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_at_peace/src/data/claude_vision_client.dart';

void main() {
  group('buildRequestBody', () {
    final body = buildRequestBody(
      base64Image: 'AAAA',
      mediaType: 'image/jpeg',
      model: 'claude-sonnet-4-6',
    );

    test('targets the model and forces the log_food tool', () {
      expect(body['model'], 'claude-sonnet-4-6');
      expect((body['tool_choice'] as Map)['name'], 'log_food');
      expect(((body['tools'] as List).first as Map)['name'], 'log_food');
    });

    test('carries the image block and a cached system prompt', () {
      final content =
          ((body['messages'] as List).first as Map)['content'] as List;
      final image =
          content.firstWhere((b) => (b as Map)['type'] == 'image') as Map;
      final source = image['source'] as Map;
      expect(source['media_type'], 'image/jpeg');
      expect(source['data'], 'AAAA');

      final system = (body['system'] as List).first as Map;
      expect(system['cache_control'], {'type': 'ephemeral'});
    });
  });

  group('parseFoodAnalysis', () {
    test('reads the log_food tool_use input', () {
      final analysis = parseFoodAnalysis({
        'stop_reason': 'tool_use',
        'content': [
          {'type': 'text', 'text': 'Here is the estimate.'},
          {
            'type': 'tool_use',
            'name': 'log_food',
            'input': {
              'name': 'Chicken salad',
              'calories': 420,
              'proteinG': 38,
              'satFatG': 4,
              'portionDescription': '1 bowl (~300 g)',
              'confidence': 'medium',
              'items': ['chicken', 'lettuce'],
            },
          },
        ],
      });
      expect(analysis.name, 'Chicken salad');
      expect(analysis.calories, 420);
      expect(analysis.proteinG, 38);
      expect(analysis.satFatG, 4);
      expect(analysis.confidence, 'medium');
      expect(analysis.items, ['chicken', 'lettuce']);
    });

    test('throws when no tool_use block is present', () {
      expect(
        () => parseFoodAnalysis({
          'stop_reason': 'end_turn',
          'content': [
            {'type': 'text', 'text': 'I cannot tell.'},
          ],
        }),
        throwsA(isA<ClaudeApiException>()),
      );
    });
  });

  group('analyze (mocked HTTP)', () {
    test('sends auth headers and parses a 200 tool_use response', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'stop_reason': 'tool_use',
            'content': [
              {
                'type': 'tool_use',
                'name': 'log_food',
                'input': {
                  'name': 'Toast',
                  'calories': 120,
                  'proteinG': 4,
                  'satFatG': 1,
                  'portionDescription': '1 slice',
                  'confidence': 'high',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ClaudeVisionClient(httpClient: mock);
      final result = await client.analyze(
        apiKey: 'sk-ant-test',
        imageBytes: Uint8List.fromList([1, 2, 3]),
        mediaType: 'image/jpeg',
      );

      expect(result.name, 'Toast');
      expect(captured.headers['x-api-key'], 'sk-ant-test');
      expect(captured.headers['anthropic-version'], '2023-06-01');
    });

    test('maps a 401 to a friendly error', () async {
      final mock = MockClient(
        (req) async => http.Response(
          jsonEncode({
            'error': {'type': 'authentication_error', 'message': 'invalid key'},
          }),
          401,
        ),
      );
      final client = ClaudeVisionClient(httpClient: mock);
      expect(
        () => client.analyze(
          apiKey: 'bad',
          imageBytes: Uint8List.fromList([1]),
          mediaType: 'image/jpeg',
        ),
        throwsA(
          isA<ClaudeApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });
  });
}
