import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_at_peace/src/data/auth_client.dart';
import 'package:food_at_peace/src/data/sync_client.dart';

void main() {
  group('SyncClient.deleteAccount', () {
    test('POSTs to /account/delete with the bearer token', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode({'deleted': 3}), 200);
      });

      final client = SyncClient(baseUrl: 'https://x.example', httpClient: mock);
      await client.deleteAccount(token: 'tok-123');

      expect(captured.method, 'POST');
      expect(captured.url.path, '/account/delete');
      expect(captured.headers['authorization'], 'Bearer tok-123');
    });

    test('401 → SessionExpired', () async {
      final mock = MockClient(
        (req) async => http.Response(
          jsonEncode({
            'error': {'message': 'Not authenticated.'},
          }),
          401,
        ),
      );
      final client = SyncClient(baseUrl: 'https://x.example', httpClient: mock);
      expect(
        () => client.deleteAccount(token: 'bad'),
        throwsA(isA<SessionExpired>()),
      );
    });

    test('500 → AuthException with the server message', () async {
      final mock = MockClient(
        (req) async => http.Response(
          jsonEncode({
            'error': {'message': 'Unexpected error. Please try again.'},
          }),
          500,
        ),
      );
      final client = SyncClient(baseUrl: 'https://x.example', httpClient: mock);
      expect(
        () => client.deleteAccount(token: 'tok'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Unexpected error. Please try again.',
          ),
        ),
      );
    });
  });
}
