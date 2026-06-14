// Demo / proof for the language-localization fix, driven on a real simulator
// so it can be screen-recorded. The app is forced to Chinese; the image picker
// is faked to return a bundled food photo (no native picker UI in a test); the
// real ProxyAnalyzer then calls the live v2 backend, which returns the estimate
// in Chinese. Run with --dart-define-from-file=dart_defines.json so the proxy
// URL/token are configured.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:food_at_peace/src/features/add/add_entry_screen.dart';
import 'package:food_at_peace/src/providers/providers.dart';
import 'package:food_at_peace/src/theme/app_theme.dart';

import 'demo_food_image.dart';

/// Returns a fixed file from the gallery, bypassing the native picker.
/// `getImageFromSource` (what `ImagePicker().pickImage` calls) delegates to
/// `getImage` by default, so overriding this one method is enough.
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

/// Pumps real wall-clock time so live network calls can actually complete.
Future<void> beat(WidgetTester t, int ms) async {
  var elapsed = 0;
  while (elapsed < ms) {
    await t.pump(const Duration(milliseconds: 60));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    elapsed += 60;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Chinese app → photo scan → AI estimate comes back in Chinese',
      (t) async {
    // Materialize the bundled demo photo and make the picker return it.
    final dir = await Directory.systemTemp.createTemp('fap_demo');
    final file = File('${dir.path}/food.jpg')
      ..writeAsBytesSync(base64Decode(demoFoodJpgB64));
    ImagePickerPlatform.instance = _FakePicker(file.path);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await t.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          locale: const Locale('zh'), // app is in Chinese
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AddEntryScreen(),
        ),
      ),
    );
    await beat(t, 1800); // let the welcome-grant Beans load (enables scanning)

    // Tap "scan a photo".
    await t.tap(find.byIcon(Icons.camera_alt_outlined));
    await beat(t, 900);

    // Choose "from library" in the source sheet → fake picker returns the photo.
    await t.tap(find.byIcon(Icons.photo_library_outlined).hitTestable());
    await beat(t, 900);

    // Real analysis against the live v2 backend (a few seconds).
    await beat(t, 18000);

    // The dish name (first editable field) should now hold the Chinese estimate.
    final nameField = find.byType(EditableText).first;
    final name =
        (nameField.evaluate().first.widget as EditableText).controller.text;
    debugPrint('ANALYZED NAME: "$name"');
    expect(name.trim(), isNotEmpty, reason: 'analysis did not populate a name');
    final hasChinese =
        name.runes.any((r) => r >= 0x4E00 && r <= 0x9FFF);
    expect(hasChinese, isTrue, reason: 'expected Chinese in the name: "$name"');

    // Hold the Chinese result on screen so the recording captures it.
    await beat(t, 5000);
  });
}
