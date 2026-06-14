import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
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
  @override
  void initState() {
    super.initState();
    // One non-PII "app opened" ping for the owner dashboard. Fire-and-forget;
    // a no-op when no backend is configured.
    ref.read(analyticsServiceProvider).emit('open');
  }

  @override
  Widget build(BuildContext context) {
    // null locale = follow the iOS system language (Chinese → zh, else en).
    final locale = ref.watch(localeProvider);
    final onboarded = ref.watch(onboardingCompleteProvider);
    return MaterialApp(
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
