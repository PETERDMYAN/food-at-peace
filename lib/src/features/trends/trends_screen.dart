import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../models/daily_summary.dart';
import '../../providers/providers.dart';
import '../../util/format.dart';

/// Trends: daily charts comparing actual intake against the current target for
/// calories, protein, and saturated fat over the recent days.
class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key});

  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  /// Selectable windows (days), ending today (inclusive).
  static const _options = [7, 14, 30];
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final entries = ref.watch(visibleFoodEntriesProvider);
    final profile = ref.watch(profileProvider);

    // Sum each metric per day.
    final totals = <DateTime, _DayTotals>{};
    for (final e in entries) {
      final acc = totals.putIfAbsent(dateOnly(e.timestamp), _DayTotals.new);
      acc.calories += e.calories;
      acc.protein += e.proteinG;
      acc.satFat += e.satFatG;
    }

    // Continuous daily axis: the selected window ending today (inclusive).
    final today = dateOnly(DateTime.now());
    final start = today.subtract(Duration(days: _days - 1));
    final days = <DateTime>[
      for (var d = start; !d.isAfter(today); d = d.add(const Duration(days: 1)))
        d,
    ];

    // A stable target reference from the current profile. Historical days have
    // no per-day HealthKit reading, so the target uses the profile's estimated
    // burn — the same baseline the Today screen falls back to.
    final target = DailySummary.compute(
      date: today,
      entries: const [],
      profile: profile,
    );

    final loggedDays = days.where((d) => totals[d] != null).length;
    List<double> seriesOf(double Function(_DayTotals) pick) => [
      for (final d in days) totals[d] == null ? 0.0 : pick(totals[d]!),
    ];
    // Days (with food logged) where the target was met: under the cap for
    // calories / saturated fat, at-or-above for protein.
    int metDays(double Function(_DayTotals) pick, double tgt, bool cap) =>
        days.where((d) {
          final tot = totals[d];
          if (tot == null) return false;
          final v = pick(tot);
          return cap ? v <= tgt : v >= tgt;
        }).length;

    return Scaffold(
      appBar: AppBar(title: Text(t.navTrends)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Center(
            child: SegmentedButton<int>(
              segments: [
                for (final d in _options)
                  ButtonSegment(value: d, label: Text(t.daysCount(d))),
              ],
              selected: {_days},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _days = s.first),
            ),
          ),
          const SizedBox(height: 16),
          if (loggedDays == 0)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                t.noTrendsYet,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            _TrendCard(
              title: t.calories,
              days: days,
              values: seriesOf((d) => d.calories),
              target: target.calorieTarget,
              metDays: metDays((d) => d.calories, target.calorieTarget, true),
              loggedDays: loggedDays,
              kcalUnit: true,
              cap: true,
            ),
            const SizedBox(height: 16),
            _TrendCard(
              title: t.protein,
              days: days,
              values: seriesOf((d) => d.protein),
              target: target.proteinTarget,
              metDays: metDays((d) => d.protein, target.proteinTarget, false),
              loggedDays: loggedDays,
              kcalUnit: false,
              cap: false,
            ),
            const SizedBox(height: 16),
            _TrendCard(
              title: t.saturatedFat,
              days: days,
              values: seriesOf((d) => d.satFat),
              target: target.satFatCap,
              metDays: metDays((d) => d.satFat, target.satFatCap, true),
              loggedDays: loggedDays,
              kcalUnit: false,
              cap: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Accumulates a single day's macro totals.
class _DayTotals {
  double calories = 0;
  double protein = 0;
  double satFat = 0;
}

/// One metric's card: title, legend, and the daily actual-vs-target chart.
class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.days,
    required this.values,
    required this.target,
    required this.metDays,
    required this.loggedDays,
    required this.kcalUnit,
    required this.cap,
  });

  final String title;
  final List<DateTime> days;
  final List<double> values;
  final double target;

  /// Days on target, out of the days with food logged in the window.
  final int metDays;
  final int loggedDays;

  /// Whether the metric is measured in kcal (vs grams) — for label formatting.
  final bool kcalUnit;

  /// True when exceeding the target is "bad" (calories, saturated fat) so those
  /// bars turn red; false when more is fine (protein).
  final bool cap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final maxValue = values.fold<double>(0, math.max);
    final maxY = _niceCeil(math.max(maxValue, target) * 1.05);
    final targetText = kcalUnit
        ? t.kcalValue(kcal(target))
        : t.gramsValue(kcal(target));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              t.onTargetDays(metDays, loggedDays),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _LegendSwatch(color: scheme.primary),
                const SizedBox(width: 5),
                Text(t.chartActual, style: theme.textTheme.labelSmall),
                const SizedBox(width: 16),
                _LegendDash(color: scheme.tertiary),
                const SizedBox(width: 5),
                Text(
                  '${t.chartTarget} · $targetText',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ChartArea(
              days: days,
              values: values,
              target: target,
              maxY: maxY,
              cap: cap,
            ),
          ],
        ),
      ),
    );
  }
}

