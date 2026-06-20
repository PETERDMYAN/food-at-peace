import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../data/eva_wisdom.dart';
import '../../data/meal_photos.dart';
import '../../data/profile_photo.dart';
import '../../models/food_entry.dart';
import '../../models/friend.dart';
import '../../providers/providers.dart';
import '../../widgets/notify_permission_cta.dart';
import '../../widgets/story_avatar.dart';
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
    final evaIndex = lessons.isEmpty
        ? 0
        : evaLessonIndex(DateTime.now(), lessons.length);
    final evaLesson = lessons.isEmpty ? null : lessons[evaIndex];
    // Eva is followed by default; unfollowing hides her story + tip (she moves to
    // Manage ▸ Suggested to re-follow).
    final evaFollowed = ref.watch(evaFollowedProvider);

    // Your profile photo (used for the "You" avatar + your story header).
    final myPhoto = ref.watch(profilePhotoProvider);


    // Your food story = the last 7 days of food log (the archive), newest first
    // — all of it, not just meals shared to the circle.
    final now = DateTime.now();
    final weekStart =
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final recentFood = ref
        .watch(foodEntriesProvider)
        .where((e) =>
            !e.deleted && !e.hiddenFromStory && !e.timestamp.isBefore(weekStart))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Story "seen" rings: the key embeds the content (newest meal + count / the
    // day's Eva lesson) so fresh content resets the ring back to unseen.
    final seen = ref.watch(seenStoriesProvider);
    final youKey = youStoryKey(recentFood);
    final evaKey = evaStoryKey(evaIndex);

    // Roro (the creator's official account) belongs with the official accounts —
    // left of the Add icon, next to Eva — not mixed in among your peers.
    final roroMatches =
        connected.where((f) => f.handle == '@$kRoroHandle').toList();
    final roroFriend = roroMatches.isEmpty ? null : roroMatches.first;
    final peers =
        connected.where((f) => f.handle != '@$kRoroHandle').toList();

    // Open the chained story tray (You → Eva). [initialStory] 0 = your food
    // story, 1 = Eva — advancing past the end of one rolls into the next. Each
    // story is marked "seen" as the viewer shows it.
    void openStories(int initialStory) =>
        openMyStory(context, ref, initialStory: initialStory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(t.yourCircle, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              tooltip: t.archive,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.history),
              onPressed: () =>
                  openMyStory(context, ref, includeEva: false),
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
        // Prompt to grant OS notification permission when either reminders or
        // circle activity is on (both default on) but iOS hasn't allowed them.
        NotifyPermissionCta.maybeShow(ref),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // You — your own food story (last 7 days, story-style). Shows your
              // profile photo when set, else a person icon. Opens the chained
              // story tray (You → Eva) starting on your story.
              _AvatarColumn(
                label: t.feedYou,
                avatar: StoryAvatar(
                  imageBytes: myPhoto,
                  icon: myPhoto == null ? Icons.person : null,
                  colorSeed: 3,
                  seen: seen.contains(youKey),
                  onTap: () => openStories(0),
                ),
                onTap: () => openStories(0),
              ),
              // Eva — a companion you follow; opens the same tray on her story,
              // so swiping back/forward moves between You and Eva. Hidden once
              // unfollowed (she reappears under Manage ▸ Suggested).
              if (evaFollowed && evaLesson != null)
                _AvatarColumn(
                  label: 'Eva',
                  avatar: StoryAvatar(
                    initials: 'E',
                    colorSeed: 7,
                    seen: seen.contains(evaKey),
                    onTap: () => openStories(1),
                  ),
                  onTap: () => openStories(1),
                ),
              // Roro — the creator's official account, grouped with Eva (left of
              // the Add icon). Tapping shows their trend, like any friend.
              if (roroFriend != null)
                _AvatarColumn(
                  label: roroFriend.name,
                  avatar: StoryAvatar(
                    initials: roroFriend.initials,
                    colorSeed: roroFriend.id.hashCode,
                    onTap: () => showFriendTrend(context, roroFriend),
                  ),
                  onTap: () => showFriendTrend(context, roroFriend),
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
              for (final f in peers)
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
                label: Text(t.feedUnfollow),
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
        title: Text(t.feedUnfollowTitle(friend.name)),
        content: Text(t.feedUnfollowBody),
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
            child: Text(t.feedUnfollow),
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

/// Open the circle stories as one chained tray: your food story, then Eva's.
/// Advancing past the end of one rolls into the next (and back past the start
/// returns to the previous), Instagram-style. [initialStory] picks which opens
/// first (0 = your food story, 1 = Eva).
/// Story-key helpers — the strip uses them for the avatar "seen" ring, and the
/// viewer marks them as each story is shown. The key embeds the content (newest
/// meal + count / the day's Eva lesson) so fresh content shows as unseen again.
String youStoryKey(List<FoodEntry> food) =>
    food.isEmpty ? 'you:empty' : 'you:${food.first.id}:${food.length}';

String evaStoryKey(int index) => 'eva:$index';

Future<void> openCircleStories(
  BuildContext context, {
  required List<FoodEntry> food,
  required String lang,
  required MealPhotos photos,
  required Uint8List? photo,
  required List<EvaLesson> evaLessons, // empty = no Eva story
  required int evaIndex,
  required int initialStory,
  void Function(String key)? onStorySeen,
}) {
  // Eva's story now spans the last 3 days (newest first), mirroring the 3-day
  // circle feed window — one calm lesson page per day, so swiping her story shows
  // the recent days, not just today.
  final evaPages = _evaLast3DaysPages(evaLessons, lang);
  // Stories paired with their seen-keys (same order) so the viewer's
  // onStoryViewed(index) maps straight back to the right key.
  final items = <(Story, String)>[
    (Story(pages: _foodStoryPages(food, photos, photo)), youStoryKey(food)),
    if (evaPages.isNotEmpty) (Story(pages: evaPages), evaStoryKey(evaIndex)),
  ];
  return showStories(
    context,
    stories: [for (final it in items) it.$1],
    initialStory: initialStory,
    onStoryViewed:
        onStorySeen == null ? null : (i) => onStorySeen(items[i].$2),
  );
}

/// Eva's lesson pages for the last 3 days (today first), keyed to each day's
/// deterministic lesson — same 3-day window as the circle photo feed. Empty when
/// she isn't followed (no lessons passed).
List<Widget> _evaLast3DaysPages(List<EvaLesson> lessons, String lang) {
  if (lessons.isEmpty) return const [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final pages = <Widget>[];
  for (var d = 0; d < 3; d++) {
    final day = today.subtract(Duration(days: d));
    final idx = evaLessonIndex(day, lessons.length);
    pages.add(
      _EvaStoryPage(lesson: lessons[idx], lang: lang, index: idx, date: day),
    );
  }
  return pages;
}

/// Open the current user's story tray (their food story → Eva), reading
/// everything it needs from [ref]. Shared by the strip's You/Eva avatars and the
/// Manage-circle handle-card avatar, so tapping any of them opens the story and
/// marks it seen.
void openMyStory(
  BuildContext context,
  WidgetRef ref, {
  int initialStory = 0,
  bool includeEva = true,
}) {
  final lang = Localizations.localeOf(context).languageCode;
  final lessons = ref.read(evaWisdomProvider).asData?.value ?? const [];
  final evaIndex =
      lessons.isEmpty ? 0 : evaLessonIndex(DateTime.now(), lessons.length);
  openCircleStories(
    context,
    food: _recentFoodFor(ref),
    lang: lang,
    photos: ref.read(mealPhotosProvider),
    photo: ref.read(profilePhotoProvider),
    // The "Archive" entry opens only the user's own food story (no Eva chain).
    evaLessons: includeEva ? lessons : const [],
    evaIndex: evaIndex,
    initialStory: initialStory,
    onStorySeen: (key) => ref.read(seenStoriesProvider.notifier).markSeen(key),
  );
}

/// The user's own story key — used to show a "seen" ring on their avatar outside
/// the strip (e.g. the Manage-circle handle card).
String myStorySeenKey(WidgetRef ref) => youStoryKey(_recentFoodFor(ref));

/// The last 7 days of the user's food log (newest first), excluding deleted /
/// story-hidden entries — the basis for both the food story and its seen key.
List<FoodEntry> _recentFoodFor(WidgetRef ref) {
  final now = DateTime.now();
  final weekStart =
      DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  return ref
      .read(foodEntriesProvider)
      .where((e) =>
          !e.deleted && !e.hiddenFromStory && !e.timestamp.isBefore(weekStart))
      .toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
}

/// Your food story pages = one per food logged in the last 7 days (a nudge if
/// none). Shows the whole log — not just meals shared to the circle. [photo] is
/// your profile photo for the story-header avatar.
List<Widget> _foodStoryPages(
  List<FoodEntry> entries,
  MealPhotos photos,
  Uint8List? photo,
) => entries.isEmpty
    ? [_FoodNudgePage(photo: photo)]
    : [
        for (final e in entries)
          _FoodStoryPage(entry: e, photoPath: photos.pathFor(e.id), photo: photo),
      ];

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

Widget _storyHeader(
  String title,
  String subtitle,
  Widget avatar, {
  Widget? trailing,
}) => Row(
  children: [
    avatar,
    const SizedBox(width: 10),
    Expanded(
      child: Column(
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
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    ),
    ?trailing,
  ],
);

/// A small dark-backed delete button for a story page (legible over photos).
class _StoryDeleteButton extends StatelessWidget {
  const _StoryDeleteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: AppLocalizations.of(context).deleteStory,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.32),
      ),
      icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
      onPressed: onPressed,
    );
  }
}

// ---------------------------------------------------------------------------
// Eva — Calm-style scenes. A curated set of soft gradients + a warm glow; each
// daily lesson maps to one deterministically, so the 100 lessons cycle through
// varied dawn/dusk/ocean/forest backdrops (no asset download, works offline).
// Real licensed photography would be a nice follow-up.
// ---------------------------------------------------------------------------

class _CalmScene {
  const _CalmScene(this.colors, this.glow);

  final List<Color> colors; // top → bottom gradient
  final Color glow; // soft radial light near the top
}

const List<_CalmScene> _calmScenes = [
  _CalmScene([Color(0xFFFFCBA4), Color(0xFFFF9A76), Color(0xFF6D4068)], Color(0xFFFFE7C7)),
  _CalmScene([Color(0xFFFF7E5F), Color(0xFFFEB47B), Color(0xFF5B2C6F)], Color(0xFFFFD9A0)),
  _CalmScene([Color(0xFF3A7BD5), Color(0xFF3A6073), Color(0xFF0F2027)], Color(0xFF9BE7FF)),
  _CalmScene([Color(0xFF2E7D5B), Color(0xFF1E5631), Color(0xFF0C2A1E)], Color(0xFFB9F6CA)),
  _CalmScene([Color(0xFF9D7BB5), Color(0xFF6A4C93), Color(0xFF2C1B3D)], Color(0xFFE6D6FF)),
  _CalmScene([Color(0xFF4B6CB7), Color(0xFF314A8A), Color(0xFF182848)], Color(0xFFA9C0FF)),
  _CalmScene([Color(0xFFE8A2B8), Color(0xFFC76B98), Color(0xFF6E3B5E)], Color(0xFFFFD6E8)),
  _CalmScene([Color(0xFF7FD8BE), Color(0xFF4FB0A5), Color(0xFF1F5F73)], Color(0xFFCFFFE6)),
  _CalmScene([Color(0xFFFFC371), Color(0xFFFF8C42), Color(0xFF9A4F3B)], Color(0xFFFFE9C2)),
  _CalmScene([Color(0xFF3F4C9B), Color(0xFF2A2A72), Color(0xFF11102B)], Color(0xFF8E9BFF)),
  _CalmScene([Color(0xFF49C5C0), Color(0xFF2E8C8C), Color(0xFF12404A)], Color(0xFFC8FFF4)),
  _CalmScene([Color(0xFF7B4397), Color(0xFF5A2A82), Color(0xFF2B1240)], Color(0xFFE0B3FF)),
  _CalmScene([Color(0xFFE0C3A0), Color(0xFFC99E75), Color(0xFF7A5A3A)], Color(0xFFFFEFD6)),
  _CalmScene([Color(0xFFA8C8A0), Color(0xFF7BA67D), Color(0xFF3F5E47)], Color(0xFFE4F6DD)),
  _CalmScene([Color(0xFFB24592), Color(0xFF8E2D72), Color(0xFF431A3D)], Color(0xFFFFC2E8)),
  _CalmScene([Color(0xFF6E7F8D), Color(0xFF47606E), Color(0xFF22323C)], Color(0xFFCFE4F0)),
];

_CalmScene _calmSceneFor(int index) =>
    _calmScenes[index.abs() % _calmScenes.length];

class _EvaStoryPage extends StatelessWidget {
  const _EvaStoryPage({
    required this.lesson,
    required this.lang,
    required this.index,
    this.date,
  });

  final EvaLesson lesson;
  final String lang;
  final int index;

  /// The day this lesson is for — shown in the header so the 3-day story's pages
  /// are distinguishable ("Today" for the newest, the date for older days).
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scene = _calmSceneFor(index);
    // Newest page → "Daily lesson"; older days in the 3-day story show their date.
    final ml = MaterialLocalizations.of(context);
    final d = date;
    final now = DateTime.now();
    final subtitle =
        (d != null &&
            !(d.year == now.year && d.month == now.month && d.day == now.day))
        ? ml.formatMediumDate(d)
        : t.evaDailyLesson;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base calming gradient.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: scene.colors,
            ),
          ),
        ),
        // Soft warm glow near the top (a sun/moon feel).
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.62),
              radius: 1.15,
              colors: [scene.glow.withValues(alpha: 0.55), Colors.transparent],
              stops: const [0, 0.72],
            ),
          ),
        ),
        // Gentle bottom scrim so the attribution stays legible on bright scenes.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black38],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, _storyTopPad, 30, 54),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _storyHeader(
                  'Eva',
                  subtitle,
                  const StoryAvatar(initials: 'E', colorSeed: 7, size: 40),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '“',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 76,
                            height: 0.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          lesson.text(lang),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(blurRadius: 14, color: Colors.black38),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          '— ${lesson.author(lang)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            shadows: [
                              Shadow(blurRadius: 10, color: Colors.black45),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FoodStoryPage extends ConsumerStatefulWidget {
  const _FoodStoryPage({
    required this.entry,
    required this.photoPath,
    required this.photo,
  });

  final FoodEntry entry;
  final String photoPath;
  final Uint8List? photo;

  @override
  ConsumerState<_FoodStoryPage> createState() => _FoodStoryPageState();
}

