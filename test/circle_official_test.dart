// Official Circle accounts: Eva (built-in AI coach, followed by default,
// unfollowable) and Roro (creator's real account, only *recommended* to follow
// — never auto-followed). followsRoroProvider drives whether the Roro
// recommendation shows.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/models/friend.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCircle extends CircleNotifier {
  _FakeCircle(this._friends);
  final List<Friend> _friends;
  @override
  List<Friend> build() => _friends;
}

Future<ProviderContainer> _container(
  Map<String, Object> seed, {
  List<Friend> friends = const [],
}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      circleProvider.overrideWith(() => _FakeCircle(friends)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Friend _f(String handle, {FriendStatus status = FriendStatus.connected}) =>
    Friend(id: handle, name: handle, handle: handle, status: status);

void main() {
  test('Eva is followed by default (she is part of a new circle)', () async {
    final c = await _container(const {});
    expect(c.read(evaFollowedProvider), isTrue);
  });

  test('unfollowing Eva persists', () async {
    final c = await _container(const {});
    await c.read(evaFollowedProvider.notifier).setFollowed(false);
    expect(c.read(evaFollowedProvider), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('eva_followed'), isFalse);
  });

  test('Eva follow state is restored from prefs', () async {
    final c = await _container(const {'eva_followed': false});
    expect(c.read(evaFollowedProvider), isFalse);
  });

  test('Roro is NOT auto-followed — recommended until you connect', () async {
    final c = await _container(const {}, friends: [_f('@alex')]);
    expect(c.read(followsRoroProvider), isFalse);
  });

  test('followsRoro flips true once connected to @roro', () async {
    final c = await _container(const {}, friends: [_f('@roro'), _f('@alex')]);
    expect(c.read(followsRoroProvider), isTrue);
  });

  test('a pending (non-connected) @roro still counts as not-followed', () async {
    final c = await _container(
      const {},
      friends: [_f('@roro', status: FriendStatus.outgoing)],
    );
    expect(c.read(followsRoroProvider), isFalse);
  });

  test('the creator (own handle @roro) is never suggested to follow self',
      () async {
    // The real creator's own handle IS roro; without this guard they'd see a
    // "Suggested: Roro / Follow" tile prompting them to follow themselves.
    final c = await _container(const {'circle_my_handle': 'roro'});
    expect(c.read(followsRoroProvider), isTrue);
  });
}
