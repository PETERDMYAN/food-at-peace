/// One ephemeral food-photo post in the Circle feed (expires after 3 days).
class CirclePost {
  const CirclePost({
    required this.postId,
    required this.authorId,
    this.authorName,
    this.authorHandle,
    this.name,
    this.calories = 0,
    this.createdAt = 0,
    this.photoUrl,
    this.mine = false,
    this.reactions = const {},
    this.myReaction,
    this.reactors = const [],
  });

  final String postId;
  final String authorId;
  final String? authorName;
  final String? authorHandle;
  final String? name; // dish name
  final int calories;
  final int createdAt; // epoch ms
  final String? photoUrl; // presigned S3 GET url
  final bool mine; // the viewer's own post
  final Map<String, int> reactions; // emoji → count
  final String? myReaction; // the viewer's current emoji, if any
  final List<CircleReactor> reactors; // who reacted (own posts only)

  factory CirclePost.fromJson(Map<String, dynamic> j) => CirclePost(
    postId: j['postId'] as String,
    authorId: j['authorId'] as String? ?? '',
    authorName: j['authorName'] as String?,
    authorHandle: j['authorHandle'] as String?,
    name: j['name'] as String?,
    calories: (j['calories'] as num?)?.toInt() ?? 0,
    createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
    photoUrl: j['photoUrl'] as String?,
    mine: j['mine'] == true,
    reactions: {
      for (final e in ((j['reactions'] as Map?) ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    myReaction: j['myReaction'] as String?,
    reactors: [
      for (final r in (j['reactors'] as List?) ?? const [])
        CircleReactor(
          name: (r as Map)['name'] as String? ?? '',
          emoji: r['emoji'] as String? ?? '',
        ),
    ],
  );
}

/// A friend's reaction on one of the viewer's own posts.
class CircleReactor {
  const CircleReactor({required this.name, required this.emoji});
  final String name;
  final String emoji;
}
