import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/features/circle/connect_sheet.dart';
import 'package:food_at_peace/src/models/friend.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:food_at_peace/src/theme/app_theme.dart';

/// Signed-out auth that never touches secure storage (no plugin under
/// `flutter test`) — keeps the Circle on its offline/local path.
class _NoAuth extends AuthNotifier {
  @override
  build() => null;
}

void main() {
  testWidgets('connect sheet renders the prompt and connects on tap', (t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_NoAuth.new),
      ],
    );
    addTearDown(container.dispose);

    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showConnectSheet(context, 'smoketest'),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Open the sheet (as the app_links deep-link handler would).
    await t.tap(find.text('go'));
    await t.pumpAndSettle();

    // The "Add @handle to your circle?" prompt + Connect CTA.
    expect(find.text('Add to your circle'), findsOneWidget);
    expect(find.textContaining('@smoketest'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Connect'), findsOneWidget);

    // Tap Connect → offline path adds them as a connected friend, shows a toast.
    await t.tap(find.widgetWithText(FilledButton, 'Connect'));
    await t.pumpAndSettle();

    expect(find.textContaining('now connected'), findsOneWidget);
    final friends = container.read(circleProvider);
    expect(
      friends.any((f) =>
          f.handle == '@smoketest' && f.status == FriendStatus.connected),
      isTrue,
    );
  });
}
