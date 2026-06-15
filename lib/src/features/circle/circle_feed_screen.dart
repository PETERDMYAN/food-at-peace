import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../models/circle_post.dart';
import '../../providers/providers.dart';
import '../../widgets/story_avatar.dart';

Future<void> showCircleFeed(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CircleFeedScreen()),
  );
}

/// The circle photo feed: friends' (and your own) shared meals, with emoji
/// reactions. Posts expire after 3 days (server-side TTL).
class CircleFeedScreen extends ConsumerWidget {
  const CircleFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final feed = ref.watch(circleFeedProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.feedTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(circleFeedProvider.future),
        child: feed.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
            ],
          ),
          data: (posts) => posts.isEmpty
              ? ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 96, 28, 24),
                      child: Text(
                        t.feedEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
                  itemCount: posts.length,
                  itemBuilder: (_, i) => _PostCard(post: posts[i]),
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
    final title = post.mine ? 'You' : (post.authorName ?? 'Someone');
    final sub = (post.name != null && post.name!.isNotEmpty)
        ? '${post.name} · ${post.calories} kcal'
        : '${post.calories} kcal';
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: StoryAvatar(
              initials: _initials(title),
              colorSeed: post.authorId.hashCode,
              size: 40,
            ),
            title: Text(title, style: text.titleSmall),
            subtitle: Text(sub),
          ),
          if (post.photoUrl != null)
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                post.photoUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (c, child, progress) => progress == null
                    ? child
                    : Container(
                        color: scheme.surfaceContainerHighest,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                errorBuilder: (_, _, _) => Container(
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
                    onTap: () => _react(ref, emoji),
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

  Future<void> _react(WidgetRef ref, String emoji) async {
    final token = ref.read(authProvider)?.token;
    if (token == null || token.isEmpty) return;
    try {
      await ref
          .read(postsClientProvider)
          .react(postId: post.postId, emoji: emoji, token: token);
      ref.invalidate(circleFeedProvider);
    } catch (_) {
      // A failed reaction shouldn't surface; the next refresh reconciles.
    }
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
