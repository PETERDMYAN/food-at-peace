import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Channel to Dart for push deep-linking (tapped-notification routing).
  private var notifChannel: FlutterMethodChannel?
  /// A route from a tap that happened before Dart was listening (cold start) —
  /// Dart drains it via `getInitialNotification` on launch.
  private var pendingRoute: [String: Any]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by flutter_local_notifications so scheduled local notifications
    // are handled (incl. while the app is in the foreground).
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    // Ask iOS for an APNs device token. It's delivered (didRegister… below) once
    // the user has granted notification permission; harmless before then.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// APNs token arrived — stash it where Flutter's shared_preferences can read it
  /// (keys are stored under a "flutter." prefix), so Dart can register it with
  /// the server (/circle/register-device) for friend-meal push.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    UserDefaults.standard.set(hex, forKey: "flutter.apns_device_token")
    super.application(
      application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    // Best-effort: no token this launch (e.g. notifications not yet granted).
    super.application(
      application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  /// Present circle-activity / reminder notifications as a banner even when the
  /// app is in the foreground (a friend's reaction should still slide down as a
  /// real iOS banner, not be swallowed silently while you're in the app).
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Set up the notification deep-link channel on the engine's messenger.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FAPNotifications") {
      let channel = FlutterMethodChannel(
        name: "app.foodatpeace/notifications",
        binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "getInitialNotification" {
          result(self?.pendingRoute)  // a cold-start tap's route (or nil)
          self?.pendingRoute = nil
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      notifChannel = channel
    }
  }

  /// User TAPPED a notification → forward its route keys to Dart so the app can
  /// deep-link (open the meal/comment/@mention). Live taps invoke the channel
  /// directly; a cold-start tap is stashed in `pendingRoute` (Dart drains it).
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let route = AppDelegate.route(from: response.notification.request.content.userInfo) {
      pendingRoute = route
      notifChannel?.invokeMethod("onNotificationTap", arguments: route)
    }
    completionHandler()
  }

  /// Pull the custom deep-link keys out of a push's userInfo (nil if absent).
  private static func route(from info: [AnyHashable: Any]) -> [String: Any]? {
    guard let postId = info["postId"] as? String, !postId.isEmpty else { return nil }
    var r: [String: Any] = ["postId": postId]
    if let author = info["postAuthorId"] as? String { r["postAuthorId"] = author }
    if let open = info["open"] as? String { r["open"] = open }
    return r
  }
}
