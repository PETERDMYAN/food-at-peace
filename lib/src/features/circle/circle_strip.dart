import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../data/eva_wisdom.dart';
import '../../models/food_entry.dart';
import '../../models/friend.dart';
import '../../providers/providers.dart';
import '../../widgets/story_avatar.dart';
import 'circle_feed_screen.dart';
import 'invite_card.dart';
import 'manage_friends_screen.dart';
import 'story_viewer.dart';

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

    // Your food story = today's food log (all of it — not just shared meals).
    final now = DateTime.now();
    final todayFood = ref
        .watch(foodEntriesProvider)
        .where((e) =>
            !e.deleted &&
            e.timestamp.year == now.year &&
            e.timestamp.month == now.month &&
            e.timestamp.day == now.day)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

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
              // You — your own food story (today's food log, story-style).
              _AvatarColumn(
                label: t.feedYou,
                avatar: StoryAvatar(
                  icon: Icons.person,
                  colorSeed: 3,
                  onTap: () => showFoodStory(context, todayFood, lang),
                ),
                onTap: () => showFoodStory(context, todayFood, lang),
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
// Full-screen stories (Instagram-style) — tap a circle avatar to open
// ---------------------------------------------------------------------------

const double _storyTopPad = 80; // clear the progress bar + close button

/// Eva's daily lesson as a one-page story.
Future<void> showEvaStory(BuildContext context, EvaLesson lesson, String lang) =>
    showStory(context, pages: [_EvaStoryPage(lesson: lesson, lang: lang)]);

/// Your food story = one page per food logged today (a nudge if none yet). Shows
/// the whole day's log — not just meals shared to the circle.
Future<void> showFoodStory(
  BuildContext context,
  List<FoodEntry> entries,
  String lang,
) {
  final pages = entries.isEmpty
      ? <Widget>[const _FoodNudgePage()]
      : [
          for (final e in entries) _FoodStoryPage(entry: e),
        ];
  return showStory(context, pages: pages);
}

class _StoryScaffold extends StatelessWidget {
  const _StoryScaffold({required this.header, required this.body, required this.colors});

  final Widget header;
  final Widget body;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, _storyTopPad, 26, 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [header, Expanded(child: Center(child: body))],
          ),
        ),
      ),
    );
  }
}

Widget _storyHeader(String title, String subtitle, Widget avatar) => Row(
  children: [
    avatar,
    const SizedBox(width: 10),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    ),
  ],
);

class _EvaStoryPage extends StatelessWidget {
  const _EvaStoryPage({required this.lesson, required this.lang});

  final EvaLesson lesson;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _StoryScaffold(
      colors: const [Color(0xFF3A1D5C), Color(0xFF0E0B14)],
      header: _storyHeader(
        'Eva',
        t.evaDailyLesson,
        const StoryAvatar(initials: 'E', colorSeed: 7, size: 40),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '“${lesson.text(lang)}”',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '— ${lesson.author(lang)}',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _FoodStoryPage extends StatelessWidget {
  const _FoodStoryPage({required this.entry});

  final FoodEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(entry.timestamp));
    return _StoryScaffold(
      colors: const [Color(0xFF241A40), Color(0xFF0E0B14)],
      header: _storyHeader(
        t.foodStory,
        time,
        const StoryAvatar(icon: Icons.person, colorSeed: 3, size: 40),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            t.kcalValue(entry.calories.round().toString()),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 46,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Macro(label: t.protein, value: entry.proteinG),
              const SizedBox(width: 30),
              _Macro(label: t.saturatedFat, value: entry.satFatG),
            ],
          ),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value.round()} g',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

class _FoodNudgePage extends StatelessWidget {
  const _FoodNudgePage();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _StoryScaffold(
      colors: const [Color(0xFF241A40), Color(0xFF0E0B14)],
      header: _storyHeader(
        t.foodStory,
        '',
        const StoryAvatar(icon: Icons.person, colorSeed: 3, size: 40),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.restaurant_outlined, color: Colors.white70, size: 44),
          const SizedBox(height: 16),
          Text(
            t.shareFirstMeal,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
          ),
        ],
      ),
    );
  }
}
