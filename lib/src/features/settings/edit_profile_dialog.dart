import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../models/user_profile.dart';
import '../../providers/providers.dart';
import '../../util/l10n_labels.dart';

/// Shared profile editor (nickname, sex, age, height, weight) used by the
/// Settings Profile card and the Today "complete your profile" TODO.
///
/// While the profile is unconfigured the number fields start blank — the
/// defaults are placeholders, not facts, and shouldn't look like them. Saving
/// marks the profile configured once sex/age/height/weight are all known,
/// flags manual age/sex edits (so the Apple Health refresh won't overwrite
/// them — those characteristics are read-only in Health), and writes height +
/// weight back to Apple Health.
Future<void> showEditProfileDialog(BuildContext context, WidgetRef ref) async {
  final t = AppLocalizations.of(context);
  final p = ref.read(profileProvider);
  final cfg = p.isConfigured;
  final name = TextEditingController(text: p.name ?? '');
  final age = TextEditingController(text: cfg ? p.age.toString() : '');
  final height = TextEditingController(
    text: cfg ? p.heightCm.round().toString() : '',
  );
  final weight = TextEditingController(
    text: !cfg
        ? ''
        : p.weightKg.truncateToDouble() == p.weightKg
        ? p.weightKg.round().toString()
        : p.weightKg.toStringAsFixed(1),
  );
  var sex = p.sex;
  InputDecoration dec(String label, [String? suffix]) =>
      InputDecoration(labelText: label, suffixText: suffix);
  final save = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(t.editProfile),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: dec(t.nickname),
              ),
              const SizedBox(height: 16),
              SegmentedButton<Sex>(
                segments: [
                  for (final s in Sex.values)
                    ButtonSegment(value: s, label: Text(s.labelOf(t))),
                ],
                selected: {sex},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setLocal(() => sex = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: age,
                keyboardType: TextInputType.number,
                decoration: dec(t.age),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: height,
                keyboardType: TextInputType.number,
                decoration: dec(t.heightTitle, 'cm'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: dec(t.weightTitle, 'kg'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.save),
          ),
        ],
      ),
    ),
  );
  if (save == true) {
    final p2 = ref.read(profileProvider);
    final newName = name.text.trim();
    final newAge = int.tryParse(age.text.trim());
    final newHeight = double.tryParse(height.text.trim());
    final newWeight = double.tryParse(weight.text.trim());
    await ref
        .read(profileProvider.notifier)
        .save(
          p2.copyWith(
            name: newName.isEmpty ? null : newName,
            sex: sex,
            age: newAge ?? p2.age,
            heightCm: newHeight ?? p2.heightCm,
            weightKg: newWeight ?? p2.weightKg,
            isConfigured:
                p2.isConfigured ||
                (newAge != null && newHeight != null && newWeight != null),
            ageManuallySet: p2.ageManuallySet || newAge != null,
            sexManuallySet: p2.sexManuallySet || sex != p2.sex,
          ),
        );
    // Write edited height/weight back to Apple Health (best-effort).
    if (ref.read(healthConnectedProvider)) {
      final svc = ref.read(healthServiceProvider);
      if (newWeight != null) {
        unawaited(svc.writeWeight(newWeight, DateTime.now()));
      }
      if (newHeight != null) unawaited(svc.writeHeight(newHeight));
    }
  }
  name.dispose();
  age.dispose();
  height.dispose();
  weight.dispose();
}
