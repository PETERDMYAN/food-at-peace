import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../data/auth_client.dart';
import '../../data/sync_engine.dart';
import '../../models/daily_summary.dart';
import '../../models/user_profile.dart';
import '../../providers/providers.dart';
import '../../util/format.dart';
import '../../util/l10n_labels.dart';
import '../feedback/feedback_screen.dart';

/// Profile setup (drives all targets), weight log, Claude key, Apple
/// Health/Garmin, language, and feedback.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late UserProfile _draft;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(profileProvider);
    _age = TextEditingController(text: _draft.age.toString());
    _height = TextEditingController(text: _draft.heightCm.round().toString());
    _weight = TextEditingController(text: _draft.weightKg.toString());
  }

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// Auto-save: persist (and sync) the profile on every edit — there's no Save
  /// button. `ProfileNotifier.save` bumps `updatedAt`, which the sync engine
  /// picks up (debounced) and pushes to the backend.
  void _apply(UserProfile next) {
    setState(() => _draft = next);
    ref.read(profileProvider.notifier).save(next.copyWith(isConfigured: true));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Compute the target exactly like the Today budget so the preview matches it
    // (full-day BMR + measured active when Health is connected, else estimated).
    final summary = DailySummary.compute(
      date: dateOnly(DateTime.now()),
      entries: const [],
      profile: _draft,
      energyOut: ref.watch(energyOutProvider).asData?.value,
    );
    final adj = _draft.goal.calorieAdjustment;
    final adjStr = adj > 0 ? '+${kcal(adj)}' : kcal(adj);
    final breakdown = summary.usingHealthData
        ? t.budgetBreakdown(
            kcal(summary.bmr),
            kcal(summary.activeEnergy),
            adjStr,
          )
        : t.budgetBreakdownEst(kcal(summary.expenditure), adjStr);

    return Scaffold(
      appBar: AppBar(title: Text(t.navSettings)),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(t.profile, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _label(context, t.sex),
          SegmentedButton<Sex>(
            segments: Sex.values
                .map((s) => ButtonSegment(value: s, label: Text(s.labelOf(t))))
                .toList(),
            selected: {_draft.sex},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _apply(_draft.copyWith(sex: s.first)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(labelText: t.age),
                  onChanged: (v) =>
                      _apply(_draft.copyWith(age: int.tryParse(v))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: TextInputType.number,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(labelText: t.heightCm),
                  onChanged: (v) =>
                      _apply(_draft.copyWith(heightCm: double.tryParse(v))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(labelText: t.weightKg),
                  onChanged: (v) =>
                      _apply(_draft.copyWith(weightKg: double.tryParse(v))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label(context, t.goal),
          SegmentedButton<Goal>(
            segments: Goal.values
                .map((g) => ButtonSegment(value: g, label: Text(g.labelOf(t))))
                .toList(),
            selected: {_draft.goal},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _apply(_draft.copyWith(goal: s.first)),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.yourTargets,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _statRow(
                    t.dailyCalorieTarget,
                    t.kcalValue(kcal(summary.calorieTarget)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 6),
                    child: Text(
                      breakdown,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _statRow(
                    t.proteinTargetLabel,
                    t.gramsValue(kcal(summary.proteinTarget)),
                  ),
                  _statRow(t.satFatCap, t.gramsValue(kcal(summary.satFatCap))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _AccountCard(),
          const SizedBox(height: 12),
          const _WeightCard(),
          const SizedBox(height: 12),
          const _HealthCard(),
          const SizedBox(height: 12),
          const _LanguageCard(),
          const SizedBox(height: 12),
          const _FeedbackTile(),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );

  Widget _statRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text(value)],
    ),
  );
}

String _fmtKg(double kg) => kg.toStringAsFixed(1);

/// Logs body weight and shows recent readings.
class _WeightCard extends ConsumerWidget {
  const _WeightCard();

  Future<void> _logWeight(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: _fmtKg(ref.read(profileProvider).weightKg),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.logWeight),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: t.weightKg,
            hintText: t.enterWeight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: Text(t.save),
          ),
        ],
      ),
    );
    if (result == null || result <= 0) return;
    await ref.read(weightEntriesProvider.notifier).add(result);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.weightSaved)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final entries = ref.watch(visibleWeightEntriesProvider);
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final latest = entries.isNotEmpty
        ? entries.first.kg
        : ref.watch(profileProvider).weightKg;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_weight_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  t.weightTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  t.weightKgValue(_fmtKg(latest)),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            for (final e in entries.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat.yMMMd(localeName).format(e.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      t.weightKgValue(_fmtKg(e.kg)),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _logWeight(context, ref),
              icon: const Icon(Icons.add),
              label: Text(t.logWeight),
            ),
          ],
        ),
      ),
    );
  }
}

