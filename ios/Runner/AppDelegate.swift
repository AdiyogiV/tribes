import Flutter
import UIKit
import Firebase
import FirebaseAppCheck
import FirebaseMessaging
import UserNotifications
import WatchConnectivity
import WidgetKit

/// App Group identifier used to share UserDefaults between the Flutter app
/// and the AurogramWidget extension. Must match `kAppGroup` in the widget
/// target and the App Group capability in both entitlements files.
private let kWidgetAppGroup = "group.com.canay.dhaara.widget"

@main
@objc class AppDelegate: FlutterAppDelegate {

  private var deviceType: String {
    UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // App Check provider MUST be installed BEFORE FirebaseApp.configure(),
    // otherwise the SDK's default DeviceCheck provider wins the startup race
    // (FCM/Firestore request a token before Dart's bootstrap runs).
    //
    // DEBUG: use the Debug provider. On first launch it prints
    //   "Firebase App Check Debug Token: <UUID>" to the Xcode console.
    //   Register that token in Firebase Console > App Check > [iOS app] >
    //   Manage debug tokens. (The iOS app must also be registered under
    //   App Check with a provider, else every exchange returns 400
    //   "App not registered".)
    // RELEASE: App Check is activated from Dart (app_bootstrap.dart) with
    //   App Attest + DeviceCheck fallback.
    #if DEBUG
    AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
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
    setupWidgetPlatformChannel()

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

      case "getPendingData":
        // Return any data that arrived before Dart was ready
        let pending = watchManager.getPendingData()
        result(pending)

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

  // MARK: - Home Screen Widget Platform Channel

  /// Bridges Flutter `WidgetDataService` writes to the App Group UserDefaults
  /// that the AurogramWidget extension reads from.
  ///
  /// Why a platform channel: the `shared_preferences` plugin writes to
  /// `NSUserDefaults.standard`, which is sandboxed per-process. Widget
  /// extensions live in a separate process and only see App Group defaults.
  private func setupWidgetPlatformChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }

    let channel = FlutterMethodChannel(name: "com.canay.dhaara/widget",
                                       binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "updateWidgetData":
        guard let args = call.arguments as? [String: Any?] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected map", details: nil))
          return
        }
        guard let defaults = UserDefaults(suiteName: kWidgetAppGroup) else {
          result(FlutterError(code: "APP_GROUP_MISSING",
                              message: "App Group \(kWidgetAppGroup) not configured",
                              details: nil))
          return
        }
        for (key, value) in args {
          if let str = value as? String, !str.isEmpty {
            defaults.set(str, forKey: key)
          } else if value == nil {
            defaults.removeObject(forKey: key)
          }
        }
        // Force widgets to reload now instead of waiting for the next timeline.
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(true)

      default:
        result(FlutterMethodNotImplemented)
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
