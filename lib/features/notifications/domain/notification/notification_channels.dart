import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'package:aurogram/platform/flutter_local_notifications_stub.dart';
import 'package:aurogram/shared/models/notification.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/platform/platform.dart';

import '../notification_service.dart';

/// Notification channel IDs, names, and Android channel creation.
/// Also handles iOS notification categories for call actions.
extension NotificationChannels on NotificationService {
  // ── Android Channel IDs ────────────────────────────────────────────────────
  static const String chatChannelId = 'chat_messages';
  static const String chatChannelName = 'Chat Messages';
  static const String chatChannelDesc =
      'Notifications for new chat messages';

  static const String socialChannelId = 'social_notifications';
  static const String socialChannelName = 'Social Activity';
  static const String socialChannelDesc =
      'Likes, replies, and other social notifications';

  static const String gramChannelId = 'gram_notifications';
  static const String gramChannelName = 'Gram Updates';
  static const String gramChannelDesc =
      'Invites, requests, and gram updates';

  static const String astroChannelId = 'astro_insights';
  static const String astroChannelName = 'Daily Insights';
  static const String astroChannelDesc =
      'Your personalized astrology insights';

  static const String generalChannelId = 'general_notifications';
  static const String generalChannelName = 'General';
  static const String generalChannelDesc = 'General app notifications';

  static const String callChannelId = 'call_notifications';
  static const String callChannelName = 'Incoming Calls';
  static const String callChannelDesc =
      'Voice and video call notifications';

  static const String groupCallChannelId = 'group_calls';
  static const String groupCallChannelName = 'Group Calls';
  static const String groupCallChannelDesc =
      'Notifications for group calls in grams';

  // ── iOS / Local notification action IDs ───────────────────────────────────
  static const String actionAcceptCall = 'accept_call';
  static const String actionRejectCall = 'reject_call';
  static const String actionJoinGroupCall = 'join_group_call';
  static const String actionDismissGroupCall = 'dismiss_group_call';

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Initialise flutter_local_notifications with iOS categories and Android
  /// channels. Does NOT request permissions.
  Future<void> initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      notificationCategories: [
        // 1:1 Call – Accept / Reject
        DarwinNotificationCategory(
          'incoming_call',
          actions: [
            DarwinNotificationAction.plain(
              actionAcceptCall,
              'Accept',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              actionRejectCall,
              'Reject',
              options: {DarwinNotificationActionOption.destructive},
            ),
          ],
          options: {
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
        // Group call – Join / Dismiss
        DarwinNotificationCategory(
          'group_call',
          actions: [
            DarwinNotificationAction.plain(
              actionJoinGroupCall,
              'Join',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              actionDismissGroupCall,
              'Dismiss',
              options: {},
            ),
          ],
          options: {
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: handleLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse:
          backgroundNotificationHandler,
    );

    if (!kIsWeb && PlatformServices.instance.isAndroid) {
      await createNotificationChannels();
    }
  }

  /// Create all Android notification channels.
  Future<void> createNotificationChannels() async {
    final androidPlugin =
        localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      chatChannelId,
      chatChannelName,
      description: chatChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      socialChannelId,
      socialChannelName,
      description: socialChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      gramChannelId,
      gramChannelName,
      description: gramChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      astroChannelId,
      astroChannelName,
      description: astroChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      generalChannelId,
      generalChannelName,
      description: generalChannelDesc,
      importance: Importance.defaultImportance,
      playSound: true,
      showBadge: true,
    ));

    // Max priority – enables full-screen intent for incoming calls.
    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      callChannelId,
      callChannelName,
      description: callChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      groupCallChannelId,
      groupCallChannelName,
      description: groupCallChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    AppLogger.d('Android notification channels created',
        category: LogCategory.messaging);
  }

  // ── Channel / name helpers ─────────────────────────────────────────────────

  String getChannelIdForType(NotificationType type) {
    switch (type) {
      case NotificationType.chat:
      case NotificationType.message:
        return chatChannelId;
      case NotificationType.reply:
      case NotificationType.like:
      case NotificationType.namaste:
      case NotificationType.newSpacePost:
        return socialChannelId;
      case NotificationType.invite:
      case NotificationType.request:
      case NotificationType.addedToGroup:
        return gramChannelId;
      case NotificationType.dailyAstroInsight:
        return astroChannelId;
      case NotificationType.incomingCall:
      case NotificationType.missedCall:
        return callChannelId;
      default:
        return generalChannelId;
    }
  }

  String getChannelNameForType(NotificationType type) {
    switch (type) {
      case NotificationType.chat:
      case NotificationType.message:
        return chatChannelName;
      case NotificationType.reply:
      case NotificationType.like:
      case NotificationType.namaste:
      case NotificationType.newSpacePost:
        return socialChannelName;
      case NotificationType.invite:
      case NotificationType.request:
      case NotificationType.addedToGroup:
        return gramChannelName;
      case NotificationType.dailyAstroInsight:
        return astroChannelName;
      case NotificationType.incomingCall:
      case NotificationType.missedCall:
        return callChannelName;
      case NotificationType.anonymousMessage:
        return generalChannelName;
      default:
        return generalChannelName;
    }
  }
}
