import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/firebase_options.dart';
import 'package:aurogram/platform/platform.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'package:aurogram/platform/flutter_local_notifications_stub.dart';

/// Firebase Messaging background handler
/// Must be a top-level function (not a class method)
/// This is called for DATA-ONLY FCM messages when app is in background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed (for background isolate)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    AppLogger.d(
      'Background FCM received',
      category: LogCategory.messaging,
      data: {'type': message.data['type'], 'data': message.data},
    );
  }

  final type = message.data['type'];

  // Handle incoming call notifications in background
  if (type == 'incoming_call') {
    await showIncomingCallNotification(message);
  }

  // Handle group call notifications in background
  if (type == 'group_call') {
    await showGroupCallNotification(message);
  }
}

/// Generate a consistent notification ID from call ID for proper cancellation
int getNotificationIdForCall(String callId) {
  // Use a consistent hash of the call ID to generate notification ID
  // This allows us to cancel the notification later when call ends
  return callId.hashCode.abs() % 2147483647; // Keep within 32-bit int range
}

/// Show incoming call notification when app is in background
/// This ensures the user sees a high-priority notification for calls
/// NOTE: This function is only called on mobile platforms (guarded by kIsWeb check)
@pragma('vm:entry-point')
Future<void> showIncomingCallNotification(RemoteMessage message) async {
  // Skip on web - local notifications not supported
  if (kIsWeb) return;

  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  // Initialize local notifications (needed in background isolate)
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await localNotifications.initialize(initSettings);

  // CRITICAL: Create the notification channel in background isolate
  // Android requires channel to exist before showing notification
  // Using v2 channel to ensure fresh creation with action support
  // Check platform safely for web compatibility
  final isAndroid = !kIsWeb && PlatformServices.instance.isAndroid;
  if (isAndroid) {
    final androidPlugin =
        localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'call_notifications_v2',
          'Incoming Calls',
          description: 'Notifications for incoming voice and video calls',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }
  }

  final data = message.data;
  final callId = data['callId'] ?? '';
  final callerName = data['callerName'] ?? data['title'] ?? 'Someone';
  final callBody = data['body'] ??
      (data['callType'] == 'video'
          ? '📹 Incoming video call...'
          : '📞 Incoming voice call...');

  // Create action buttons for answer and decline
  // These allow users to respond directly from the notification
  const answerAction = AndroidNotificationAction(
    'answer_call',
    '✓ Answer',
    showsUserInterface: true, // Opens app when tapped
    cancelNotification: true,
    contextual: false,
  );

  const declineAction = AndroidNotificationAction(
    'decline_call',
    '✕ Decline',
    showsUserInterface: true, // Must open app to properly handle decline
    cancelNotification: true,
    contextual: false,
  );

  // Android notification details - high priority for calls with action buttons
  const androidDetails = AndroidNotificationDetails(
    'call_notifications_v2', // New channel ID to force recreation with actions
    'Incoming Calls',
    channelDescription: 'Notifications for incoming voice and video calls',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.call,
    fullScreenIntent: true,
    ongoing: true, // Keep notification visible until handled
    autoCancel: false, // Don't auto-cancel, let actions handle it
    visibility: NotificationVisibility.public,
    playSound: true,
    enableVibration: true,
    timeoutAfter: 60000, // 60 second timeout (matches call service timeout)
    actions: <AndroidNotificationAction>[
      answerAction,
      declineAction
    ], // Action buttons
  );

  // iOS notification details with category for actions
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
    categoryIdentifier:
        'incoming_call', // iOS notification category for actions
  );

  final notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  // Use consistent notification ID based on call ID for later cancellation
  final notificationId = getNotificationIdForCall(callId);

  // Show the notification with actions
  await localNotifications.show(
    notificationId,
    callerName,
    callBody,
    notificationDetails,
    payload:
        'incoming_call:$callId:${data['callerId']}:$callerName:${data['callerAvatar'] ?? ''}:${data['callType'] ?? 'voice'}',
  );

  if (kDebugMode) {
    AppLogger.d(
      'Background: showed incoming call notification',
      category: LogCategory.messaging,
      data: {'callerName': callerName, 'notificationId': notificationId},
    );
  }
}

/// Show group call notification when app is in background
/// This ensures the user sees a notification with Join/Dismiss actions
/// NOTE: This function is only called on mobile platforms (guarded by kIsWeb check)
@pragma('vm:entry-point')
Future<void> showGroupCallNotification(RemoteMessage message) async {
  // Skip on web - local notifications not supported
  if (kIsWeb) return;

  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  // Initialize local notifications (needed in background isolate)
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await localNotifications.initialize(initSettings);

  // Create the notification channel in background isolate
  // Check platform safely for web compatibility
  final isAndroid = !kIsWeb && PlatformServices.instance.isAndroid;
  if (isAndroid) {
    final androidPlugin =
        localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'group_calls',
          'Group Calls',
          description: 'Notifications for group calls in grams',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }
  }

  final data = message.data;
  final spaceId = data['spaceId'] ?? '';
  final spaceName = data['spaceName'] ?? data['title'] ?? 'Group';
  final callerName = data['callerName'] ?? 'Someone';
  final participantCount = data['participantCount'] ?? '1';
  final callBody = data['body'] ?? '📞 $callerName started a group call';

  // Create action buttons for Join and Dismiss
  const joinAction = AndroidNotificationAction(
    'join_group_call',
    '📞 Join',
    showsUserInterface: true, // Opens app when tapped
    cancelNotification: true,
  );

  const dismissAction = AndroidNotificationAction(
    'dismiss_group_call',
    'Dismiss',
    showsUserInterface: false,
    cancelNotification: true,
  );

  // Android notification details with action buttons
  const androidDetails = AndroidNotificationDetails(
    'group_calls',
    'Group Calls',
    channelDescription: 'Notifications for group calls in grams',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.call,
    autoCancel: true,
    playSound: true,
    enableVibration: true,
    actions: <AndroidNotificationAction>[joinAction, dismissAction],
  );

  // iOS notification details with category for actions
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

  // Show the notification with actions
  await localNotifications.show(
    notificationId,
    spaceName,
    callBody,
    notificationDetails,
    payload: 'group_call:$spaceId:$spaceName:$participantCount',
  );

  if (kDebugMode) {
    AppLogger.d(
      'Background: showed group call notification',
      category: LogCategory.messaging,
      data: {'spaceName': spaceName, 'notificationId': notificationId},
    );
  }
}
