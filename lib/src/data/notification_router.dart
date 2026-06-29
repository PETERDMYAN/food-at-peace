import 'package:flutter/services.dart';

/// Bridges native notification taps (iOS `AppDelegate`) into Dart so a tapped
/// push can deep-link to the right screen. The native side forwards the push's
/// custom route keys (`postId` / `postAuthorId` / `open`) — both for **live**
/// taps (`onNotificationTap`) and for a tap that **cold-launched** the app
/// (`getInitialNotification`). A no-op on platforms without the native handler.
class NotificationRouter {
  static const _channel = MethodChannel('app.foodatpeace/notifications');

  /// Start listening. [onRoute] is called with each tapped notification's route
  /// map, including any pending one that launched the app.
  static void start(void Function(Map<Object?, Object?> route) onRoute) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTap' && call.arguments is Map) {
        onRoute(call.arguments as Map<Object?, Object?>);
      }
      return null;
    });
    // Cold start: drain any notification that launched the app (best-effort —
    // the method is absent on Android/web, so swallow MissingPluginException).
    _channel.invokeMethod('getInitialNotification').then((r) {
      if (r is Map) onRoute(r);
    }).catchError((_) {});
  }
}
