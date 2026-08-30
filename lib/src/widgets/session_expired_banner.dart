import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../app_globals.dart';
import '../data/auth_client.dart';
import '../providers/providers.dart';

/// "Your sign-in expired" card, shown at the top of the home shell once the app
/// has found its stored session is no longer valid (stale at launch, a 401 from
/// the server, or a renewal the server refused). Offers the same Sign in with
/// Apple flow as Settings, or "Later" to dismiss.
///
/// Before 1.1.3 the app just signed the user out silently — sync, photo backup
/// and Circle sharing all stopped with no explanation, which users read as "the
/// server is broken" / "my photos no longer appear in the Circle".
class SessionExpiredBanner extends ConsumerStatefulWidget {
  const SessionExpiredBanner({super.key});

  @override
  ConsumerState<SessionExpiredBanner> createState() =>
      _SessionExpiredBannerState();
}

class _SessionExpiredBannerState extends ConsumerState<SessionExpiredBanner> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      // Success clears the notice (AuthNotifier.signIn), which hides this card.
      await ref.read(authProvider.notifier).signIn();
    } on SignInCancelled {
      // user dismissed the Apple sheet — keep offering
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (_) {
      if (mounted) _toast(AppLocalizations.of(context).signInFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    rootMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(sessionExpiredNoticeProvider)) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_clock_outlined, color: scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.sessionExpiredTitle,
                      style: text.titleSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.sessionExpiredBody,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onPrimaryContainer,
                ),
                onPressed: _busy
                    ? null
                    : () =>
                        ref.read(sessionExpiredNoticeProvider.notifier).clear(),
                child: Text(t.sessionExpiredLater),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.apple, size: 18),
                label: Text(t.sessionExpiredAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
