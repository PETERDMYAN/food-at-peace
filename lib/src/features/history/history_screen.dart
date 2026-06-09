import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/food_entry.dart';
import '../../providers/providers.dart';
import '../../util/format.dart';

/// All logged food, grouped by day (most recent first).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(visibleFoodEntriesProvider);

    final byDay = <DateTime, List<FoodEntry>>{};
    for (final e in all) {
      byDay.putIfAbsent(dateOnly(e.timestamp), () => []).add(e);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: days.isEmpty
          ? Center(
              child: Text(
                'No history yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: days.length,
              itemBuilder: (context, i) {
                final day = days[i];
                final entries = byDay[day]!
                  ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                final totalCal =
                    entries.fold<double>(0, (s, e) => s + e.calories);
                return _DaySection(
                  day: day,
                  entries: entries,
                  totalCalories: totalCal,
                  onTapDay: () {
                    ref.read(selectedDateProvider.notifier).set(day);
                  },
                );
              },
            ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.entries,
    required this.totalCalories,
    required this.onTapDay,
  });

  final DateTime day;
  final List<FoodEntry> entries;
  final double totalCalories;
  final VoidCallback onTapDay;

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(day, dateOnly(DateTime.now()));
    final label =
        isToday ? 'Today' : DateFormat('EEE, MMM d, yyyy').format(day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        InkWell(
          onTap: onTapDay,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                Text('${kcal(totalCalories)} kcal',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (final e in entries)
                ListTile(
                  dense: true,
                  title: Text(e.name),
                  subtitle: Text(e.mealType.label),
                  trailing: Text('${kcal(e.calories)} kcal'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
