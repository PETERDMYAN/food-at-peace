// Screen-recordable **photo → calories → log** walkthrough, driven on a real
// simulator. The image picker is faked to return a bundled food photo (no native
// picker UI in a test); the real ProxyAnalyzer then calls the LIVE v2 backend,
// which returns the nutrition estimate. Saving lands the entry on Today and the
// calorie card updates. Run with --dart-define-from-file=dart_defines.json so the
// proxy URL/token are configured.
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('photo → calories → log on Today', (t) async {
    final dir = await Directory.systemTemp.createTemp('fap_photolog');
    final file = File('${dir.path}/food.jpg')
      ..writeAsBytesSync(base64Decode(demoFoodJpgB64));
    ImagePickerPlatform.instance = _FakePicker(file.path);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_complete': true,
      'health_connected': true, // Eva connected Health during onboarding (step 1)
    });
    final prefs = await SharedPreferences.getInstance();
    // A configured profile → the calorie budget is real, not a placeholder.
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

    // ── Open "Add food" → tap the photo-scan action ─────────────────────────
    await t.tap(find.byIcon(Icons.add)); // Today FAB
    await beat(t, 1500);
    await t.tap(find.byIcon(Icons.camera_alt_outlined));
    await beat(t, 900);
    await t.tap(find.byIcon(Icons.photo_library_outlined).hitTestable());
    await beat(t, 1000);

    // ── Real analysis against the live v2 backend ───────────────────────────
    await beat(t, 14000);
    await beat(t, 3000); // hold the estimate (dish name + calories + macros)

    // ── Save → back on Today, the calorie card reflects the entry ───────────
    await t.tap(
      find.descendant(of: find.byType(AppBar), matching: find.text('Save')),
    );
    await beat(t, 2600);
    // Scroll the list up so the freshly-logged entry tile is on screen.
    await t.drag(find.byType(Scrollable).first, const Offset(0, -260));
    await beat(t, 3200);
  });
}
