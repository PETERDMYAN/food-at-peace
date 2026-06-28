import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../data/auth_client.dart';
import '../../data/notification_service.dart';
import '../../models/user_profile.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../util/l10n_labels.dart';
import '../today/today_screen.dart' show greetingTitle;

/// First-run flow over the brand gradient: name (via Apple or typed), goal,
/// connecting Apple Health, then "about you" (sex/age/height/weight —
/// Health-prefilled, never guessed). Completing it flips
/// [onboardingCompleteProvider], so the app swaps to the home shell.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pages = 5;
  final _controller = PageController();
  late final TextEditingController _name;
  late Goal _goal;
  int _page = 0;
  bool _appleBusy = false;
  bool _healthBusy = false;
  bool _remindersBusy = false;
  bool _finishing = false;

  // "About you" — starts blank (no guessed defaults); prefilled from Apple
  // Health when it shares the data. _health* remember what Health provided so
  // a user-typed value can be flagged as a manual edit.
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  Sex? _sex;
  Sex? _healthSex;
  int? _healthAge;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _name = TextEditingController(text: profile.name ?? '');
    _goal = profile.goal;
    // Health may already be connected (e.g. re-onboarding) — prefill.
    if (ref.read(healthConnectedProvider)) {
      Future.microtask(_pullFromHealth);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// Pulls sex/age/height/weight from Apple Health and prefills any "About
  /// you" fields the user hasn't typed into yet.
  Future<void> _pullFromHealth() async {
    final reads = await ref.read(profileProvider.notifier).refreshFromHealth();
    if (!mounted) return;
    setState(() {
      _healthSex = reads.sex;
      _healthAge = reads.age;
      _sex ??= reads.sex;
      if (_age.text.isEmpty && reads.age != null) {
        _age.text = '${reads.age}';
      }
      if (_height.text.isEmpty && reads.heightCm != null) {
        _height.text = '${reads.heightCm!.round()}';
      }
      if (_weight.text.isEmpty && reads.weightKg != null) {
        final w = reads.weightKg!;
        _weight.text = w.truncateToDouble() == w
            ? '${w.round()}'
            : w.toStringAsFixed(1);
      }
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signInWithApple() async {
    setState(() => _appleBusy = true);
    var ok = false;
    try {
      await ref.read(authProvider.notifier).signIn();
      final name = ref.read(profileProvider).name;
      if (name != null && name.isNotEmpty) _name.text = name;
      ok = true;
    } on SignInCancelled {
      // user dismissed the Apple sheet — no-op
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (_) {
      if (mounted) _toast(AppLocalizations.of(context).signInFailed);
    } finally {
      if (mounted) setState(() => _appleBusy = false);
    }
    // Signed in: let the "✓ Signed in" state register for a beat, then auto-
    // advance to the next onboarding step (no manual "Continue" needed).
    if (ok) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted && _page == 0) _next();
    }
  }

  Future<void> _connectHealth() async {
    setState(() => _healthBusy = true);
    try {
      final ok = await ref.read(healthConnectedProvider.notifier).connect();
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      if (ok) {
        await _pullFromHealth(); // prefill the "About you" page
      } else {
        _toast(t.healthNotGranted);
      }
    } finally {
      if (mounted) setState(() => _healthBusy = false);
    }
  }

  Future<void> _enableReminders() async {
    setState(() => _remindersBusy = true);
    try {
      final granted = await ref.read(remindersEnabledProvider.notifier).enable();
      if (!mounted) return;
      // Refresh the permission status so the page flips to "✓ on" when granted.
      ref.invalidate(notificationsAllowedProvider);
      if (granted) {
        await rescheduleReminders(
          service: ref.read(notificationServiceProvider),
          enabled: true,
          reminders: ref.read(remindersProvider),
          t: AppLocalizations.of(context),
        );
      } else {
        _toast(AppLocalizations.of(context).remindersDenied);
      }
    } finally {
      if (mounted) setState(() => _remindersBusy = false);
    }
  }

  void _next() {
    if (_page < _pages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final name = _name.text.trim();
    final ageV = int.tryParse(_age.text.trim());
    final heightV = double.tryParse(_height.text.trim());
    final weightV = double.tryParse(_weight.text.trim());
    final current = ref.read(profileProvider);
    await ref
        .read(profileProvider.notifier)
        .save(
          current.copyWith(
            name: name.isEmpty ? null : name,
            goal: _goal,
            sex: _sex ?? current.sex,
            age: ageV ?? current.age,
            heightCm: heightV ?? current.heightCm,
            weightKg: weightV ?? current.weightKg,
            // The profile counts as reliable only once sex/age/height/weight
            // are all known — skipped fields leave it unconfigured (a Today
            // TODO asks again) instead of silently guessing.
            isConfigured:
                current.isConfigured ||
                (_sex != null &&
                    ageV != null &&
                    heightV != null &&
                    weightV != null),
            // A value differing from what Health supplied is a manual edit —
            // protect it from the daily Health refresh.
            ageManuallySet:
                current.ageManuallySet || (ageV != null && ageV != _healthAge),
            sexManuallySet:
                current.sexManuallySet || (_sex != null && _sex != _healthSex),
          ),
        );
    // Flips the gate → app.dart rebuilds into HomeShell.
    await ref.read(onboardingCompleteProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: Theme(
        // White-on-gradient controls throughout the flow.
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  showBack: _page > 0,
                  onBack: _back,
                  onSkip: _finishing ? null : _finish,
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      _NamePage(
                        nameController: _name,
                        busy: _appleBusy,
                        signedIn: ref.watch(authProvider) != null,
                        onApple: _appleBusy ? null : _signInWithApple,
                        onChanged: (_) => setState(() {}),
                      ),
                      _GoalPage(
                        selected: _goal,
                        onSelect: (g) => setState(() => _goal = g),
                      ),
                      _HealthPage(
                        busy: _healthBusy,
                        onConnect: _healthBusy ? null : _connectHealth,
                      ),
                      _RemindersPage(
                        busy: _remindersBusy,
                        onEnable: _remindersBusy ? null : _enableReminders,
                      ),
                      _BodyPage(
                        sex: _sex,
                        onSex: (s) => setState(() => _sex = s),
                        age: _age,
                        height: _height,
                        weight: _weight,
                      ),
                    ],
                  ),
                ),
                _BottomBar(
                  page: _page,
                  pages: _pages,
                  label: _page == _pages - 1 ? t.getStarted : t.continueLabel,
                  busy: _finishing,
                  onNext: _next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showBack,
    required this.onBack,
    required this.onSkip,
  });

  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              tooltip: t.back,
            )
          else
            const SizedBox(width: 48),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: Text(t.skip),
          ),
        ],
      ),
    );
  }
}

