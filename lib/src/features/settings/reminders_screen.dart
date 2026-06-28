import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../data/notification_service.dart';
import '../../models/meal_type.dart';
import '../../models/reminder.dart';
import '../../providers/providers.dart';
import '../../util/l10n_labels.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/notify_permission_cta.dart';

/// Manage the daily meal reminders: a master on/off, then a list of reminders
/// each of which can be retimed, toggled or deleted, plus "Add reminder".
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool _busy = false;

  /// Push the current settings to the OS. Called after every change so the
  /// scheduled notifications always match what's on screen.
  Future<void> _apply() async {
    await rescheduleReminders(
      service: ref.read(notificationServiceProvider),
      enabled: ref.read(remindersEnabledProvider),
      reminders: ref.read(remindersProvider),
      t: AppLocalizations.of(context),
    );
  }

  Future<void> _toggleMaster(bool value) async {
    setState(() => _busy = true);
    try {
      if (value) {
        // Intent goes on regardless; if iOS denies, the CTA banner prompts.
        final granted = await ref
            .read(remindersEnabledProvider.notifier)
            .enable();
        ref.invalidate(notificationsAllowedProvider);
        if (granted) await _apply();
      } else {
        await ref.read(remindersEnabledProvider.notifier).disable();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleCircle(bool value) async {
    setState(() => _busy = true);
    try {
      if (value) {
        await ref.read(circleNotifyProvider.notifier).enable();
        ref.invalidate(notificationsAllowedProvider);
      } else {
        await ref.read(circleNotifyProvider.notifier).disable();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleComments(bool value) async {
    setState(() => _busy = true);
    try {
      if (value) {
        await ref.read(commentNotifyProvider.notifier).enable();
        ref.invalidate(notificationsAllowedProvider);
      } else {
        await ref.read(commentNotifyProvider.notifier).disable();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editTime(Reminder r) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: r.hour, minute: r.minute),
    );
    if (picked == null) return;
    await ref
        .read(remindersProvider.notifier)
        .setTime(r.id, picked.hour, picked.minute);
    await _apply();
  }

  Future<void> _toggleReminder(Reminder r, bool value) async {
    await ref.read(remindersProvider.notifier).setEnabled(r.id, value);
    await _apply();
  }

  Future<void> _delete(Reminder r) async {
    await ref.read(remindersProvider.notifier).remove(r.id);
    await _apply();
  }

  Future<void> _addReminder() async {
    final result = await showDialog<({MealType meal, TimeOfDay time})>(
      context: context,
      builder: (_) => const _AddReminderDialog(),
    );
    if (result == null) return;
    await ref
        .read(remindersProvider.notifier)
        .add(result.meal, result.time.hour, result.time.minute);
    await _apply();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final enabled = ref.watch(remindersEnabledProvider);
    final reminders = ref.watch(remindersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.reminders)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // If notifications are wanted (either toggle on) but iOS hasn't granted
          // permission, prompt to enable — with the why — so the toggles aren't
          // silent.
          NotifyPermissionCta.maybeShow(ref),
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
              title: Text(
                t.remindersEnable,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(t.remindersSubtitle),
              ),
              isThreeLine: true,
              value: enabled,
              onChanged: _busy ? null : _toggleMaster,
              secondary: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconTile(
                      icon: Icons.notifications_active,
                      color: scheme.primary,
                    ),
            ),
          ),
          if (enabled) ...[
            const SizedBox(height: 16),
            if (reminders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  t.remindersNone,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              for (final r in reminders)
                _ReminderTile(
                  reminder: r,
                  onTapTime: () => _editTime(r),
                  onToggle: (v) => _toggleReminder(r, v),
                  onDelete: () => _delete(r),
                ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addReminder,
              icon: const Icon(Icons.add),
              label: Text(t.addReminder),
            ),
          ],
          const SizedBox(height: 16),
          // Circle activity — same notification permission/service as the meal
          // reminders, surfaced when a friend shares a meal.
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
              title: Text(
                t.circleActivity,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(t.circleActivitySubtitle),
              ),
              isThreeLine: true,
              value: ref.watch(circleNotifyProvider),
              onChanged: _busy ? null : _toggleCircle,
              secondary: IconTile(
                icon: Icons.group_outlined,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Comment notifications — friends commenting on / replying to / @-mentioning
          // you. Synced to the server, which gates the push (so muting really mutes).
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
              title: Text(
                t.commentNotify,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(t.commentNotifySubtitle),
              ),
              isThreeLine: true,
              value: ref.watch(commentNotifyProvider),
              onChanged: _busy ? null : _toggleComments,
              secondary: IconTile(
                icon: Icons.mode_comment_outlined,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _mealIcon(MealType meal) => switch (meal) {
  MealType.breakfast => Icons.bakery_dining_outlined,
  MealType.lunch => Icons.lunch_dining_outlined,
  MealType.dinner => Icons.dinner_dining_outlined,
  MealType.snack => Icons.bedtime_outlined,
};

/// One reminder row: meal icon + label, its time (tap to change), an enable
/// switch, and swipe-to-delete.
class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.onTapTime,
    required this.onToggle,
    required this.onDelete,
  });

  final Reminder reminder;
  final VoidCallback onTapTime;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final time = TimeOfDay(hour: reminder.hour, minute: reminder.minute);
    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTapTime,
          leading: IconTile(
            icon: _mealIcon(reminder.meal),
            color: scheme.primary,
          ),
          title: Text(reminder.meal.labelOf(t)),
          subtitle: Text(time.format(context)),
          trailing: Switch(value: reminder.enabled, onChanged: onToggle),
        ),
      ),
    );
  }
}

/// Pick a meal kind + time for a new reminder.
class _AddReminderDialog extends StatefulWidget {
  const _AddReminderDialog();

  @override
  State<_AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<_AddReminderDialog> {
  MealType _meal = MealType.snack;
  TimeOfDay _time = const TimeOfDay(hour: 15, minute: 0);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.addReminder),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<MealType>(
            initialValue: _meal,
            decoration: InputDecoration(labelText: t.meal),
            items: [
              for (final m in MealType.values)
                DropdownMenuItem(value: m, child: Text(m.labelOf(t))),
            ],
            onChanged: (m) => setState(() => _meal = m ?? _meal),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(_time.format(context)),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (picked != null) setState(() => _time = picked);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (meal: _meal, time: _time)),
          child: Text(t.addReminder),
        ),
      ],
    );
  }
}
