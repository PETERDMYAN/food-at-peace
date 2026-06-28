// The comments sheet renders PRIVATE per-commenter threads: the post OWNER sees
// every commenter's thread (with a reply box into each); a COMMENTER sees only
// their own thread + a box to add to it. (Server-side privacy is covered by
// backend/tests/test_posts.py — here we prove the UI maps what the server
// returns.) See the circle-comments-privacy skill.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/features/circle/circle_feed_screen.dart';
import 'package:food_at_peace/src/models/circle_post.dart';
import 'package:food_at_peace/src/models/friend.dart';
import 'package:food_at_peace/src/models/session.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A signed-in session so the comment affordance opens the sheet instead of
/// showing the sign-in prompt.
class _FakeAuth extends AuthNotifier {
  @override
  Session? build() =>
      Session(token: 'test-token', userId: 'me', expiresAt: DateTime(2999));
}

/// A fixed circle (connected friends) so the @mention picker can offer someone
/// who hasn't commented yet.
class _FakeCircle extends CircleNotifier {
  _FakeCircle(this._friends);
  final List<Friend> _friends;
  @override
  List<Friend> build() => _friends;
}

CircleComment _c(String id, String author, String name, bool owner, String text) =>
    CircleComment(
      commentId: id,
      authorId: author,
      authorName: name,
      isOwner: owner,
      text: text,
    );

