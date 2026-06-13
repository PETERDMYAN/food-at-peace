import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/models/friend.dart';

void main() {
  test('initials take up to two name parts', () {
    expect(
      const Friend(id: '1', name: 'Mia Tan', handle: '@m', status: FriendStatus.connected)
          .initials,
      'MT',
    );
    expect(
      const Friend(id: '2', name: 'Ben', handle: '@b', status: FriendStatus.connected)
          .initials,
      'B',
    );
  });

  test('seed has connected friends and a pending incoming invite', () {
    final seed = Friend.seed();
    expect(seed.where((f) => f.status == FriendStatus.connected), isNotEmpty);
    expect(seed.where((f) => f.status == FriendStatus.incoming), isNotEmpty);
  });

  test('sample produces a 7-day adherence series within range', () {
    final f = Friend.sample(
      id: 'x',
      name: 'A B',
      handle: '@ab',
      status: FriendStatus.connected,
      seed: 7,
    );
    expect(f.adherence7d.length, 7);
    expect(f.adherence7d.every((v) => v >= 0 && v <= 100), isTrue);
    expect(f.targetKcal, greaterThan(0));
  });

  test('JSON round-trips', () {
    final f = Friend.sample(
      id: 'y',
      name: 'Sara Wong',
      handle: '@saraw',
      status: FriendStatus.connected,
      seed: 3,
    );
    final back = Friend.fromJson(f.toJson());
    expect(back.id, f.id);
    expect(back.name, f.name);
    expect(back.handle, f.handle);
    expect(back.status, f.status);
    expect(back.adherence7d, f.adherence7d);
    expect(back.targetKcal, f.targetKcal);
  });
}
