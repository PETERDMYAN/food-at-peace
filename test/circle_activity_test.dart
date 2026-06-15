import 'package:flutter_test/flutter_test.dart';

import 'package:food_at_peace/src/models/circle_post.dart';
import 'package:food_at_peace/src/providers/providers.dart';

CirclePost _post(String id, int ts, {bool mine = false}) => CirclePost(
  postId: id,
  authorId: 'u_$id',
  authorName: id,
  createdAt: ts,
  mine: mine,
);

void main() {
  group('freshFriendPosts', () {
    test('returns only friends\' posts newer than lastSeen, newest first', () {
      final feed = [
        _post('a', 100),
        _post('b', 300),
        _post('c', 200),
      ];
      final fresh = freshFriendPosts(feed, 150);
      expect(fresh.map((p) => p.postId), ['b', 'c']); // 300, 200 desc; 100 dropped
    });

    test('excludes the viewer\'s own posts', () {
      final feed = [
        _post('mine', 500, mine: true),
        _post('friend', 400),
      ];
      expect(freshFriendPosts(feed, 0).map((p) => p.postId), ['friend']);
    });

    test('nothing newer than lastSeen → empty (no alert)', () {
      final feed = [_post('a', 100), _post('b', 90)];
      expect(freshFriendPosts(feed, 100), isEmpty);
    });

    test('empty feed → empty', () {
      expect(freshFriendPosts(const [], 0), isEmpty);
    });
  });
}
