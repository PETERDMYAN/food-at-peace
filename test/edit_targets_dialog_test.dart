import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/features/settings/settings_screen.dart';
import 'package:food_at_peace/src/models/user_profile.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:food_at_peace/src/theme/app_theme.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('unconfigured profile shows dashes and no "Use automatic"', (
    tester,
  ) async {
    await pump(tester);

    // No guessed sex/age/height/weight — dashes until real data arrives.
    expect(find.text('—'), findsNWidgets(4));

    await tester.tap(find.byTooltip('Edit targets'));
    await tester.pumpAndSettle();

    // Goal is editable in the dialog, but automatic targets are gated until
    // the profile is reliable.
    expect(find.text('Maintain'), findsOneWidget);
    expect(find.text('Use automatic'), findsNothing);
  });

  testWidgets('configured profile shows stats, helpers and "Use automatic"', (
    tester,
  ) async {
    await pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    await container
        .read(profileProvider.notifier)
        .save(UserProfile.defaultProfile.copyWith(isConfigured: true));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsNothing);

    await tester.tap(find.byTooltip('Edit targets'));
    await tester.pumpAndSettle();

    expect(find.text('Use automatic'), findsOneWidget);
    // Each target explains its automatic calculation.
    expect(find.textContaining('Auto from your goal'), findsOneWidget);
    expect(find.textContaining('1.6 g ×'), findsOneWidget);
    expect(find.textContaining('10% of your calorie budget'), findsOneWidget);
  });
}
