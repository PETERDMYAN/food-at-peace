// Two-simulator "Circle of Food" walkthrough, driven on real simulators so it
// can be screen-recorded. One device runs as the INVITER (posts a meal photo +
// shows its invite QR); the other runs as the VIEWER (connects via the invite,
// opens the feed, sees the meal, reacts). Both are "signed in" against the LIVE
// v2 backend via a server-minted session token injected through an authProvider
// override (Sign in with Apple can't run on a simulator). The token + role come
// from --dart-define so no secret is committed.
//
// Run (per device):
//   flutter test integration_test/circle_two_user_demo.dart -d <SIM> \
//     --dart-define-from-file=dart_defines.json \
//     --dart-define DEMO_ROLE=inviter --dart-define DEV_SESSION_TOKEN=... \
//     --dart-define DEV_USER_ID=... --dart-define DEMO_MY_HANDLE=alexNNN \
//     --dart-define DEMO_PEER_HANDLE=miaNNN
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
import 'package:food_at_peace/src/features/circle/connect_sheet.dart';
import 'package:food_at_peace/src/features/home/home_shell.dart';
import 'package:food_at_peace/src/models/session.dart';
import 'package:food_at_peace/src/providers/providers.dart';

import 'demo_food_image.dart';

const _role = String.fromEnvironment('DEMO_ROLE'); // inviter | viewer
const _token = String.fromEnvironment('DEV_SESSION_TOKEN');
const _uid = String.fromEnvironment('DEV_USER_ID');
const _myHandle = String.fromEnvironment('DEMO_MY_HANDLE');
const _peerHandle = String.fromEnvironment('DEMO_PEER_HANDLE');

/// Treats the app as signed in with a real (server-minted) session token, so
/// the Circle/feed Bearer calls hit the live v2 backend. Test-only — production
/// auth still goes through Sign in with Apple.
class _DemoAuth extends AuthNotifier {
  @override
  Session? build() => _token.isEmpty
      ? null
      : Session(
          token: _token,
          userId: _uid,
          expiresAt: DateTime.now().add(const Duration(hours: 4)),
        );
}

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

  testWidgets('two-user circle demo — $_role', (t) async {
    final dir = await Directory.systemTemp.createTemp('fap_demo2');
    final file = File('${dir.path}/food.jpg')
      ..writeAsBytesSync(base64Decode(demoFoodJpgB64));
    ImagePickerPlatform.instance = _FakePicker(file.path);

    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'circle_my_handle': _myHandle,
      'circle_handle_set': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          weatherProvider.overrideWith((ref) async => null),
          authProvider.overrideWith(_DemoAuth.new),
        ],
        child: const FoodAtPeaceApp(),
      ),
    );
    await beat(t, 2800); // boot + first online circle refresh

    if (_role == 'inviter') {
      await _runInviter(t);
    } else {
      await _runViewer(t);
    }
  });
}

/// Alex: scan + post a meal to the circle, then show the invite QR.
Future<void> _runInviter(WidgetTester t) async {
  // Today → Add food.
  await t.tap(find.byIcon(Icons.add));
  await beat(t, 1800); // AddEntryScreen + welcome-grant Beans (enables scanning)

  // Scan a photo from the library (fake picker returns the bundled meal).
  await t.tap(find.byIcon(Icons.camera_alt_outlined));
  await beat(t, 900);
  await t.tap(find.byIcon(Icons.photo_library_outlined).hitTestable());
  await beat(t, 1000);
  await beat(t, 18000); // live analysis against the v2 backend

  // "Share to circle" is on by default — save (fires the post, best-effort).
  await t.tap(find.widgetWithText(TextButton, 'Save').hitTestable());
  await beat(t, 5000);

  // Trends → Manage circle → the invite QR + link.
  await t.tap(find.byIcon(Icons.insights_outlined));
  await beat(t, 1600);
  await t.tap(find.byIcon(Icons.group_outlined).hitTestable());
  await beat(t, 2500);
  await beat(t, 6000); // hold the QR on screen for the recording
}

/// Mia: connect via Alex's invite link, then view the feed and react.
Future<void> _runViewer(WidgetTester t) async {
  // Trends tab.
  await t.tap(find.byIcon(Icons.insights_outlined));
  await beat(t, 1600);

  // Mimic opening Alex's invite link (foodatpeace://i/<peer>) — same sheet the
  // app_links deep-link handler shows.
  final ctx = t.element(find.byType(HomeShell));
  showConnectSheet(ctx, _peerHandle);
  await beat(t, 1800);
  await t.tap(find.widgetWithText(FilledButton, 'Connect').hitTestable());
  await beat(t, 3500); // connect + circle refresh

  // Open the circle feed → Alex's meal photo (presigned S3 image) loads.
  await t.tap(find.byIcon(Icons.dynamic_feed_outlined).hitTestable());
  await beat(t, 5000);

  // React with ❤️ — Alex will receive it.
  await t.tap(find.text('❤️').first.hitTestable());
  await beat(t, 4000);
}
