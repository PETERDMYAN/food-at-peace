import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

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
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
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

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet();

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _handle = TextEditingController();

  @override
  void dispose() {
    _handle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final myHandle = ref.watch(myCircleHandleProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
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
            const SizedBox(height: 20),
            // Primary path: share a universal invite link / QR.
            if (myHandle != null) ...[
              InviteShareCard(handle: myHandle),
              const SizedBox(height: 24),
              Text(
                t.inviteHandleLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Secondary path: invite by typing a friend's @handle.
            TextField(
              controller: _handle,
              decoration: InputDecoration(
                labelText: t.inviteHandleLabel,
                prefixText: '@',
              ),
              onSubmitted: (_) => _send(t, messenger),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _send(t, messenger),
              child: Text(t.inviteSend),
            ),
          ],
        ),
      ),
    );
  }

  void _send(AppLocalizations t, ScaffoldMessengerState messenger) {
    final handle = _handle.text.trim();
    if (handle.isEmpty) return;
    ref.read(circleProvider.notifier).invite(handle);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(content: Text(t.inviteSent('@${handle.replaceAll('@', '')}'))),
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
