import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../models/friend.dart';
import '../../providers/providers.dart';
import '../../widgets/story_avatar.dart';
import 'circle_strip.dart';
import 'invite_card.dart';

/// Full friend-management screen: share your invite (QR + link), see and remove
/// connected friends, accept/decline incoming requests, and cancel invites you
/// sent. Reached from the "Manage circle" action on the Trends strip.
class ManageCircleScreen extends ConsumerWidget {
  const ManageCircleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final friends = ref.watch(circleProvider);
    final myHandle = ref.watch(myCircleHandleProvider);
    final connected =
        friends.where((f) => f.status == FriendStatus.connected).toList();
    final incoming =
        friends.where((f) => f.status == FriendStatus.incoming).toList();
    final outgoing =
        friends.where((f) => f.status == FriendStatus.outgoing).toList();

    return Scaffold(
      appBar: AppBar(title: Text(t.manageCircle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          MyHandleCard(
            handle: myHandle,
            onEdit: () => editCircleHandle(context, ref),
          ),
          const SizedBox(height: 20),
          if (myHandle != null) InviteShareCard(handle: myHandle),
          if (connected.isEmpty && incoming.isEmpty && outgoing.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Text(
                t.circleEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (incoming.isNotEmpty) ...[
            _SectionHeader(t.sectionRequests, count: incoming.length),
            for (final f in incoming)
              _FriendTile(
                friend: f,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () =>
                          ref.read(circleProvider.notifier).remove(f.id),
                      child: Text(t.decline),
                    ),
                    FilledButton(
                      onPressed: () {
                        ref.read(circleProvider.notifier).accept(f.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.friendAccepted(f.name))),
                        );
                      },
                      child: Text(t.accept),
                    ),
                  ],
                ),
              ),
          ],
          if (connected.isNotEmpty) ...[
            _SectionHeader(t.sectionConnected, count: connected.length),
            for (final f in connected)
              _FriendTile(
                friend: f,
                trailing: IconButton(
                  tooltip: t.removeFriend,
                  icon: Icon(
                    Icons.person_remove_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _confirmRemove(context, ref, t, f),
                ),
              ),
          ],
          if (outgoing.isNotEmpty) ...[
            _SectionHeader(t.sectionInvited, count: outgoing.length),
            for (final f in outgoing)
              _FriendTile(
                friend: f,
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(circleProvider.notifier).remove(f.id),
                  child: Text(t.cancelInvite),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    Friend friend,
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
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        '$label · $count',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.trailing});

  final Friend friend;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final connected = friend.status == FriendStatus.connected;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
        onTap: connected ? () => showFriendTrend(context, friend) : null,
        leading: StoryAvatar(
          initials: friend.initials,
          colorSeed: friend.id.hashCode,
          size: 40,
          muted: friend.status == FriendStatus.outgoing,
        ),
        title: Text(friend.name),
        subtitle: Text(friend.handle),
        trailing: trailing,
      ),
    );
  }
}
