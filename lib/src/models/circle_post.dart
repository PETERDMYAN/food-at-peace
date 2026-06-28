/// One ephemeral food-photo post in the Circle feed (expires after 3 days).
class CirclePost {
  const CirclePost({
    required this.postId,
    required this.authorId,
    this.authorName,
    this.authorHandle,
    this.authorPhotoUrl,
    this.name,
    this.calories = 0,
    this.createdAt = 0,
    this.photoUrl,
    this.mine = false,
    this.reactions = const {},
    this.myReaction,
    this.reactors = const [],
    this.commentCount = 0,
    this.recentComments = const [],
  });

  final String postId;
  final String authorId;
  final String? authorName;
  final String? authorHandle;
  final String? authorPhotoUrl; // presigned profile-photo URL for the avatar
  final String? name; // dish name
  final int calories;
  final int createdAt; // epoch ms
  final String? photoUrl; // presigned S3 GET url
  final bool mine; // the viewer's own post
  final Map<String, int> reactions; // emoji → count
  final String? myReaction; // the viewer's current emoji, if any
  final List<CircleReactor> reactors; // who reacted (own posts only)
  final int commentCount; // comments VISIBLE to the viewer (owner: all; else own thread)
  final List<CircleComment> recentComments; // up to 3 most-recent visible, for an inline preview

  factory CirclePost.fromJson(Map<String, dynamic> j) => CirclePost(
    postId: j['postId'] as String,
    authorId: j['authorId'] as String? ?? '',
    authorName: j['authorName'] as String?,
    authorHandle: j['authorHandle'] as String?,
    authorPhotoUrl: j['authorPhotoUrl'] as String?,
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
    commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
    recentComments: [
      for (final c in (j['recentComments'] as List? ?? const []))
        CircleComment.fromJson((c as Map).cast<String, dynamic>()),
    ],
  );
}

/// A friend's reaction on one of the viewer's own posts.
class CircleReactor {
  const CircleReactor({required this.name, required this.emoji});
  final String name;
  final String emoji;
}

/// One comment in a post's private thread. Comments are PRIVATE per-commenter
/// threads with the post owner as the hub: the owner sees every thread, each
/// commenter sees only their own (their comments + the owner's replies).
class CircleComment {
  const CircleComment({
    required this.commentId,
    required this.authorId,
    this.authorName,
    this.authorHandle,
    this.isOwner = false,
    this.public = false,
    required this.text,
    this.createdAt = 0,
  });

  final String commentId;
  final String authorId;
  final String? authorName;
  final String? authorHandle;
  final bool isOwner; // written by the post owner (a reply or a public comment)
  final bool public; // a PUBLIC broadcast by the owner (everyone who sees the post sees it)
  final String text;
  final int createdAt; // epoch ms

  factory CircleComment.fromJson(Map<String, dynamic> j) => CircleComment(
    commentId: j['commentId'] as String? ?? '',
    authorId: j['authorId'] as String? ?? '',
    authorName: j['authorName'] as String?,
    authorHandle: j['authorHandle'] as String?,
    isOwner: j['isOwner'] == true,
    public: j['public'] == true,
    text: j['text'] as String? ?? '',
    createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
  );
}

/// One private comment thread on a post: the conversation between the post owner
/// and a single commenter ([userId] is that commenter). The owner sees many of
/// these; a commenter sees only their own.
class CircleCommentThread {
  const CircleCommentThread({
    required this.userId,
    this.handle,
    this.name,
    this.comments = const [],
  });

  final String userId; // the non-owner participant (the commenter)
  final String? handle;
  final String? name;
  final List<CircleComment> comments;

  factory CircleCommentThread.fromJson(Map<String, dynamic> j) {
    final u = ((j['user'] as Map?) ?? const {}).cast<String, dynamic>();
    return CircleCommentThread(
      userId: u['id'] as String? ?? '',
      handle: u['handle'] as String?,
      name: u['name'] as String?,
      comments: [
        for (final c in (j['comments'] as List? ?? const []))
          CircleComment.fromJson((c as Map).cast<String, dynamic>()),
      ],
    );
  }
}

/// The comment threads visible to the current viewer for a post. For the post
/// owner, [threads] holds every commenter's thread; for a commenter it holds at
/// most their own (empty until they comment).
class CircleComments {
  const CircleComments({
    this.isOwner = false,
    this.public = const [],
    this.threads = const [],
  });

  final bool isOwner;

  /// The owner's PUBLIC comments on this post — visible to everyone.
  final List<CircleComment> public;
  final List<CircleCommentThread> threads;

  /// Total comments visible to this viewer (public + their threads).
  int get total =>
      public.length + threads.fold(0, (sum, t) => sum + t.comments.length);

  factory CircleComments.fromJson(Map<String, dynamic> j) => CircleComments(
    isOwner: j['isOwner'] == true,
    public: [
      for (final c in (j['public'] as List? ?? const []))
        CircleComment.fromJson((c as Map).cast<String, dynamic>()),
    ],
    threads: [
      for (final t in (j['threads'] as List? ?? const []))
        CircleCommentThread.fromJson((t as Map).cast<String, dynamic>()),
    ],
  );
}
