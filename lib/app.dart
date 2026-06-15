import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'src/app_globals.dart';
import 'src/data/invite_link.dart';
import 'src/features/circle/connect_sheet.dart';
import 'src/features/home/home_shell.dart';
import 'src/features/onboarding/onboarding_screen.dart';
import 'src/providers/providers.dart';
import 'src/theme/app_theme.dart';

class FoodAtPeaceApp extends ConsumerStatefulWidget {
  const FoodAtPeaceApp({super.key});

  @override
  ConsumerState<FoodAtPeaceApp> createState() => _FoodAtPeaceAppState();
}

class _FoodAtPeaceAppState extends ConsumerState<FoodAtPeaceApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  bool _handlingInvite = false;

  @override
  void initState() {
    super.initState();
    // One non-PII "app opened" ping for the owner dashboard. Fire-and-forget;
    // a no-op when no backend is configured.
    ref.read(analyticsServiceProvider).emit('open');
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Warm links (app already running) + the cold-start link (app launched by
    // tapping an invite). Both route to the "Connect with @handle" sheet.
    _linkSub = _appLinks.uriLinkStream.listen(_onLink, onError: (_) {});
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _onLink(initial);
    } catch (_) {}
  }

  void _onLink(Uri uri) {
    final handle = handleFromInvite(uri);
    if (handle == null) return;
    // Defer until the navigator is mounted (cold start races the first frame).
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptConnect(handle));
  }

  Future<void> _promptConnect(String handle) async {
    if (_handlingInvite) return;
    final ctx = _navigatorKey.currentState?.context;
    if (ctx == null) return;
    _handlingInvite = true;
    try {
      await showConnectSheet(ctx, handle);
    } finally {
      _handlingInvite = false;
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // null locale = follow the iOS system language (Chinese → zh, else en).
    final locale = ref.watch(localeProvider);
    final onboarded = ref.watch(onboardingCompleteProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: rootMessengerKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      // Always dark — GXS-style. (No light theme / no system toggle.)
      theme: AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: onboarded ? const HomeShell() : const OnboardingScreen(),
    );
  }
}
