import 'dart:math';

/// Where a friend sits in the connection flow.
enum FriendStatus {
  /// Mutually connected — their trend is visible.
  connected,

  /// They invited you; awaiting your accept/decline.
  incoming,

  /// You invited them; awaiting their acceptance.
  outgoing,
}

/// A friend in your "Circle of Food", plus a snapshot of their recent trend.
/// Pure Dart (no Flutter) so it stays testable.
///
/// NOTE: trend fields are mock data for the client MVP — real friend trends
/// must come from the backend (with the friend's consent / privacy controls).
class Friend {
  const Friend({
    required this.id,
    required this.name,
    required this.handle,
    required this.status,
    this.streakDays = 0,
    this.adherence7d = const [],
    this.todayKcal = 0,
    this.targetKcal = 0,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String handle; // e.g. "@alex"
  final FriendStatus status;

  // --- trend snapshot (mock) ---
  final int streakDays;
  final List<int> adherence7d; // 0–100 per day, oldest → newest
  final int todayKcal;
  final int targetKcal;

  /// Presigned URL for the friend's profile-photo avatar (from the circle list),
  /// or null → fall back to initials.
  final String? photoUrl;

  /// Up to two initials for the avatar.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  Friend copyWith({FriendStatus? status}) => Friend(
    id: id,
    name: name,
    handle: handle,
    status: status ?? this.status,
    streakDays: streakDays,
    adherence7d: adherence7d,
    todayKcal: todayKcal,
    targetKcal: targetKcal,
    photoUrl: photoUrl,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'handle': handle,
    'status': status.name,
    'streak': streakDays,
    'adh': adherence7d,
    'kcal': todayKcal,
    'target': targetKcal,
    if (photoUrl != null) 'photoUrl': photoUrl,
  };

  factory Friend.fromJson(Map<String, dynamic> j) => Friend(
    id: j['id'] as String,
    name: j['name'] as String,
    handle: j['handle'] as String,
    status: FriendStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => FriendStatus.connected,
    ),
    streakDays: (j['streak'] as num?)?.toInt() ?? 0,
    adherence7d: [for (final v in (j['adh'] as List? ?? [])) (v as num).toInt()],
    todayKcal: (j['kcal'] as num?)?.toInt() ?? 0,
    targetKcal: (j['target'] as num?)?.toInt() ?? 0,
    photoUrl: j['photoUrl'] as String?,
  );

  /// Builds a plausible mock trend snapshot (client MVP only).
  static Friend sample({
    required String id,
    required String name,
    required String handle,
    required FriendStatus status,
    int seed = 0,
  }) {
    final rng = Random(seed);
    final target = 1800 + rng.nextInt(600);
    return Friend(
      id: id,
      name: name,
      handle: handle,
      status: status,
      streakDays: rng.nextInt(21),
      adherence7d: [for (var i = 0; i < 7; i++) 55 + rng.nextInt(45)],
      todayKcal: (target * (0.6 + rng.nextDouble() * 0.5)).round(),
      targetKcal: target,
    );
  }

  /// The starter circle a fresh install shows (so the feature isn't empty).
  static List<Friend> seed() => [
    Friend.sample(
      id: 'f_mia',
      name: 'Mia Tan',
      handle: '@miatan',
      status: FriendStatus.connected,
      seed: 1,
    ),
    Friend.sample(
      id: 'f_jay',
      name: 'Jay Lim',
      handle: '@jaylim',
      status: FriendStatus.connected,
      seed: 2,
    ),
    Friend.sample(
      id: 'f_sara',
      name: 'Sara Wong',
      handle: '@saraw',
      status: FriendStatus.connected,
      seed: 3,
    ),
    Friend.sample(
      id: 'f_ben',
      name: 'Ben Koh',
      handle: '@benkoh',
      status: FriendStatus.incoming,
      seed: 4,
    ),
  ];
}
