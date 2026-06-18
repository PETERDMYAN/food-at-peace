// The per-post ⋯ menu (Apple 1.2 UGC moderation) appears only on OTHERS'
// posts and offers Report + Unfollow; Report opens a reason picker.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/features/circle/circle_feed_screen.dart';
import 'package:food_at_peace/src/models/circle_post.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester t) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        circleFeedProvider.overrideWith(
          (ref) async => const [
            CirclePost(
              postId: 'p_friend',
              authorId: 'friend-1',
              authorName: 'Eva',
              name: 'Sea bass',
              calories: 520,
            ),
            CirclePost(
              postId: 'p_mine',
              authorId: 'me',
              authorName: 'You',
              name: 'Pasta',
              calories: 620,
              mine: true,
            ),
          ],
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: CircleFeedScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('⋯ shows on others\' posts only, not your own', (t) async {
    await _pump(t);
    // Two posts rendered, exactly one ⋯ (the friend's; not the mine post).
    expect(find.text('Eva'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
  });

  testWidgets('⋯ opens Report + Unfollow; Report opens a reason picker', (
    t,
  ) async {
    await _pump(t);
    await t.tap(find.byIcon(Icons.more_horiz));
    await t.pumpAndSettle();
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Unfollow'), findsOneWidget);

    await t.tap(find.text('Report'));
    await t.pumpAndSettle();
    // The reason sheet (Apple 1.2 flag flow).
    expect(find.text('Report this post'), findsOneWidget);
    expect(find.text('Spam or scam'), findsOneWidget);
    expect(find.text('Harassment or bullying'), findsOneWidget);
  });
}
