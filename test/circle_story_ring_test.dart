// A friend's strip avatar should only show a story ring when they actually have
// a shared post in the feed. A brand-new friend with nothing shared has no story
// → plain avatar, no false "unseen stories" ring. (Bug: new users showed a ring.)
import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/features/circle/circle_strip.dart';
import 'package:food_at_peace/src/models/circle_post.dart';
import 'package:food_at_peace/src/models/friend.dart';

Friend _f(String id, String handle) =>
    Friend(id: id, name: 'X', handle: handle, status: FriendStatus.connected);

CirclePost _p({required String authorId, String? handle, String? photo}) =>
    CirclePost(
      postId: 'p_$authorId',
      authorId: authorId,
      authorHandle: handle,
      photoUrl: photo,
    );

void main() {
  test('a friend with a shared photo post has a story', () {
    final feed = [_p(authorId: 'u1', photo: 'https://x/p.jpg')];
    expect(friendHasStory(_f('u1', '@eric'), feed), isTrue);
  });

  test('a brand-new friend with no posts has NO story (no false ring)', () {
    expect(friendHasStory(_f('u1', '@eric'), const []), isFalse);
    // Someone else's post must not give them a story either.
    final feed = [_p(authorId: 'someone-else', photo: 'https://x/p.jpg')];
    expect(friendHasStory(_f('u1', '@eric'), feed), isFalse);
  });

  test('matches by @handle when the post authorId differs (e.g. official acct)', () {
    final feed = [_p(authorId: 'real-id', handle: 'eric', photo: 'https://x/p.jpg')];
    expect(friendHasStory(_f('synthetic-id', '@eric'), feed), isTrue);
  });

  test('a post with no photo is not a story', () {
    final feed = [_p(authorId: 'u1', photo: null), _p(authorId: 'u1', photo: '')];
    expect(friendHasStory(_f('u1', '@eric'), feed), isFalse);
  });
}
