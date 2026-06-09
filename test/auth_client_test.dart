import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_at_peace/src/data/auth_client.dart';

void main() {
  group('AuthClient.exchange', () {
    test(
      'POSTs identityToken + rawNonce to /auth/apple and parses the session',
      () async {
        late http.Request captured;
        final mock = MockClient((req) async {
          captured = req;
          return http.Response(
            jsonEncode({
              'sessionToken': 'sess-abc',
              'userId': 'apple:000123.def',
              'email': 'jane@example.com',
              'expiresInSeconds': 60 * 60 * 24 * 60,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = AuthClient(
          baseUrl: 'https://api.example.com/',
          httpClient: mock,
        );
        final before = DateTime.now();
        final session = await client.exchange(
          identityToken: 'id-token-xyz',
          rawNonce: 'raw-nonce-123',
          fullName: 'Jane Doe',
        );

        expect(session.token, 'sess-abc');
        expect(session.userId, 'apple:000123.def');
        expect(session.email, 'jane@example.com');
        expect(session.isExpired, isFalse);
        expect(
          session.expiresAt.isAfter(before.add(const Duration(days: 59))),
          isTrue,
        );

        // Endpoint normalized to a single /auth/apple despite the trailing slash.
        expect(captured.url.toString(), 'https://api.example.com/auth/apple');
        expect(captured.method, 'POST');
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body['identityToken'], 'id-token-xyz');
        expect(body['rawNonce'], 'raw-nonce-123');
        expect(body['fullName'], 'Jane Doe');
      },
    );

    test('omits fullName when null and tolerates a missing email', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'sessionToken': 't',
            'userId': 'apple:1',
            'expiresInSeconds': 3600,
          }),
          200,
        );
      });
      final client = AuthClient(baseUrl: 'https://x.test', httpClient: mock);
      final s = await client.exchange(identityToken: 'i', rawNonce: 'n');

      expect(s.email, isNull);
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body.containsKey('fullName'), isFalse);
    });

    test(
      'maps a non-200 to a friendly AuthException with the server message',
      () async {
        final mock = MockClient(
          (req) async => http.Response(
            jsonEncode({
              'error': {
                'message':
                    'Could not verify your Apple sign-in. Please try again.',
              },
            }),
            401,
          ),
        );
        final client = AuthClient(baseUrl: 'https://x.test', httpClient: mock);

        await expectLater(
          client.exchange(identityToken: 'bad', rawNonce: 'n'),
          throwsA(
            isA<AuthException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having(
                  (e) => e.message,
                  'message',
                  contains('verify your Apple'),
                ),
          ),
        );
      },
    );

    test('maps a network failure to a friendly AuthException', () async {
      final mock = MockClient((req) async => throw Exception('boom'));
      final client = AuthClient(baseUrl: 'https://x.test', httpClient: mock);

      await expectLater(
        client.exchange(identityToken: 'i', rawNonce: 'n'),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