Future<void> _pump(
  WidgetTester t, {
  required List<CirclePost> posts,
  required CircleComments comments,
  List<Friend> friends = const [],
}) async {
  // A tall viewport so the ~3/5-height sheet shows all threads (the lazy ListView
  // wouldn't build off-screen reply boxes otherwise).
  t.view.physicalSize = const Size(1200, 3200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues(const {'eva_followed': false});
  final prefs = await SharedPreferences.getInstance();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_FakeAuth.new),
        if (friends.isNotEmpty) circleProvider.overrideWith(() => _FakeCircle(friends)),
        circleFeedProvider.overrideWith((ref) async => posts),
        postCommentsProvider.overrideWith((ref, arg) async => comments),
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

Future<void> _openSheet(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.mode_comment_outlined));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('owner sees all threads with a single @mention composer', (
    t,
  ) async {
    await _pump(
      t,
      posts: const [
        CirclePost(
          postId: 'p_mine',
          authorId: 'me',
          authorName: 'You',
          name: 'Pasta',
          calories: 620,
          mine: true,
          commentCount: 3,
        ),
      ],
      comments: CircleComments(
        isOwner: true,
        threads: [
          CircleCommentThread(
            userId: 'A',
            name: 'Anna',
            handle: 'anna',
            comments: [_c('c1', 'A', 'Anna', false, 'looks tasty')],
          ),
          CircleCommentThread(
            userId: 'B',
            name: 'Ben',
            handle: 'ben',
            comments: [
              _c('c2', 'B', 'Ben', false, 'recipe?'),
              _c('c3', 'me', 'You', true, 'sure thing'),
            ],
          ),
        ],
      ),
    );

    await _openSheet(t);

    // All comments in ONE ranked list (no sections), each tagged with audience.
    expect(find.text('looks tasty'), findsOneWidget);
    expect(find.text('recipe?'), findsOneWidget);
    expect(find.text('sure thing'), findsOneWidget);
    // A private comment is tagged "Only <commenter>" for the owner.
    expect(find.text('Only Anna'), findsWidgets);
    expect(find.text('Only Ben'), findsWidgets);
    // Exactly ONE composer (plain = public, "@handle …" = private reply).
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Comment, or @name for a private reply…'), findsOneWidget);
  });

  testWidgets('a commenter sees one ranked list, their comments tagged Private', (
    t,
  ) async {
    await _pump(
      t,
      posts: const [
        CirclePost(
          postId: 'p_friend',
          authorId: 'friend-1',
          authorName: 'Eva',
          name: 'Sea bass',
          calories: 520,
          commentCount: 2,
        ),
      ],
      comments: CircleComments(
        isOwner: false,
        threads: [
          CircleCommentThread(
            userId: 'me',
            name: 'You',
            comments: [
              _c('c1', 'me', 'You', false, 'yum'),
              _c('c2', 'friend-1', 'Eva', true, 'thanks!'),
            ],
          ),
        ],
      ),
    );

    await _openSheet(t);

    expect(find.text('yum'), findsOneWidget); // my comment
    expect(find.text('thanks!'), findsOneWidget); // the owner's private reply to me
    // No sections / privacy note — each private comment names who can see it:
    // just me + the post's owner (Eva). Both bubbles carry the tag.
    expect(find.text('Only you & Eva'), findsNWidgets(2));
    // A single composer (text field) to add a comment. (The feed card's own
    // "Add a comment…" label is a Text, not a field, so this is unambiguous.)
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('feed card previews recent comments + "View all" when there are more', (
    t,
  ) async {
    await _pump(
      t,
      posts: [
        CirclePost(
          postId: 'p1',
          authorId: 'friend-1',
          authorName: 'Eva',
          name: 'Soup',
          calories: 300,
          commentCount: 5,
          recentComments: [
            _c('c1', 'me', 'You', false, 'looks great'),
            _c('c2', 'friend-1', 'Eva', true, 'thank you'),
            _c('c3', 'me', 'You', false, 'what spice'),
          ],
        ),
      ],
      comments: const CircleComments(),
    );
    // 5 total, 3 shown → a View all link, and the 3 recent comments inline.
    expect(find.text('View all 5 comments'), findsOneWidget);
    expect(find.textContaining('looks great', findRichText: true), findsOneWidget);
    expect(find.textContaining('thank you', findRichText: true), findsOneWidget);
    expect(find.textContaining('what spice', findRichText: true), findsOneWidget);
  });

  testWidgets('typing @ opens a local mention picker; tapping inserts the handle', (
    t,
  ) async {
    await _pump(
      t,
      posts: const [
        CirclePost(
          postId: 'p_mine',
          authorId: 'me',
          authorName: 'You',
          name: 'Pasta',
          calories: 620,
          mine: true,
          commentCount: 1,
        ),
      ],
      comments: CircleComments(
        isOwner: true,
        threads: [
          CircleCommentThread(
            userId: 'A',
            name: 'Anna',
            handle: 'anna',
            comments: [_c('c1', 'A', 'Anna', false, 'hi')],
          ),
        ],
      ),
    );
    await _openSheet(t);
    await t.enterText(find.byType(TextField), '@');
    await t.pumpAndSettle();
    // A suggestion ListTile for Anna appears (no network — from loaded threads).
    expect(find.widgetWithText(ListTile, 'Anna'), findsOneWidget);
    await t.tap(find.widgetWithText(ListTile, 'Anna'));
    await t.pumpAndSettle();
    // The composer now holds "@anna ".
    expect(find.textContaining('@anna'), findsWidgets);
    expect(find.widgetWithText(ListTile, 'Anna'), findsNothing); // picker dismissed
  });

  testWidgets('owner can @-mention a connected friend who has not commented', (
    t,
  ) async {
    // A brand-new post: no comment threads yet, but the owner has a circle
    // friend (Cara). Typing "@" must still offer her so the owner can start a
    // private thread that only she + the owner will see.
    await _pump(
      t,
      friends: const [
        Friend(
          id: 'C',
          name: 'Cara',
          handle: '@cara',
          status: FriendStatus.connected,
        ),
      ],
      posts: const [
        CirclePost(
          postId: 'p_mine',
          authorId: 'me',
          authorName: 'You',
          name: 'Pasta',
          calories: 620,
          mine: true,
        ),
      ],
      comments: const CircleComments(isOwner: true), // no threads
    );
    await _openSheet(t);
    await t.enterText(find.byType(TextField), '@');
    await t.pumpAndSettle();
    // Cara is offered even with zero existing comments (she's a circle friend).
    expect(find.widgetWithText(ListTile, 'Cara'), findsOneWidget);
    await t.tap(find.widgetWithText(ListTile, 'Cara'));
    await t.pumpAndSettle();
    expect(find.textContaining('@cara'), findsWidgets);
  });

  testWidgets('no "View all" when all visible comments fit the preview', (t) async {
    await _pump(
      t,
      posts: [
        CirclePost(
          postId: 'p2',
          authorId: 'friend-1',
          authorName: 'Eva',
          name: 'Rice',
          calories: 200,
          commentCount: 2,
          recentComments: [
            _c('c1', 'me', 'You', false, 'yum'),
            _c('c2', 'friend-1', 'Eva', true, 'ty'),
          ],
        ),
      ],
      comments: const CircleComments(),
    );
    expect(find.textContaining('View all', findRichText: true), findsNothing);
    expect(find.textContaining('yum', findRichText: true), findsOneWidget);
  });
}
