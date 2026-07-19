import 'dart:async';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/services/deep_link_service.dart';
import 'package:aurogram/shared/services/media/audio_service.dart';
import 'package:aurogram/features/chat/domain/chat_notification_service.dart';
import 'package:aurogram/features/calling/domain/call_service.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/core/routing/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'package:aurogram/platform/flutter_local_notifications_stub.dart';
import 'package:aurogram/platform/platform.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

/// Static callback for background notification tap.
/// Must be a top-level function.
@pragma('vm:entry-point')
@pragma('vm:entry-point')
void onBackgroundNotificationTapped(NotificationResponse response) {
  if (kDebugMode) {
    AppLogger.d(
      'Background notification tapped',
      category: LogCategory.messaging,
      data: {'payload': response.payload, 'actionId': response.actionId},
    );
  }
}

// =============================================================================
// STARTUP SERVICES: FCM, local notifications, deep links, messaging handlers
// =============================================================================

/// Handles FCM setup, local notifications, deep links, and message routing.
/// Mixed into [StartupService].
mixin StartupServicesMixin {
  // Legacy call notification handling is disabled to avoid duplicate flows.
  static const bool _enableLegacyCallNotifications = false;

  // Local notifications for foreground notifications
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _localNotificationsInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize local notifications for foreground display.
  Future<void> initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: const [],
      );

      final initialized = await _localNotifications.initialize(
        InitializationSettings(android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse:
            onBackgroundNotificationTapped,
      );

      _localNotificationsInitialized = initialized ?? false;

      await _checkInitialLocalNotification();
    } catch (e) {
      AppLogger.w('Local notifications init failed',
          category: LogCategory.messaging, data: {'error': e.toString()});
    }
  }

  /// Check if app was launched from a local notification.
  Future<void> _checkInitialLocalNotification() async {
    try {
      final launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchDetails?.notificationResponse != null) {
        final payload = launchDetails!.notificationResponse!.payload ?? '';
        final actionId = launchDetails.notificationResponse!.actionId;

        AppLogger.i('📱 App launched from local notification',
            category: LogCategory.messaging,
            data: {'payload': payload, 'actionId': actionId});

        if (_enableLegacyCallNotifications &&
            payload.startsWith('incoming_call:')) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            _handleIncomingCallNotificationTap(payload, actionId: actionId);
          });
        } else if (payload.startsWith('group_call:')) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            _handleGroupCallLocalNotificationTap(payload, actionId: actionId);
          });
        }
      }
    } catch (e) {
      AppLogger.w('Failed to check initial notification',
          category: LogCategory.messaging, data: {'error': e.toString()});
    }
  }

  /// Handle group call local notification tap from launch.
  void _handleGroupCallLocalNotificationTap(String payload,
      {String? actionId}) {
    if (actionId == 'dismiss_group_call') {
      AppLogger.d('📞 Group call notification dismissed',
          category: LogCategory.messaging);
      return;
    }

    final parts = payload.split(':');
    if (parts.length < 3) {
      AppLogger.w('Invalid group call payload',
          category: LogCategory.messaging, data: {'payload': payload});
      return;
    }

    final spaceId = parts[1];
    final spaceName = parts.length > 2 ? parts[2] : 'Group Call';

    _handleGroupCallNotificationTap(
      {'spaceId': spaceId, 'spaceName': spaceName},
      _navigatorKey!,
    );
  }

  /// Handle notification tap.
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload ?? '';
    final actionId = response.actionId;

    if (payload == 'dailyAstroInsight') {
      _navigateToDailyInsight();
    } else if (_enableLegacyCallNotifications &&
        payload.startsWith('incoming_call:')) {
      _handleIncomingCallNotificationTap(payload, actionId: actionId);
    }
  }

  /// Handle incoming call notification tap or action button press.
  void _handleIncomingCallNotificationTap(String payload, {String? actionId}) {
    final parts = payload.split(':');
    if (parts.length < 6) {
      AppLogger.w('Invalid incoming call payload',
          category: LogCategory.messaging);
      return;
    }

    final callId = parts[1];
    final callerId = parts[2];
    final callerName = parts[3];
    final callerAvatar = parts[4].isNotEmpty ? parts[4] : null;
    final callType = parts[5];

    if (actionId == 'decline_call') {
      _handleDeclineCallFromNotification(callId);
      return;
    }

    if (actionId == 'answer_call') {
      _navigateToIncomingCall(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        callType: callType,
        autoAnswer: true,
      );
      return;
    }

    _navigateToIncomingCall(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      callType: callType,
    );
  }

  /// Handle decline call action from notification.
  Future<void> _handleDeclineCallFromNotification(String callId) async {
    try {
      await cancelCallNotification(callId);

      final callService = CallService();
      if (callService.state == CallState.incoming &&
          callService.currentCall?.id == callId) {
        await callService.rejectCall();
      } else {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .update({
          'status': 'rejected',
          'endedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      AppLogger.e('Failed to decline call from notification',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Navigate to incoming call screen with validation.
  Future<void> _navigateToIncomingCall({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerAvatar,
    required String callType,
    int retryCount = 0,
    bool autoAnswer = false,
  }) async {
    if (_navigatorKey?.currentState == null) {
      if (retryCount < 10) {
        Future.delayed(Duration(milliseconds: 300 * (retryCount + 1)), () {
          _navigateToIncomingCall(
            callId: callId,
            callerId: callerId,
            callerName: callerName,
            callerAvatar: callerAvatar,
            callType: callType,
            retryCount: retryCount + 1,
            autoAnswer: autoAnswer,
          );
        });
      }
      return;
    }

    final isCallValid = await _validateCallStatus(callId);
    if (!isCallValid) {
      await cancelCallNotification(callId);
      _showCallEndedMessage();
      return;
    }

    final call = Call(
      id: callId,
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      calleeId: FirebaseAuth.instance.currentUser?.uid ?? '',
      calleeName: '',
      type: callType == 'video' ? CallType.video : CallType.voice,
      createdAt: DateTime.now(),
      status: 'ringing',
    );

    final callService = CallService();
    if (callService.state == CallState.idle &&
        callService.currentCall == null) {
      callService.setupIncomingCall(call);
    }

    await cancelCallNotification(callId);

    if (autoAnswer) {
      appRouter.push(RouteNames.callScreen, extra: {
        'calleeId': callerId,
        'calleeName': callerName,
        'calleeAvatar': callerAvatar,
        'callType': callType == 'video' ? CallType.video : CallType.voice,
        'isIncoming': true,
      });
    } else {
      appRouter.push(RouteNames.incomingCall, extra: call);
    }
  }

  /// Validate if call is still valid in Firestore.
  Future<bool> _validateCallStatus(String callId) async {
    try {
      final callDoc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(callId)
          .get();

      if (!callDoc.exists) return false;

      final status = callDoc.data()?['status'] as String?;
      return status == 'ringing';
    } catch (e) {
      return false;
    }
  }

  /// Show a brief message when user tries to answer an ended call.
  void _showCallEndedMessage() {
    final context = _navigatorKey?.currentContext;
    if (context != null) {
      showCustomSnackBar(context,
          message: 'This call has ended',
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating);
    }
  }

  /// Cancel incoming call notification by call ID.
  static Future<void> cancelCallNotification(String callId) async {
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      final notificationId = _getNotificationIdForCall(callId);
      await localNotifications.cancel(notificationId);
    } catch (e) {
      AppLogger.w('Failed to cancel call notification',
          category: LogCategory.messaging, data: {'error': e.toString()});
    }
  }

  static int _getNotificationIdForCall(String callId) {
    return callId.hashCode.abs() % 2147483647;
  }

  /// Navigate to daily insight page with retry.
  void _navigateToDailyInsight({
    int retryCount = 0,
    String? insightDate,
  }) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    if (_navigatorKey?.currentState == null) {
      if (retryCount < 5) {
        Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)), () {
          _navigateToDailyInsight(
            retryCount: retryCount + 1,
            insightDate: insightDate,
          );
        });
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        appRouter.push(RouteNames.dailyInsight, extra: {
          'uid': userId,
          'insightDate': insightDate,
        });
      } catch (e, stack) {
        AppLogger.e('Navigation error',
            category: LogCategory.messaging, error: e, stackTrace: stack);
      }
    });
  }

  /// Show local notification (for foreground display).
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_localNotificationsInitialized) {
      await initializeLocalNotifications();
    }

    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'general_channel',
          'General Notifications',
          channelDescription: 'General app notifications',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      AppLogger.e('🔔 Local notification error',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Set up Firebase Messaging WITHOUT requesting permissions.
  Future<void> setupFirebaseMessaging(
      GlobalKey<NavigatorState> navigatorKey) async {
    if (kIsWeb) return;

    try {
      _navigatorKey = navigatorKey;

      await initializeLocalNotifications();

      FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenToFirestore);

      _tryRegisterExistingToken();

      final chatNotificationService = ChatNotificationService();
      chatNotificationService.initialize();
      chatNotificationService.setNavigatorKey(navigatorKey);

      FirebaseMessaging.onMessage.listen((message) => _handleForegroundMessage(
          message, chatNotificationService, navigatorKey));

      FirebaseMessaging.onMessageOpenedApp.listen((message) =>
          _handleMessageTap(message, chatNotificationService, navigatorKey));

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationWithRetry(
            initialMessage, chatNotificationService, navigatorKey);
      }
    } catch (e, stack) {
      AppLogger.e('🔔 FCM setup error',
          category: LogCategory.messaging, error: e, stackTrace: stack);
    }
  }

  /// Handle foreground FCM messages.
  void _handleForegroundMessage(
      RemoteMessage message,
      ChatNotificationService chatService,
      GlobalKey<NavigatorState> navigatorKey) {
    final type = message.data['type'];

    switch (type) {
      case 'chat':
      case 'message':
        chatService.handleForegroundMessage(message);
        break;
      case 'incoming_call':
        if (_enableLegacyCallNotifications) {
          _handleIncomingCallNotification(message, navigatorKey);
        }
        break;
      case 'group_call':
        return;
      case 'dailyAstroInsight':
        showLocalNotification(
          title: message.notification?.title ?? 'Your Daily Insight 🌟',
          body: message.notification?.body ??
              'Your daily astrology insight is ready.',
          payload: 'dailyAstroInsight',
        );
        break;
      case 'follow':
      case 'followRequest':
      case 'followAccepted':
        if (message.notification != null &&
            navigatorKey.currentContext != null) {
          final userId = message.data['authorId'] as String? ??
              message.data['fromUserId'] as String?;
          showCupertinoDialog(
            context: navigatorKey.currentContext!,
            builder: (context) => CupertinoAlertDialog(
              title: Text(message.notification!.title ?? 'Notification'),
              content: Text(message.notification!.body ?? ''),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Dismiss'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                if (userId != null)
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    child: const Text('View Profile'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      appRouter.push('${RouteNames.userProfile}/$userId');
                    },
                  ),
              ],
            ),
          );
        }
        break;
      case 'mutualFollow':
        if (message.notification != null &&
            navigatorKey.currentContext != null) {
          final userId = message.data['authorId'] as String? ??
              message.data['fromUserId'] as String?;
          showCupertinoDialog(
            context: navigatorKey.currentContext!,
            builder: (context) => CupertinoAlertDialog(
              title:
                  Text(message.notification!.title ?? 'You\'re Now Friends!'),
              content: Text(message.notification!.body ?? ''),
              actions: [
                if (userId != null) ...[
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    child: const Text('See Compatibility'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      appRouter.push('${RouteNames.userProfile}/$userId');
                    },
                  ),
                  CupertinoDialogAction(
                    child: const Text('See Profile'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      appRouter.push('${RouteNames.userProfile}/$userId');
                    },
                  ),
                ],
                CupertinoDialogAction(
                  child: const Text('Dismiss'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        }
        break;
      default:
        if (message.notification != null &&
            navigatorKey.currentContext != null) {
          showCupertinoDialog(
            context: navigatorKey.currentContext!,
            builder: (context) => CupertinoAlertDialog(
              title: Text(message.notification!.title ?? 'Notification'),
              content: Text(message.notification!.body ?? ''),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        }
    }
  }

  /// Handle incoming call notification (foreground).
  void _handleIncomingCallNotification(
      RemoteMessage message, GlobalKey<NavigatorState> navigatorKey) {
    final data = message.data;
    final callId = data['callId'] as String?;
    final callerId = data['callerId'] as String?;
    final callerName = data['callerName'] as String? ?? 'Someone';
    final callerAvatar = data['callerAvatar'] as String?;
    final callType = data['callType'] as String? ?? 'voice';

    if (callId == null || callerId == null) return;

    final callService = CallService();
    if (callService.state == CallState.incoming &&
        callService.currentCall?.id == callId) {
      return;
    }

    if (navigatorKey.currentState != null) {
      final call = Call(
        id: callId,
        callerId: callerId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        calleeId: FirebaseAuth.instance.currentUser?.uid ?? '',
        calleeName: '',
        type: callType == 'video' ? CallType.video : CallType.voice,
        createdAt: DateTime.now(),
        status: 'ringing',
      );

      appRouter.push(RouteNames.incomingCall, extra: call);
    }
  }

  /// Handle notification tap (background or terminated state).
  void _handleMessageTap(
      RemoteMessage message,
      ChatNotificationService chatService,
      GlobalKey<NavigatorState> navigatorKey) {
    final type = message.data['type'];

    if (type == 'chat' || type == 'message') {
      chatService.handleBackgroundMessageTap(message);
    } else if (type == 'incoming_call') {
      if (_enableLegacyCallNotifications) {
        _handleIncomingCallNotification(message, navigatorKey);
      }
    } else if (type == 'group_call') {
      _handleGroupCallNotificationTap(message.data, navigatorKey);
    } else {
      _handleNotificationNavigation(message.data, navigatorKey);
    }
  }

  /// Handle group call notification tap.
  void _handleGroupCallNotificationTap(
      Map<String, dynamic> data, GlobalKey<NavigatorState> navigatorKey,
      {int retryCount = 0}) {
    final spaceId = data['spaceId'] as String?;
    final spaceName = data['spaceName'] as String? ?? 'Group Call';

    if (spaceId == null) return;

    if (navigatorKey.currentState == null) {
      if (retryCount < 15) {
        Future.delayed(Duration(milliseconds: 500 + (retryCount * 200)), () {
          _handleGroupCallNotificationTap(data, navigatorKey,
              retryCount: retryCount + 1);
        });
        return;
      }
      return;
    }

    appRouter.push(
      '${RouteNames.groupCall}/$spaceId',
      extra: {'spaceName': spaceName},
    );
  }

  /// Handle notification with retry mechanism for cold start.
  void _handleNotificationWithRetry(
      RemoteMessage message,
      ChatNotificationService chatService,
      GlobalKey<NavigatorState> navigatorKey,
      {int attempt = 0}) {
    if (navigatorKey.currentState == null) {
      if (attempt < 15) {
        Future.delayed(Duration(milliseconds: 500 + (attempt * 200)), () {
          _handleNotificationWithRetry(message, chatService, navigatorKey,
              attempt: attempt + 1);
        });
        return;
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleMessageTap(message, chatService, navigatorKey);
    });
  }

  /// Save FCM token to Firestore (multi-device support).
  Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
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
      }
    } catch (e) {
      AppLogger.e('🔔 Token save failed',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Try to register existing FCM token if permissions already granted.
  Future<void> _tryRegisterExistingToken() async {
    if (kIsWeb) return;

    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      if (!kIsWeb && PlatformServices.instance.isIOS) {
        String? apnsToken;
        for (int i = 0; i < 5; i++) {
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 10));

      if (token != null && token.isNotEmpty) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      AppLogger.e('Failed to proactively register FCM token',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Set up deep linking and related services.
  Future<void> setupDynamicLinks(GlobalKey<NavigatorState> navigatorKey) async {
    try {
      await DeepLinkService().initialize();
      await AudioService().initialize();
      AppLogger.i('Deep links ready', category: LogCategory.general);
    } catch (e, stack) {
      AppLogger.e('Deep links setup error',
          category: LogCategory.general, error: e, stackTrace: stack);
    }
  }

  /// Handle navigation based on notification type.
  void _handleNotificationNavigation(
      Map<String, dynamic> data, GlobalKey<NavigatorState> navigatorKey) {
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'dailyAstroInsight':
        final insightDate =
            data['date'] as String? ?? data['insightId'] as String?;
        _navigateToDailyInsight(insightDate: insightDate);
        break;
    }
  }
}
