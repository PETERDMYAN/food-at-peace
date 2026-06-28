import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/util/relative_time.dart';

void main() {
  late AppLocalizations t;
  setUpAll(() async {
    t = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final now = DateTime(2026, 6, 28, 12, 0);
  String ago(Duration d) => relativeTime(t, now.subtract(d), now: now);

  test('under a minute → just now', () {
    expect(ago(const Duration(seconds: 30)), 'just now');
  });
  test('minutes (with singular)', () {
    expect(ago(const Duration(minutes: 1)), '1 minute ago');
    expect(ago(const Duration(minutes: 5)), '5 minutes ago');
    expect(ago(const Duration(minutes: 59)), '59 minutes ago');
  });
  test('hours within a day', () {
    expect(ago(const Duration(hours: 1)), '1 hour ago');
    expect(ago(const Duration(hours: 23)), '23 hours ago');
  });
  test('days above one', () {
    expect(ago(const Duration(days: 1)), '1 day ago');
    expect(ago(const Duration(days: 6)), '6 days ago');
  });
  test('future/clock-skew is clamped to just now', () {
    expect(relativeTime(t, now.add(const Duration(minutes: 5)), now: now), 'just now');
  });
}
