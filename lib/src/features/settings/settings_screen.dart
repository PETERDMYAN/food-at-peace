import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../data/auth_client.dart';
import '../../data/profile_photo.dart';
import '../../data/sync_client.dart';
import '../../data/sync_engine.dart';
import '../../models/daily_summary.dart';
import '../../models/user_profile.dart';
import '../../nutrition/nutrition_math.dart';
import '../../providers/providers.dart';
import '../../util/format.dart';
import '../../util/l10n_labels.dart';
import '../../widgets/bean_icon.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/story_avatar.dart';
import '../feedback/feedback_screen.dart';
import '../sources/sources_screen.dart';
import '../wallet/beans_screen.dart';
import 'data_sources_screen.dart';
import 'edit_profile_dialog.dart';
import 'reminders_screen.dart';

/// Profile setup (drives all targets), weight log, Claude key, Apple
/// Health/Garmin, language, and feedback.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Pen-icon editor for the goal + targets. Each field's helper text explains
  /// the automatic calculation; "Use automatic" (offered once the profile has
  /// reliable sex/age/height/weight) resets the fields to those values. A value
  /// matching the automatic one is stored as "no override" so it keeps
  /// tracking the profile.
  Future<void> _editTargets(UserProfile profile, DailySummary summary) async {
    final t = AppLocalizations.of(context);
    var goal = profile.goal;
    final gap = profile.calorieGoalOverride ?? goal.calorieAdjustment;
    final cal = TextEditingController(text: gap.round().toString());
    final protein = TextEditingController(
      text: summary.proteinTarget.round().toString(),
    );
    final satFat = TextEditingController(
      text: summary.satFatCap.round().toString(),
    );
    final autoProtein = NutritionMath.proteinTargetG(profile);
    final autoSatFat = NutritionMath.satFatCapG(
      calorieTarget: summary.computedCalorieTarget,
    );
    String fmtGap(Goal g) {
      final v = g.calorieAdjustment.round();
      return v > 0 ? '+$v' : '$v';
    }

    InputDecoration dec(String label, String suffix, String? helper) =>
        InputDecoration(
          labelText: label,
          suffixText: suffix,
          helperText: helper,
          helperMaxLines: 2,
        );
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(t.editTargets),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SegmentedButton<Goal>(
                    segments: [
                      for (final g in Goal.values)
                        ButtonSegment(value: g, label: Text(g.labelOf(t))),
                    ],
                    selected: {goal},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setLocal(() {
                      goal = s.first;
                      cal.text = goal.calorieAdjustment.round().toString();
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cal,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  decoration: dec(
                    t.calorieGapTarget,
                    'kcal',
                    t.autoFromGoal(fmtGap(goal)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: protein,
                  keyboardType: TextInputType.number,
                  decoration: dec(
                    t.proteinTargetLabel,
                    'g',
                    profile.isConfigured
                        ? t.autoProteinRule(
                            kcal(profile.weightKg),
                            kcal(autoProtein),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: satFat,
                  keyboardType: TextInputType.number,
                  decoration: dec(
                    t.satFatCap,
                    'g',
                    profile.isConfigured
                        ? t.autoSatFatRule(kcal(autoSatFat))
                        : null,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // Automatic values need a reliable profile (sex/age/height/weight).
            if (profile.isConfigured)
              TextButton(
                onPressed: () => setLocal(() {
                  cal.text = goal.calorieAdjustment.round().toString();
                  protein.text = autoProtein.round().toString();
                  satFat.text = autoSatFat.round().toString();
                }),
                child: Text(t.useAutomatic),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text(t.save),
            ),
          ],
        ),
      ),
    );
    if (mounted && action == 'save') {
      // Empty/invalid or matching-the-automatic → store no override.
      double? ovr(String text, double auto) {
        final v = double.tryParse(text.trim());
        if (v == null) return null;
        return v.round() == auto.round() ? null : v;
      }

      ref
          .read(profileProvider.notifier)
          .save(
            profile.copyWith(
              goal: goal,
              calorieGoalOverride: ovr(cal.text, goal.calorieAdjustment),
              proteinTargetOverride: ovr(protein.text, autoProtein),
              satFatTargetOverride: ovr(satFat.text, autoSatFat),
            ),
          );
    }
    cal.dispose();
    protein.dispose();
    satFat.dispose();
  }

  Widget _statRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(profileProvider);
    // Compute the target exactly like the Today budget so the preview matches it
    // (full-day BMR + measured active when Health is connected, else estimated).
    final summary = DailySummary.compute(
      date: dateOnly(DateTime.now()),
      entries: const [],
      profile: profile,
      energyOut: ref.watch(energyOutProvider).asData?.value,
    );
    // The signed goal gap shown as "Calorie gap target" (override, else the
    // goal default: lose -500 / maintain 0 / gain +400).
    final gap = profile.calorieGoalOverride ?? profile.goal.calorieAdjustment;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _ProfileStatsCard(profile: profile),
            const SizedBox(height: 12),
            const _BeansTile(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.yourTargets,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: t.editTargets,
                          onPressed: () => _editTargets(profile, summary),
                        ),
                      ],
                    ),
                    _statRow(
                      t.calorieGapTarget,
                      t.kcalValue(gap > 0 ? '+${kcal(gap)}' : kcal(gap)),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.calorieBudgetExplainer,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statRow(
                      t.proteinTargetLabel,
                      t.gramsValue(kcal(summary.proteinTarget)),
                    ),
                    _statRow(
                      t.satFatCap,
                      t.gramsValue(kcal(summary.satFatCap)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _SourcesTile(),
            const SizedBox(height: 24),
            const _AccountCard(),
            const SizedBox(height: 12),
            const _HealthCard(),
            const SizedBox(height: 12),
            const _DataSourcesTile(),
            const SizedBox(height: 12),
            const _RemindersTile(),
            const SizedBox(height: 12),
            const _LanguageCard(),
            const SizedBox(height: 12),
            const _FeedbackTile(),
            const SizedBox(height: 20),
            const _VersionFooter(),
          ],
        ),
      ),
    );
  }
}

