// Capture Eva's story now spanning the last 3 days (3 segmented pages, the
// older days dated), via openMyStory(initialStory: 1).
//   flutter test integration_test/eva_3day_shots.dart -d <sim-udid>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/data/eva_wisdom.dart';
import 'package:food_at_peace/src/data/meal_photos.dart';
import 'package:food_at_peace/src/data/profile_photo.dart';
import 'package:food_at_peace/src/features/circle/circle_strip.dart';
import 'package:food_at_peace/src/models/session.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:food_at_peace/src/theme/app_theme.dart';

const _shotPort = int.fromEnvironment('SHOT_PORT', defaultValue: 8099);

Future<void> beat(WidgetTester t, int ms) async {
  var e = 0;
  while (e < ms) {
    await t.pump(const Duration(milliseconds: 90));
    await Future<void>.delayed(const Duration(milliseconds: 90));
    e += 90;
  }
}

Future<void> shot(WidgetTester t, String name) async {
  await beat(t, 700);
  try {
    final c = HttpClient();
    final r = await c.getUrl(Uri.parse('http://127.0.0.1:$_shotPort/shot/$name'));
    await (await r.close()).drain();
    c.close();
  } catch (_) {}
  await beat(t, 250);
}

class _DemoAuth extends AuthNotifier {
  @override
  Session? build() =>
      Session(token: 't', userId: 'apple:x', email: 'roro@icloud.com', expiresAt: DateTime(2031));
}

class _Launcher extends ConsumerWidget {
  const _Launcher();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch so the FutureProvider actually starts loading the bundled lessons;
    // openMyStory reads them synchronously, so they must be resolved first.
    ref.watch(evaWisdomProvider);
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => openMyStory(context, ref, initialStory: 1),
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Eva story spans the last 3 days', (t) async {
    SharedPreferences.setMockInitialValues(const {'eva_followed': true});
    final prefs = await SharedPreferences.getInstance();
    final mealDir = Directory.systemTemp.createTempSync('eva_meal');
    final profileFile = File(
      '${Directory.systemTemp.createTempSync('eva_prof').path}/p.jpg',
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mealPhotosProvider.overrideWithValue(MealPhotos(mealDir)),
          profilePhotoFileProvider.overrideWithValue(profileFile),
          authProvider.overrideWith(_DemoAuth.new),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const _Launcher(),
        ),
      ),
    );
    await beat(t, 1200); // let evaWisdom asset load
    await t.tap(find.text('open'));
    await beat(t, 1400);
    await shot(t, 'eva_day0'); // today — 3-segment progress bar
    final size = t.view.physicalSize / t.view.devicePixelRatio;
    final right = Offset(size.width * 0.8, size.height * 0.5);
    await t.tapAt(right);
    await beat(t, 900);
    await shot(t, 'eva_day1'); // yesterday (dated)
    await t.tapAt(right);
    await beat(t, 900);
    await shot(t, 'eva_day2'); // day before (dated)
  });
}