/// Shared scrollable page body: a big title, supporting copy, then content.
class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.title,
    required this.body,
    required this.child,
  });

  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: text.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}

class _NamePage extends StatelessWidget {
  const _NamePage({
    required this.nameController,
    required this.busy,
    required this.signedIn,
    required this.onApple,
    required this.onChanged,
  });

  final TextEditingController nameController;
  final bool busy;

  /// True once Sign in with Apple has stored a session — swaps the Apple button
  /// for a clear "signed in" confirmation so onboarding doesn't look stuck.
  final bool signedIn;
  final VoidCallback? onApple;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final name = nameController.text.trim();
    return _PageBody(
      title: t.onboardingWelcomeTitle,
      body: t.onboardingNameBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: busy
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: SizedBox(
                        height: 26,
                        width: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : signedIn
                ? Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t.onboardingSignedIn,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : SignInWithAppleButton(
                    onPressed: onApple ?? () {},
                    style: SignInWithAppleButtonStyle.white,
                    borderRadius: BorderRadius.circular(28),
                    height: 54,
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            t.onboardingNameManual,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            onChanged: onChanged,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            cursorColor: Colors.white,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: t.onboardingNameLabel,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.15),
              prefixIcon: const Icon(
                Icons.person_outline,
                color: Colors.white70,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
            ),
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.waving_hand_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    greetingTitle(t, name),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  const _GoalPage({required this.selected, required this.onSelect});

  final Goal selected;
  final ValueChanged<Goal> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _PageBody(
      title: t.onboardingGoalTitle,
      body: t.onboardingGoalBody,
      child: Column(
        children: [
          for (final g in Goal.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GoalCard(
                label: g.labelOf(t),
                gap: t.perDayKcal(_gapString(g)),
                icon: _iconFor(g),
                selected: g == selected,
                onTap: () => onSelect(g),
              ),
            ),
        ],
      ),
    );
  }

  static String _gapString(Goal g) {
    final v = g.calorieAdjustment.round();
    return v > 0 ? '+$v' : '$v';
  }

  static IconData _iconFor(Goal g) => switch (g) {
    Goal.lose => Icons.trending_down,
    Goal.maintain => Icons.trending_flat,
    Goal.gain => Icons.fitness_center,
  };
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.label,
    required this.gap,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String gap;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.white.withValues(alpha: selected ? 0.95 : 0.14),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: selected ? AppTheme.violetDeep : Colors.white),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: text.titleMedium?.copyWith(
                        color: selected
                            ? const Color(0xFF1A0B40)
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      gap,
                      style: text.bodySmall?.copyWith(
                        color: selected
                            ? AppTheme.violetDeep
                            : Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppTheme.violetDeep),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthPage extends ConsumerWidget {
  const _HealthPage({required this.busy, required this.onConnect});

  final bool busy;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final supported = ref.watch(healthServiceProvider).isSupported;
    final connected = ref.watch(healthConnectedProvider);
    return _PageBody(
      title: t.onboardingHealthTitle,
      body: t.onboardingHealthBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!supported)
            Text(
              t.healthNotAvailable,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            )
          else if (connected)
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.onboardingHealthConnected,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            )
          else
            FilledButton.icon(
              onPressed: onConnect,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.violetDeep,
              ),
              icon: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.violetDeep,
                      ),
                    )
                  : const Icon(Icons.favorite_outline),
              label: Text(t.connectAppleHealth),
            ),
        ],
      ),
    );
  }
}