/// App version at the bottom of Profile — a hidden owner/debug entry, not for
/// regular users. Tap it **10×** to reveal this account's stable user id (the
/// key it syncs under in the backend DB), with copy. (Owner metrics moved to a
/// standalone web dashboard, so the old 5×-tap screen is gone.)
class _VersionFooter extends ConsumerStatefulWidget {
  const _VersionFooter();

  @override
  ConsumerState<_VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends ConsumerState<_VersionFooter> {
  PackageInfo? _info;
  int _taps = 0;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _info = i);
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  // One hidden gesture: act once tapping pauses so a stray tap doesn't trigger
  // it. 10+ taps → reveal this account's stable user id.
  void _tap() {
    _taps++;
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 700), () {
      final taps = _taps;
      _taps = 0;
      if (!mounted) return;
      if (taps >= 10) {
        _showAccountId();
      }
    });
  }

  void _showAccountId() {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final userId = ref.read(authProvider)?.userId;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.accountIdTitle),
        content: userId == null
            ? Text(t.accountIdSignedOut)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.accountIdHint,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    userId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
        actions: [
          if (userId != null)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: userId));
                Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(content: Text(t.accountIdCopied)),
                );
              },
              child: Text(t.copy),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final info = _info;
    final label = info == null
        ? ''
        : t.versionLabel(t.appTitle, info.version, info.buildNumber);
    return Center(
      child: GestureDetector(
        onTap: _tap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Age / height / weight, synced from Apple Health and editable via the pen.
/// Edits write height + weight back to Apple Health (age can't be — it's a
/// read-only HealthKit characteristic).
class _ProfileStatsCard extends ConsumerStatefulWidget {
  const _ProfileStatsCard({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_ProfileStatsCard> createState() => _ProfileStatsCardState();
}

class _ProfileStatsCardState extends ConsumerState<_ProfileStatsCard> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      await ref.read(profileProvider.notifier).refreshFromHealth();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Take / choose / remove the profile photo (used in the circle "You" avatar
  /// and your food-story header). Square-cropped + downscaled by the notifier.
  Future<void> _editPhoto() async {
    final t = AppLocalizations.of(context);
    final hasPhoto = ref.read(profilePhotoProvider) != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t.takePhoto),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.chooseFromLibrary),
              onTap: () => Navigator.pop(ctx, 'library'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(t.removePhoto),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final notifier = ref.read(profilePhotoProvider.notifier);
    if (action == 'remove') {
      await notifier.clear();
      return;
    }
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 1024,
        maxHeight: 1024,
      );
    } catch (_) {
      return;
    }
    if (file == null) return;
    await notifier.setFromBytes(await file.readAsBytes());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final profile = widget.profile;
    final cfg = profile.isConfigured;
    final photo = ref.watch(profilePhotoProvider);
    final connected = ref.watch(healthConnectedProvider);
    final lastSync = ref.watch(healthSyncProvider);
    // Watching circleProvider keeps it alive so the @handle auto-assigns when
    // signed in even if the Circle tab is never opened; it's shown read-only
    // under the nickname (editing happens in the profile dialog).
    ref.watch(circleProvider);
    final handle = ref.watch(myCircleHandleProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.profile,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: t.editProfile,
                  onPressed: () => showEditProfileDialog(context, ref),
                ),
              ],
            ),
            Row(
              children: [
                // Tap the avatar to set/change the profile photo.
                GestureDetector(
                  onTap: _editPhoto,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      StoryAvatar(
                        imageBytes: photo,
                        icon: photo == null ? Icons.person : null,
                        colorSeed: 3,
                        size: 48,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.surface, width: 2),
                          ),
                          child: Icon(
                            Icons.photo_camera,
                            size: 12,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (profile.name?.trim().isNotEmpty ?? false)
                            ? profile.name!.trim()
                            : t.todoAddName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: (profile.name?.trim().isNotEmpty ?? false)
                              ? null
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      // The @handle, read-only, right under the nickname. Friends
                      // find you (and recharge Beans) with it; edit it in the
                      // profile dialog (the pen above), not a separate button.
                      if (handle != null && handle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '@$handle',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Unconfigured values are placeholders, not facts — show dashes
            // until the user (or Apple Health) provides the real ones.
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      value: cfg ? profile.sex.labelOf(t) : '—',
                      label: t.sex,
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      value: cfg ? '${profile.age}' : '—',
                      label: t.age,
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      value: cfg ? '${profile.heightCm.round()} cm' : '—',
                      label: t.heightTitle,
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      value: cfg ? '${kcal(profile.weightKg)} kg' : '—',
                      label: t.weightTitle,
                    ),
                  ),
                ],
              ),
            ),
            if (connected)
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _syncing ? null : _syncNow,
                    icon: _syncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 16),
                    label: Text(t.syncNow),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                      textStyle: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      lastSync == null
                          ? t.syncedFromHealth
                          : t.lastSynced(DateFormat.Hm().format(lastSync)),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
                IconTile(icon: Icons.language, color: scheme.primary),
                const SizedBox(width: 12),
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

