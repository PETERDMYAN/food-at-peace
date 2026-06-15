import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../data/notification_service.dart';
import '../../data/sync_engine.dart';
import '../../providers/providers.dart';
import '../add/add_entry_screen.dart';
import '../settings/settings_screen.dart';
import '../today/today_screen.dart';
import '../trends/trends_screen.dart';

/// Root scaffold with the bottom navigation and the Today "Add food" button.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _screens = [TodayScreen(), TrendsScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Instantiate the sync engine so its sign-in / edit listeners are active
    // for the whole app session (it keeps itself alive).
    ref.read(syncEngineProvider);
    // Pull age / height / weight from Apple Health on launch (best-effort).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).refreshFromHealth();
      _refreshReminders();
      _checkCircleActivity();
    });
  }

  /// Surface a notification + in-app banner when a friend has shared a new meal
  /// to the circle since we last looked. Best-effort; uses the same
  /// notification service as the meal reminders. (Instant background delivery
  /// would need server push — a planned APNs follow-up.)
  Future<void> _checkCircleActivity() async {
    final fresh = await ref.read(circleActivityProvider.notifier).pollNew();
    if (!mounted || fresh.isEmpty) return;
    if (!ref.read(circleNotifyProvider)) return;
    final t = AppLocalizations.of(context);
    final post = fresh.first;
    final who = post.authorName ?? post.authorHandle ?? t.aFriend;
    final msg = t.circleSharedMeal(who);
    ref
        .read(notificationServiceProvider)
        .show(id: NotificationService.circleId, title: msg, body: post.name ?? '');
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
  }

  /// Re-sync the OS meal reminders on launch/resume so they reflect the latest
  /// settings and the current language. No-op when reminders are off (disabling
  /// already cancelled them), which also keeps the plugin untouched in tests.
  void _refreshReminders() {
    if (!ref.read(remindersEnabledProvider)) return;
    rescheduleReminders(
      service: ref.read(notificationServiceProvider),
      enabled: true,
      reminders: ref.read(remindersProvider),
      t: AppLocalizations.of(context),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncEngineProvider.notifier).syncNow();
      ref.read(profileProvider.notifier).refreshFromHealth();
      _refreshReminders();
      _checkCircleActivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      // Logging food only makes sense from Today; Trends and Settings hide it.
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AddEntryScreen())),
              icon: const Icon(Icons.add),
              label: Text(t.addFood),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: t.navToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: t.navTrends,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: t.navSettings,
          ),
        ],
      ),
    );
  }
}
