/// Stub for flutter_local_notifications on web
/// Web uses the Web Notifications API instead

// Re-export common types that might be used
class FlutterLocalNotificationsPlugin {
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    Function(NotificationResponse)? onDidReceiveNotificationResponse,
    Function(NotificationResponse)? onDidReceiveBackgroundNotificationResponse,
  }) async {
    return true;
  }

  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails, {
    String? payload,
  }) async {
    // Use Web Notifications API if permission granted
    // This is handled by WebPlatformServices
  }

  Future<void> cancel(int id) async {}

  Future<void> cancelAll() async {}

  T? resolvePlatformSpecificImplementation<T>() => null;

  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async {
    return null;
  }
}

class InitializationSettings {
  final AndroidInitializationSettings? android;
  final DarwinInitializationSettings? iOS;

  const InitializationSettings({this.android, this.iOS});
}

class AndroidInitializationSettings {
  final String defaultIcon;
  const AndroidInitializationSettings(this.defaultIcon);
}

class DarwinInitializationSettings {
  final bool requestAlertPermission;
  final bool requestBadgePermission;
  final bool requestSoundPermission;
  final bool defaultPresentAlert;
  final bool defaultPresentBadge;
  final bool defaultPresentSound;
  final List<DarwinNotificationCategory>? notificationCategories;

  const DarwinInitializationSettings({
    this.requestAlertPermission = false,
    this.requestBadgePermission = false,
    this.requestSoundPermission = false,
    this.defaultPresentAlert = true,
    this.defaultPresentBadge = true,
    this.defaultPresentSound = true,
    this.notificationCategories,
  });
}

class DarwinNotificationCategory {
  final String identifier;
  final List<DarwinNotificationAction>? actions;
  final Set<DarwinNotificationCategoryOption>? options;

  const DarwinNotificationCategory(
    this.identifier, {
    this.actions,
    this.options,
  });
}

class DarwinNotificationAction {
  final String identifier;
  final String title;
  final Set<DarwinNotificationActionOption>? options;

  const DarwinNotificationAction.plain(
    this.identifier,
    this.title, {
    this.options,
  });
}

enum DarwinNotificationActionOption {
  foreground,
  destructive,
  authenticationRequired,
}

enum DarwinNotificationCategoryOption {
  hiddenPreviewShowTitle,
  hiddenPreviewShowSubtitle,
  allowInCarPlay,
  allowAnnouncement,
  customDismissAction,
}

class NotificationDetails {
  final AndroidNotificationDetails? android;
  final DarwinNotificationDetails? iOS;

  const NotificationDetails({this.android, this.iOS});
}

class AndroidNotificationDetails {
  final String channelId;
  final String channelName;
  final String? channelDescription;
  final Importance? importance;
  final Priority? priority;
  final AndroidNotificationCategory? category;
  final bool? fullScreenIntent;
  final bool? ongoing;
  final bool? autoCancel;
  final NotificationVisibility? visibility;
  final bool? playSound;
  final bool? enableVibration;
  final bool? showBadge;
  final int? timeoutAfter;
  final List<AndroidNotificationAction>? actions;
  final StyleInformation? styleInformation;

  const AndroidNotificationDetails(
    this.channelId,
    this.channelName, {
    this.channelDescription,
    this.importance,
    this.priority,
    this.category,
    this.fullScreenIntent,
    this.ongoing,
    this.autoCancel,
    this.visibility,
    this.playSound,
    this.enableVibration,
    this.showBadge,
    this.timeoutAfter,
    this.actions,
    this.styleInformation,
  });
}

class DarwinNotificationDetails {
  final bool? presentAlert;
  final bool? presentBadge;
  final bool? presentSound;
  final InterruptionLevel? interruptionLevel;
  final String? categoryIdentifier;

  const DarwinNotificationDetails({
    this.presentAlert,
    this.presentBadge,
    this.presentSound,
    this.interruptionLevel,
    this.categoryIdentifier,
  });
}

class AndroidNotificationAction {
  final String id;
  final String title;
  final bool? showsUserInterface;
  final bool? cancelNotification;
  final bool? contextual;

  const AndroidNotificationAction(
    this.id,
    this.title, {
    this.showsUserInterface,
    this.cancelNotification,
    this.contextual,
  });
}

class AndroidNotificationChannel {
  final String id;
  final String name;
  final String? description;
  final Importance importance;
  final bool? playSound;
  final bool? enableVibration;
  final bool? showBadge;

  const AndroidNotificationChannel(
    this.id,
    this.name, {
    this.description,
    this.importance = Importance.defaultImportance,
    this.playSound,
    this.enableVibration,
    this.showBadge,
  });
}

enum Importance {
  unspecified,
  none,
  min,
  low,
  defaultImportance,
  high,
  max,
}

enum Priority {
  min,
  low,
  defaultPriority,
  high,
  max,
}

enum NotificationVisibility {
  private,
  public,
  secret,
}

enum InterruptionLevel {
  passive,
  active,
  timeSensitive,
  critical,
}

enum AndroidNotificationCategory {
  alarm,
  call,
  email,
  error,
  event,
  message,
  navigation,
  progress,
  promo,
  recommendation,
  reminder,
  service,
  social,
  status,
  stopwatch,
  transport,
  workout,
}

class NotificationResponse {
  final int? id;
  final String? actionId;
  final String? input;
  final String? payload;
  final NotificationResponseType notificationResponseType;

  const NotificationResponse({
    this.id,
    this.actionId,
    this.input,
    this.payload,
    this.notificationResponseType = NotificationResponseType.selectedNotification,
  });
}

enum NotificationResponseType {
  selectedNotification,
  selectedNotificationAction,
}

class NotificationAppLaunchDetails {
  final bool didNotificationLaunchApp;
  final NotificationResponse? notificationResponse;

  const NotificationAppLaunchDetails(
    this.didNotificationLaunchApp,
    this.notificationResponse,
  );
}

class StyleInformation {
  const StyleInformation();
}

class BigTextStyleInformation extends StyleInformation {
  final String bigText;
  const BigTextStyleInformation(this.bigText);
}

// Stub for AndroidFlutterLocalNotificationsPlugin
class AndroidFlutterLocalNotificationsPlugin {
  Future<void> createNotificationChannel(AndroidNotificationChannel channel) async {}
}
