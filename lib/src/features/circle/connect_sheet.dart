import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../data/circle_client.dart';
import '../../providers/providers.dart';
import '../../widgets/story_avatar.dart';

/// Shows the "Add @handle to your circle?" confirmation when the user opens an
/// invite link/QR. Tapping Connect calls `/circle/connect` — both sides become
/// connected immediately (the inviter consented by sharing the link).
Future<void> showConnectSheet(BuildContext context, String handle) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ConnectSheet(handle: handle),
  );
}

String _initialsFor(String handle) {
  final h = handle.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
  if (h.isEmpty) return '?';
  return (h.length == 1 ? h : h.substring(0, 2)).toUpperCase();
}

class _ConnectSheet extends ConsumerStatefulWidget {
  const _ConnectSheet({required this.handle});

  final String handle;

  @override
  ConsumerState<_ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends ConsumerState<_ConnectSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final at = '@${widget.handle}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StoryAvatar(
              initials: _initialsFor(widget.handle),
              colorSeed: widget.handle.hashCode,
              size: 68,
            ),
            const SizedBox(height: 16),
            Text(
              t.connectTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              t.connectPrompt(at),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _connect,
                child: _busy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Text(t.connecting),
                        ],
                      )
                    : Text(t.connectCta),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: Text(t.cancel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context);
    try {
      final name = await ref.read(circleProvider.notifier).connect(widget.handle);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(t.connectedToast(name ?? '@${widget.handle}'))),
      );
    } on CircleException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(t.connectFailed)));
    }
  }
}
