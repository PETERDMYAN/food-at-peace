// Build 43 before/after shots: (1) the scrollable Circle feed with Eva's daily
// lesson riding at the top above the food-story posts, and (2) the Manage-circle
// handle card showing the nickname (display name) distinct from the @handle.
// The SAME file renders correctly on build 42 (no Eva card / @handle-only card)
// and build 43, so it can be run on both via `git stash` for a faithful pair.
//
//   flutter test integration_test/build43_shots.dart -d <sim-udid>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/data/meal_photos.dart';
import 'package:food_at_peace/src/data/profile_photo.dart';
import 'package:food_at_peace/src/features/circle/circle_feed_screen.dart';
import 'package:food_at_peace/src/features/circle/manage_friends_screen.dart';
import 'package:food_at_peace/src/models/circle_post.dart';
import 'package:food_at_peace/src/models/friend.dart';
import 'package:food_at_peace/src/models/session.dart';
import 'package:food_at_peace/src/models/user_profile.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:food_at_peace/src/theme/app_theme.dart';

const _shotPort = int.fromEnvironment('SHOT_PORT', defaultValue: 8099);

Future<void> beat(WidgetTester t, int ms) async {
  var e = 0;
  while (e < ms) {
    await t.pump(const Duration(milliseconds: 80));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    e += 80;
  }
}

Future<void> shot(WidgetTester t, String name, {int settle = 1100}) async {
  await beat(t, settle);
  try {
    final c = HttpClient();
    final req =
        await c.getUrl(Uri.parse('http://127.0.0.1:$_shotPort/shot/$name'));
    final resp = await req.close();
    await resp.drain();
    c.close();
  } catch (_) {}
  await beat(t, 300);
}

class _DemoAuth extends AuthNotifier {
  @override
  Session? build() => Session(
        token: 'shots',
        userId: 'apple:shots',
        email: 'roro@icloud.com',
        expiresAt: DateTime(2031),
      );
}

class _DemoProfile extends ProfileNotifier {
  @override
  UserProfile build() => UserProfile.defaultProfile.copyWith(name: 'roro');
}

/// Eva + one connected peer (Peter) so the feed has a friend post too.
class _DemoCircle extends CircleNotifier {
  @override
  List<Friend> build() => const [
        Friend(
          id: 'u_peter',
          name: 'Peter',
          handle: '@peter',
          status: FriendStatus.connected,
        ),
      ];
}

const _feedPosts = <CirclePost>[
  CirclePost(
    postId: 'p_peter',
    authorId: 'u_peter',
    authorName: 'Peter',
    name: 'Grilled salmon bowl',
    calories: 540,
  ),
  CirclePost(
    postId: 'p_mine',
    authorId: 'apple:shots',
    authorName: 'roro',
    name: 'Avocado toast',
    calories: 320,
    mine: true,
  ),
];

Widget _scaffoldHost(Widget home, SharedPreferences prefs) {
  final mealDir = Directory.systemTemp.createTempSync('fap43_meal');
  final profileFile = File(
    '${Directory.systemTemp.createTempSync('fap43_prof').path}/p.jpg',
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      mealPhotosProvider.overrideWithValue(MealPhotos(mealDir)),
      profilePhotoFileProvider.overrideWithValue(profileFile),
      authProvider.overrideWith(_DemoAuth.new),
      profileProvider.overrideWith(_DemoProfile.new),
      circleProvider.overrideWith(_DemoCircle.new),
      circleFeedProvider.overrideWith((ref) async => _feedPosts),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'circle_notify_enabled': true,
    'circle_my_handle': 'roro',
    'eva_followed': true,
  });
  return SharedPreferences.getInstance();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('circle feed — Eva lesson at top + food stories', (t) async {
    final prefs = await _prefs();
    await t.pumpWidget(_scaffoldHost(const CircleFeedScreen(), prefs));
    await beat(t, 1600);
    await shot(t, 'feed');
  });

  testWidgets('manage circle — nickname distinct from @handle', (t) async {
    final prefs = await _prefs();
    await t.pumpWidget(_scaffoldHost(const ManageCircleScreen(), prefs));
    await beat(t, 1600);
    await shot(t, 'handle');
  });
}
