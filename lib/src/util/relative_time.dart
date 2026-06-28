import 'package:food_at_peace/l10n/app_localizations.dart';

/// A short, localized relative time: "just now" (< 1 min), "X minutes ago"
/// (< 1 hour), "X hours ago" (< 1 day), else "X days ago". Used for feed posts
/// and the food story. [now] is injectable for tests.
String relativeTime(AppLocalizations t, DateTime when, {DateTime? now}) {
  var diff = (now ?? DateTime.now()).difference(when);
  if (diff.isNegative) diff = Duration.zero; // a clock skew shouldn't read "in the future"
  if (diff.inMinutes < 1) return t.timeJustNow;
  if (diff.inMinutes < 60) return t.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return t.timeHoursAgo(diff.inHours);
  return t.timeDaysAgo(diff.inDays);
}
