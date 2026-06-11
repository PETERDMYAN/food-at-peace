import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/features/sources/sources_screen.dart';

void main() {
  testWidgets('Sources screen lists references, links and a disclaimer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SourcesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Each calculation is named...
    expect(find.text('Resting energy (BMR)'), findsOneWidget);
    expect(find.text('Daily calorie budget'), findsOneWidget);
    expect(find.text('Protein target'), findsOneWidget);
    expect(find.text('Saturated-fat cap'), findsOneWidget);

    // ...cites its source...
    expect(find.textContaining('Mifflin'), findsWidgets);
    expect(find.textContaining('Dietary Guidelines'), findsWidgets);

    // ...with a tappable link per entry, plus the medical disclaimer.
    expect(find.widgetWithText(TextButton, 'View source'), findsNWidgets(4));
    expect(find.textContaining('not medical advice'), findsOneWidget);
  });
}