class _FoodStoryPageState extends ConsumerState<_FoodStoryPage> {
  late final Uint8List? _thumb = _decodeThumb(widget.entry.photoThumb);
  late bool _localReady = File(widget.photoPath).existsSync();

  /// True while we check S3 for a photo meal that has neither a local file nor a
  /// synced thumbnail — so we show a loader, not a premature caption.
  bool _resolvingS3 = false;

  @override
  void initState() {
    super.initState();
    // A photo meal with no local file AND no synced thumbnail can still have its
    // full-res backed up in S3 (after a reinstall, or when the thumbnail was too
    // large to sync). Pull it so the real photo shows instead of a bare caption.
    if (!_localReady &&
        _thumb == null &&
        widget.entry.source == FoodSource.photo) {
      _resolvingS3 = true;
      _hydrateFromS3();
    }
  }

  Future<void> _hydrateFromS3() async {
    final token = ref.read(authProvider)?.token;
    var ok = false;
    if (token != null && token.isNotEmpty) {
      ok = await ref
          .read(mealPhotoStoreProvider)
          .ensureLocal(widget.entry.id, token);
    }
    if (mounted) {
      setState(() {
        _localReady = ok;
        _resolvingS3 = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final ml = MaterialLocalizations.of(context);
    final entry = widget.entry;
    final when =
        '${ml.formatMediumDate(entry.timestamp)} · '
        '${ml.formatTimeOfDay(TimeOfDay.fromDateTime(entry.timestamp))}';
    final header = _storyHeader(
      t.foodStory,
      when,
      StoryAvatar(
        imageBytes: widget.photo,
        icon: widget.photo == null ? Icons.person : null,
        colorSeed: 3,
        size: 40,
      ),
      trailing: _StoryDeleteButton(
        onPressed: () => _confirmDelete(context, ref, t),
      ),
    );

    // A meal has a photo if the full-res original is on THIS device, a synced
    // thumbnail rides on the entry, OR we just pulled it from S3. Manual entries
    // (and photo meals whose image is truly gone) fall back to a caption card.
    final hasPhoto = _localReady || _thumb != null;

    if (!hasPhoto) {
      return _StoryScaffold(
        colors: const [Color(0xFF241A40), Color(0xFF0E0B14)],
        header: header,
        body: _resolvingS3
            ? const CircularProgressIndicator(color: Colors.white70)
            : _foodCaption(t, entry, centered: true),
      );
    }

    // Photo is the hero: full-bleed image, dark scrim, header up top, the
    // calories/macros as a caption at the bottom. [_HeroPhoto] shows the synced
    // thumbnail instantly and upgrades to the full-res original (pulling it from
    // the durable S3 store into the cache if this device doesn't have it yet).
    return Stack(
      fit: StackFit.expand,
      children: [
        _HeroPhoto(
          entryId: entry.id,
          photoPath: widget.photoPath,
          thumbBytes: _thumb,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Colors.black87, Colors.black],
              stops: [0.0, 0.4, 0.85, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, _storyTopPad, 26, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const Spacer(),
                _foodCaption(t, entry, centered: false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Confirm, then hide this meal from the story only — the log entry stays in
  /// Today/Trends — and close the story. The strip rebuilds, so the archive
  /// updates.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteStory),
        content: Text(t.deleteStoryBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.deleteStory),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // Hide from the story only — keep the food-log entry (Today/Trends).
    await ref.read(foodEntriesProvider.notifier).hideFromStory(widget.entry.id);
    nav.pop(); // close the whole story viewer
    messenger.showSnackBar(SnackBar(content: Text(t.storyDeleted)));
  }
}

/// The full-bleed Food-story hero image. Shows the synced 1080px thumbnail
/// instantly, and upgrades to the full-resolution original — pulling it from the
/// durable S3 store into the local cache when this device doesn't have it yet
/// (e.g. a new device / after a reinstall). All best-effort: no account, no
/// network, or no remote copy just leaves the thumbnail showing.
class _HeroPhoto extends ConsumerStatefulWidget {
  const _HeroPhoto({
    required this.entryId,
    required this.photoPath,
    required this.thumbBytes,
  });

  final String entryId;
  final String photoPath;
  final Uint8List? thumbBytes;

  @override
  ConsumerState<_HeroPhoto> createState() => _HeroPhotoState();
}

class _HeroPhotoState extends ConsumerState<_HeroPhoto> {
  bool _localReady = false;

  @override
  void initState() {
    super.initState();
    _localReady = File(widget.photoPath).existsSync();
    if (!_localReady) _hydrate();
  }

  Future<void> _hydrate() async {
    final token = ref.read(authProvider)?.token;
    if (token == null || token.isEmpty) return;
    final ok = await ref
        .read(mealPhotoStoreProvider)
        .ensureLocal(widget.entryId, token);
    if (ok && mounted) setState(() => _localReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider? img = _localReady
        ? FileImage(File(widget.photoPath))
        : (widget.thumbBytes != null ? MemoryImage(widget.thumbBytes!) : null);
    if (img == null) return const ColoredBox(color: Color(0xFF0E0B14));
    return Image(
      image: img,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF0E0B14)),
    );
  }
}

/// The meal's calories + macros as a single Instagram-style caption (name on
/// top, nutrition beneath). Centered on the no-photo card; left-aligned over a
/// photo so the picture stays the hero.
/// Decode the entry's synced base64 thumbnail to bytes (null/invalid → null).
Uint8List? _decodeThumb(String? b64) {
  if (b64 == null || b64.isEmpty) return null;
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

Widget _foodCaption(AppLocalizations t, FoodEntry entry, {required bool centered}) {
  final nutrition = [
    t.kcalValue(entry.calories.round().toString()),
    '${t.protein} ${entry.proteinG.round()} g',
    '${t.saturatedFat} ${entry.satFatG.round()} g',
  ].join('   ·   ');
  final align = centered ? TextAlign.center : TextAlign.start;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment:
        centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
    children: [
      Text(
        entry.name,
        textAlign: align,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          height: 1.15,
          shadows: [Shadow(blurRadius: 12, color: Colors.black54)],
        ),
      ),
      const SizedBox(height: 10),
      Text(
        nutrition,
        textAlign: align,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.35,
          shadows: const [Shadow(blurRadius: 10, color: Colors.black54)],
        ),
      ),
    ],
  );
}

class _FoodNudgePage extends StatelessWidget {
  const _FoodNudgePage({required this.photo});

  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _StoryScaffold(
      colors: const [Color(0xFF241A40), Color(0xFF0E0B14)],
      header: _storyHeader(
        t.foodStory,
        '',
        StoryAvatar(
          imageBytes: photo,
          icon: photo == null ? Icons.person : null,
          colorSeed: 3,
          size: 40,
        ),
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
