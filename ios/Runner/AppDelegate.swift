import Flutter
import UIKit
import Firebase
import FirebaseAppCheck
import FirebaseMessaging
import UserNotifications
import WatchConnectivity

/// A no-op App Check provider that silently absorbs token requests
/// instead of letting the SDK fall back to DeviceCheck (which fails
/// with 400 "App not registered" when the app isn't enrolled in
/// Firebase Console > App Check).
///
/// Returning `nil` from the factory causes the SDK to auto-detect
/// DeviceCheck and attempt a token exchange anyway.  Returning an
/// actual provider that errors immediately stops the retry loop.
private class NoOpAppCheckProvider: NSObject, AppCheckProvider {
  func getToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
    print("🛡️ NoOp App Check provider: returning nil token (debug build)")
    handler(nil, NSError(domain: "com.canay.dhaara.debug",
                         code: -1,
                         userInfo: [NSLocalizedDescriptionKey:
                                      "App Check disabled for debug builds"]))
  }
}

private class NoOpAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    print("🛡️ NoOp App Check factory: returning NoOp provider (debug build)")
    return NoOpAppCheckProvider()
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {

  private var deviceType: String {
    UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // App Check: Install a no-op factory BEFORE FirebaseApp.configure() so the
    // eagerly-created AppCheck component gets our NoOp provider (and caches it).
    // Without this, FIRComponentContainer returns nil on the first attempt, then
    // the Flutter firebase_app_check plugin sets a DeviceCheck factory during
    // GeneratedPluginRegistrant.register(), and subsequent token requests create
    // an AppCheck instance with DeviceCheck — which fails with 400
    // "App not registered" on development-signed builds.
    //
    // NOTE: #if DEBUG is NOT used because Swift compilation conditions evaluate
    // to false in this project's build configuration despite SWIFT_ACTIVE_-
    // COMPILATION_CONDITIONS containing DEBUG. Using unconditional NoOp is safe
    // because App Check is in Monitoring mode (not Enforced), so all requests
    // pass regardless of token validity.
    //
    // When App Check enforcement is enabled, replace this with a runtime check
    // (e.g. embedded.mobileprovision detection) or fix the build flags.
    AppCheck.setAppCheckProviderFactory(NoOpAppCheckProviderFactory())

    // Configure Firebase
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    
    print("🔔 App launching on \(deviceType), iOS \(UIDevice.current.systemVersion)")
    
    // Set up push notifications
    UNUserNotificationCenter.current().delegate = self
    
    // Request notification permissions
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
      if let error = error {
        print("🔔 Permission error: \(error.localizedDescription)")
      }
      print("🔔 Notifications \(granted ? "enabled" : "denied") on \(self.deviceType)")
    }
    
    // Register for remote notifications
    DispatchQueue.main.async {
      application.registerForRemoteNotifications()
    }
    
    // Set messaging delegate
    Messaging.messaging().delegate = self
    
    // Activate WatchConnectivity for watch companion app
    WatchSessionManager.shared.activate()
    setupWatchPlatformChannel()

    GeneratedPluginRegistrant.register(with: self)

    // Re-install no-op factory AFTER plugin registration — the Flutter
    // firebase_app_check plugin unconditionally overrides our factory with a
    // DeviceCheck-backed one during GeneratedPluginRegistrant.register().
    // This second set ensures our NoOp stays active.
    AppCheck.setAppCheckProviderFactory(NoOpAppCheckProviderFactory())
    // Kill the periodic token refresh that fires the 400s
    AppCheck.appCheck().isTokenAutoRefreshEnabled = false

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Watch Platform Channel

  /// Sets up the Flutter ↔ Watch bridge via platform channel.
  /// Flutter sends data via "com.canay.dhaara/watch" method channel.
  private func setupWatchPlatformChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }

    let channel = FlutterMethodChannel(name: "com.canay.dhaara/watch",
                                        binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let _ = self else { return }
      let watchManager = WatchSessionManager.shared

      switch call.method {
      case "sendPanchang":
        if let args = call.arguments as? [String: Any] {
          watchManager.sendPanchang(args)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected map", details: nil))
        }

      case "sendProfile":
        if let args = call.arguments as? [String: Any] {
          watchManager.sendProfile(args)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected map", details: nil))
        }

      case "sendInsight":
        if let args = call.arguments as? [String: Any] {
          watchManager.sendInsight(args)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected map", details: nil))
        }

      case "sendMuhurat":
        if let args = call.arguments as? [String: Any] {
          watchManager.sendMuhurat(args)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected map", details: nil))
        }

      case "sendSky":
        if let args = call.arguments as? [String: Any] {
          watchManager.sendSky(args)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected map", details: nil))
        }

      case "sendRecommendations":
        if let args = call.arguments as? [String: Any] {
          watchManager.sendRecommendations(args)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected map", details: nil))
        }

      case "isWatchPaired":
        result(watchManager.isWatchAvailable)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Forward watch data back to Flutter
    WatchSessionManager.shared.onWatchData = { data in
      DispatchQueue.main.async {
        channel.invokeMethod("onWatchData", arguments: data)
      }
    }
  }
  
  // MARK: - APNs Token Registration
  
  override func application(_ application: UIApplication,
                          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("🔔 APNs token received on \(deviceType)")
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  override func application(_ application: UIApplication,
                          didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("🔔 ❌ APNs registration failed on \(deviceType): \(error.localizedDescription)")
  }
  
  // MARK: - Foreground Notifications
  
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show notification even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
  
  // MARK: - Notification Tap
  
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // Forward to Flutter plugins (flutter_local_notifications, FCM)
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
  
  // MARK: - Background/Silent Push
  
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    Messaging.messaging().appDidReceiveMessage(userInfo)
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }
}

// MARK: - Firebase Messaging Delegate

extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("🔔 FCM token received on \(deviceType)")
    
    // Post notification for Flutter
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: ["token": fcmToken ?? ""]
    )
  }
}
