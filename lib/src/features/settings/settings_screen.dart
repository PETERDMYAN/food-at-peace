import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../models/user_profile.dart';
import '../../nutrition/nutrition_math.dart';
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

  void _save() {
    final t = AppLocalizations.of(context);
    ref.read(profileProvider.notifier).save(_draft.copyWith(isConfigured: true));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.profileSaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bmr = NutritionMath.mifflinStJeorBmr(_draft);
    final tdee = NutritionMath.estimatedTdee(_draft);
    final calTarget =
        NutritionMath.calorieTarget(expenditure: tdee, goal: _draft.goal);
    final protein = NutritionMath.proteinTargetG(_draft);
    final satCap = NutritionMath.satFatCapG(calorieTarget: calTarget);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.navSettings),
        actions: [
          TextButton(onPressed: _save, child: Text(t.save)),
        ],
      ),
      body: ListView(
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
            onSelectionChanged: (s) =>
                setState(() => _draft = _draft.copyWith(sex: s.first)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t.age),
                  onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(age: int.tryParse(v))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t.heightCm),
                  onChanged: (v) => setState(() =>
                      _draft = _draft.copyWith(heightCm: double.tryParse(v))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: t.weightKg),
                  onChanged: (v) => setState(() =>
                      _draft = _draft.copyWith(weightKg: double.tryParse(v))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label(context, t.activityLevel),
          Wrap(
            spacing: 8,
            children: ActivityLevel.values
                .map(
                  (a) => ChoiceChip(
                    label: Text(a.labelOf(t)),
                    selected: _draft.activity == a,
                    onSelected: (_) => setState(
                        () => _draft = _draft.copyWith(activity: a)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _label(context, t.goal),
          SegmentedButton<Goal>(
            segments: Goal.values
                .map((g) => ButtonSegment(value: g, label: Text(g.labelOf(t))))
                .toList(),
            selected: {_draft.goal},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                setState(() => _draft = _draft.copyWith(goal: s.first)),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.yourTargets,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _statRow(t.restingBurn, t.kcalValue(kcal(bmr))),
                  _statRow(t.estDailyBurn, t.kcalValue(kcal(tdee))),
                  _statRow(t.dailyCalorieTarget, t.kcalValue(kcal(calTarget))),
                  _statRow(t.proteinTargetLabel, t.gramsValue(kcal(protein))),
                  _statRow(t.satFatCap, t.gramsValue(kcal(satCap))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(t.saveProfile),
          ),
          const SizedBox(height: 24),
          const _WeightCard(),
          const SizedBox(height: 12),
          const _ApiKeyCard(),
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
          decoration:
              InputDecoration(labelText: t.weightKg, hintText: t.enterWeight),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.weightSaved)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final entries = ref.watch(weightEntriesProvider);
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final latest =
        entries.isNotEmpty ? entries.first.kg : ref.watch(profileProvider).weightKg;
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
                Text(t.weightTitle,
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(t.weightKgValue(_fmtKg(latest)),
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            for (final e in entries.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat.yMMMd(localeName).format(e.timestamp),
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(t.weightKgValue(_fmtKg(e.kg)),
                        style: Theme.of(context).textTheme.bodySmall),
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
                Text(t.language,
                    style: Theme.of(context).textTheme.titleSmall),
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeedbackScreen()),
        ),
      ),
    );
  }
}

/// Lets the user paste / replace / remove their Anthropic API key.
class _ApiKeyCard extends ConsumerStatefulWidget {
  const _ApiKeyCard();

  @override
  ConsumerState<_ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends ConsumerState<_ApiKeyCard> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    await ref.read(apiKeyProvider.notifier).save(value);
    _controller.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.apiKeySavedToast)));
  }

  Future<void> _clear() async {
    final t = AppLocalizations.of(context);
    await ref.read(apiKeyProvider.notifier).clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.apiKeyRemoved)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final key = ref.watch(apiKeyProvider);
    final hasKey = hasApiKey(key);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.camera_alt_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.foodPhotoAnalysis,
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                if (hasKey)
                  Icon(Icons.check_circle, color: scheme.primary, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasKey ? t.apiKeySavedDevice : t.apiKeyPrompt,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: hasKey ? t.replaceApiKey : t.apiKeyLabel,
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(onPressed: _save, child: Text(t.saveKey)),
                const SizedBox(width: 8),
                if (hasKey)
                  TextButton(onPressed: _clear, child: Text(t.remove)),
              ],
            ),
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
                  child: Text(t.healthGarminTitle,
                      style: Theme.of(context).textTheme.titleSmall),
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
                          ok ? t.appleHealthConnected : t.healthNotGranted),
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
