import Flutter
import UIKit
import Firebase
import FirebaseAppCheck
import FirebaseMessaging
import UserNotifications
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  private var deviceType: String {
    UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
  }
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // App Check configuration.
    //
    // DEBUG: We deliberately do NOT install any App Check provider in debug
    // builds. The iOS Firebase SDK only attempts token exchanges when a
    // provider is registered, so leaving it unset keeps Firestore /
    // Functions / Storage calls from being blocked while the app waits for
    // an App Check token that will never arrive (the dev iOS app is not
    // registered in Firebase Console > App Check, which is why every
    // exchangeDeviceCheckToken request returns 400 "App not registered"
    // and triggers a retry storm that starves Firestore).
    //
    // RELEASE: Dart-side bootstrap (`app_bootstrap.dart`) installs
    // DeviceCheck via FirebaseAppCheck.activate(). When you ship to
    // production, register the iOS app at:
    //   https://console.firebase.google.com/project/_/appcheck/apps
    // Once registered, you can re-enable a debug provider here for local
    // testing of App-Check-enforced endpoints.
    #if DEBUG
    // Intentionally no-op. See comment above.
    #endif

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
