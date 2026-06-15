import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_at_peace/src/data/circle_client.dart';
import 'package:food_at_peace/src/models/friend.dart';

void main() {
  group('CircleClient', () {
    test('list parses connected/incoming/outgoing into Friends with trend', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'me': {'handle': '@alice', 'name': 'Alice'},
            'connected': [
              {
                'id': 'u_bob', 'name': 'Bob', 'handle': '@bob',
                'status': 'connected', 'streak': 3,
                'adh': [10, 20, 30, 40, 50, 60, 70], 'kcal': 1500, 'target': 2000,
              },
            ],
            'incoming': [
              {'id': 'u_cara', 'name': 'Cara', 'handle': '@cara', 'status': 'incoming'},
            ],
            'outgoing': [],
          }),
          200,
        );
      });
      final c = CircleClient(baseUrl: 'https://x.test/', httpClient: mock);
      final friends = await c.list('tok');

      expect(captured.url.toString(), 'https://x.test/circle/list');
      expect(captured.headers['authorization'], 'Bearer tok');
      expect(friends.length, 2);
      final bob = friends.firstWhere((f) => f.id == 'u_bob');
      expect(bob.status, FriendStatus.connected);
      expect(bob.todayKcal, 1500);
      expect(bob.targetKcal, 2000);
      expect(bob.adherence7d.length, 7);
      expect(friends.firstWhere((f) => f.id == 'u_cara').status,
          FriendStatus.incoming);
    });

    test('invite posts the handle with the bearer token', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response('{}', 200);
      });
      final c = CircleClient(baseUrl: 'https://x.test', httpClient: mock);
      expect(await c.invite('tok', 'bob'), 200);
      expect(captured.url.toString(), 'https://x.test/circle/invite');
      expect(captured.method, 'POST');
      expect((jsonDecode(captured.body) as Map)['handle'], 'bob');
      expect(captured.headers['authorization'], 'Bearer tok');
    });

    test('connect posts the handle and returns the friend name', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'status': 'connected', 'handle': '@bob', 'name': 'Bob'}),
          200,
        );
      });
      final c = CircleClient(baseUrl: 'https://x.test', httpClient: mock);
      final name = await c.connect('tok', 'bob');
      expect(name, 'Bob');
      expect(captured.url.toString(), 'https://x.test/circle/connect');
      expect(captured.method, 'POST');
      expect((jsonDecode(captured.body) as Map)['handle'], 'bob');
      expect(captured.headers['authorization'], 'Bearer tok');
    });

    test('connect throws CircleException on an unknown handle', () async {
      final mock = MockClient((req) async => http.Response(
          jsonEncode({'error': {'message': 'No one with that handle.'}}), 404));
      final c = CircleClient(baseUrl: 'https://x.test', httpClient: mock);
      await expectLater(
        c.connect('tok', 'ghost'),
        throwsA(isA<CircleException>()),
      );
    });

    test('register surfaces 409 (handle taken) as a status code, not a throw', () async {
      final mock = MockClient((req) async =>
          http.Response(jsonEncode({'error': {'message': 'taken'}}), 409));
      final c = CircleClient(baseUrl: 'https://x.test', httpClient: mock);
      expect(await c.register('tok', 'bob'), 409);
    });

    test('respond posts userId + action', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response('{}', 200);
      });
      final c = CircleClient(baseUrl: 'https://x.test', httpClient: mock);
      await c.respond('tok', 'u_bob', 'accept');
      final body = jsonDecode(captured.body) as Map;
      expect(captured.url.toString(), 'https://x.test/circle/respond');
      expect(body['userId'], 'u_bob');
      expect(body['action'], 'accept');
    });

    test('a non-200/409 error throws CircleException with the server message', () async {
      final mock = MockClient((req) async => http.Response(
          jsonEncode({'error': {'message': 'No one with that handle.'}}), 404));
      final c = CircleClient(baseUrl: 'https://x.test', httpClient: mock);
      await expectLater(
        c.invite('tok', 'ghost'),
        throwsA(isA<CircleException>()
            .having((e) => e.message, 'message', contains('No one'))),
      );
    });
  });
}
