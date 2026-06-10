import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../models/daily_summary.dart';
import '../../providers/providers.dart';
import '../../util/format.dart';

/// Trends: daily charts comparing actual intake against the current target for
/// calories, protein, and saturated fat over a selectable window, with
/// prev/next paging through earlier windows.
class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key});

  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  /// Selectable window lengths in days.
  static const _options = [1, 7, 30];

  /// The current window length.
  int _period = 7;

  /// How many whole windows back from "now" we're viewing (0 = current).
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final entries = ref.watch(visibleFoodEntriesProvider);
    final profile = ref.watch(profileProvider);
    final localeName = Localizations.localeOf(context).toLanguageTag();

    // Sum each metric per day.
    final totals = <DateTime, _DayTotals>{};
    for (final e in entries) {
      final acc = totals.putIfAbsent(dateOnly(e.timestamp), _DayTotals.new);
      acc.calories += e.calories;
      acc.protein += e.proteinG;
      acc.satFat += e.satFatG;
    }

    // The window: [start..end], shifted back by `_offset` whole windows.
    final today = dateOnly(DateTime.now());
    final end = today.subtract(Duration(days: _offset * _period));
    final start = end.subtract(Duration(days: _period - 1));
    final days = <DateTime>[
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1)))
        d,
    ];

    // Target reference from the current profile (historical days have no
    // per-day HealthKit reading, so use the estimated burn baseline).
    final target = DailySummary.compute(
      date: today,
      entries: const [],
      profile: profile,
    );

    final loggedDays = days.where((d) => totals[d] != null).length;
    List<double> seriesOf(double Function(_DayTotals) pick) => [
      for (final d in days) totals[d] == null ? 0.0 : pick(totals[d]!),
    ];
    int metDays(double Function(_DayTotals) pick, double tgt, bool cap) =>
        days.where((d) {
          final tot = totals[d];
          if (tot == null) return false;
          final v = pick(tot);
          return cap ? v <= tgt : v >= tgt;
        }).length;

    final rangeLabel = _period == 1
        ? DateFormat.MMMEd(localeName).format(end)
        : '${DateFormat.MMMd(localeName).format(start)} – '
              '${DateFormat.MMMd(localeName).format(end)}';
    final canGoNext = _offset > 0;

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
              selected: {_period},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _period = s.first;
                _offset = 0; // jump back to the present on a period change
              }),
            ),
          ),
          const SizedBox(height: 8),
          // Prev / range / next pager.
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _offset++),
                icon: const Icon(Icons.chevron_left),
                tooltip: MaterialLocalizations.of(context).previousPageTooltip,
              ),
              Expanded(
                child: Text(
                  rangeLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                onPressed: canGoNext
                    ? () => setState(() => _offset--)
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: MaterialLocalizations.of(context).nextPageTooltip,
              ),
            ],
          ),
          const SizedBox(height: 8),
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
  final int metDays;
  final int loggedDays;
  final bool kcalUnit;
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
              kcalUnit: kcalUnit,
            ),
          ],
        ),
      ),
    );
  }
}

/// The plot: y-axis labels, bottom-anchored bars, a dashed target line, a sparse
/// row of date labels, and touch-to-inspect — tap or drag to read a day's value.
class _ChartArea extends StatefulWidget {
  const _ChartArea({
    required this.days,
    required this.values,
    required this.target,
    required this.maxY,
    required this.cap,
    required this.kcalUnit,
  });

  final List<DateTime> days;
  final List<double> values;
  final double target;
  final double maxY;
  final bool cap;
  final bool kcalUnit;

  @override
  State<_ChartArea> createState() => _ChartAreaState();
}

class _ChartAreaState extends State<_ChartArea> {
  static const double _plotHeight = 132;
  static const double _yAxisWidth = 34;
  static const double _yAxisGap = 6;

  final GlobalKey _plotKey = GlobalKey();

  /// The day being inspected (null = none) and the measured plot width.
  int? _selected;
  double? _plotWidth;

