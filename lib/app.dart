import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'src/features/home/home_shell.dart';
import 'src/providers/providers.dart';
import 'src/theme/app_theme.dart';

class FoodAtPeaceApp extends ConsumerWidget {
  const FoodAtPeaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // null locale = follow the iOS system language (Chinese → zh, else en).
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      // Always dark — GXS-style. (No light theme / no system toggle.)
      theme: AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeShell(),
    );
  }
}
