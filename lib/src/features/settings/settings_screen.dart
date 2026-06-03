import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../nutrition/nutrition_math.dart';
import '../../providers/providers.dart';
import '../../util/format.dart';

/// Profile setup (drives all targets) plus placeholders for the upcoming
/// HealthKit and photo-analysis phases.
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
    ref.read(profileProvider.notifier).save(_draft.copyWith(isConfigured: true));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bmr = NutritionMath.mifflinStJeorBmr(_draft);
    final tdee = NutritionMath.estimatedTdee(_draft);
    final calTarget =
        NutritionMath.calorieTarget(expenditure: tdee, goal: _draft.goal);
    final protein = NutritionMath.proteinTargetG(_draft);
    final satCap = NutritionMath.satFatCapG(calorieTarget: calTarget);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Profile', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _label(context, 'Sex'),
          SegmentedButton<Sex>(
            segments: Sex.values
                .map((s) => ButtonSegment(value: s, label: Text(s.label)))
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
                  decoration: const InputDecoration(labelText: 'Age'),
                  onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(age: int.tryParse(v))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
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
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  onChanged: (v) => setState(() =>
                      _draft = _draft.copyWith(weightKg: double.tryParse(v))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label(context, 'Activity level'),
          Wrap(
            spacing: 8,
            children: ActivityLevel.values
                .map(
                  (a) => ChoiceChip(
                    label: Text(a.label),
                    selected: _draft.activity == a,
                    onSelected: (_) => setState(
                        () => _draft = _draft.copyWith(activity: a)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _label(context, 'Goal'),
          SegmentedButton<Goal>(
            segments: Goal.values
                .map((g) => ButtonSegment(value: g, label: Text(g.label)))
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
                  Text('Your targets',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _statRow('Resting burn (BMR)', '${kcal(bmr)} kcal'),
                  _statRow('Est. daily burn', '${kcal(tdee)} kcal'),
                  _statRow('Daily calorie target', '${kcal(calTarget)} kcal'),
                  _statRow('Protein target', grams(protein)),
                  _statRow('Saturated-fat cap', grams(satCap)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Save profile'),
          ),
          const SizedBox(height: 24),
          const _ComingSoonCard(
            icon: Icons.favorite_outline,
            title: 'Apple Health & Garmin',
            body: 'Soon: pull your real basal + active calories burned so the '
                'budget updates as you move. (Your Garmin data syncs in via '
                'Apple Health.)',
          ),
          const SizedBox(height: 12),
          const _ComingSoonCard(
            icon: Icons.camera_alt_outlined,
            title: 'Food photo analysis',
            body: 'Soon: snap a photo and Claude estimates calories, protein, '
                'and saturated fat for you to confirm.',
          ),
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

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text('Soon'),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