/// Language selector: follow the system, or force English / Chinese.
class _LanguageCard extends ConsumerWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = ref.watch(localeProvider)?.languageCode ?? 'system';

    void choose(String? v) {
      ref
          .read(localeProvider.notifier)
          .setLocale(v == null || v == 'system' ? null : Locale(v));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.language, color: scheme.primary),
                const SizedBox(width: 8),
                Text(t.language, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            for (final opt in [
              ('system', t.languageSystem),
              ('en', t.languageEnglish),
              ('zh', t.languageChinese),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selected == opt.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected == opt.$1 ? scheme.primary : null,
                ),
                title: Text(opt.$2),
                onTap: () => choose(opt.$1),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the feedback form.
class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.feedback_outlined, color: scheme.primary),
        title: Text(t.feedback),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const FeedbackScreen())),
      ),
    );
  }
}

/// Sign in with Apple to enable cloud sync (optional — the app works
/// signed-out). Shows the signed-in account + Sign out when authenticated.
class _AccountCard extends ConsumerStatefulWidget {
  const _AccountCard();

  @override
  ConsumerState<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<_AccountCard> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).signIn();
    } on SignInCancelled {
      // user dismissed the Apple sheet — no-op
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (_) {
      if (mounted) _toast(AppLocalizations.of(context).signInFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() => ref.read(authProvider.notifier).signOut();

  String _syncStatus(AppLocalizations t, SyncState sync) {
    if (sync.phase == SyncPhase.syncing) return t.syncing;
    if (sync.phase == SyncPhase.error) return sync.error ?? '';
    final at = sync.lastSyncedAt;
    return at == null ? '' : t.lastSynced(DateFormat.Hm().format(at));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(authProvider);
    final sync = ref.watch(syncEngineProvider);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.account,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (session != null)
                  Icon(Icons.check_circle, color: scheme.primary, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            if (session != null) ...[
              Text(
                t.signedInAs(session.email ?? session.userId),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: sync.phase == SyncPhase.syncing
                        ? null
                        : () => ref.read(syncEngineProvider.notifier).syncNow(),
                    icon: const Icon(Icons.sync, size: 18),
                    label: Text(t.syncNow),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      _syncStatus(t, sync),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: _signOut, child: Text(t.signOut)),
              ),
            ] else ...[
              Text(
                t.signInPrompt,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (_busy)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                SignInWithAppleButton(
                  onPressed: _signIn,
                  style: Theme.of(context).brightness == Brightness.dark
                      ? SignInWithAppleButtonStyle.white
                      : SignInWithAppleButtonStyle.black,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Connect/disconnect Apple Health (which also carries Garmin data) and shows
/// what the app reads and writes.
class _HealthCard extends ConsumerWidget {
  const _HealthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final supported = ref.watch(healthServiceProvider).isSupported;
    final connected = ref.watch(healthConnectedProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_outline, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.healthGarminTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (connected)
                  Icon(Icons.check_circle, color: scheme.primary, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              !supported
                  ? t.healthNotAvailable
                  : connected
                  ? t.healthConnectedBody
                  : t.healthConnectBody,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (supported && !connected) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
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
                label: Text(t.connectAppleHealth),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
