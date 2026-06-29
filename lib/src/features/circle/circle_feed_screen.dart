import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../data/eva_wisdom.dart';
import '../../models/circle_post.dart';
import '../../models/friend.dart';
import '../../providers/providers.dart';
import '../../util/relative_time.dart';
import '../../widgets/official_badge.dart';
import '../../widgets/story_avatar.dart';
import 'circle_strip.dart';

Future<void> showCircleFeed(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const CircleFeedScreen()));
}

/// The circle photo feed: friends' (and your own) shared meals, with emoji
/// reactions. Posts expire after 3 days (server-side TTL).
class CircleFeedScreen extends StatelessWidget {
  const CircleFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.feedTitle)),
      body: const CircleFeedBody(),
    );
  }
}

/// The circle feed list (pull-to-refresh + posts) without its own Scaffold, so it
/// can sit under the strip on the Circle tab as well as be pushed full-screen.
class CircleFeedBody extends ConsumerWidget {
  const CircleFeedBody({super.key, this.header});

  /// Optional first item that scrolls **with** the feed. The Circle tab passes the
  /// stories strip here so the whole page scrolls as one (Instagram-style: the
  /// stories scroll away as you go down the feed), instead of a fixed header over
  /// a separately-scrolling feed. Null on the standalone full-screen feed.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final feed = ref.watch(circleFeedProvider);

    // The feed content for the current state, as flat list items (so the single
    // ListView below virtualises them and the [header] scrolls with them).
    List<Widget> bodyItems() => feed.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (e, _) => [
            Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
          ],
          data: (posts) {
            // Drop locally hidden posts (reported, or authored by someone the
            // viewer unfollowed); also drop @roro's posts when he's unfollowed.
            final hidden = ref.watch(hiddenPostsProvider);
            final roroHidden = ref.watch(roroHiddenProvider);
            final visible = [
              for (final p in posts)
                if (!hidden.contains(p.postId) &&
                    !(roroHidden &&
                        (p.authorHandle ?? '').toLowerCase() == kRoroHandle))
                  p,
            ];
            final showEva = ref.watch(evaFollowedProvider) &&
                (ref.watch(evaWisdomProvider).asData?.value.isNotEmpty ?? false);
            if (visible.isEmpty && !showEva) {
              return [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
                  child: Text(
                    t.feedEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ];
            }
            // One reverse-chronological stream (newest first): meal posts keyed by
            // createdAt + Eva's lesson for each of the last 3 days, interleaved.
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final entries = <(int, Widget)>[
              for (final p in visible) (p.createdAt, _PostCard(post: p)),
              if (showEva)
                for (var d = 0; d < 3; d++)
                  (
                    today.subtract(Duration(days: d)).millisecondsSinceEpoch,
                    _EvaFeedCard(dayOffset: d),
                  ),
            ];
            entries.sort((a, b) => b.$1.compareTo(a.$1));
            return [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: e.$2,
                ),
              const SizedBox(height: 32),
            ];
          },
        );

    return RefreshIndicator(
      onRefresh: () => ref.refresh(circleFeedProvider.future),
      child: ListView(
        padding: EdgeInsets.zero,
        // Always scrollable so pull-to-refresh works even when the page is short.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ?header,
          ...bodyItems(),
        ],
      ),
    );
  }
}

/// Eva's lesson for one day as a feed card (when she's followed). The feed shows
/// one per day for the last 3 days, matching her 3-day story. Tapping opens her
/// story. [dayOffset]: 0 = today, 1 = yesterday, 2 = two days ago.
class _EvaFeedCard extends ConsumerWidget {
  const _EvaFeedCard({this.dayOffset = 0});

