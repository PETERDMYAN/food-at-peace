import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../data/eva_wisdom.dart';
import '../../models/circle_post.dart';
import '../../models/friend.dart';
import '../../providers/providers.dart';
import '../../widgets/story_avatar.dart';
import 'circle_feed_screen.dart';
import 'invite_card.dart';
import 'manage_friends_screen.dart';

/// "Circle of Food" strip shown on top of the Trends graph: a row of
/// Instagram-style friend avatars, an "Add" bubble (invite), and a Requests
/// entry when invites are pending. Tapping a friend shows their trend.
class CircleStrip extends ConsumerWidget {
  const CircleStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final friends = ref.watch(circleProvider);
    final connected =
        friends.where((f) => f.status == FriendStatus.connected).toList();
    final outgoing =
        friends.where((f) => f.status == FriendStatus.outgoing).toList();
    final incoming =
        friends.where((f) => f.status == FriendStatus.incoming).length;

    // Eva is a story you follow: her daily lesson, keyed to the local date.
    final lessons = ref.watch(evaWisdomProvider).asData?.value ?? const [];
    final lang = Localizations.localeOf(context).languageCode;
    final evaLesson = lessons.isEmpty
        ? null
        : lessons[evaLessonIndex(DateTime.now(), lessons.length)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(t.yourCircle, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              tooltip: t.feedTitle,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.dynamic_feed_outlined),
              onPressed: () => showCircleFeed(context),
            ),
            IconButton(
              tooltip: t.manageCircle,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.group_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManageCircleScreen()),
              ),
            ),
            if (incoming > 0)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CircleRequestsScreen()),
                ),
                child: Text(t.circleRequestsN(incoming)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // You — your own food story (your shared meals).
              _AvatarColumn(
                label: t.feedYou,
                avatar: StoryAvatar(
                  icon: Icons.person,
                  colorSeed: 3,
                  onTap: () => showMyMeals(context),
                ),
                onTap: () => showMyMeals(context),
              ),
              // Eva — a companion you follow; tap her story for today's lesson.
              if (evaLesson != null)
                _AvatarColumn(
                  label: 'Eva',
                  avatar: StoryAvatar(
                    initials: 'E',
                    colorSeed: 7,
                    onTap: () => showEvaStory(context, evaLesson, lang),
                  ),
                  onTap: () => showEvaStory(context, evaLesson, lang),
                ),
              _AvatarColumn(
                label: t.addFriend,
                avatar: StoryAvatar(
                  icon: Icons.add,
                  ring: false,
                  onTap: () => showInviteSheet(context),
                ),
                onTap: () => showInviteSheet(context),
              ),
              for (final f in connected)
                _AvatarColumn(
                  label: f.name,
                  avatar: StoryAvatar(
                    initials: f.initials,
                    colorSeed: f.id.hashCode,
                    onTap: () => showFriendTrend(context, f),
                  ),
                  onTap: () => showFriendTrend(context, f),
                ),
              for (final f in outgoing)
                _AvatarColumn(
                  label: t.pendingLabel,
                  avatar: StoryAvatar(
                    initials: f.initials,
                    colorSeed: f.id.hashCode,
                    muted: true,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarColumn extends StatelessWidget {
  const _AvatarColumn({required this.avatar, required this.label, this.onTap});

  final Widget avatar;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            avatar,
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invite sheet
// ---------------------------------------------------------------------------

Future<void> showInviteSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _InviteSheet(),
  );
}

class _InviteSheet extends ConsumerWidget {
  const _InviteSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final myHandle = ref.watch(myCircleHandleProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.invitePeople,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // The user's own @handle — friends add them with this.
            MyHandleCard(
              handle: myHandle,
              onEdit: () => editCircleHandle(context, ref),
            ),
            const SizedBox(height: 8),
            // Where to find a friend's handle — it's in this same spot on theirs.
            Text(
              t.inviteHandleHelp,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            // Share a universal invite link / QR — one tap connects you both.
            if (myHandle != null) ...[
              const SizedBox(height: 20),
              InviteShareCard(handle: myHandle),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Friend trend sheet
// ---------------------------------------------------------------------------

Future<void> showFriendTrend(BuildContext context, Friend friend) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _FriendTrendSheet(friend: friend),
  );
}

class _FriendTrendSheet extends ConsumerWidget {
  const _FriendTrendSheet({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StoryAvatar(
                  initials: friend.initials,
                  colorSeed: friend.id.hashCode,
                  size: 52,
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(friend.name, style: text.titleLarge),
                    Text(
                      friend.handle,
                      style: text.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: t.todayLabel,
                    value: '${friend.todayKcal} / ${friend.targetKcal}',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: t.streakLabel,
                    value: t.streakDays(friend.streakDays),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(t.friendAdherence, style: text.titleSmall),
            const SizedBox(height: 10),
            _AdherenceBars(values: friend.adherence7d),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _confirmRemove(context, ref, t),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(Icons.person_remove_outlined),
                label: Text(t.removeFriend),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.removeFriend),
        content: Text(t.removeFriendQ(friend.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.removeFriend),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(circleProvider.notifier).remove(friend.id);
    if (context.mounted) Navigator.pop(context); // close the trend sheet
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        Text(
          label,
          style: text.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AdherenceBars extends StatelessWidget {
  const _AdherenceBars({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  height: 86 * (v.clamp(0, 100) / 100),
                  decoration: BoxDecoration(
                    color: v >= 80 ? const Color(0xFF34B36A) : scheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Requests screen
// ---------------------------------------------------------------------------

class CircleRequestsScreen extends ConsumerWidget {
  const CircleRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final incoming = ref
        .watch(circleProvider)
        .where((f) => f.status == FriendStatus.incoming)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(t.circleRequests)),
      body: incoming.isEmpty
          ? Center(
              child: Text(
                t.noRequests,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                for (final f in incoming)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                      leading: StoryAvatar(
                        initials: f.initials,
                        colorSeed: f.id.hashCode,
                        size: 40,
                      ),
                      title: Text(f.name),
                      subtitle: Text(f.handle),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => ref
                                .read(circleProvider.notifier)
                                .remove(f.id),
                            child: Text(t.decline),
                          ),
                          FilledButton(
                            onPressed: () {
                              ref.read(circleProvider.notifier).accept(f.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(t.friendAccepted(f.name)),
                                ),
                              );
                            },
                            child: Text(t.accept),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Eva's daily-lesson story (tap her avatar)
// ---------------------------------------------------------------------------

Future<void> showEvaStory(BuildContext context, EvaLesson lesson, String lang) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _EvaStorySheet(lesson: lesson, lang: lang),
  );
}

class _EvaStorySheet extends StatelessWidget {
  const _EvaStorySheet({required this.lesson, required this.lang});

  final EvaLesson lesson;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const StoryAvatar(initials: 'E', colorSeed: 7, size: 44),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eva',
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      t.evaDailyLesson,
                      style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              '“${lesson.text(lang)}”',
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(height: 1.4, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            Text(
              '— ${lesson.author(lang)}',
              style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Your own food story (tap "You") — your shared meals
// ---------------------------------------------------------------------------

Future<void> showMyMeals(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _MyMealsSheet(),
  );
}

class _MyMealsSheet extends ConsumerWidget {
  const _MyMealsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final feed = ref.watch(circleFeedProvider);

    Widget nudge() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Icon(Icons.restaurant_outlined, size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            t.shareFirstMeal,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const StoryAvatar(icon: Icons.person, colorSeed: 3, size: 44),
                const SizedBox(width: 12),
                Text(t.yourMeals, style: text.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            feed.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => nudge(),
              data: (posts) {
                final mine = posts.where((p) => p.mine).toList();
                if (mine.isEmpty) return nudge();
                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: mine.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _MyMealRow(post: mine[i]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MyMealRow extends StatelessWidget {
  const _MyMealRow({required this.post});

  final CirclePost post;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: post.photoUrl != null
              ? Image.network(
                  post.photoUrl!,
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _thumbFallback(scheme),
                )
              : _thumbFallback(scheme),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (post.name != null && post.name!.isNotEmpty) ? post.name! : t.feedYou,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                t.kcalValue('${post.calories}'),
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thumbFallback(ColorScheme scheme) => Container(
    width: 58,
    height: 58,
    color: scheme.surfaceContainerHighest,
    child: Icon(Icons.photo_outlined, color: scheme.onSurfaceVariant),
  );
}
