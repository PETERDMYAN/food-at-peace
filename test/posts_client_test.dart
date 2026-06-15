import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_at_peace/src/data/posts_client.dart';

void main() {
  group('PostsClient', () {
    test('post sends base64 image + name + calories with the bearer', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response('{}', 200);
      });
      await PostsClient(baseUrl: 'https://x.test', httpClient: mock).post(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        mediaType: 'image/jpeg',
        name: 'Toast',
        calories: 120,
        token: 'tok',
      );
      expect(captured.url.toString(), 'https://x.test/circle/post');
      final b = jsonDecode(captured.body) as Map;
      expect(b['image'], base64Encode([1, 2, 3]));
      expect(b['name'], 'Toast');
      expect(b['calories'], 120);
      expect(captured.headers['authorization'], 'Bearer tok');
    });

    test('feed parses posts with reactions + reactors', () async {
      final mock = MockClient((req) async {
        expect(req.url.toString(), 'https://x.test/circle/feed');
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'posts': [
              {
                'postId': 'p1', 'authorId': 'u1', 'authorName': 'Alice',
                'name': 'Veggie bowl', 'calories': 520, 'createdAt': 1,
                'photoUrl': 'https://img.example/p1.jpg', 'mine': true,
                'reactions': {'😋': 2}, 'myReaction': null,
                'reactors': [{'name': 'Bob', 'emoji': '😋'}],
              },
            ],
          })),
          200,
        );
      });
      final posts =
          await PostsClient(baseUrl: 'https://x.test', httpClient: mock).feed('tok');
      expect(posts.length, 1);
      final p = posts.first;
      expect(p.calories, 520);
      expect(p.reactions['😋'], 2);
      expect(p.mine, isTrue);
      expect(p.reactors.first.name, 'Bob');
      expect(p.photoUrl, 'https://img.example/p1.jpg');
    });

    test('react posts postId + emoji and returns the resulting reaction', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response.bytes(utf8.encode('{"myReaction":"👍"}'), 200);
      });
      final r = await PostsClient(baseUrl: 'https://x.test', httpClient: mock)
          .react(postId: 'p1', emoji: '👍', token: 'tok');
      expect(r, '👍');
      expect(captured.url.toString(), 'https://x.test/circle/react');
      final b = jsonDecode(captured.body) as Map;
      expect(b['postId'], 'p1');
      expect(b['emoji'], '👍');
    });
  });
}
