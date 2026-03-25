import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'package:aurogram/platform/flutter_local_notifications_stub.dart';
import 'package:aurogram/models/notification.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/services/chat/chat_notification_service.dart';
import 'package:aurogram/pages/astrology/daily_insight_page.dart';
import 'package:aurogram/pages/thread_view.dart';
import 'package:aurogram/pages/spaces/space_screen.dart';
import 'package:aurogram/pages/spaces/space_chat_screen.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/pages/invites.dart';
import 'package:aurogram/pages/requests.dart';
import 'package:aurogram/pages/call/group_call_screen.dart';
import 'package:aurogram/pages/send_me_something/inbox_screen.dart';
import 'package:aurogram/platform/platform.dart';

/// Centralized notification service for handling all push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  // Track current route for smart notification filtering
  String? _currentRoute;
  String? _currentChatSpaceId;

  // Stream controllers for notification events
  final StreamController<AppNotification> _notificationStreamController =
      StreamController<AppNotification>.broadcast();

  // Notification counts
  int _unreadCount = 0;
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  // Android Notification Channels
  static const String _chatChannelId = 'chat_messages';
  static const String _chatChannelName = 'Chat Messages';
  static const String _chatChannelDesc = 'Notifications for new chat messages';

  static const String _socialChannelId = 'social_notifications';
  static const String _socialChannelName = 'Social Activity';
  static const String _socialChannelDesc =
      'Likes, replies, and other social notifications';

  static const String _gramChannelId = 'gram_notifications';
  static const String _gramChannelName = 'Gram Updates';
  static const String _gramChannelDesc = 'Invites, requests, and gram updates';

  static const String _astroChannelId = 'astro_insights';
  static const String _astroChannelName = 'Daily Insights';
  static const String _astroChannelDesc =
      'Your personalized astrology insights';

  static const String _generalChannelId = 'general_notifications';
  static const String _generalChannelName = 'General';
  static const String _generalChannelDesc = 'General app notifications';

  static const String _callChannelId = 'call_notifications';
  static const String _callChannelName = 'Incoming Calls';
  static const String _callChannelDesc = 'Voice and video call notifications';

  static const String _groupCallChannelId = 'group_calls';
  static const String _groupCallChannelName = 'Group Calls';
  static const String _groupCallChannelDesc =
      'Notifications for group calls in grams';

  // Getters
  User? get _currentUser => _auth.currentUser;
  Stream<AppNotification> get notificationStream =>
      _notificationStreamController.stream;
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  int get unreadCount => _unreadCount;

  // Track if permissions have been requested
  bool _permissionsRequested = false;

  /// Initialize the notification service WITHOUT requesting permissions
  /// Permissions should be requested later at a contextual moment (e.g., after showing insights)
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;

    _navigatorKey = navigatorKey;

    try {
      // Initialize local notifications with channels
      await _initializeLocalNotifications();

      // Set up FCM handlers (these work even without permission - just won't show notifications)
      _setupFCMHandlers();

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenToFirestore);

      // Start listening to unread count
      _startUnreadCountListener();

      _initialized = true;
      AppLogger.i('NotificationService initialized (permissions deferred)',
          category: LogCategory.messaging);

      // CRITICAL: Check if permissions already granted and register token proactively
      // This handles cases where user granted permissions previously but token wasn't saved
      _checkAndRegisterExistingPermissions();
    } catch (e, stack) {
      AppLogger.e('NotificationService initialization failed',
          category: LogCategory.messaging, error: e, stackTrace: stack);
    }
  }

  /// Check if permissions are already granted and register token if so
  /// On Android 13+, this will also request permissions if not already granted
  /// On web, this will request permissions and register token
  Future<void> _checkAndRegisterExistingPermissions() async {
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      final hasPermission =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      AppLogger.i(
          'Checking existing notification permissions: ${settings.authorizationStatus}',
          category: LogCategory.messaging);

      if (hasPermission) {
        AppLogger.i(
            'Permissions already granted, registering FCM token proactively',
            category: LogCategory.messaging);
        _permissionsRequested = true; // Mark as already requested

        // Register token in background to not block initialization
        unawaited(_registerFCMToken());
      } else if (kIsWeb) {
        // On web, request permissions proactively after a short delay
        AppLogger.i(
            'Web: Permissions not granted, will request when appropriate',
            category: LogCategory.messaging);

        // Delay to avoid blocking app startup and to wait for user interaction
        Future.delayed(const Duration(seconds: 3), () async {
          try {
            final granted = await requestPermissions(showRationale: false);
            if (granted) {
              AppLogger.i('Web: Permissions granted after proactive request',
                  category: LogCategory.messaging);
            } else {
              AppLogger.w('Web: User denied notification permissions',
                  category: LogCategory.messaging);
            }
          } catch (e) {
            AppLogger.e('Web: Error requesting permissions: $e',
                category: LogCategory.messaging);
          }
        });
      } else if (PlatformServices.instance.isAndroid) {
        // On Android 13+, permissions must be explicitly requested
        // Request them proactively for existing users who may not have gone through FTUE again
        AppLogger.i('Android: Permissions not granted, requesting proactively',
            category: LogCategory.messaging);

        // Delay slightly to avoid blocking app startup
        Future.delayed(const Duration(seconds: 2), () async {
          try {
            final granted = await requestPermissions(showRationale: false);
            if (granted) {
              AppLogger.i(
                  'Android: Permissions granted after proactive request',
                  category: LogCategory.messaging);
            } else {
              AppLogger.w('Android: User denied notification permissions',
                  category: LogCategory.messaging);
            }
          } catch (e) {
            AppLogger.e('Android: Error requesting permissions: $e',
                category: LogCategory.messaging);
          }
        });
      }
    } catch (e) {
      AppLogger.w('Error checking existing permissions: $e',
          category: LogCategory.messaging);
    }
  }

  /// Request notification permissions at a contextual moment
  /// Returns true if permission was granted
  /// Best called after user has seen value (e.g., after viewing daily insights)
  Future<bool> requestPermissions({bool showRationale = true}) async {
    if (_permissionsRequested) {
      // Already requested, check current status
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }

    try {
      _permissionsRequested = true;

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: true,
        criticalAlert: false,
      );

      AppLogger.d(
          'Push notification permission: ${settings.authorizationStatus}',
          category: LogCategory.messaging);

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      if (granted) {
        // Now that we have permission, register for FCM token
        await _registerFCMToken();
      }

      return granted;
    } catch (e, stack) {
      AppLogger.e('Failed to request notification permissions',
          category: LogCategory.messaging, error: e, stackTrace: stack);
      return false;
    }
  }

  /// Check if notification permissions have been granted (without prompting)
  Future<bool> hasPermission() async {
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      return false;
    }
  }

  /// Check if permissions have been requested before
  bool get permissionsRequested => _permissionsRequested;

  // Notification action IDs
  static const String _actionAcceptCall = 'accept_call';
  static const String _actionRejectCall = 'reject_call';
  static const String _actionJoinGroupCall = 'join_group_call';
  static const String _actionDismissGroupCall = 'dismiss_group_call';

  /// Initialize local notifications with proper channels
  Future<void> _initializeLocalNotifications() async {
    // Android settings with notification channels
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings with notification categories for call actions
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      notificationCategories: [
        // 1:1 Call category with Accept/Reject
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
        // Group call category with Join/Dismiss
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

    // Create Android notification channels
    if (!kIsWeb && PlatformServices.instance.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Create Android notification channels for different notification types
  Future<void> _createNotificationChannels() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Chat messages channel (high priority)
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

    // Social activity channel
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

    // Group updates channel
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

    // Astrology insights channel
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

    // General notifications channel
    await androidPlugin
        .createNotificationChannel(const AndroidNotificationChannel(
      _generalChannelId,
      _generalChannelName,
      description: _generalChannelDesc,
      importance: Importance.defaultImportance,
      playSound: true,
      showBadge: true,
    ));

    // Incoming calls channel (max priority for full-screen intent)
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

    // Group calls channel (high priority for group call notifications)
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

  /// Set up FCM message handlers
  void _setupFCMHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background/terminated tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check for initial message (app opened from terminated state)
    _checkInitialMessage();
  }

  /// Check if app was opened via notification from terminated state
  Future<void> _checkInitialMessage() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      AppLogger.d('App opened via notification from terminated state',
          category: LogCategory.messaging,
          data: {'type': initialMessage.data['type']});
      // Delay to allow app to fully initialize
      _handleNotificationTapWithRetry(initialMessage);
    }

    // Also check for pending local notification taps from background
    _checkPendingBackgroundNotification();

    // Check local notification launch details
    await _checkLocalNotificationLaunch();
  }

  /// Check if app was launched via a local notification tap
  Future<void> _checkLocalNotificationLaunch() async {
    try {
      final launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchDetails?.notificationResponse != null) {
        final payload = launchDetails!.notificationResponse!.payload ?? '';
        final actionId = launchDetails.notificationResponse!.actionId;

        AppLogger.i('📱 App launched via local notification',
            category: LogCategory.messaging,
            data: {'payload': payload, 'actionId': actionId});

        // Handle with retry since navigator might not be ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleLocalNotificationTap(launchDetails.notificationResponse!);
        });
      }
    } catch (e) {
      AppLogger.w('Error checking local notification launch: $e',
          category: LogCategory.messaging);
    }
  }

  /// Check for pending background notification and handle it
  void _checkPendingBackgroundNotification() {
    if (_pendingBackgroundNotification != null) {
      AppLogger.i('📱 Processing pending background notification',
          category: LogCategory.messaging,
          data: {'payload': _pendingBackgroundNotification!.payload});

      // Handle after a short delay to ensure app is fully initialized
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_pendingBackgroundNotification != null) {
          _handleLocalNotificationTap(_pendingBackgroundNotification!);
          _pendingBackgroundNotification = null;
        }
      });
    }
  }

  /// Handle foreground FCM message
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = _parseRemoteMessage(message);

    // Check if app is truly in foreground (visible to user)
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isAppInForeground = lifecycleState == AppLifecycleState.resumed;

    // Log with INFO level to ensure it's visible
    AppLogger.i('📬 FCM message received in NotificationService',
        category: LogCategory.general,
        data: {
          'type': notification.type.value,
          'rawType': message.data['type'],
          'id': notification.id,
          'lifecycleState': lifecycleState?.name ?? 'unknown',
          'isAppInForeground': isAppInForeground,
          'isCallNotification': notification.isCallNotification,
          'callerName': message.data['callerName'],
        });

    // For 1:1 call notifications:
    // - If app is in foreground: skip (CallService will show incoming call screen)
    // - If app is backgrounded: show local notification so user sees the call
    if (notification.isCallNotification) {
      if (isAppInForeground) {
        AppLogger.i(
            '📞 Skipping call notification - app in foreground, CallService handles it',
            category: LogCategory.general);
        return;
      } else {
        // App is backgrounded but still alive - show local notification
        AppLogger.i('📞 Showing call notification - app is backgrounded',
            category: LogCategory.general);
        await _showCallNotification(notification, message.data);
        return;
      }
    }

    // For group call notifications - always show (even in foreground for grams)
    if (notification.isGroupCallNotification) {
      AppLogger.i('📞 Showing group call notification',
          category: LogCategory.general, data: message.data);
      await _showGroupCallNotification(message.data);
      return;
    }

    // Check if we should suppress this notification
    if (_shouldSuppressNotification(notification)) {
      AppLogger.d('Notification suppressed (user viewing relevant screen)',
          category: LogCategory.messaging);
      return;
    }

    // Emit to stream for in-app handling
    _notificationStreamController.add(notification);

    // Show appropriate notification based on type
    if (notification.isChatNotification) {
      // Use ChatNotificationService for in-app chat notifications
      final chatService = ChatNotificationService();
      chatService.handleForegroundMessage(message);
    } else {
      // Show local notification for other types
      await _showLocalNotification(notification);
    }
  }

  /// Show call notification with high priority for incoming calls (1:1)
  Future<void> _showCallNotification(
      AppNotification notification, Map<String, dynamic> data) async {
    final callerName = data['callerName'] ?? notification.displayTitle;
    final callType = data['callType'] ?? 'voice';
    final callId = data['callId'] ?? '';
    final callerId = data['callerId'] ?? '';
    final callerAvatar = data['callerAvatar'] ?? '';

    AppLogger.i('📞 _showCallNotification called',
        category: LogCategory.general,
        data: {
          'callerName': callerName,
          'callType': callType,
          'callId': callId,
        });

    final callBody = callType == 'video'
        ? '📹 Incoming video call...'
        : '📞 Incoming voice call...';

    // Android notification with action buttons
    final androidDetails = AndroidNotificationDetails(
      'call_notifications_v2',
      'Incoming Calls',
      channelDescription: 'Notifications for incoming voice and video calls',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      timeoutAfter: 60000,
      actions: [
        AndroidNotificationAction(
          _actionAcceptCall,
          '✓ Accept',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _actionRejectCall,
          '✕ Reject',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: 'incoming_call',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use consistent notification ID based on call ID
    final notificationId = callId.hashCode.abs() % 2147483647;

    try {
      await _localNotifications.show(
        notificationId,
        callerName,
        callBody,
        notificationDetails,
        payload:
            'incoming_call:$callId:$callerId:$callerName:$callerAvatar:$callType',
      );

      AppLogger.i(
          '📞 Successfully showed incoming call notification with actions',
          category: LogCategory.general,
          data: {
            'callerName': callerName,
            'notificationId': notificationId,
            'callBody': callBody
          });
    } catch (e, stack) {
      AppLogger.e('📞 Failed to show call notification',
          category: LogCategory.general, error: e, stackTrace: stack);
    }
  }

  /// Public method to show group call notification from foreground handler
  /// Called by StartupService when a group_call FCM message is received
  Future<void> showGroupCallNotificationFromForeground(
      Map<String, dynamic> data) async {
    await _showGroupCallNotification(data);
  }

  /// Show group call notification with Join/Dismiss actions
  Future<void> _showGroupCallNotification(Map<String, dynamic> data) async {
    final spaceName = data['spaceName'] ?? 'Group';
    final callerName = data['callerName'] ?? 'Someone';
    final spaceId = data['spaceId'] ?? '';
    final participantCount = data['participantCount'] ?? '1';

    AppLogger.i('📞 _showGroupCallNotification called',
        category: LogCategory.general,
        data: {
          'spaceName': spaceName,
          'callerName': callerName,
          'spaceId': spaceId,
        });

    final callBody = '📞 $callerName started a call';

    // Android notification with action buttons
    final androidDetails = AndroidNotificationDetails(
      _groupCallChannelId,
      _groupCallChannelName,
      channelDescription: _groupCallChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      playSound: true,
      enableVibration: true,
      autoCancel: true,
      actions: [
        AndroidNotificationAction(
          _actionJoinGroupCall,
          '📞 Join',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _actionDismissGroupCall,
          'Dismiss',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
      categoryIdentifier: 'group_call',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use consistent notification ID based on space ID
    final notificationId = spaceId.hashCode.abs() % 2147483647;

    try {
      await _localNotifications.show(
        notificationId,
        spaceName,
        callBody,
        notificationDetails,
        payload: 'group_call:$spaceId:$spaceName:$participantCount',
      );

      AppLogger.i('📞 Successfully showed group call notification with actions',
          category: LogCategory.general,
          data: {'spaceName': spaceName, 'callerName': callerName});
    } catch (e, stack) {
      AppLogger.e('📞 Failed to show group call notification',
          category: LogCategory.general, error: e, stackTrace: stack);
    }
  }

  /// Check if notification should be suppressed
  bool _shouldSuppressNotification(AppNotification notification) {
    // Suppress chat notifications if viewing that chat
    if (notification.isChatNotification &&
        notification.spaceId != null &&
        _currentChatSpaceId == notification.spaceId) {
      return true;
    }

    // Suppress astro notifications if on astro page
    if (notification.isAstroNotification &&
        _currentRoute?.contains('insight') == true) {
      return true;
    }

    return false;
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    final notification = _parseRemoteMessage(message);

    AppLogger.d('Notification tapped',
        category: LogCategory.messaging,
        data: {'type': notification.type.value});

    _navigateForNotification(notification);
  }

  /// Handle notification tap with retry for cold starts
  void _handleNotificationTapWithRetry(RemoteMessage message,
      {int attempt = 0}) {
    if (_navigatorKey?.currentState == null) {
      if (attempt < 15) {
        Future.delayed(Duration(milliseconds: 500 + (attempt * 200)), () {
          _handleNotificationTapWithRetry(message, attempt: attempt + 1);
        });
        return;
      }
      AppLogger.e('Failed to handle notification tap after retries',
          category: LogCategory.messaging);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationTap(message);
    });
  }

  /// Handle local notification tap or action button press
  void _handleLocalNotificationTap(NotificationResponse response) {
    // Handle action button presses
    if (response.actionId != null && response.actionId!.isNotEmpty) {
      _handleNotificationAction(response.actionId!, response.payload);
      return;
    }

    if (response.payload == null) return;

    // Handle incoming call notification tap
    if (response.payload!.startsWith('incoming_call:')) {
      _handleIncomingCallTap(response.payload!);
      return;
    }

    // Handle group call notification tap
    if (response.payload!.startsWith('group_call:')) {
      _handleGroupCallTap(response.payload!);
      return;
    }

    final parts = response.payload!.split('|');
    if (parts.isEmpty) return;

    final type = NotificationTypeExtension.fromString(parts[0]);

    switch (type) {
      case NotificationType.chat:
      case NotificationType.message:
        if (parts.length > 1) {
          _navigateToChatWithRetry(parts[1]);
        }
        break;
      case NotificationType.dailyAstroInsight:
        // Parse cardIndex and insightDate from payload
        int? cardIndex;
        String? insightDate;
        if (parts.length > 1 && parts[1].isNotEmpty) {
          cardIndex = int.tryParse(parts[1]);
        }
        if (parts.length > 2 && parts[2].isNotEmpty) {
          insightDate = parts[2];
        }
        _navigateToDailyInsight(cardIndex: cardIndex, insightDate: insightDate);
        break;
      case NotificationType.reply:
      case NotificationType.like:
      case NotificationType.newSpacePost:
        if (parts.length > 2) {
          _navigateToPost(parts[1], parts[2]); // spaceId, postId
        }
        break;
      case NotificationType.namaste:
        if (parts.length > 1) {
          _navigateToProfile(parts[1]); // userId
        }
        break;
      case NotificationType.invite:
        _navigateToInvites();
        break;
      case NotificationType.request:
        if (parts.length > 1) {
          _navigateToRequests(parts[1]); // spaceId
        }
        break;
      case NotificationType.addedToGroup:
        if (parts.length > 1) {
          _navigateToSpace(parts[1]); // spaceId
        }
        break;
      case NotificationType.follow:
      case NotificationType.followAccepted:
      case NotificationType.followRequest:
      case NotificationType.mutualFollow:
        if (parts.length > 1) {
          _navigateToProfile(parts[1]); // userId
        }
        break;
      case NotificationType.anonymousMessage:
        _navigateToSecretMessagesInbox();
        break;
      default:
        break;
    }
  }

  /// Parse RemoteMessage to AppNotification
  AppNotification _parseRemoteMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);

    // Add notification title/body to data if present
    if (message.notification != null) {
      data['title'] = message.notification!.title;
      data['preview'] = message.notification!.body;
    }

    // Generate ID from message
    data['id'] =
        message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();
    data['timestamp'] = Timestamp.now();

    return AppNotification.fromMap(data);
  }

  /// Show local notification based on type
  Future<void> _showLocalNotification(AppNotification notification) async {
    final channelId = _getChannelIdForType(notification.type);
    final channelName = _getChannelNameForType(notification.type);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(notification.displayBody),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Create payload for tap handling
    final payload = _createPayloadForNotification(notification);

    await _localNotifications.show(
      notification.id.hashCode,
      notification.displayTitle,
      notification.displayBody,
      details,
      payload: payload,
    );
  }

  /// Get Android channel ID for notification type
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

  /// Get Android channel name for notification type
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

  /// Create payload string for local notification
  String _createPayloadForNotification(AppNotification notification) {
    final parts = <String>[notification.type.value];

    switch (notification.type) {
      case NotificationType.chat:
      case NotificationType.message:
        if (notification.spaceId != null) parts.add(notification.spaceId!);
        break;
      case NotificationType.reply:
      case NotificationType.like:
      case NotificationType.newSpacePost:
        if (notification.spaceId != null) parts.add(notification.spaceId!);
        if (notification.postId != null) parts.add(notification.postId!);
        break;
      case NotificationType.namaste:
        if (notification.authorId != null) parts.add(notification.authorId!);
        break;
      case NotificationType.request:
      case NotificationType.addedToGroup:
        if (notification.spaceId != null) parts.add(notification.spaceId!);
        break;
      case NotificationType.dailyAstroInsight:
        // Include cardIndex and insightId (date) for deep linking
        parts.add(notification.cardIndex?.toString() ?? '');
        parts.add(notification.insightId ?? notification.date ?? '');
        break;
      case NotificationType.follow:
      case NotificationType.followRequest:
      case NotificationType.followAccepted:
      case NotificationType.mutualFollow:
        // Include the userId of the person who followed/requested
        // authorId is mapped from fromUserId by the backend
        final userId =
            notification.authorId ?? notification.data['fromUserId'] as String?;
        if (userId != null) parts.add(userId);
        break;
      case NotificationType.anonymousMessage:
        if (notification.data['messageId'] != null) {
          parts.add(notification.data['messageId'].toString());
        }
        break;
      default:
        break;
    }

    return parts.join('|');
  }

  /// Navigate based on notification type
  void _navigateForNotification(AppNotification notification) {
    switch (notification.type) {
      case NotificationType.chat:
      case NotificationType.message:
        if (notification.spaceId != null) {
          _navigateToChatWithRetry(notification.spaceId!);
        }
        break;
      case NotificationType.dailyAstroInsight:
        _navigateToDailyInsight(
          cardIndex: notification.cardIndex,
          insightDate: notification.insightId ?? notification.date,
        );
        break;
      case NotificationType.reply:
      case NotificationType.like:
      case NotificationType.newSpacePost:
        if (notification.spaceId != null) {
          _navigateToPost(notification.spaceId!, notification.postId);
        }
        break;
      case NotificationType.namaste:
        if (notification.authorId != null) {
          _navigateToProfile(notification.authorId!);
        }
        break;
      case NotificationType.invite:
        _navigateToInvites();
        break;
      case NotificationType.request:
        if (notification.spaceId != null) {
          _navigateToRequests(notification.spaceId!);
        }
        break;
      case NotificationType.addedToGroup:
        if (notification.spaceId != null) {
          _navigateToSpace(notification.spaceId!);
        }
        break;
      case NotificationType.follow:
      case NotificationType.followAccepted:
      case NotificationType.mutualFollow:
        // Navigate to the profile of the user who followed/is now friends
        // authorId is from FCM data, fromUserId is from Firestore
        final userId = notification.authorId ??
            notification.data['fromUserId'] as String? ??
            notification.data['authorId'] as String?;
        if (userId != null) {
          _navigateToProfile(userId);
        }
        break;
      case NotificationType.followRequest:
        // Navigate to the requestor's profile
        // authorId is from FCM data, fromUserId is from Firestore
        final requestorId = notification.authorId ??
            notification.data['fromUserId'] as String? ??
            notification.data['authorId'] as String?;
        if (requestorId != null) {
          _navigateToProfile(requestorId);
        }
        break;
      case NotificationType.anonymousMessage:
        _navigateToSecretMessagesInbox();
        break;
      default:
        break;
    }
  }

  void _navigateToSecretMessagesInbox() {
    if (_navigatorKey?.currentState == null) return;
    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (context) => const SecretMessagesInboxScreen(),
      ),
    );
  }

  // Navigation helpers
  void _navigateToChatWithRetry(String spaceId, {int attempt = 0}) {
    if (_navigatorKey?.currentState == null) {
      if (attempt < 10) {
        Future.delayed(Duration(milliseconds: 500 * (attempt + 1)), () {
          _navigateToChatWithRetry(spaceId, attempt: attempt + 1);
        });
      }
      return;
    }

    final chatService = ChatNotificationService();
    chatService.setNavigatorKey(_navigatorKey!);

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (context) => SpaceChatScreen(
          spaceId: spaceId,
          space: null,
          otherUserId: spaceId.startsWith('dm_')
              ? spaceId
                  .split('_')
                  .where((id) => id != _currentUser?.uid)
                  .firstOrNull
              : null,
        ),
      ),
    );
  }

  void _navigateToDailyInsight({
    int attempt = 0,
    int? cardIndex,
    String? insightDate,
  }) {
    final userId = _currentUser?.uid;
    if (userId == null) return;

    if (_navigatorKey?.currentState == null) {
      if (attempt < 5) {
        Future.delayed(Duration(milliseconds: 500 * (attempt + 1)), () {
          _navigateToDailyInsight(
            attempt: attempt + 1,
            cardIndex: cardIndex,
            insightDate: insightDate,
          );
        });
      }
      return;
    }

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (_) => DailyInsightPage(
          uid: userId,
          highlightCardIndex: cardIndex,
          insightDate: insightDate,
        ),
      ),
    );
  }

  void _navigateToPost(String spaceId, String? postId) {
    if (_navigatorKey?.currentState == null) return;
    if (postId != null && postId.isNotEmpty) {
      _navigatorKey!.currentState!.push(
        MaterialPageRoute(
          builder: (_) => ThreadView(postId: postId),
        ),
      );
    } else {
      _navigatorKey!.currentState!.push(
        MaterialPageRoute(
          builder: (_) => SpaceScreen(rid: spaceId),
        ),
      );
    }
  }

  void _navigateToProfile(String userId) {
    if (_navigatorKey?.currentState == null) return;

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(uid: userId),
      ),
    );
  }

  void _navigateToSpace(String spaceId) {
    if (_navigatorKey?.currentState == null) return;

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (_) => SpaceScreen(rid: spaceId),
      ),
    );
  }

  void _navigateToInvites() {
    if (_navigatorKey?.currentState == null) return;

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(builder: (_) => const Invites()),
    );
  }

  void _navigateToRequests(String spaceId) {
    if (_navigatorKey?.currentState == null) return;

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(builder: (_) => const Requests()),
    );
  }

  /// Handle notification action button presses (Accept/Reject calls)
  void _handleNotificationAction(String actionId, String? payload) {
    AppLogger.i('📞 Notification action pressed',
        category: LogCategory.general,
        data: {'actionId': actionId, 'payload': payload});

    // Normalize legacy action IDs from older notification handlers
    final normalizedActionId = switch (actionId) {
      'answer_call' => _actionAcceptCall,
      'decline_call' => _actionRejectCall,
      _ => actionId,
    };

    switch (normalizedActionId) {
      case _actionAcceptCall:
        if (payload != null && payload.startsWith('incoming_call:')) {
          _handleAcceptCall(payload);
        }
        break;
      case _actionRejectCall:
        if (payload != null && payload.startsWith('incoming_call:')) {
          _handleRejectCall(payload);
        }
        break;
      case _actionJoinGroupCall:
        if (payload != null && payload.startsWith('group_call:')) {
          _handleGroupCallTap(payload);
        }
        break;
      case _actionDismissGroupCall:
        // Just dismiss - do nothing
        AppLogger.d('📞 Group call notification dismissed',
            category: LogCategory.general);
        break;
    }
  }

  /// Handle tapping on incoming call notification
  void _handleIncomingCallTap(String payload) {
    // payload format: incoming_call:callId:callerId:callerName:callerAvatar:callType
    final parts = payload.split(':');
    if (parts.length < 6) return;

    final callId = parts[1];
    final callerName = parts[3];

    AppLogger.i('📞 Incoming call notification tapped',
        category: LogCategory.general,
        data: {'callId': callId, 'callerName': callerName});

    // Accept the call by navigating to call screen
    _handleAcceptCall(payload);
  }

  /// Handle Accept Call action
  void _handleAcceptCall(String payload) {
    // payload format: incoming_call:callId:callerId:callerName:callerAvatar:callType
    final parts = payload.split(':');
    if (parts.length < 6) return;

    final callId = parts[1];
    final callerName = parts[3];

    AppLogger.i('📞 Accepting incoming call',
        category: LogCategory.general,
        data: {'callId': callId, 'callerName': callerName});

    // Cancel the notification
    _localNotifications.cancel(callId.hashCode.abs() % 2147483647);

    // The call service should already be listening and will show the incoming call UI
    // The notification tap brings the app to foreground
    AppLogger.i('📞 Bringing app to foreground for call',
        category: LogCategory.general);
  }

  /// Handle Reject Call action
  void _handleRejectCall(String payload) {
    // payload format: incoming_call:callId:callerId:callerName:callerAvatar:callType
    final parts = payload.split(':');
    if (parts.length < 2) return;

    final callId = parts[1];

    AppLogger.i('📞 Rejecting incoming call',
        category: LogCategory.general, data: {'callId': callId});

    // Cancel the notification
    _localNotifications.cancel(callId.hashCode.abs() % 2147483647);

    // Update call status to rejected in Firestore
    _rejectCallInFirestore(callId);
  }

  /// Reject call by updating Firestore
  Future<void> _rejectCallInFirestore(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'rejected',
        'endedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.i('📞 Call rejected in Firestore',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('📞 Failed to reject call in Firestore',
          category: LogCategory.general, error: e);
    }
  }

  /// Handle tapping on group call notification
  void _handleGroupCallTap(String payload, {int retryCount = 0}) {
    // payload format: group_call:spaceId:spaceName:participantCount
    final parts = payload.split(':');
    if (parts.length < 3) {
      AppLogger.w('📞 Invalid group call payload',
          category: LogCategory.general, data: {'payload': payload});
      return;
    }

    final spaceId = parts[1];
    final spaceName = parts[2];

    AppLogger.i('📞 Group call notification tapped - navigating to call',
        category: LogCategory.general,
        data: {
          'spaceId': spaceId,
          'spaceName': spaceName,
          'retryCount': retryCount
        });

    // Cancel the notification
    _localNotifications.cancel(spaceId.hashCode.abs() % 2147483647);

    // Navigate to group call screen with retry
    _navigateToGroupCall(spaceId, spaceName, retryCount: retryCount);
  }

  /// Navigate to group call screen with retry for app startup timing
  void _navigateToGroupCall(String spaceId, String spaceName,
      {int retryCount = 0}) {
    if (_navigatorKey?.currentState == null) {
      if (retryCount < 15) {
        AppLogger.d(
            '📞 Navigator not ready for group call, retrying... (attempt ${retryCount + 1})',
            category: LogCategory.general);
        Future.delayed(Duration(milliseconds: 500 + (retryCount * 200)), () {
          _navigateToGroupCall(spaceId, spaceName, retryCount: retryCount + 1);
        });
        return;
      }
      AppLogger.e(
          '📞 Cannot navigate to group call - navigator not ready after retries',
          category: LogCategory.general);
      return;
    }

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (_) => GroupCallScreen(
          spaceId: spaceId,
          spaceName: spaceName,
        ),
      ),
    );
  }

  // VAPID key for web push notifications
  // Generate this from Firebase Console > Project Settings > Cloud Messaging > Web Push Certificates
  static const String _webVapidKey =
      'YOUR_VAPID_KEY_HERE'; // TODO: Replace with actual VAPID key

  /// Register FCM token with retry for iOS APNs and support for web
  Future<void> _registerFCMToken() async {
    try {
      String? token;

      if (kIsWeb) {
        // Web: Request permission first, then get token with VAPID key
        final permission = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (permission.authorizationStatus == AuthorizationStatus.authorized ||
            permission.authorizationStatus == AuthorizationStatus.provisional) {
          // Note: VAPID key must be configured in Firebase Console
          // If VAPID key is not set, getToken() will still work but without push capability
          try {
            if (_webVapidKey != 'YOUR_VAPID_KEY_HERE') {
              token = await FirebaseMessaging.instance
                  .getToken(
                    vapidKey: _webVapidKey,
                  )
                  .timeout(const Duration(seconds: 30));
            } else {
              // Fallback: try without VAPID key (limited functionality)
              token = await FirebaseMessaging.instance
                  .getToken()
                  .timeout(const Duration(seconds: 30));
              AppLogger.w(
                  'Web FCM: Using token without VAPID key - configure VAPID for full push support',
                  category: LogCategory.messaging);
            }
          } catch (e) {
            AppLogger.e('Web FCM token retrieval failed',
                category: LogCategory.messaging, error: e);
          }
        } else {
          AppLogger.w('Web notification permission denied',
              category: LogCategory.messaging);
          return;
        }
      } else {
        // Mobile: iOS requires APNs token first
        if (PlatformServices.instance.isIOS) {
          String? apnsToken;
          // Try up to 15 times with increasing delays (total ~45 seconds)
          for (int i = 0; i < 15; i++) {
            apnsToken = await FirebaseMessaging.instance.getAPNSToken();
            if (apnsToken != null) {
              AppLogger.d('APNs token obtained on attempt ${i + 1}',
                  category: LogCategory.messaging);
              break;
            }
            // Increasing delay: 1s, 1s, 2s, 2s, 3s, 3s, 4s, 4s, 5s...
            await Future.delayed(Duration(seconds: (i ~/ 2) + 1));
          }

          if (apnsToken == null) {
            AppLogger.e(
                'APNs token not available after 15 attempts - iOS push notifications will NOT work!',
                category: LogCategory.messaging);
            // Still try to get FCM token anyway - it might work in some cases
          }
        }

        token = await FirebaseMessaging.instance
            .getToken()
            .timeout(const Duration(seconds: 30));
      }

      if (token != null) {
        await _saveTokenToFirestore(token);
        AppLogger.i(
            'FCM token registered successfully${kIsWeb ? ' (web)' : ''}',
            category: LogCategory.messaging);
      } else {
        AppLogger.e('FCM token is null', category: LogCategory.messaging);
      }
    } catch (e) {
      AppLogger.e('FCM token registration failed',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Force register FCM token - call this if token wasn't registered initially
  Future<void> forceRegisterToken() async {
    await _registerFCMToken();
  }

  /// Save FCM token to Firestore (supports multi-device)
  Future<void> _saveTokenToFirestore(String token) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc = _firestore.collection('users').doc(uid);
      final snapshot = await userDoc.get();

      if (snapshot.exists) {
        final existingTokens =
            (snapshot.data()?['fcmTokens'] as List<dynamic>?)?.cast<String>() ??
                [];

        if (!existingTokens.contains(token)) {
          await userDoc.update({
            'fcmToken': token,
            'fcmTokens': FieldValue.arrayUnion([token]),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          AppLogger.d('FCM token registered', category: LogCategory.messaging);
        } else {
          await userDoc.update({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await userDoc.set({
          'fcmToken': token,
          'fcmTokens': [token],
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        AppLogger.d('FCM token saved', category: LogCategory.messaging);
      }
    } catch (e) {
      AppLogger.e('FCM token save failed',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Start listening to unread notification count
  void _startUnreadCountListener() {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    _firestore
        .collection('notifications')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      _unreadCount = snapshot.docs.length;
      _unreadCountController.add(_unreadCount);
    });
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore
          .collection('notifications')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      AppLogger.e('Failed to mark notification as read',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    try {
      final batch = _firestore.batch();
      final unread = await _firestore
          .collection('notifications')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
    } catch (e) {
      AppLogger.e('Failed to mark all notifications as read',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Delete old notifications (older than 30 days)
  Future<void> cleanupOldNotifications() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final batch = _firestore.batch();

      final oldNotifications = await _firestore
          .collection('notifications')
          .doc(uid)
          .collection('notifications')
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      for (final doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      AppLogger.d(
          'Cleaned up ${oldNotifications.docs.length} old notifications',
          category: LogCategory.messaging);
    } catch (e) {
      AppLogger.e('Failed to cleanup old notifications',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Update current route for smart notification filtering
  void setCurrentRoute(String? route) {
    _currentRoute = route;
  }

  /// Update current chat space for notification suppression
  void setCurrentChatSpace(String? spaceId) {
    _currentChatSpaceId = spaceId;
  }

  /// Clear current chat space when leaving chat
  void clearCurrentChatSpace() {
    _currentChatSpaceId = null;
  }

  /// Diagnostic method to check notification setup status
  /// Returns a map with diagnostic info for debugging
  Future<Map<String, dynamic>> runDiagnostics() async {
    final diagnostics = <String, dynamic>{};

    try {
      // Check platform
      if (kIsWeb) {
        diagnostics['platform'] = 'Web';
      } else {
        diagnostics['platform'] =
            PlatformServices.instance.isIOS ? 'iOS' : 'Android';
      }

      // Check permission status
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      diagnostics['permissionStatus'] = settings.authorizationStatus.toString();
      diagnostics['permissionGranted'] =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      // Check APNs token (iOS only)
      if (!kIsWeb && PlatformServices.instance.isIOS) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        diagnostics['apnsToken'] = apnsToken != null
            ? '${apnsToken.substring(0, 20)}...'
            : 'NULL - APNs not working!';
        diagnostics['hasApnsToken'] = apnsToken != null;
      }

      // Check FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      diagnostics['fcmToken'] =
          fcmToken != null ? '${fcmToken.substring(0, 20)}...' : 'NULL';
      diagnostics['hasFcmToken'] = fcmToken != null;

      // Check if token is saved in Firestore
      final uid = _currentUser?.uid;
      if (uid != null && fcmToken != null) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final userData = userDoc.data();
        final savedTokens =
            (userData?['fcmTokens'] as List<dynamic>?)?.cast<String>() ?? [];
        final legacyToken = userData?['fcmToken'] as String?;

        diagnostics['tokenInFirestore'] =
            savedTokens.contains(fcmToken) || legacyToken == fcmToken;
        diagnostics['savedTokenCount'] = savedTokens.length;
        diagnostics['hasLegacyToken'] = legacyToken != null;
      }

      diagnostics['initialized'] = _initialized;
      diagnostics['permissionsRequested'] = _permissionsRequested;
      diagnostics['userId'] = uid ?? 'NOT LOGGED IN';
    } catch (e) {
      diagnostics['error'] = e.toString();
    }

    AppLogger.i('🔔 Notification Diagnostics: $diagnostics',
        category: LogCategory.messaging);
    return diagnostics;
  }

  /// Force re-register the FCM token (for debugging/fixing)
  Future<bool> forceReRegisterToken() async {
    try {
      AppLogger.i('🔔 Force re-registering FCM token...',
          category: LogCategory.messaging);
      await _registerFCMToken();
      return true;
    } catch (e) {
      AppLogger.e('🔔 Force re-register failed: $e',
          category: LogCategory.messaging);
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationStreamController.close();
    _unreadCountController.close();
  }
}

/// Background notification handler (must be top-level)
/// Note: This is called when user taps notification from background
/// The app will be brought to foreground and then navigation can happen
@pragma('vm:entry-point')
void _backgroundNotificationHandler(NotificationResponse response) {
  // Log for debugging
  if (kDebugMode) {
    AppLogger.d(
      'Background notification tapped',
      category: LogCategory.messaging,
      data: {'payload': response.payload, 'actionId': response.actionId},
    );
  }

  // Store the response for when the app fully initializes
  // The NotificationService._checkInitialNotification will pick this up
  _pendingBackgroundNotification = response;
}

/// Pending notification from background tap - checked on app initialization
NotificationResponse? _pendingBackgroundNotification;
