import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';

/// A prominent "turn on notifications" call-to-action, shown when the user wants
/// notifications (meal reminders and/or circle activity are on — both default
/// on) but iOS hasn't granted permission, so the toggles would otherwise be
/// silent. It explains *why* and offers one tap to enable: the native iOS prompt
/// the first time, then a direct route to the app's Settings page after (iOS only
/// shows its system prompt once).
///
/// Use [maybeShow] to render it only when it's actually needed.
class NotifyPermissionCta extends ConsumerWidget {
  const NotifyPermissionCta({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  /// Returns the CTA when notifications are wanted (either toggle on) but the OS
  /// hasn't granted permission; otherwise an empty box. Keeps the gating in one
  /// place so every surface (onboarding, Reminders, Circle) behaves the same.
  static Widget maybeShow(WidgetRef ref, {EdgeInsetsGeometry? margin}) {
    final wanted = ref.watch(remindersEnabledProvider) ||
        ref.watch(circleNotifyProvider);
    // Default to "allowed" while the async status loads, so the card never flashes
    // in and back out.
    final allowed =
        ref.watch(notificationsAllowedProvider).asData?.value ?? true;
    if (!wanted || allowed) return const SizedBox.shrink();
    return NotifyPermissionCta(margin: margin);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // After the first ask iOS won't prompt again → switch to a one-tap "Open
    // Settings" route.
    final asked = ref.watch(notificationAskedProvider);
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active_outlined,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.notifyCtaTitle,
                  style: text.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  asked ? t.notifyDeniedHint : t.notifyCtaBody,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _enable(context, ref, asked),
            child: Text(asked ? t.notifyOpenSettings : t.notifyCtaAction),
          ),
        ],
      ),
    );
  }

  Future<void> _enable(BuildContext context, WidgetRef ref, bool asked) async {
    if (!asked) {
      await ref.read(notificationServiceProvider).requestPermission();
      await ref.read(notificationAskedProvider.notifier).markAsked();
      ref.invalidate(notificationsAllowedProvider);
      return;
    }
    try {
      await launchUrl(
        Uri.parse('app-settings:'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    ref.invalidate(notificationsAllowedProvider);
  }
}
