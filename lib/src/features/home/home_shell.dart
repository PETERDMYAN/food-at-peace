import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../app_globals.dart';
import '../../data/app_review_service.dart';
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
      _registerPushToken();
      // Count this open and, on the 5th, ask for an App Store review (once).
      // Reaching the home shell means onboarding is done — no need to gate.
      ref.read(appReviewPrompterProvider).registerOpenAndMaybeAsk();
    });
  }

  /// Surface notifications + an in-app banner for new circle activity (friend
  /// requests, acceptances, friends' meals, reactions on your posts) since we
  /// last looked. Best-effort; uses the same notification service as the meal
  /// reminders. (Instant background delivery would need server push — a planned
  /// APNs follow-up.)
  Future<void> _checkCircleActivity() async {
    final events = await ref.read(circleActivityProvider.notifier).pollActivity();
    if (!mounted || events.isEmpty) return;
    if (!ref.read(circleNotifyProvider)) return;
    final t = AppLocalizations.of(context);
    String msgFor(CircleEvent e) {
      final who = e.name.isEmpty ? t.aFriend : e.name;
      return switch (e.kind) {
        CircleEventKind.request => t.circleRequestNotif(who),
        CircleEventKind.accepted => t.circleAcceptedNotif(who),
        CircleEventKind.posted => t.circleSharedMeal(who),
        CircleEventKind.reaction => t.circleReactionNotif(who, e.detail ?? '❤️'),
      };
    }

    final svc = ref.read(notificationServiceProvider);
    for (final e in events) {
      svc.show(
        id: NotificationService.circleId + e.kind.index,
        title: msgFor(e),
        body: e.detail ?? '',
      );
    }
    // Defer to the next frame + use the app-wide messenger key, so the banner
    // shows reliably even when this fires right after launch (where
    // ScaffoldMessenger.of(context) can race the first frame and drop it).
    final banner = msgFor(events.first);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rootMessengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(banner),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
    });
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

  /// Send this device's APNs token (captured natively into shared_preferences as
  /// `apns_device_token`) to the server once, so friend-meal / request /
  /// reaction pushes can arrive when the app is backgrounded. Best-effort; needs
  /// an account, and re-tries on the next launch/resume until it sticks.
  Future<void> _registerPushToken() async {
    final token = ref.read(authProvider)?.token;
    if (token == null || token.isEmpty || proxyBaseUrl.isEmpty) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final device = prefs.getString('apns_device_token');
    if (device == null || device.isEmpty) return;
    if (prefs.getString('apns_device_token_synced') == device) return;
    try {
      await ref.read(circleClientProvider).registerDevice(token, device);
      await prefs.setString('apns_device_token_synced', device);
    } catch (_) {
      // best-effort — retried on the next launch/resume
    }
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
      _registerPushToken();
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
