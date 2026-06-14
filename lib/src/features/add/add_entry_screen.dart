import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/claude_vision_client.dart';
import '../../models/food_analysis.dart';
import '../../models/food_entry.dart';
import '../../models/meal_type.dart';
import '../../providers/providers.dart';
import '../../util/l10n_labels.dart';
import '../../widgets/bean_icon.dart';
import '../wallet/beans_screen.dart';

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
      servingDescription: _serving.text.trim().isEmpty
          ? null
          : _serving.text.trim(),
    );
    ref.read(foodEntriesProvider.notifier).add(entry);
    Navigator.of(context).pop();
  }

  Future<void> _scanPhoto() async {
    final t = AppLocalizations.of(context);
    // The resolved UI language ('en' / 'zh') — captured before any await so the
    // AI writes its estimate in the same language the user is reading.
    final lang = Localizations.localeOf(context).languageCode;
    final analyzer = ref.read(foodPhotoAnalyzerProvider);
    if (analyzer == null) {
      _showKeyNeededDialog();
      return;
    }
    // Each scan costs one Bean. Out of Beans → paywall; if they top up there,
    // fall through and continue.
    if (!ref.read(beansProvider).canAnalyze) {
      await showBeansPaywall(context, ref);
      if (!mounted || !ref.read(beansProvider).canAnalyze) return;
    }
    final source = await _pickSource();
    if (source == null) return;

    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        // 1024px long edge keeps the upload under Anthropic's ~1.15 MP vision
        // downscale threshold (so we pay actual size, not the ~1,600-token cap)
        // — smaller payload + lower latency, still plenty for food estimation.
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (_) {
      _toast(t.cameraError);
      return;
    }
    if (file == null) return;

    setState(() => _analyzing = true);
    try {
      final bytes = await file.readAsBytes();
      final analysis = await analyzer.analyze(
        imageBytes: bytes,
        mediaType: _mediaTypeFor(file),
        lang: lang,
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
      // Charge one Bean for the successful scan.
      await ref.read(beansProvider.notifier).spendOnPhoto(analysis.name);
      // Non-PII usage ping for the owner dashboard (fire-and-forget).
      ref.read(analyticsServiceProvider).emit('scan');
    } on ClaudeApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      if (mounted) _toast(AppLocalizations.of(context).analysisFailed);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<ImageSource?> _pickSource() {
    final t = AppLocalizations.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t.takePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.chooseFromLibrary),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showKeyNeededDialog() {
    final t = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.addApiKeyTitle),
        content: Text(t.addApiKeyBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.ok)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final beans = ref.watch(beansProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.addFood),
        actions: [TextButton(onPressed: _save, child: Text(t.save))],
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
                  label: Text(t.scanPhoto),
                ),
                // How many scans (Beans) the user has left.
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const BeanIcon(size: 15),
                      const SizedBox(width: 6),
                      Text(
                        t.scansLeft(beans.balance),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_analysis != null) ...[
                  const SizedBox(height: 12),
                  _AnalysisBanner(analysis: _analysis!),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: t.foodName,
                    hintText: t.foodNameHint,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? t.enterName : null,
                ),
                const SizedBox(height: 16),
                Text(t.meal, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<MealType>(
                  segments: MealType.values
                      .map(
                        (m) =>
                            ButtonSegment(value: m, label: Text(m.labelOf(t))),
                      )
                      .toList(),
                  selected: {_mealType},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _mealType = s.first),
                ),
                const SizedBox(height: 16),
                _NumberField(
                  controller: _calories,
                  label: t.caloriesKcal,
                  required: true,
                ),
                const SizedBox(height: 16),
                _NumberField(controller: _protein, label: t.proteinG),
                const SizedBox(height: 16),
                _NumberField(controller: _satFat, label: t.saturatedFatG),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _serving,
                  decoration: InputDecoration(
                    labelText: t.servingOptional,
                    hintText: t.servingHint,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: Text(t.saveEntry),
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
    final t = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final text = v?.trim() ?? '';
        if (text.isEmpty) {
          return required ? t.required : null;
        }
        final parsed = double.tryParse(text);
        if (parsed == null || parsed < 0) return t.enterValidNumber;
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
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final detail = [
      if (analysis.portionDescription.isNotEmpty) analysis.portionDescription,
      t.confidenceLabel(analysis.confidence),
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
                    t.estimatedByClaude,
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
    final t = AppLocalizations.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(t.analyzingPhoto),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