/// The plot: y-axis labels, bottom-anchored bars, a dashed target line, and a
/// sparse row of date labels.
class _ChartArea extends StatelessWidget {
  const _ChartArea({
    required this.days,
    required this.values,
    required this.target,
    required this.maxY,
    required this.cap,
  });

  final List<DateTime> days;
  final List<double> values;
  final double target;
  final double maxY;
  final bool cap;

  static const double _plotHeight = 132;
  static const double _yAxisWidth = 34;
  static const double _yAxisGap = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final localeName = Localizations.localeOf(context).toLanguageTag();
    final df = DateFormat.Md(localeName);
    final n = days.length;
    final labelled = _labelIndices(n);
    final targetFactor = (target / maxY).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _plotHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _yAxisWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(maxY.round().toString(), style: labelStyle),
                    Text('0', style: labelStyle),
                  ],
                ),
              ),
              const SizedBox(width: _yAxisGap),
              Expanded(
                child: Stack(
                  children: [
                    // Baseline at zero.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 1,
                        color: scheme.outlineVariant,
                      ),
                    ),
                    // Bars — vibrant violet gradient; over-cap days go red.
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < n; i++)
                            Expanded(
                              child: _BarColumn(
                                heightFactor: (values[i] / maxY).clamp(0.0, 1.0),
                                color: scheme.error,
                                gradient: cap && values[i] > target
                                    ? null
                                    : LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          scheme.primary,
                                          scheme.secondary,
                                        ],
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Target line — high-contrast magenta so it reads on dark.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: targetFactor * _plotHeight,
                      child: SizedBox(
                        height: 2,
                        child: CustomPaint(
                          painter: _DashedLinePainter(color: scheme.tertiary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: _yAxisWidth + _yAxisGap),
          child: Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: labelled.contains(i)
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(df.format(days[i]), style: labelStyle),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single bottom-anchored bar filling [heightFactor] of the plot height.
class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.heightFactor,
    required this.color,
    this.gradient,
  });

  final double heightFactor;
  final Color color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: FractionallySizedBox(
        alignment: Alignment.bottomCenter,
        heightFactor: heightFactor,
        widthFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _LegendDash extends StatelessWidget {
  const _LegendDash({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 3,
      child: CustomPaint(painter: _DashedLinePainter(color: color)),
    );
  }
}

/// Paints a horizontal dashed line, centered vertically in its bounds.
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dash = 6.0, gap = 4.0;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

/// Rounds [v] up to a clean axis maximum (1/1.5/2/2.5/3/4/5/6/8 × 10ⁿ).
double _niceCeil(double v) {
  if (v <= 0) return 1;
  final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final norm = v / mag;
  const steps = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0];
  final step = steps.firstWhere((s) => s >= norm, orElse: () => 10.0);
  return step * mag;
}

/// Up to 5 evenly spaced indices (always including the first and last day) to
/// label on the x-axis without crowding.
Set<int> _labelIndices(int n) {
  if (n <= 1) return {0};
  final count = math.min(n, 5);
  return {
    for (var k = 0; k < count; k++) ((k * (n - 1)) / (count - 1)).round(),
  };
}
