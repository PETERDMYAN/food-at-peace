import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import '../models/meal_type.dart';
import '../models/reminder.dart';

/// A reminder resolved to a concrete time + localized copy, ready to schedule.
typedef ScheduledReminder = ({
  int id,
  int hour,
  int minute,
  String title,
  String body,
});

/// Light, funny per-meal nudges, in whatever language the app is showing.
ScheduledReminder _resolve(int id, AppLocalizations t, Reminder r) => (
  id: id,
  hour: r.hour,
  minute: r.minute,
  title: reminderTitleFor(t, r.meal),
  body: reminderBodyFor(t, r.meal),
);

/// Turns the user's enabled reminders into schedulable items with localized,
/// meal-appropriate copy. Disabled reminders are dropped.
List<ScheduledReminder> scheduledRemindersFor(
  AppLocalizations t,
  List<Reminder> reminders,
) {
  final out = <ScheduledReminder>[];
  var i = 0;
  for (final r in reminders) {
    if (!r.enabled) continue;
    out.add(_resolve(NotificationService.baseId + i, t, r));
    i++;
  }
  return out;
}

String reminderTitleFor(AppLocalizations t, MealType meal) => switch (meal) {
  MealType.breakfast => t.reminderBreakfastTitle,
  MealType.lunch => t.reminderLunchTitle,
  MealType.dinner => t.reminderDinnerTitle,
  MealType.snack => t.reminderSnackTitle,
};

String reminderBodyFor(AppLocalizations t, MealType meal) => switch (meal) {
  MealType.breakfast => t.reminderBreakfastBody,
  MealType.lunch => t.reminderLunchBody,
  MealType.dinner => t.reminderDinnerBody,
  MealType.snack => t.reminderSnackBody,
};

/// Reschedules the device's local notifications to exactly match the user's
/// settings: nothing when reminders are off, otherwise one daily-repeating
/// notification per enabled reminder. Safe to call on every change / app open.
Future<void> rescheduleReminders({
  required NotificationService service,
  required bool enabled,
  required List<Reminder> reminders,
  required AppLocalizations t,
}) async {
  // Notifications are best-effort: a platform error (or no plugin, e.g. in
  // tests) must never break the calling flow.
  try {
    if (!enabled) {
      await service.cancelAll();
      return;
    }
    await service.sync(scheduledRemindersFor(t, reminders));
  } catch (_) {}
}

/// Schedules daily food-logging reminders via local notifications. Each enabled
/// reminder becomes one notification that repeats every day at its local time.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String _channelId = 'daily_reminder';

  /// Notification ids are allocated from here, one per enabled reminder.
  static const int baseId = 7000;

  /// Channel + id for one-off "circle activity" notifications (a friend shared
  /// a meal). Same plugin/service as the meal reminders so it's managed in one
  /// place; a distinct channel keeps the OS grouping/labels sensible.
  static const String _circleChannelId = 'circle_activity';
  static const int circleId = 7100;

  bool _ready = false;

  /// One-time init: timezone database + plugin. Safe to call repeatedly.
  Future<void> init() async {
    if (_ready || kIsWeb) return;
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(
        tz.getLocation(await FlutterTimezone.getLocalTimezone()),
      );
    } catch (_) {
      // Fall back to the default (UTC) if the platform name can't be resolved —
      // better than crashing.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Permission is requested explicitly in [requestPermission], not at init.
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  /// Prompts the OS for notification permission. Returns whether it was granted
  /// (false on platforms/web where notifications aren't available).
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await init();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    return false;
  }

  /// Cancels everything and schedules the given reminders, each repeating daily
  /// at its time.
  Future<void> sync(List<ScheduledReminder> reminders) async {
    if (kIsWeb) return;
    await init();
    await cancelAll();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Meal reminders',
        channelDescription: 'Gentle nudges to log your meals.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (final r in reminders) {
      await _plugin.zonedSchedule(
        r.id,
        r.title,
        r.body,
        _nextInstanceOf(r.hour, r.minute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // Repeat every day at the same wall-clock time.
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  /// Fires an immediate one-off notification (used for "a friend shared a meal"
  /// circle activity). Best-effort; never throws into the caller.
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    try {
      await init();
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _circleChannelId,
          'Circle activity',
          channelDescription: 'When a friend shares a meal to your circle.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
        ),
      );
      await _plugin.show(id, title, body, details);
    } catch (_) {}
  }

  /// The next future occurrence of [hour]:[minute] in local time (today if it's
  /// still ahead, otherwise tomorrow).
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
