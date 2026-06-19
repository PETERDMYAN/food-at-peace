import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/invite_link.dart';
import '../../data/profile_photo.dart';
import '../../providers/providers.dart';
import '../../widgets/story_avatar.dart';

/// The shareable invite block: the viewer's @handle, a QR of their universal
/// invite link, and Share / Copy actions. The link opens the app to a
/// "Connect with @handle" sheet (or the website if the app isn't installed),
/// so it works pasted into WeChat / WhatsApp / SMS or scanned as a QR.
class InviteShareCard extends ConsumerWidget {
  const InviteShareCard({super.key, required this.handle});

  /// The viewer's own handle (bare, no leading `@`).
  final String handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final link = inviteLinkFor(handle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // QR must sit on white to stay scannable in the dark theme.
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: QrImageView(
              data: link,
              version: QrVersions.auto,
              size: 184,
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          t.scanToConnect,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              IconButton(
                tooltip: t.copyLink,
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.inviteLinkCopied)),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Builder(
          builder: (btnContext) => FilledButton.icon(
            icon: const Icon(Icons.ios_share),
            label: Text(t.shareInvite),
            onPressed: () {
              // sharePositionOrigin avoids an iPad popover crash.
              final box = btnContext.findRenderObject() as RenderBox?;
              Share.share(
                t.shareInviteMessage(link),
                subject: 'Food at Peace',
                sharePositionOrigin: box != null
                    ? box.localToGlobal(Offset.zero) & box.size
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Shows the viewer's own @handle (with copy + edit), or a "set your handle"
/// button when they haven't picked one yet. Friends connect using this handle.
/// When [onAvatarTap] is set, the user's own avatar is shown on the left and
/// tapping it opens their story (used on the Manage-circle screen).
class MyHandleCard extends ConsumerWidget {
  const MyHandleCard({
    super.key,
    required this.handle,
    required this.onEdit,
    this.onAvatarTap,
    this.seen = false,
  });

  final String? handle;
  final VoidCallback onEdit;

  /// Tapping the user's avatar opens their story; null hides the avatar.
  final VoidCallback? onAvatarTap;

  /// Show a grey "seen" ring on the avatar (story already viewed).
  final bool seen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (handle == null) {
      return OutlinedButton.icon(
        onPressed: onEdit,
        icon: const Icon(Icons.alternate_email),
        label: Text(t.setHandle),
      );
    }
    final at = '@$handle';
    final photo = ref.watch(profilePhotoProvider);
    return Container(
      // Left inset matches the section tiles' ListTile contentPadding (12) so the
      // avatar lines up vertically with the official/peer rows below.
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (onAvatarTap != null) ...[
            StoryAvatar(
              imageBytes: photo,
              icon: photo == null ? Icons.person : null,
              colorSeed: 3,
              // Same size as the tile avatars below (40) so they all align.
              size: 40,
              seen: seen,
              onTap: onAvatarTap,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.yourHandle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  at,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t.setHandle,
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: t.yourHandle,
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: at));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t.handleCopied(at))),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Prompts for a handle and applies it via [CircleNotifier.setHandle], showing
/// the outcome as a SnackBar. Shared by the invite sheet and the manage screen.
Future<void> editCircleHandle(BuildContext context, WidgetRef ref) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final submitted = await showDialog<String>(
    context: context,
    builder: (_) => _SetHandleDialog(initial: ref.read(myCircleHandleProvider)),
  );
  if (submitted == null || submitted.trim().isEmpty) return;
  final outcome = await ref.read(circleProvider.notifier).setHandle(submitted);
  final cleaned = '@${submitted.trim().replaceAll('@', '').toLowerCase()}';
  final msg = switch (outcome) {
    SetHandleResult.ok => t.handleSaved(cleaned),
    SetHandleResult.taken => t.handleTaken,
    SetHandleResult.invalid => t.handleInvalid,
    SetHandleResult.error => t.handleError,
  };
  messenger.showSnackBar(SnackBar(content: Text(msg)));
}

/// Handle-entry dialog. Owns its [TextEditingController] so it's disposed only
/// after the dismiss animation finishes — disposing it synchronously after
/// `showDialog` returns crashes the dialog mid-animation.
class _SetHandleDialog extends StatefulWidget {
  const _SetHandleDialog({this.initial});

  final String? initial;

  @override
  State<_SetHandleDialog> createState() => _SetHandleDialogState();
}

class _SetHandleDialogState extends State<_SetHandleDialog> {
  late final _controller = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.setHandle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(prefixText: '@', helperText: t.handleHint),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(t.save),
        ),
      ],
    );
  }
}
