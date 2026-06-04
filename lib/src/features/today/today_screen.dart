import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/daily_summary.dart';
import '../../models/food_entry.dart';
import '../../providers/providers.dart';
import '../../util/format.dart';

/// The dashboard: calories remaining, protein & saturated-fat quotas, and the
/// day's logged food.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dailySummaryProvider);
    final entries = ref.watch(entriesForSelectedDayProvider);
    final profile = ref.watch(profileProvider);
    final date = ref.watch(selectedDateProvider);
    final isToday = isSameDay(date, dateOnly(DateTime.now()));
    final healthSupported = ref.watch(healthServiceProvider).isSupported;
    final healthConnected = ref.watch(healthConnectedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Food at Peace')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _DateHeader(
            date: date,
            isToday: isToday,
            onPrev: () => ref.read(selectedDateProvider.notifier).shiftDays(-1),
            onNext: isToday
                ? null
                : () => ref.read(selectedDateProvider.notifier).shiftDays(1),
            onToday: () => ref.read(selectedDateProvider.notifier).goToToday(),
          ),
          const SizedBox(height: 12),
          if (!profile.isConfigured) ...[
            const _ProfilePrompt(),
            const SizedBox(height: 12),
          ],
          _CalorieCard(summary: summary),
          if (healthSupported && !healthConnected) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final ok =
                    await ref.read(healthConnectedProvider.notifier).connect();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Apple Health connected'
                        : 'Health access was not granted'),
                  ),
                );
              },
              icon: const Icon(Icons.favorite_outline),
              label: const Text('Connect Apple Health (calories burned)'),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MacroCard(
                  label: 'Protein',
                  icon: Icons.egg_alt_outlined,
                  consumed: summary.consumedProtein,
                  target: summary.proteinTarget,
                  progress: summary.proteinProgress,
                  footer: summary.hitProtein
                      ? 'Target reached'
                      : '${grams(summary.proteinRemaining)} to go',
                  over: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MacroCard(
                  label: 'Saturated fat',
                  icon: Icons.water_drop_outlined,
                  consumed: summary.consumedSatFat,
                  target: summary.satFatCap,
                  progress: summary.satFatProgress,
                  footer: summary.isOverSatFat
                      ? 'Over by ${grams(-summary.satFatRemaining)}'
                      : '${grams(summary.satFatRemaining)} left',
                  over: summary.isOverSatFat,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text("Today's food",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const _EmptyState()
          else
            ...entries.map(
              (e) => _EntryTile(
                entry: e,
                onDelete: () =>
                    ref.read(foodEntriesProvider.notifier).remove(e.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime date;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final label =
        isToday ? 'Today' : DateFormat('EEE, MMM d').format(date);
    return Row(
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: GestureDetector(
            onTap: isToday ? null : onToday,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class _CalorieCard extends StatelessWidget {
  const _CalorieCard({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final over = summary.isOverCalories;
    final remaining = summary.caloriesRemaining;
    final accent = over ? scheme.error : scheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 9,
                      color: scheme.surfaceContainerHighest,
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(
                      value: summary.calorieProgress,
                      strokeWidth: 9,
                      color: accent,
                    ),
                  ),
                  Text(
                    '${(summary.calorieProgress * 100).round()}%',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    over ? 'Over budget' : 'Calories left today',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kcal(remaining.abs()),
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(color: accent, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Budget ${kcal(summary.calorieTarget)} · '
                    'Eaten ${kcal(summary.consumedCalories)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    summary.usingHealthData
                        ? 'Burn ${kcal(summary.expenditure)} kcal · '
                            '${kcal(summary.activeEnergy)} active via Health'
                        : 'Est. burn ~${kcal(summary.expenditure)} kcal/day',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({
    required this.label,
    required this.icon,
    required this.consumed,
    required this.target,
    required this.progress,
    required this.footer,
    required this.over,
  });

  final String label;
  final IconData icon;
  final double consumed;
  final double target;
  final double progress;
  final String footer;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = over ? scheme.error : scheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(label, style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${grams(consumed)} / ${grams(target)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: color,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(footer, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onDelete});

  final FoodEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline),
      ),
      child: Card(
        child: ListTile(
          title: Text(entry.name),
          subtitle: Text(
            '${entry.mealType.label} · '
            'P ${grams(entry.proteinG)} · Sat ${grams(entry.satFatG)}',
          ),
          trailing: Text(
            '${kcal(entry.calories)} kcal',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'Nothing logged yet.\nTap "Add food" to start.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _ProfilePrompt extends StatelessWidget {
  const _ProfilePrompt();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Set up your profile in Settings for accurate targets.',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
