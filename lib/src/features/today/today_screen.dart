import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../models/daily_summary.dart';
import '../../models/food_entry.dart';
import '../../models/user_profile.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../../util/l10n_labels.dart';

/// "Good morning / afternoon / evening, {name}" by the local hour, or the app
/// title when there's no name yet.
String greetingTitle(AppLocalizations t, String? name) {
  final n = name?.trim();
  if (n == null || n.isEmpty) return t.appTitle;
  final hour = DateTime.now().hour;
  if (hour < 12) return t.greetMorning(n);
  if (hour < 18) return t.greetAfternoon(n);
  return t.greetEvening(n);
}

/// The dashboard: calories remaining, protein & saturated-fat quotas, and the
/// day's logged food.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final summary = ref.watch(dailySummaryProvider);
    final entries = ref.watch(entriesForSelectedDayProvider);
    final profile = ref.watch(profileProvider);
    final date = ref.watch(selectedDateProvider);
    final isToday = isSameDay(date, dateOnly(DateTime.now()));
    final healthSupported = ref.watch(healthServiceProvider).isSupported;
    final healthConnected = ref.watch(healthConnectedProvider);

    return Scaffold(
      appBar: AppBar(title: Text(greetingTitle(t, profile.name))),
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
          _CalorieCard(summary: summary, goal: profile.goal),
          if (healthSupported && !healthConnected) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await ref
                    .read(healthConnectedProvider.notifier)
                    .connect();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? t.appleHealthConnected : t.healthNotGranted,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.favorite_outline),
              label: Text(t.connectHealthGarmin),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MacroCard(
                  label: t.protein,
                  icon: Icons.egg_alt_outlined,
                  consumed: summary.consumedProtein,
                  target: summary.proteinTarget,
                  progress: summary.proteinProgress,
                  footer: summary.hitProtein
                      ? t.targetReached
                      : t.toGo(t.gramsValue(kcal(summary.proteinRemaining))),
                  over: false,
                  accent: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MacroCard(
                  label: t.saturatedFat,
                  icon: Icons.water_drop_outlined,
                  consumed: summary.consumedSatFat,
                  target: summary.satFatCap,
                  progress: summary.satFatProgress,
                  footer: summary.isOverSatFat
                      ? t.overBy(t.gramsValue(kcal(-summary.satFatRemaining)))
                      : t.amountLeft(
                          t.gramsValue(kcal(summary.satFatRemaining)),
                        ),
                  over: summary.isOverSatFat,
                  accent: scheme.tertiary,
                ),
              ),
            ],
          ),
          const _WorkoutsCard(),
          const SizedBox(height: 20),
          Text(t.todaysFood, style: Theme.of(context).textTheme.titleMedium),
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
    final t = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final label = isToday
        ? t.navToday
        : DateFormat.MMMEd(localeName).format(date);
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
  const _CalorieCard({required this.summary, required this.goal});

  final DailySummary summary;
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final over = summary.isOverCalories;
    final remaining = summary.caloriesRemaining;
    final adj = goal.calorieAdjustment;
    final adjStr = adj > 0 ? '+${kcal(adj)}' : kcal(adj);
    final breakdown = summary.usingHealthData
        ? t.budgetBreakdown(
            kcal(summary.bmr),
            kcal(summary.activeEnergy),
            adjStr,
          )
        : t.budgetBreakdownEst(kcal(summary.expenditure), adjStr);
    // GXS-style gradient hero — white content on the brand violet→magenta.
    Color white(double a) => Colors.white.withValues(alpha: a);

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.magenta.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
                    color: white(0.25),
                  ),
                ),
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CircularProgressIndicator(
                    value: summary.calorieProgress,
                    strokeWidth: 9,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${(summary.calorieProgress * 100).round()}%',
                  style: text.labelLarge?.copyWith(color: Colors.white),
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
                  over ? t.overBudget : t.caloriesLeftToday,
                  style: text.labelMedium?.copyWith(color: white(0.85)),
                ),
                const SizedBox(height: 2),
                Text(
                  kcal(remaining.abs()),
                  style: text.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t.budgetEaten(
                    kcal(summary.calorieTarget),
                    kcal(summary.consumedCalories),
                  ),
                  style: text.bodySmall?.copyWith(color: white(0.9)),
                ),
                Text(
                  breakdown,
                  style: text.bodySmall?.copyWith(color: white(0.75)),
                ),
              ],
            ),
          ),
        ],
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
    required this.accent,
  });

  final String label;
  final IconData icon;
  final double consumed;
  final double target;
  final double progress;
  final String footer;
  final bool over;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = over ? scheme.error : accent;
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
              '${t.gramsValue(kcal(consumed))} / ${t.gramsValue(kcal(target))}',
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
    final t = AppLocalizations.of(context);
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
            '${entry.mealType.labelOf(t)} · '
            '${t.protein} ${t.gramsValue(kcal(entry.proteinG))} · '
            '${t.saturatedFat} ${t.gramsValue(kcal(entry.satFatG))}',
          ),
          trailing: Text(
            t.kcalValue(kcal(entry.calories)),
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
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          t.nothingLogged,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Today's workouts pulled from Apple Health (e.g. Garmin activities). Renders
/// nothing when there are none.
class _WorkoutsCard extends ConsumerWidget {
  const _WorkoutsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final workouts = ref.watch(workoutsProvider).asData?.value ?? const [];
    if (workouts.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_run, size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    t.workouts,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...workouts.map(
                (w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(w.label, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        [
                          _fmtDuration(w.duration),
                          if (w.energyBurned != null)
                            t.kcalValue(kcal(w.energyBurned!)),
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
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

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

class _ProfilePrompt extends StatelessWidget {
  const _ProfilePrompt();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
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
                t.profilePrompt,
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