/// Opt into the daily meal reminders (breakfast/lunch/dinner, plus an optional
/// late check-in). Requesting permission flips the master toggle and schedules
/// the defaults; everything stays editable in Settings afterwards.
class _RemindersPage extends ConsumerWidget {
  const _RemindersPage({required this.busy, required this.onEnable});

  final bool busy;
  final VoidCallback? onEnable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    // Reminders + circle activity default ON, so what onboarding actually needs
    // here is the OS *permission* — key the confirmation off that, not the intent
    // (otherwise the page would say "on" without ever asking iOS).
    final allowed =
        ref.watch(notificationsAllowedProvider).asData?.value ?? false;
    return _PageBody(
      title: t.onboardingRemindersTitle,
      body: t.onboardingRemindersBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (allowed)
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.onboardingRemindersEnabled,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            )
          else
            FilledButton.icon(
              onPressed: onEnable,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.violetDeep,
              ),
              icon: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.violetDeep,
                      ),
                    )
                  : const Icon(Icons.notifications_active_outlined),
              label: Text(t.enableReminders),
            ),
        ],
      ),
    );
  }
}

/// "About you": sex, age, height and weight — prefilled from Apple Health when
/// available, otherwise typed. Skipping leaves the profile unconfigured (a
/// Today TODO asks again); nothing is guessed.
class _BodyPage extends StatelessWidget {
  const _BodyPage({
    required this.sex,
    required this.onSex,
    required this.age,
    required this.height,
    required this.weight,
  });

  final Sex? sex;
  final ValueChanged<Sex> onSex;
  final TextEditingController age;
  final TextEditingController height;
  final TextEditingController weight;

  Widget _field(
    BuildContext context,
    TextEditingController controller,
    String label, {
    String? suffix,
    bool decimal = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: const TextStyle(color: Colors.white, fontSize: 18),
      cursorColor: Colors.white,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _PageBody(
      title: t.aboutYouTitle,
      body: t.aboutYouBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final s in Sex.values) ...[
                Expanded(
                  child: _SexTile(
                    label: s.labelOf(t),
                    icon: s == Sex.male ? Icons.male : Icons.female,
                    selected: sex == s,
                    onTap: () => onSex(s),
                  ),
                ),
                if (s != Sex.values.last) const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _field(context, age, t.age),
          const SizedBox(height: 12),
          _field(context, height, t.heightTitle, suffix: 'cm'),
          const SizedBox(height: 12),
          _field(context, weight, t.weightTitle, suffix: 'kg', decimal: true),
        ],
      ),
    );
  }
}

class _SexTile extends StatelessWidget {
  const _SexTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: selected ? 0.95 : 0.14),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppTheme.violetDeep : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFF1A0B40) : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.pages,
    required this.label,
    required this.busy,
    required this.onNext,
  });

  final int page;
  final int pages;
  final String label;
  final bool busy;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < pages; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: i == page ? 22 : 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: i == page ? 1 : 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onNext,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.violetDeep,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
              ),
              child: busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.violetDeep,
                      ),
                    )
                  : Text(label),
            ),
          ),
        ],
      ),
    );
  }
}
