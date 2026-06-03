import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/food_entry.dart';
import '../../models/meal_type.dart';
import '../../providers/providers.dart';

/// Manual food-entry form. (Phase 3 will add a "scan a photo" path that
/// pre-fills these same fields from Claude's analysis.)
class AddEntryScreen extends ConsumerStatefulWidget {
  const AddEntryScreen({super.key});

  @override
  ConsumerState<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends ConsumerState<AddEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _satFat = TextEditingController();
  final _serving = TextEditingController();

  late MealType _mealType = _defaultMeal();

  static MealType _defaultMeal() {
    final h = DateTime.now().hour;
    if (h < 11) return MealType.breakfast;
    if (h < 15) return MealType.lunch;
    if (h < 21) return MealType.dinner;
    return MealType.snack;
  }

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _satFat.dispose();
    _serving.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final selected = ref.read(selectedDateProvider);
    final now = DateTime.now();
    final entry = FoodEntry(
      id: now.microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      calories: double.parse(_calories.text),
      proteinG: double.tryParse(_protein.text) ?? 0,
      satFatG: double.tryParse(_satFat.text) ?? 0,
      mealType: _mealType,
      timestamp: DateTime(
        selected.year,
        selected.month,
        selected.day,
        now.hour,
        now.minute,
        now.second,
      ),
      servingDescription:
          _serving.text.trim().isEmpty ? null : _serving.text.trim(),
    );
    ref.read(foodEntriesProvider.notifier).add(entry);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add food'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Food name',
                hintText: 'e.g. Grilled chicken salad',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            Text('Meal', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<MealType>(
              segments: MealType.values
                  .map((m) =>
                      ButtonSegment(value: m, label: Text(m.label)))
                  .toList(),
              selected: {_mealType},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _mealType = s.first),
            ),
            const SizedBox(height: 16),
            _NumberField(
              controller: _calories,
              label: 'Calories (kcal)',
              required: true,
            ),
            const SizedBox(height: 16),
            _NumberField(controller: _protein, label: 'Protein (g)'),
            const SizedBox(height: 16),
            _NumberField(controller: _satFat, label: 'Saturated fat (g)'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serving,
              decoration: const InputDecoration(
                labelText: 'Serving (optional)',
                hintText: 'e.g. 1 bowl, 200 g',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save entry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.required = false,
  });

  final TextEditingController controller;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final text = v?.trim() ?? '';
        if (text.isEmpty) {
          return required ? 'Required' : null;
        }
        final parsed = double.tryParse(text);
        if (parsed == null || parsed < 0) return 'Enter a valid number';
        return null;
      },
    );
  }
}
