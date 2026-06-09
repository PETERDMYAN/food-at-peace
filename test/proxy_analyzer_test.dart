import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_at_peace/src/data/claude_vision_client.dart';
import 'package:food_at_peace/src/data/food_photo_analyzer.dart';

void main() {
  group('ProxyAnalyzer', () {
    test('POSTs to <base>/analyze with the app token and parses a 200', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'name': 'Toast',
            'calories': 120,
            'proteinG': 4,
            'satFatG': 1,
            'portionDescription': '1 slice',
            'confidence': 'high',
            'items': ['bread'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final analyzer = ProxyAnalyzer(
        baseUrl: 'https://api.example.com/', // trailing slash on purpose
        appToken: 'app-token-123',
        httpClient: mock,
      );
      final result = await analyzer.analyze(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        mediaType: 'image/jpeg',
      );

      expect(result.name, 'Toast');
      expect(result.calories, 120);
      expect(result.items, ['bread']);

      // Endpoint is normalized to a single /analyze regardless of trailing slash.
      expect(captured.url.toString(), 'https://api.example.com/analyze');
      expect(captured.method, 'POST');
      expect(captured.headers['x-app-token'], 'app-token-123');

      final sent = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(sent['mediaType'], 'image/jpeg');
      expect(sent['image'], base64Encode([1, 2, 3]));
    });

    test('surfaces the proxy error message verbatim on non-200', () async {
      final mock = MockClient(
        (req) async => http.Response(
          jsonEncode({
            'error': {'message': 'That image is too large. Try another photo.'},
          }),
          413,
        ),
      );
      final analyzer = ProxyAnalyzer(
        baseUrl: 'https://api.example.com',
        appToken: 't',
        httpClient: mock,
      );

      await expectLater(
        analyzer.analyze(
          imageBytes: Uint8List.fromList([1]),
          mediaType: 'image/jpeg',
        ),
        throwsA(
          isA<ClaudeApiException>()
              .having((e) => e.statusCode, 'statusCode', 413)
              .having((e) => e.message, 'message', contains('too large')),
        ),
      );
    });

    test(
      'falls back to a generic message when the body has no error',
      () async {
        final mock = MockClient((req) async => http.Response('not json', 500));
        final analyzer = ProxyAnalyzer(
          baseUrl: 'https://x.test',
          appToken: 't',
          httpClient: mock,
        );

        await expectLater(
          analyzer.analyze(
            imageBytes: Uint8List.fromList([1]),
            mediaType: 'image/jpeg',
          ),
          throwsA(
            isA<ClaudeApiException>().having(
              (e) => e.message,
              'message',
              'Analysis failed. Please try again.',
            ),
          ),
        );
      },
    );

    test('maps a network failure to a friendly error', () async {
      final mock = MockClient((req) async => throw Exception('boom'));
      final analyzer = ProxyAnalyzer(
        baseUrl: 'https://api.example.com',
        appToken: 't',
        httpClient: mock,
      );

      await expectLater(
        analyzer.analyze(
          imageBytes: Uint8List.fromList([1]),
          mediaType: 'image/jpeg',
        ),
        throwsA(isA<ClaudeApiException>()),
      );
    });
  });
}