  final int dayOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lessons = ref.watch(evaWisdomProvider).asData?.value ?? const [];
    if (lessons.isEmpty) return const SizedBox.shrink();
    final lang = Localizations.localeOf(context).languageCode;
    final ml = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: dayOffset));
    final lesson = lessons[evaLessonIndex(day, lessons.length)];
    // Newest card → "Daily lesson"; older days show their date (like the story).
    final subtitle =
        dayOffset == 0 ? t.evaDailyLesson : ml.formatMediumDate(day);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openMyStory(context, ref, initialStory: 1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const StoryAvatar(initials: 'E', colorSeed: 7, size: 40),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Eva', style: text.titleSmall),
                          if (ref.watch(myCircleHandleProvider)?.toLowerCase() !=
                              kRoroHandle) ...[
                            const SizedBox(width: 6),
                            const OfficialBadge(),
                          ],
                        ],
                      ),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                lesson.text(lang),
                style: text.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});

  final CirclePost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = AppLocalizations.of(context);
    final title = post.mine ? t.feedYou : (post.authorName ?? t.feedSomeone);
    final kcal = t.kcalValue('${post.calories}');
    final sub = (post.name != null && post.name!.isNotEmpty)
        ? '${post.name} · $kcal'
        : kcal;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: StoryAvatar(
              initials: _initials(title),
              imageUrl: post.authorPhotoUrl,
              imageCacheKey: post.authorId,
              colorSeed: post.authorId.hashCode,
              size: 40,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: text.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Blue "Official" tag on an official account's posts (Roro or
                // Eva) — for everyone except your own posts and that account
                // viewing itself.
                if (!post.mine &&
                    isOfficialHandle(post.authorHandle) &&
                    !isOfficialHandle(ref.watch(myCircleHandleProvider))) ...[
                  const SizedBox(width: 6),
                  const OfficialBadge(),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub),
                if (post.createdAt > 0)
                  Text(
                    relativeTime(
                      t,
                      DateTime.fromMillisecondsSinceEpoch(post.createdAt),
                    ),
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            // No moderation actions on your own post.
            trailing: post.mine
                ? null
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz),
                    tooltip: t.feedPostMenu,
                    onSelected: (v) {
                      if (v == 'report') _report(context, ref, t);
                      if (v == 'unfollow') _unfollow(context, ref, t, title);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'report',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.flag_outlined),
                          title: Text(t.feedReport),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'unfollow',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_remove_outlined),
                          title: Text(t.feedUnfollow),
                        ),
                      ),
                    ],
                  ),
          ),
          if (post.photoUrl != null)
            AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: post.photoUrl!,
                // The presigned S3 URL's signature rotates on every feed fetch,
                // so cache by the stable postId — otherwise the disk cache would
                // miss every launch and re-download each photo.
                cacheKey: post.postId,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: scheme.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, _, _) => Container(
                  color: scheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                for (final emoji in circleReactionEmojis)
                  _ReactionChip(
                    emoji: emoji,
                    count: post.reactions[emoji] ?? 0,
                    selected: post.myReaction == emoji,
                    onTap: () => _react(context, ref, emoji),
                  ),
              ],
            ),
          ),
          if (post.mine && post.reactors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                post.reactors.map((r) => '${r.emoji} ${r.name}').join('   '),
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          // Comments: an inline preview of the most recent few VISIBLE to this
          // viewer (PRIVATE per-commenter threads — the owner sees everyone's, a
          // friend only their own; the server already scopes `recentComments`).
          // The WHOLE area (incl. gaps) is tappable to open the full sheet.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openComments(context, ref),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.commentCount > post.recentComments.length)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        t.viewAllComments(post.commentCount),
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  for (final c in post.recentComments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${c.authorName ?? t.feedSomeone}  ',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: c.text),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.mode_comment_outlined,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          t.commentHint,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _react(BuildContext context, WidgetRef ref, String emoji) async {
    final token = ref.read(authProvider)?.token;
    if (token == null || token.isEmpty) {
      // Reactions are attributed to an account, so they need sign-in — tell the
      // viewer instead of silently doing nothing.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).signInToReact)),
      );
      return;
    }
    try {
      await ref
          .read(postsClientProvider)
          .react(postId: post.postId, emoji: emoji, token: token);
      ref.invalidate(circleFeedProvider);
    } catch (_) {
      // A failed reaction shouldn't surface; the next refresh reconciles.
    }
  }

  /// Open the private comment threads for this post. Commenting needs an account
  /// (comments are attributed), so prompt sign-in when signed out.
  void _openComments(BuildContext context, WidgetRef ref) {
    final token = ref.read(authProvider)?.token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).signInToComment)),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // keyboard lifts the sheet; sized to ~3/5 screen
      showDragHandle: true,
      builder: (_) => _CommentsSheet(post: post),
    );
  }

  /// Apple Guideline 1.2: let the viewer flag objectionable content. Pick a
  /// reason, then hide the post immediately and confirm we act within 24h.
  Future<void> _report(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  t.feedReportTitle,
                  style: Theme.of(sheetCtx).textTheme.titleMedium,
                ),
              ),
              for (final r in [
                t.feedReportSpam,
                t.feedReportNudity,
                t.feedReportHarassment,
                t.feedReportViolence,
                t.feedReportOther,
              ])
                ListTile(
                  title: Text(r),
                  onTap: () => Navigator.of(sheetCtx).pop(r),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (reason == null) return;
    // Client-side moderation: the post vanishes for the reporter at once.
    await ref.read(hiddenPostsProvider.notifier).hide(post.postId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.feedReportThanks)));
  }

  /// Apple Guideline 1.2: let the viewer block an abusive user. Removes the
  /// friendship (server-side, so they stop seeing each other) and hides the post.
  Future<void> _unfollow(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(t.feedUnfollowTitle(name)),
        content: Text(t.feedUnfollowBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(t.feedUnfollow),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(circleProvider.notifier).remove(post.authorId);
    await ref.read(hiddenPostsProvider.notifier).hide(post.postId);
    ref.invalidate(circleFeedProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.feedUnfollowed(name))));
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: selected ? Border.all(color: scheme.primary) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text('$count', style: Theme.of(context).textTheme.labelMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The private comment threads on a post. The post OWNER sees one section per
/// commenter and replies into each; a COMMENTER sees only their own thread (their
/// comments + the owner's replies) with a box to add to it. This mirrors the
/// server's privacy model — see circle-comments-privacy skill.
/// The thread sentinel for the owner's PUBLIC comments (matches `posts._PUBLIC`
/// server-side). Used when deleting a public comment.
const _kPublicThread = '__public__';

/// An optimistic comment being sent: rendered immediately so the composer clears,
/// then sent in the background. A failed one keeps a retry control.
class _Pending {
  _Pending(this.id, this.text, {this.threadUser, this.public = false});
  final String id;
  final String text;
  final String? threadUser;
  final bool public;
  bool sending = true;
  bool failed = false;
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.post});

  final CirclePost post;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  ({String postId, String authorId}) get _key =>
      (postId: widget.post.postId, authorId: widget.post.authorId);

  // The owner has a single composer; tapping a thread prefills "@handle ". Typing
  // "@" opens a LOCAL mention picker over the already-loaded commenters (no
  // server call).
  final _ownerController = TextEditingController();
  final _ownerFocus = FocusNode();
  String? _mentionQuery; // text typed after an active "@" ("" = bare @), else null
  final List<_Pending> _pending = []; // optimistic comments being sent
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _ownerController.addListener(_onOwnerChanged);
    // The cached comments show instantly; freshen them in the background only
    // when there IS a cache (reopen) — the sheet keeps showing the cached threads
    // via skipLoadingOnReload, so no spinner. First-ever open just fetches once.
    Future.microtask(() {
      if (mounted && ref.read(postCommentsProvider(_key)).hasValue) {
        ref.invalidate(postCommentsProvider(_key));
      }
    });
  }

  @override
  void dispose() {
    _ownerController.removeListener(_onOwnerChanged);
    _ownerController.dispose();
    _ownerFocus.dispose();
    super.dispose();
  }

  void _onOwnerChanged() {
    final q = _activeMentionQuery();
    if (q != _mentionQuery) setState(() => _mentionQuery = q);
  }

  /// The query of an in-progress "@mention" at the cursor (e.g. "p" for "@p"), or
  /// null when not mentioning. "" means a bare "@" → show everyone.
  String? _activeMentionQuery() {
    final c = _ownerController;
    final sel = c.selection;
    if (!sel.isValid || !sel.isCollapsed) return null;
    final cursor = sel.start.clamp(0, c.text.length).toInt();
    final m = RegExp(
      r'(?:^|\s)@([A-Za-z0-9_]*)$',
    ).firstMatch(c.text.substring(0, cursor));
    return m?.group(1);
  }

  /// Replace the in-progress "@query" with "@handle " when a suggestion is tapped.
  void _pickMention(String? rawHandle) {
    final handle = (rawHandle ?? '').replaceFirst('@', '');
    final c = _ownerController;
    if (handle.isEmpty) {
      _ownerFocus.requestFocus();
      return;
    }
    final cursor =
        (c.selection.isValid ? c.selection.start : c.text.length).clamp(
          0,
          c.text.length,
        ).toInt();
    final before = c.text
        .substring(0, cursor)
        .replaceFirst(RegExp(r'@[A-Za-z0-9_]*$'), '@$handle ');
    final text = before + c.text.substring(cursor);
    c.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: before.length),
    );
    _ownerFocus.requestFocus();
  }

  /// Prefill the owner's box with "@handle " and focus it, so a tap on a thread
  /// starts a private reply to that commenter.
  void _replyTo(String? handle) {
    final h = (handle ?? '').replaceFirst('@', '').trim();
    if (h.isEmpty) {
      _ownerFocus.requestFocus();
      return;
    }
    final rest = _ownerController.text.replaceFirst(RegExp(r'^\s*@\S+\s*'), '');
    _ownerController.text = '@$h ${rest.trimLeft()}';
    _ownerController.selection = TextSelection.collapsed(
      offset: _ownerController.text.length,
    );
    _ownerFocus.requestFocus();
  }

  /// A person the owner can @-mention: an existing commenter OR a connected
  /// circle friend (so a brand-new post with no comments can still start a
  /// private thread). Deduped by user id; threads win (they carry live names).
  List<({String userId, String? handle, String? name})> _mentionCandidates(
    List<CircleCommentThread> threads,
  ) {
    final out = <({String userId, String? handle, String? name})>[];
    final seen = <String>{};
    for (final th in threads) {
      if (seen.add(th.userId)) {
        out.add((userId: th.userId, handle: th.handle, name: th.name));
      }
    }
    for (final f in ref.read(circleProvider)) {
      if (f.status != FriendStatus.connected) continue;
      if (seen.add(f.id)) {
        out.add((userId: f.id, handle: f.handle, name: f.name));
      }
    }
    return out;
  }

  /// Owner send from the single box: a leading "@handle" matching a commenter or
  /// a connected friend → a PRIVATE comment to just them (the server opens the
  /// thread if it's new); otherwise a PUBLIC comment everyone sees.
  Future<void> _ownerSend(String text, List<CircleCommentThread> threads) {
    final m = RegExp(r'^\s*@([A-Za-z0-9_]+)').firstMatch(text);
    if (m != null) {
      final h = m.group(1)!.toLowerCase();
      for (final c in _mentionCandidates(threads)) {
        if ((c.handle ?? '').replaceFirst('@', '').toLowerCase() == h) {
          return _send(text, threadUser: c.userId);
        }
      }
    }
    return _send(text, public: true);
  }

  /// Optimistic post: show the comment immediately (it returns at once so the
  /// composer clears), then send in the background. On failure it stays with a
  /// retry icon; on success the real, refetched comment replaces it.
  Future<void> _send(String text, {String? threadUser, bool public = false}) async {
    final p = _Pending('${_seq++}', text, threadUser: threadUser, public: public);
    setState(() => _pending.add(p));
    unawaited(_trySend(p));
  }

  Future<void> _trySend(_Pending p) async {
    final token = ref.read(authProvider)?.token;
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          p.sending = false;
          p.failed = true;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        p.failed = false;
        p.sending = true;
      });
    }
    try {
      await ref
          .read(postsClientProvider)
          .comment(
            postId: widget.post.postId,
            postAuthorId: widget.post.authorId,
            text: p.text,
            threadUser: p.threadUser,
            public: p.public,
            token: token,
          );
      if (!mounted) return;
      ref.invalidate(circleFeedProvider); // refresh the card's count/preview
      ref.invalidate(postCommentsProvider(_key));
      await ref.read(postCommentsProvider(_key).future); // wait for the real row
      if (mounted) setState(() => _pending.remove(p)); // replaced by the fetched one
    } catch (_) {
      if (mounted) {
        setState(() {
          p.sending = false;
          p.failed = true;
        });
      }
    }
  }

  /// Delete [c] from thread [threadUser]. The server allows the post owner to
  /// delete any comment and a commenter to delete their own; the UI only offers
  /// the control where that's allowed.
  Future<void> _delete(CircleComment c, String threadUser) async {
    final t = AppLocalizations.of(context);
    final token = ref.read(authProvider)?.token;
    if (token == null || token.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(t.commentDelete),
        content: Text(t.commentDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(postsClientProvider)
          .deleteComment(
            postId: widget.post.postId,
            postAuthorId: widget.post.authorId,
            commentId: c.commentId,
            threadUser: threadUser,
            token: token,
          );
      ref.invalidate(postCommentsProvider(_key));
      ref.invalidate(circleFeedProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.commentError)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final async = ref.watch(postCommentsProvider(_key));
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        // ~3/5 of the screen, but never so tall (with the keyboard up) that the
        // close ✕ / drag handle get pushed off the top.
        height: (media.size.height * 0.6).clamp(
          0.0,
          media.size.height - media.viewInsets.bottom - 80,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
              child: Row(
                children: [
                  Text(t.commentsTitle, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: t.cancel,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                skipLoadingOnReload: true, // keep the thread visible while refetching
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('$e'),
                ),
                data: (c) => _commentsView(context, t, c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One time-ranked list of every comment the viewer may see (public + the
  /// private threads the server scoped to them). Each carries a who-can-see-it
  /// tag. Optimistic (pending) comments append at the end. One composer: plain →
  /// public (owner) / private-to-owner (commenter); "@handle …" → private reply.
  Widget _commentsView(BuildContext context, AppLocalizations t, CircleComments c) {
    final items =
        <({CircleComment comment, bool isPublic, String threadUser, String? name, String? handle})>[];
    for (final pc in c.public) {
      items.add((comment: pc, isPublic: true, threadUser: _kPublicThread, name: null, handle: null));
    }
    for (final th in c.threads) {
      for (final m in th.comments) {
        items.add((comment: m, isPublic: false, threadUser: th.userId, name: th.name, handle: th.handle));
      }
    }
    items.sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              if (items.isEmpty && _pending.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      t.commentsEmpty,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              for (final it in items) _commentBubble(context, t, it, c.isOwner),
              for (final p in _pending) _pendingBubble(context, t, p),
            ],
          ),
        ),
        // Owner-only @mention picker (local; from the already-loaded commenters).
        if (c.isOwner && _mentionQuery != null)
          _mentionSuggestions(context, t, c.threads),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: c.isOwner
              ? _Composer(
                  controller: _ownerController,
                  focusNode: _ownerFocus,
                  hint: t.commentOwnerHint,
                  onSend: (text) => _ownerSend(text, c.threads),
                )
              // A commenter's box always posts to their own private thread.
              : _Composer(hint: t.commentHint, onSend: (text) => _send(text)),
        ),
      ],
    );
  }

  Widget _commentBubble(
    BuildContext context,
    AppLocalizations t,
    ({CircleComment comment, bool isPublic, String threadUser, String? name, String? handle}) it,
    bool viewerIsOwner,
  ) {
    final c = it.comment;
    final mine = c.isOwner == viewerIsOwner;
    final audience = it.isPublic
        ? t.commentAudiencePublic
        // The owner sees WHICH commenter ("Only Anna"); a commenter sees that it's
        // just them + the post's owner ("Only you & Eva"), so "Private" isn't vague.
        : (viewerIsOwner
              ? t.commentAudienceOnly(it.name ?? t.feedSomeone)
              : t.commentAudienceYouAnd(widget.post.authorName ?? t.feedSomeone));
    return _Bubble(
      comment: c,
      mine: mine,
      audience: audience,
      audiencePublic: it.isPublic,
      // Owner taps a private comment to reply privately to that person.
      onTap: (viewerIsOwner && !it.isPublic) ? () => _replyTo(it.handle) : null,
      // Owner deletes any comment; a commenter only their own.
      onDelete: (viewerIsOwner || mine) ? () => _delete(c, it.threadUser) : null,
    );
  }

  Widget _pendingBubble(BuildContext context, AppLocalizations t, _Pending p) {
    final scheme = Theme.of(context).colorScheme;
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: p.failed ? 0.45 : 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(p.text, style: Theme.of(context).textTheme.bodyMedium),
    );
    Widget? lead;
    if (p.sending) {
      lead = const Padding(
        padding: EdgeInsets.only(right: 6),
        child: SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(strokeWidth: 1.6),
        ),
      );
    } else if (p.failed) {
      lead = IconButton(
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        color: scheme.error,
        tooltip: t.commentResend,
        icon: const Icon(Icons.error_outline),
        onPressed: () => _trySend(p),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [?lead, Flexible(child: bubble)],
      ),
    );
  }

  /// The @mention picker — existing commenters PLUS connected circle friends
  /// (purely local, no server round-trip). Tapping one inserts "@handle ".
  Widget _mentionSuggestions(
    BuildContext context,
    AppLocalizations t,
    List<CircleCommentThread> threads,
  ) {
    final q = (_mentionQuery ?? '').toLowerCase();
    final matches = [
      for (final c in _mentionCandidates(threads))
        if (q.isEmpty ||
            (c.handle ?? '').replaceFirst('@', '').toLowerCase().startsWith(q) ||
            (c.name ?? '').toLowerCase().startsWith(q))
          c,
    ];
    if (matches.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Material(
        color: scheme.surfaceContainerHigh,
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            for (final c in matches.take(6))
              ListTile(
                dense: true,
                leading: StoryAvatar(
                  initials: _initials(c.name ?? '?'),
                  colorSeed: c.userId.hashCode,
                  size: 28,
                  story: false,
                ),
                title: Text(c.name ?? t.feedSomeone),
                subtitle: (c.handle ?? '').isNotEmpty
                    ? Text('@${c.handle!.replaceFirst('@', '')}')
                    : null,
                onTap: () => _pickMention(c.handle),
              ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

/// One comment bubble; [mine] right-aligns it (the viewer's own message). Shows a
/// small audience tag (who can see it). [onTap] (owner → reply) and [onDelete]
/// add a tap target + delete control.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.comment,
    required this.mine,
    this.audience,
    this.audiencePublic = false,
    this.onTap,
    this.onDelete,
  });

  final CircleComment comment;
  final bool mine;

  /// Who can see this — "Everyone" / "Only PY" / "Private" — shown as a chip.
  final String? audience;
  final bool audiencePublic;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final inner = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (!mine && (comment.authorName?.isNotEmpty ?? false))
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              comment.authorName!,
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        Text(comment.text, style: text.bodyMedium),
        if (audience != null && audience!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  audiencePublic ? Icons.public : Icons.lock_outline,
                  size: 11,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 3),
                Text(
                  audience!,
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    Widget bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      decoration: BoxDecoration(
        color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: inner,
    );
    if (onTap != null) bubble = GestureDetector(onTap: onTap, child: bubble);
    final align = mine ? Alignment.centerRight : Alignment.centerLeft;
    if (onDelete == null) return Align(alignment: align, child: bubble);
    final delete = IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      color: scheme.onSurfaceVariant,
      tooltip: AppLocalizations.of(context).commentDelete,
      icon: const Icon(Icons.delete_outline),
      onPressed: onDelete,
    );
    return Align(
      alignment: align,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: mine
            ? [delete, Flexible(child: bubble)]
            : [Flexible(child: bubble), delete],
      ),
    );
  }
}

/// A growable comment input with a send button. Owns its controller so typing
/// doesn't rebuild the sheet, and clears itself after a successful send.
class _Composer extends StatefulWidget {
  const _Composer({
    required this.hint,
    required this.onSend,
    this.controller,
    this.focusNode,
  });

  final String hint;
  final Future<void> Function(String text) onSend;

  /// Optional external controller/focus (the owner box is prefilled with
  /// "@handle " on a thread tap). When null, an internal one is used + disposed.
  final TextEditingController? controller;
  final FocusNode? focusNode;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late final TextEditingController _controller;
  late final bool _ownsController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    await widget.onSend(text);
    if (!mounted) return;
    _controller.clear();
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: widget.focusNode,
            enabled: !_busy,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: widget.hint,
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        _busy
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(icon: const Icon(Icons.send), onPressed: _submit),
      ],
    );
  }
}
