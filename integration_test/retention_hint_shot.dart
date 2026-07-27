// Dev tooling (NOT shipped): captures the add-entry share-to-circle toggle for
// the 3-day → 30-day retention before/after pair. Clone of photo_log_demo.dart:
// fake picker returns a bundled food photo, the real ProxyAnalyzer hits the LIVE
// v2 backend, and once the analysis (and so the share toggle + hint) is on
// screen it pings the host capture server, which grabs the device frame via
// `simctl io screenshot`.
//
// Run against a booted simulator:
//   flutter test integration_test/retention_hint_shot.dart -d <udid> \
//     --dart-define-from-file=dart_defines.json --dart-define=SHOT_NAME=hint-before
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/app.dart';
import 'package:food_at_peace/src/data/profile_repository.dart';
import 'package:food_at_peace/src/models/user_profile.dart';
import 'package:food_at_peace/src/providers/providers.dart';

import 'demo_food_image.dart';

const _shotName = String.fromEnvironment('SHOT_NAME', defaultValue: 'hint');
const _shotPort = int.fromEnvironment('SHOT_PORT', defaultValue: 8123);

class _FakePicker extends ImagePickerPlatform {
  _FakePicker(this.path);
  final String path;
  @override
  Future<XFile?> getImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile(path);
}

Future<void> beat(WidgetTester t, int ms) async {
  var e = 0;
  while (e < ms) {
    await t.pump(const Duration(milliseconds: 60));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    e += 60;
  }
}

Future<void> shot(String name) async {
  final c = HttpClient();
  try {
    final req = await c.getUrl(Uri.parse('http://127.0.0.1:$_shotPort/shot/$name'));
    await (await req.close()).drain<void>();
  } catch (_) {
    // Capture server not running — the test still passes; just no image.
  } finally {
    c.close(force: true);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('share-to-circle hint screenshot', (t) async {
    final dir = await Directory.systemTemp.createTemp('fap_hintshot');
    final file = File('${dir.path}/food.jpg')
      ..writeAsBytesSync(base64Decode(demoFoodJpgB64));
    ImagePickerPlatform.instance = _FakePicker(file.path);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_complete': true,
      'health_connected': true,
    });
    final prefs = await SharedPreferences.getInstance();
    await ProfileRepository(prefs).save(
      const UserProfile(
        sex: Sex.female,
        age: 29,
        heightCm: 168,
        weightKg: 60,
        activity: ActivityLevel.moderate,
        goal: Goal.lose,
        isConfigured: true,
        name: 'Eva',
      ),
    );

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          weatherProvider.overrideWith((ref) async => null),
        ],
        child: const FoodAtPeaceApp(),
      ),
    );
    await beat(t, 2600); // boot → Today (welcome-grant Beans enable scanning)

    await t.tap(find.byIcon(Icons.add)); // Today FAB
    await beat(t, 1500);
    await t.tap(find.byIcon(Icons.camera_alt_outlined));
    await beat(t, 900);
    await t.tap(find.byIcon(Icons.photo_library_outlined).hitTestable());
    await beat(t, 1000);

    // Wait for the live analysis to land — the share toggle appears with it.
    var waited = 0;
    while (find.byType(SwitchListTile).evaluate().isEmpty && waited < 40000) {
      await beat(t, 500);
      waited += 500;
    }
    expect(find.byType(SwitchListTile), findsOneWidget,
        reason: 'analysis (and share toggle) never appeared');
    await t.ensureVisible(find.byType(SwitchListTile));
    await beat(t, 1200); // let the frame settle for a clean capture
    await shot(_shotName);
    await beat(t, 1500);
  });
}
