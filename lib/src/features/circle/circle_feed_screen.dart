import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../data/eva_wisdom.dart';
import '../../models/circle_post.dart';
import '../../providers/providers.dart';
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
                // Blue "Official" tag on the creator @roro's posts — for everyone
                // except your own posts and the creator themselves.
                if (!post.mine &&
                    (post.authorHandle ?? '').toLowerCase() == kRoroHandle &&
                    ref.watch(myCircleHandleProvider)?.toLowerCase() !=
                        kRoroHandle) ...[
                  const SizedBox(width: 6),
                  const OfficialBadge(),
                ],
              ],
            ),
            subtitle: Text(sub),
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
