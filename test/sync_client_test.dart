import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_at_peace/src/data/auth_client.dart';
import 'package:food_at_peace/src/data/sync_client.dart';
import 'package:food_at_peace/src/models/sync_record.dart';

void main() {
  group('SyncClient.sync', () {
    test('POSTs since + changes with the bearer token and parses the pull',
        () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'serverTime': 1700000000000,
            'changes': {
              'food': [
                {
                  'id': 'f1',
                  'updatedAt': 1699999999000,
                  'deleted': false,
                  'data': {'id': 'f1', 'name': 'Toast'},
                }
              ],
              'weight': [],
              'profile': null,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client =
          SyncClient(baseUrl: 'https://api.example.com/', httpClient: mock);
      final result = await client.sync(
        token: 'sess-abc',
        sinceMs: 42,
        food: [
          const SyncRecord(
            id: 'f0',
            updatedAtMs: 50,
            deleted: false,
            data: {'id': 'f0', 'name': 'Eggs'},
          ),
        ],
        weight: const [],
        profile: null,
      );

      // Response parsed.
      expect(result.serverTimeMs, 1700000000000);
      expect(result.food.single.id, 'f1');
      expect(result.food.single.data['name'], 'Toast');
      expect(result.weight, isEmpty);
      expect(result.profile, isNull);

      // Request shaped + authed correctly.
      expect(captured.url.toString(), 'https://api.example.com/sync');
      expect(captured.headers['authorization'], 'Bearer sess-abc');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['since'], 42);
      final food = (body['changes'] as Map)['food'] as List;
      expect((food.single as Map)['id'], 'f0');
      expect((food.single as Map)['data']['name'], 'Eggs');
    });

    test('throws SessionExpired on 401', () async {
      final mock = MockClient((req) async => http.Response('nope', 401));
      final client = SyncClient(baseUrl: 'https://x.test', httpClient: mock);
      await expectLater(
        client.sync(token: 'bad', sinceMs: 0, food: const [], weight: const []),
        throwsA(isA<SessionExpired>()),
      );
    });

    test('maps other non-200s to a friendly AuthException', () async {
      final mock = MockClient(
        (req) async => http.Response(
          jsonEncode({'error': {'message': 'Sync is down.'}}),
          500,
        ),
      );
      final client = SyncClient(baseUrl: 'https://x.test', httpClient: mock);
      await expectLater(
        client.sync(token: 't', sinceMs: 0, food: const [], weight: const []),
        throwsA(isA<AuthException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });
}
