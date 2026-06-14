import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../data/metrics_service.dart';
import '../../providers/providers.dart';

/// Owner-only metrics dashboard: downloads, opens, usage, purchases, refunds.
/// Reached by tapping the version row in Profile a few times.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final metrics = ref.watch(metricsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.dashboard)),
      body: metrics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (m) => _Body(metrics: m),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.metrics});

  final AppMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final n = NumberFormat.decimalPattern();
    final m = metrics;
    final cards = <Widget>[
      _StatCard(label: t.mDownloads, value: n.format(m.downloads), icon: Icons.download_outlined),
      _StatCard(label: t.mActiveToday, value: n.format(m.activeToday), icon: Icons.bolt_outlined),
      _StatCard(label: t.mOpens, value: n.format(m.opensTotal), icon: Icons.touch_app_outlined),
      _StatCard(label: t.mPhotos, value: n.format(m.photosScanned), icon: Icons.photo_camera_outlined),
      _StatCard(label: t.mBeansSold, value: n.format(m.beansSold), icon: Icons.savings_outlined),
      _StatCard(label: t.mRevenue, value: 'S\$${m.revenueSgd.toStringAsFixed(2)}', icon: Icons.payments_outlined),
      _StatCard(label: t.mRefunds, value: '${m.refunds} · S\$${m.refundSgd.toStringAsFixed(2)}', icon: Icons.undo),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (m.isSample)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.dashboardSample,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: cards,
        ),
        const SizedBox(height: 20),
        Text(t.mOpens7d, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        _OpensBars(values: m.opens7d),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: scheme.primary, size: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A tiny 7-day bar chart of daily opens.
class _OpensBars extends StatelessWidget {
  const _OpensBars({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final v in values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$v',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 86 * (v / maxV),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