  void _selectAt(double dx) {
    final box = _plotKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final w = box.size.width;
    final n = widget.values.length;
    if (n == 0 || w <= 0) return;
    final i = (dx / w * n).floor().clamp(0, n - 1);
    if (i != _selected || w != _plotWidth) {
      setState(() {
        _selected = i;
        _plotWidth = w;
      });
    }
  }

  @override
  void didUpdateWidget(_ChartArea old) {
    super.didUpdateWidget(old);
    // Clear a stale selection when the window/series changes.
    if (old.values.length != widget.values.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final localeName = Localizations.localeOf(context).toLanguageTag();
    final df = DateFormat.Md(localeName);
    final values = widget.values;
    final maxY = widget.maxY;
    final target = widget.target;
    final n = widget.days.length;
    final labelled = _labelIndices(n);
    final targetFactor = (target / maxY).clamp(0.0, 1.0);

    Color barColor(Color base, bool dim) =>
        dim ? base.withValues(alpha: 0.35) : base;

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
                child: GestureDetector(
                  key: _plotKey,
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _selectAt(d.localPosition.dx),
                  onHorizontalDragStart: (d) => _selectAt(d.localPosition.dx),
                  onHorizontalDragUpdate: (d) => _selectAt(d.localPosition.dx),
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
                      // Bars — vibrant violet gradient; over-cap days go red;
                      // non-selected dim while inspecting.
                      Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < n; i++)
                              Expanded(
                                child: _BarColumn(
                                  heightFactor: (values[i] / maxY).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  over: widget.cap && values[i] > target,
                                  overColor: barColor(
                                    scheme.error,
                                    _selected != null && _selected != i,
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      barColor(
                                        scheme.primary,
                                        _selected != null && _selected != i,
                                      ),
                                      barColor(
                                        scheme.secondary,
                                        _selected != null && _selected != i,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Target line.
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
                      // Touch-to-inspect overlay (positioned once a tap has
                      // measured the plot width).
                      if (_selected != null && _plotWidth != null)
                        ..._inspectOverlay(context, scheme),
                    ],
                  ),
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
                          child: Text(
                            df.format(widget.days[i]),
                            style: labelStyle,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Guide line + value dot + a callout for the selected day.
  List<Widget> _inspectOverlay(BuildContext context, ColorScheme scheme) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final width = _plotWidth!;
    final i = _selected!;
    final n = widget.values.length;
    final value = widget.values[i];
    final barCenter = (i + 0.5) / n * width;
    final heightFactor = (value / widget.maxY).clamp(0.0, 1.0);
    final over = widget.cap && value > widget.target;
    final dotColor = over ? scheme.error : scheme.primary;

    String fmt(double v) =>
        widget.kcalUnit ? t.kcalValue(kcal(v)) : t.gramsValue(kcal(v));

    const tipW = 124.0;
    final tipLeft = (barCenter - tipW / 2).clamp(0.0, width - tipW);

    return [
      Positioned(
        left: barCenter - 0.5,
        top: 0,
        bottom: 0,
        child: Container(
          width: 1,
          color: scheme.tertiary.withValues(alpha: 0.55),
        ),
      ),
      Positioned(
        left: barCenter - 4,
        bottom: heightFactor * _plotHeight - 4,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: dotColor, width: 1.5),
          ),
        ),
      ),
      Positioned(
        left: tipLeft,
        top: 0,
        child: Container(
          width: tipW,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.MMMd(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(widget.days[i]),
                style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                fmt(value),
                style: text.titleSmall?.copyWith(
                  color: over ? scheme.error : scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${t.chartTarget} ${fmt(widget.target)}',
                style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

/// A single bottom-anchored bar filling [heightFactor] of the plot height.
class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.heightFactor,
    required this.over,
    required this.overColor,
    required this.gradient,
  });

  final double heightFactor;
  final bool over;
  final Color overColor;
  final Gradient gradient;

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
            color: over ? overColor : null,
            gradient: over ? null : gradient,
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