/// Beans wallet balance, with the gold gradient mark. Tapping opens the wallet
/// (balance, top-up, transaction history).
class _BeansTile extends ConsumerWidget {
  const _BeansTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final beans = ref.watch(beansProvider);
    final status = t.beansCount(beans.balance);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const BeansScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const BeanIcon(size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.beans,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry point to the Data Sources screen — which device's active energy counts
/// (Garmin / Apple Watch / iPhone, via Apple Health). Shows the current pick.
class _DataSourcesTile extends ConsumerWidget {
  const _DataSourcesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final preferred = ref.watch(energySourcePriorityProvider);
    final status = preferred ?? t.sourceAutomatic;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const DataSourcesScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconTile(icon: Icons.dataset_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.dataSources,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry point to the meal-reminders screen. Shows whether reminders are on and
/// how many are active.
class _RemindersTile extends ConsumerWidget {
  const _RemindersTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final enabled = ref.watch(remindersEnabledProvider);
    final activeCount = ref
        .watch(remindersProvider)
        .where((r) => r.enabled)
        .length;
    final status = enabled ? t.remindersActive(activeCount) : t.remindersOff;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RemindersScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconTile(
                icon: Icons.notifications_active,
                color: scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.reminders,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the citations & methodology screen (App Store Guideline 1.4.1).
class _SourcesTile extends StatelessWidget {
  const _SourcesTile();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SourcesScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconTile(icon: Icons.menu_book, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.sourcesTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const FeedbackScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconTile(icon: Icons.feedback, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.feedback,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
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
  bool _deleting = false;

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

  /// Confirm → delete the account + synced data server-side → forget the sync
  /// cursor (so a later sign-in re-pushes everything still on the device) →
  /// sign out. Data on this device is intentionally kept.
  Future<void> _deleteAccount() async {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteAccount),
        content: Text(t.deleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            child: Text(t.deleteAccount),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Capture everything before the first await: the card can unmount while
    // the network call runs (it lives in a lazy ListView), and `ref` must not
    // be touched after that. The captured notifiers/stores outlive the widget.
    final session = ref.read(authProvider);
    if (session == null) return;
    final client = ref.read(syncClientProvider);
    final cursor = ref.read(syncCursorStoreProvider);
    final auth = ref.read(authProvider.notifier);
    final engine = ref.read(syncEngineProvider.notifier);
    setState(() => _deleting = true);
    try {
      // Quiesce sync first — a debounced or in-flight push racing the delete
      // would silently repopulate the account (or resurrect the cursor).
      await engine.suspendForAccountDeletion();
      await client.deleteAccount(token: session.token);
      await cursor.clear();
      await auth.signOut();
      _toast(t.accountDeleted);
    } on SessionExpired {
      // The token was rejected, so NOTHING was deleted server-side. Sign out
      // (the token is unusable) and be explicit that a retry is needed.
      await auth.signOut();
      _toast(t.deleteAccountSignInAgain);
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast(t.deleteAccountFailed);
    } finally {
      engine.resumeAfterAccountDeletion();
      if (mounted) setState(() => _deleting = false);
    }
  }

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
                IconTile(icon: Icons.cloud, color: scheme.primary),
                const SizedBox(width: 12),
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
                    onPressed: sync.phase == SyncPhase.syncing || _deleting
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
              // Wrap (not Row): at large text scales the two English labels
              // overflow a narrow card — wrapping drops the delete button to
              // its own line instead. The SizedBox makes spaceBetween span the
              // card (a bare Wrap shrinks to its children).
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _deleting ? null : _signOut,
                      child: Text(t.signOut),
                    ),
                    // In-app account deletion (App Store 5.1.1(v)).
                    TextButton.icon(
                      onPressed: _deleting ? null : _deleteAccount,
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                      icon: _deleting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_forever_outlined, size: 18),
                      label: Text(t.deleteAccount),
                    ),
                  ],
                ),
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
                IconTile(icon: Icons.favorite, color: scheme.primary),
                const SizedBox(width: 12),
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
