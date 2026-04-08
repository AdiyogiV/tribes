part of '../notification_service.dart';

/// Notification channel IDs, names, and Android channel creation.
/// Also handles iOS notification categories for call actions.
extension _NotificationChannels on NotificationService {
  // ── Android Channel IDs ────────────────────────────────────────────────────
  static const String _chatChannelId = 'chat_messages';
  static const String _chatChannelName = 'Chat Messages';
  static const String _chatChannelDesc =
      'Notifications for new chat messages';

  static const String _socialChannelId = 'social_notifications';
  static const String _socialChannelName = 'Social Activity';
  static const String _socialChannelDesc =
      'Likes, replies, and other social notifications';

  static const String _gramChannelId = 'gram_notifications';
  static const String _gramChannelName = 'Gram Updates';
  static const String _gramChannelDesc =
      'Invites, requests, and gram updates';

  static const String _astroChannelId = 'astro_insights';
  static const String _astroChannelName = 'Daily Insights';
  static const String _astroChannelDesc =
      'Your personalized astrology insights';

  static const String _generalChannelId = 'general_notifications';
  static const String _generalChannelName = 'General';
  static const String _generalChannelDesc = 'General app notifications';

  static const String _callChannelId = 'call_notifications';
  static const String _callChannelName = 'Incoming Calls';
  static const String _callChannelDesc =
      'Voice and video call notifications';

  static const String _groupCallChannelId = 'group_calls';
  static const String _groupCallChannelName = 'Group Calls';
  static const String _groupCallChannelDesc =
      'Notifications for group calls in grams';

  // ── iOS / Local notification action IDs ───────────────────────────────────
  static const String _actionAcceptCall = 'accept_call';
  static const String _actionRejectCall = 'reject_call';
  static const String _actionJoinGroupCall = 'join_group_call';
  static const String _actionDismissGroupCall = 'dismiss_group_call';

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Initialise flutter_local_notifications with iOS categories and Android
  /// channels. Does NOT request permissions.
  Future<void> _initializeLocalNotifications() async {
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
              _actionAcceptCall,
              'Accept',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              _actionRejectCall,
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
              _actionJoinGroupCall,
              'Join',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              _actionDismissGroupCall,
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

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse:
          _backgroundNotificationHandler,
    );

    if (!kIsWeb && PlatformServices.instance.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Create all Android notification channels.
  Future<void> _createNotificationChannels() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      _chatChannelId,
      _chatChannelName,
      description: _chatChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      _socialChannelId,
      _socialChannelName,
      description: _socialChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      _gramChannelId,
      _gramChannelName,
      description: _gramChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      _astroChannelId,
      _astroChannelName,
      description: _astroChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      _generalChannelId,
      _generalChannelName,
      description: _generalChannelDesc,
      importance: Importance.defaultImportance,
      playSound: true,
      showBadge: true,
    ));

    // Max priority – enables full-screen intent for incoming calls.
    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      _callChannelId,
      _callChannelName,
      description: _callChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      _groupCallChannelId,
      _groupCallChannelName,
      description: _groupCallChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    AppLogger.d('Android notification channels created',
        category: LogCategory.messaging);
  }

  // ── Channel / name helpers ─────────────────────────────────────────────────

  String _getChannelIdForType(NotificationType type) {
    switch (type) {
      case NotificationType.chat:
      case NotificationType.message:
        return _chatChannelId;
      case NotificationType.reply:
      case NotificationType.like:
      case NotificationType.namaste:
      case NotificationType.newSpacePost:
        return _socialChannelId;
      case NotificationType.invite:
      case NotificationType.request:
      case NotificationType.addedToGroup:
        return _gramChannelId;
      case NotificationType.dailyAstroInsight:
        return _astroChannelId;
      case NotificationType.incomingCall:
      case NotificationType.missedCall:
        return _callChannelId;
      default:
        return _generalChannelId;
    }
  }

  String _getChannelNameForType(NotificationType type) {
    switch (type) {
      case NotificationType.chat:
      case NotificationType.message:
        return _chatChannelName;
      case NotificationType.reply:
      case NotificationType.like:
      case NotificationType.namaste:
      case NotificationType.newSpacePost:
        return _socialChannelName;
      case NotificationType.invite:
      case NotificationType.request:
      case NotificationType.addedToGroup:
        return _gramChannelName;
      case NotificationType.dailyAstroInsight:
        return _astroChannelName;
      case NotificationType.incomingCall:
      case NotificationType.missedCall:
        return _callChannelName;
      case NotificationType.anonymousMessage:
        return _generalChannelName;
      default:
        return _generalChannelName;
    }
  }
}
