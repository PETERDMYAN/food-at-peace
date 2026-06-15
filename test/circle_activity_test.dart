import 'package:flutter_test/flutter_test.dart';

import 'package:food_at_peace/src/models/circle_post.dart';
import 'package:food_at_peace/src/models/friend.dart';
import 'package:food_at_peace/src/providers/providers.dart';

CirclePost _post(
  String id,
  int ts, {
  bool mine = false,
  String? author,
  Map<String, int> reactions = const {},
  List<CircleReactor> reactors = const [],
}) =>
    CirclePost(
      postId: id,
      authorId: 'u_$id',
      authorName: author ?? id,
      createdAt: ts,
      mine: mine,
      reactions: reactions,
      reactors: reactors,
    );

Friend _friend(String id, FriendStatus status) =>
    Friend(id: id, name: id, handle: '@$id', status: status);

void main() {
  group('freshFriendPosts', () {
    test('returns only friends\' posts newer than lastSeen, newest first', () {
      final feed = [_post('a', 100), _post('b', 300), _post('c', 200)];
      expect(freshFriendPosts(feed, 150).map((p) => p.postId), ['b', 'c']);
    });

    test('excludes the viewer\'s own posts', () {
      final feed = [_post('mine', 500, mine: true), _post('friend', 400)];
      expect(freshFriendPosts(feed, 0).map((p) => p.postId), ['friend']);
    });

    test('nothing newer than lastSeen → empty', () {
      expect(freshFriendPosts([_post('a', 100)], 100), isEmpty);
    });
  });

  group('diffCircleActivity', () {
    test('first run (prev null) → no events, just a baseline snapshot', () {
      final r = diffCircleActivity(
        friends: [_friend('eva', FriendStatus.incoming)],
        feed: [_post('p', 500)],
        prev: null,
      );
      expect(r.events, isEmpty);
      expect(r.snapshot.statuses['eva'], 'incoming');
      expect(r.snapshot.lastPostMs, 500);
    });

    test('new incoming request → request event', () {
      final r = diffCircleActivity(
        friends: [_friend('peter', FriendStatus.incoming)],
        feed: const [],
        prev: const CircleSnapshot(statuses: {}, reactions: {}, lastPostMs: 0),
      );
      expect(r.events.single.kind, CircleEventKind.request);
      expect(r.events.single.name, 'peter');
    });

    test('outgoing → connected → accepted event', () {
      final r = diffCircleActivity(
        friends: [_friend('eva', FriendStatus.connected)],
        feed: const [],
        prev: const CircleSnapshot(
          statuses: {'eva': 'outgoing'},
          reactions: {},
          lastPostMs: 0,
        ),
      );
      expect(r.events.single.kind, CircleEventKind.accepted);
      expect(r.events.single.name, 'eva');
    });

    test('a new friend meal → posted event', () {
      final r = diffCircleActivity(
        friends: const [],
        feed: [_post('p', 900, author: 'Peter')],
        prev: const CircleSnapshot(statuses: {}, reactions: {}, lastPostMs: 100),
      );
      expect(r.events.single.kind, CircleEventKind.posted);
      expect(r.events.single.name, 'Peter');
    });

    test('a new reaction on my post → reaction event with reactor + emoji', () {
      final r = diffCircleActivity(
        friends: const [],
        feed: [
          _post('mine', 50,
              mine: true,
              reactions: {'❤️': 1},
              reactors: [const CircleReactor(name: 'Eva', emoji: '❤️')]),
        ],
        prev: const CircleSnapshot(
          statuses: {},
          reactions: {'mine': 0},
          lastPostMs: 999999999999,
        ),
      );
      expect(r.events.single.kind, CircleEventKind.reaction);
      expect(r.events.single.name, 'Eva');
      expect(r.events.single.detail, '❤️');
    });

    test('no change → no events', () {
      final r = diffCircleActivity(
        friends: [_friend('eva', FriendStatus.connected)],
        feed: [_post('mine', 50, mine: true, reactions: {'❤️': 1})],
        prev: const CircleSnapshot(
          statuses: {'eva': 'connected'},
          reactions: {'mine': 1},
          lastPostMs: 999999999999,
        ),
      );
      expect(r.events, isEmpty);
    });
  });
}
