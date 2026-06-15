// Five-phase, two-simulator "Circle of Food" walkthrough (Peter + Eva), driven on
// real simulators so it can be screen-recorded. Both are "signed in" against the
// LIVE v2 backend via a server-minted session token injected through an
// authProvider override (Sign in with Apple can't run on a sim). The phase, token
// and peer come from --dart-define so no secret is committed.
//
// Phases (run in order; they share backend state):
//   request  (Peter): send a friend request to Eva by @handle
//   accept   (Eva):   get the request notification, then accept
//   post     (Peter): get the "accepted" notification, then post a meal photo
//   like     (Eva):   get the "shared a meal" notification, open feed, react ❤️
//   reaction (Peter): get the "reacted to your meal" notification
//
// Each phase seeds the activity snapshot so the relevant notification counts as
// "new" on launch (a fresh app would otherwise baseline it away).
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
import 'package:food_at_peace/src/models/session.dart';
import 'package:food_at_peace/src/providers/providers.dart';

import 'demo_food_image.dart';

const _phase = String.fromEnvironment('DEMO_PHASE'); // request|accept|post|like|reaction
const _token = String.fromEnvironment('DEV_SESSION_TOKEN');
const _uid = String.fromEnvironment('DEV_USER_ID');
const _myHandle = String.fromEnvironment('DEMO_MY_HANDLE');
const _peerHandle = String.fromEnvironment('DEMO_PEER_HANDLE');
const _peerUid = String.fromEnvironment('DEMO_PEER_UID');
const _big = 9999999999999;

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

/// Poll (pumping) up to ~16s for a banner/text to appear — the activity check is
/// a live network call, so it can land a few seconds after launch.
Future<bool> pollFor(WidgetTester t, String text) async {
  for (var i = 0; i < 40; i++) {
    await beat(t, 400);
    if (find.textContaining(text).evaluate().isNotEmpty) return true;
  }
  return false;
}

String _snap(Map<String, String> statuses, int lastPostMs) => jsonEncode({
  'statuses': statuses,
  'reactions': <String, int>{},
  'lastPostMs': lastPostMs,
});

Map<String, Object> _seed() {
  final base = <String, Object>{
    'onboarding_complete': true,
    'circle_my_handle': _myHandle,
    'circle_handle_set': true,
    'circle_notify_enabled': true,
  };
  switch (_phase) {
    case 'accept': // Peter's incoming request should read as new
      base['circle_activity_snapshot_v1'] = _snap({}, _big);
    case 'post': // Eva (peer) just went outgoing -> connected
      base['circle_activity_snapshot_v1'] = _snap({_peerUid: 'outgoing'}, _big);
    case 'like': // Peter (peer) connected; his new post should read as new
      base['circle_activity_snapshot_v1'] = _snap({_peerUid: 'connected'}, 1);
    case 'reaction': // my own post should read as freshly reacted-to
      base['circle_activity_snapshot_v1'] = _snap({_peerUid: 'connected'}, _big);
    // 'request' → no snapshot (first run, no notifications for Peter)
  }
  return base;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('circle 5-step demo — $_phase', (t) async {
    final dir = await Directory.systemTemp.createTemp('fap_demo5');
    final file = File('${dir.path}/food.jpg')
      ..writeAsBytesSync(base64Decode(demoFoodJpgB64));
    ImagePickerPlatform.instance = _FakePicker(file.path);

    SharedPreferences.setMockInitialValues(_seed());
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
    await beat(t, 2800); // boot + first circle refresh / activity check

    switch (_phase) {
      case 'request':
        await _request(t);
      case 'accept':
        await _accept(t);
      case 'post':
        await _post(t);
      case 'like':
        await _like(t);
      case 'reaction':
        await _reaction(t);
    }
  });
}

/// Peter: Trends → Manage circle → add Eva by @handle (sends a request).
Future<void> _request(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.insights_outlined));
  await beat(t, 1500);
  await t.tap(find.byIcon(Icons.group_outlined).hitTestable());
  await beat(t, 1800);
  await t.tap(find.byIcon(Icons.person_add_alt_1_outlined).hitTestable());
  await beat(t, 1200);
  await t.enterText(
    find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
    _peerHandle,
  );
  await beat(t, 800);
  await t.tap(find.widgetWithText(FilledButton, 'Send invite').hitTestable());
  await beat(t, 2500);
  expect(await pollFor(t, 'Invited'), isTrue, reason: 'Eva should appear as Invited');
  await beat(t, 2500); // hold for the recording
}

/// Eva: get the friend-request notification, then accept it.
Future<void> _accept(WidgetTester t) async {
  expect(await pollFor(t, 'wants to join'), isTrue,
      reason: 'expected the friend-request notification');
  await beat(t, 2500); // hold the banner
  await t.tap(find.byIcon(Icons.insights_outlined));
  await beat(t, 1500);
  await t.tap(find.textContaining('Requests').hitTestable());
  await beat(t, 1600);
  await t.tap(find.widgetWithText(FilledButton, 'Accept').hitTestable());
  await beat(t, 2500);
}

/// Peter: get the "Eva accepted" notification, then post a meal to the circle.
Future<void> _post(WidgetTester t) async {
  expect(await pollFor(t, 'accepted'), isTrue,
      reason: 'expected the request-accepted notification');
  await beat(t, 2500);
  await t.tap(find.byIcon(Icons.add)); // Today FAB
  await beat(t, 1800);
  await t.tap(find.byIcon(Icons.camera_alt_outlined));
  await beat(t, 900);
  await t.tap(find.byIcon(Icons.photo_library_outlined).hitTestable());
  await beat(t, 1000);
  await beat(t, 18000); // live analysis
  await t.tap(find.widgetWithText(TextButton, 'Save').hitTestable());
  await beat(t, 5000);
}

/// Eva: get the "Peter shared a meal" notification, open the feed, react ❤️.
Future<void> _like(WidgetTester t) async {
  expect(await pollFor(t, 'shared a meal'), isTrue,
      reason: 'expected the friend-posted notification');
  await beat(t, 2500);
  await t.tap(find.byIcon(Icons.insights_outlined));
  await beat(t, 1500);
  await t.tap(find.byIcon(Icons.dynamic_feed_outlined).hitTestable());
  await beat(t, 5000);
  await t.tap(find.text('❤️').first.hitTestable());
  await beat(t, 3500);
}

/// Peter: get the "Eva reacted to your meal" notification.
Future<void> _reaction(WidgetTester t) async {
  expect(await pollFor(t, 'reacted'), isTrue,
      reason: 'expected the reaction-received notification');
  await beat(t, 4000); // hold the banner for the recording
}
