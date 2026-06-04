import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/claude_vision_client.dart';
import '../../models/food_analysis.dart';
import '../../models/food_entry.dart';
import '../../models/meal_type.dart';
import '../../providers/providers.dart';

/// Food-entry form. A photo can be scanned with Claude to pre-fill the fields,
/// which the user then reviews and edits before saving.
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
  FoodSource _source = FoodSource.manual;
  bool _analyzing = false;
  FoodAnalysis? _analysis;

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
      source: _source,
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

  Future<void> _scanPhoto() async {
    final key = ref.read(apiKeyProvider);
    if (!hasApiKey(key)) {
      _showKeyNeededDialog();
      return;
    }
    final source = await _pickSource();
    if (source == null) return;

    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1568,
        maxHeight: 1568,
        imageQuality: 85,
      );
    } catch (_) {
      _toast('Could not open the camera or photo library.');
      return;
    }
    if (file == null) return;

    setState(() => _analyzing = true);
    try {
      final bytes = await file.readAsBytes();
      final analysis = await ref.read(claudeVisionClientProvider).analyze(
            apiKey: key!,
            imageBytes: bytes,
            mediaType: _mediaTypeFor(file),
          );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _source = FoodSource.photo;
        _name.text = analysis.name;
        _calories.text = analysis.calories.round().toString();
        _protein.text = analysis.proteinG.round().toString();
        _satFat.text = analysis.satFatG.round().toString();
        if (analysis.portionDescription.isNotEmpty) {
          _serving.text = analysis.portionDescription;
        }
      });
    } on ClaudeApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Analysis failed. Please try again.');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<ImageSource?> _pickSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  String _mediaTypeFor(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showKeyNeededDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add your API key'),
        content: const Text(
          'To analyze photos, add an Anthropic API key in Settings first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                OutlinedButton.icon(
                  onPressed: _analyzing ? null : _scanPhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan a photo with Claude'),
                ),
                if (_analysis != null) ...[
                  const SizedBox(height: 12),
                  _AnalysisBanner(analysis: _analysis!),
                ],
                const SizedBox(height: 12),
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
          if (_analyzing) const _AnalyzingOverlay(),
        ],
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

class _AnalysisBanner extends StatelessWidget {
  const _AnalysisBanner({required this.analysis});

  final FoodAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = [
      if (analysis.portionDescription.isNotEmpty) analysis.portionDescription,
      'confidence: ${analysis.confidence}',
    ].join(' · ');
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated by Claude — review & edit below.',
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer,
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

class _AnalyzingOverlay extends StatelessWidget {
  const _AnalyzingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing photo…'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
