import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'package:aurogram/platform/flutter_local_notifications_stub.dart';
import 'package:aurogram/shared/models/notification.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/chat/domain/chat_notification_service.dart';

import '../notification_service.dart';

/// Handles incoming FCM and local notifications: foreground display,
/// call notifications, suppression logic, parsing, and action-button handling.
extension NotificationHandler on NotificationService {
  // ── FCM setup ─────────────────────────────────────────────────────────────

  /// Set up FCM message handlers.
  void setupFCMHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background/terminated tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check for initial message (app opened from terminated state)
    _checkInitialMessage();
  }

  /// Check if app was opened via notification from terminated state.
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

  /// Check if app was launched via a local notification tap.
  Future<void> _checkLocalNotificationLaunch() async {
    try {
      final launchDetails =
          await localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchDetails?.notificationResponse != null) {
        final payload = launchDetails!.notificationResponse!.payload ?? '';
        final actionId = launchDetails.notificationResponse!.actionId;

        AppLogger.i('App launched via local notification',
            category: LogCategory.messaging,
            data: {'payload': payload, 'actionId': actionId});

        // Handle with retry since navigator might not be ready
        Future.delayed(const Duration(milliseconds: 500), () {
          handleLocalNotificationTap(launchDetails.notificationResponse!);
        });
      }
    } catch (e) {
      AppLogger.w('Error checking local notification launch: $e',
          category: LogCategory.messaging);
    }
  }

  /// Check for pending background notification and handle it.
  void _checkPendingBackgroundNotification() {
    if (pendingBackgroundNotification != null) {
      AppLogger.i('Processing pending background notification',
          category: LogCategory.messaging,
          data: {'payload': pendingBackgroundNotification!.payload});

      // Handle after a short delay to ensure app is fully initialized
      Future.delayed(const Duration(milliseconds: 500), () {
        if (pendingBackgroundNotification != null) {
          handleLocalNotificationTap(pendingBackgroundNotification!);
          pendingBackgroundNotification = null;
        }
      });
    }
  }

  // ── Foreground message handling ───────────────────────────────────────────

  /// Handle foreground FCM message.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = _parseRemoteMessage(message);

    // Check if app is truly in foreground (visible to user)
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isAppInForeground = lifecycleState == AppLifecycleState.resumed;

    AppLogger.i('FCM message received in NotificationService',
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
            'Skipping call notification - app in foreground, CallService handles it',
            category: LogCategory.general);
        return;
      } else {
        AppLogger.i('Showing call notification - app is backgrounded',
            category: LogCategory.general);
        await _showCallNotification(notification, message.data);
        return;
      }
    }

    // For group call notifications - always show (even in foreground for grams)
    if (notification.isGroupCallNotification) {
      AppLogger.i('Showing group call notification',
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
    notificationStreamController.add(notification);

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

  // ── Call notifications ────────────────────────────────────────────────────

  /// Show call notification with high priority for incoming calls (1:1).
  Future<void> _showCallNotification(
      AppNotification notification, Map<String, dynamic> data) async {
    final callerName = data['callerName'] ?? notification.displayTitle;
    final callType = data['callType'] ?? 'voice';
    final callId = data['callId'] ?? '';
    final callerId = data['callerId'] ?? '';
    final callerAvatar = data['callerAvatar'] ?? '';

    AppLogger.i('_showCallNotification called',
        category: LogCategory.general,
        data: {
          'callerName': callerName,
          'callType': callType,
          'callId': callId,
        });

    final callBody = callType == 'video'
        ? 'Incoming video call...'
        : 'Incoming voice call...';

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
          NotificationChannels.actionAcceptCall,
          'Accept',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          NotificationChannels.actionRejectCall,
          'Reject',
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
      await localNotifications.show(
        notificationId,
        callerName,
        callBody,
        notificationDetails,
        payload:
            'incoming_call:$callId:$callerId:$callerName:$callerAvatar:$callType',
      );

      AppLogger.i(
          'Successfully showed incoming call notification with actions',
          category: LogCategory.general,
          data: {
            'callerName': callerName,
            'notificationId': notificationId,
            'callBody': callBody
          });
    } catch (e, stack) {
      AppLogger.e('Failed to show call notification',
          category: LogCategory.general, error: e, stackTrace: stack);
    }
  }

  /// Public method to show group call notification from foreground handler.
  /// Called by StartupService when a group_call FCM message is received.
  // ignore: unused_element
  Future<void> showGroupCallNotificationFromForeground(
      Map<String, dynamic> data) async {
    await _showGroupCallNotification(data);
  }

  /// Show group call notification with Join/Dismiss actions.
  Future<void> _showGroupCallNotification(Map<String, dynamic> data) async {
    final spaceName = data['spaceName'] ?? 'Group';
    final callerName = data['callerName'] ?? 'Someone';
    final spaceId = data['spaceId'] ?? '';
    final participantCount = data['participantCount'] ?? '1';

    AppLogger.i('_showGroupCallNotification called',
        category: LogCategory.general,
        data: {
          'spaceName': spaceName,
          'callerName': callerName,
          'spaceId': spaceId,
        });

    final callBody = '$callerName started a call';

    // Android notification with action buttons
    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.groupCallChannelId,
      NotificationChannels.groupCallChannelName,
      channelDescription: NotificationChannels.groupCallChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      playSound: true,
      enableVibration: true,
      autoCancel: true,
      actions: [
        AndroidNotificationAction(
          NotificationChannels.actionJoinGroupCall,
          'Join',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          NotificationChannels.actionDismissGroupCall,
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
      await localNotifications.show(
        notificationId,
        spaceName,
        callBody,
        notificationDetails,
        payload: 'group_call:$spaceId:$spaceName:$participantCount',
      );

      AppLogger.i('Successfully showed group call notification with actions',
          category: LogCategory.general,
          data: {'spaceName': spaceName, 'callerName': callerName});
    } catch (e, stack) {
      AppLogger.e('Failed to show group call notification',
          category: LogCategory.general, error: e, stackTrace: stack);
    }
  }

  // ── Suppression logic ─────────────────────────────────────────────────────

  /// Check if notification should be suppressed.
  bool _shouldSuppressNotification(AppNotification notification) {
    // Suppress chat notifications if viewing that chat
    if (notification.isChatNotification &&
        notification.spaceId != null &&
        currentChatSpaceId == notification.spaceId) {
      return true;
    }

    // Suppress astro notifications if on astro page
    if (notification.isAstroNotification &&
        currentRoute?.contains('insight') == true) {
      return true;
    }

    return false;
  }

  // ── Notification tap handling ─────────────────────────────────────────────

  /// Handle notification tap.
  void _handleNotificationTap(RemoteMessage message) {
    final notification = _parseRemoteMessage(message);

    AppLogger.d('Notification tapped',
        category: LogCategory.messaging,
        data: {'type': notification.type.value});

    navigateForNotification(notification);
  }

  /// Handle notification tap with retry for cold starts.
  void _handleNotificationTapWithRetry(RemoteMessage message,
      {int attempt = 0}) {
    if (navigatorKey?.currentState == null) {
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

  /// Handle local notification tap or action button press.
  void handleLocalNotificationTap(NotificationResponse response) {
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
          navigateToChatWithRetry(parts[1]);
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
        navigateToDailyInsight(cardIndex: cardIndex, insightDate: insightDate);
        break;
      case NotificationType.reply:
      case NotificationType.like:
      case NotificationType.newSpacePost:
        if (parts.length > 2) {
          navigateToPost(parts[1], parts[2]); // spaceId, postId
        }
        break;
      case NotificationType.namaste:
        if (parts.length > 1) {
          navigateToProfile(parts[1]); // userId
        }
        break;
      case NotificationType.invite:
        navigateToInvites();
        break;
      case NotificationType.request:
        if (parts.length > 1) {
          navigateToRequests(parts[1]); // spaceId
        }
        break;
      case NotificationType.addedToGroup:
        if (parts.length > 1) {
          navigateToSpace(parts[1]); // spaceId
        }
        break;
      case NotificationType.follow:
      case NotificationType.followAccepted:
      case NotificationType.followRequest:
      case NotificationType.mutualFollow:
        if (parts.length > 1) {
          navigateToProfile(parts[1]); // userId
        }
        break;
      case NotificationType.anonymousMessage:
        navigateToSecretMessagesInbox();
        break;
      default:
        break;
    }
  }

  // ── Parsing ───────────────────────────────────────────────────────────────

  /// Parse RemoteMessage to AppNotification.
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

  // ── Local notification display ────────────────────────────────────────────

  /// Show local notification based on type.
  Future<void> _showLocalNotification(AppNotification notification) async {
    final channelId = getChannelIdForType(notification.type);
    final channelName = getChannelNameForType(notification.type);

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

    await localNotifications.show(
      notification.id.hashCode,
      notification.displayTitle,
      notification.displayBody,
      details,
      payload: payload,
    );
  }

  /// Create payload string for local notification.
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

  // ── Action button handling ────────────────────────────────────────────────

  /// Handle notification action button presses (Accept/Reject calls).
  void _handleNotificationAction(String actionId, String? payload) {
    AppLogger.i('Notification action pressed',
        category: LogCategory.general,
        data: {'actionId': actionId, 'payload': payload});

    // Normalize legacy action IDs from older notification handlers
    final normalizedActionId = switch (actionId) {
      'answer_call' => NotificationChannels.actionAcceptCall,
      'decline_call' => NotificationChannels.actionRejectCall,
      _ => actionId,
    };

    switch (normalizedActionId) {
      case NotificationChannels.actionAcceptCall:
        if (payload != null && payload.startsWith('incoming_call:')) {
          _handleAcceptCall(payload);
        }
        break;
      case NotificationChannels.actionRejectCall:
        if (payload != null && payload.startsWith('incoming_call:')) {
          _handleRejectCall(payload);
        }
        break;
      case NotificationChannels.actionJoinGroupCall:
        if (payload != null && payload.startsWith('group_call:')) {
          _handleGroupCallTap(payload);
        }
        break;
      case NotificationChannels.actionDismissGroupCall:
        // Just dismiss - do nothing
        AppLogger.d('Group call notification dismissed',
            category: LogCategory.general);
        break;
    }
  }

  /// Handle tapping on incoming call notification.
  void _handleIncomingCallTap(String payload) {
    // payload format: incoming_call:callId:callerId:callerName:callerAvatar:callType
    final parts = payload.split(':');
    if (parts.length < 6) return;

    final callId = parts[1];
    final callerName = parts[3];

    AppLogger.i('Incoming call notification tapped',
        category: LogCategory.general,
        data: {'callId': callId, 'callerName': callerName});

    // Accept the call by navigating to call screen
    _handleAcceptCall(payload);
  }

  /// Handle Accept Call action.
  void _handleAcceptCall(String payload) {
    // payload format: incoming_call:callId:callerId:callerName:callerAvatar:callType
    final parts = payload.split(':');
    if (parts.length < 6) return;

    final callId = parts[1];
    final callerName = parts[3];

    AppLogger.i('Accepting incoming call',
        category: LogCategory.general,
        data: {'callId': callId, 'callerName': callerName});

    // Cancel the notification
    localNotifications.cancel(callId.hashCode.abs() % 2147483647);

    AppLogger.i('Bringing app to foreground for call',
        category: LogCategory.general);
  }

  /// Handle Reject Call action.
  void _handleRejectCall(String payload) {
    // payload format: incoming_call:callId:callerId:callerName:callerAvatar:callType
    final parts = payload.split(':');
    if (parts.length < 2) return;

    final callId = parts[1];

    AppLogger.i('Rejecting incoming call',
        category: LogCategory.general, data: {'callId': callId});

    // Cancel the notification
    localNotifications.cancel(callId.hashCode.abs() % 2147483647);

    // Update call status to rejected in Firestore
    _rejectCallInFirestore(callId);
  }

  /// Reject call by updating Firestore.
  Future<void> _rejectCallInFirestore(String callId) async {
    try {
      await firestore.collection('calls').doc(callId).update({
        'status': 'rejected',
        'endedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.i('Call rejected in Firestore', category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Failed to reject call in Firestore',
          category: LogCategory.general, error: e);
    }
  }

  /// Handle tapping on group call notification.
  void _handleGroupCallTap(String payload, {int retryCount = 0}) {
    // payload format: group_call:spaceId:spaceName:participantCount
    final parts = payload.split(':');
    if (parts.length < 3) {
      AppLogger.w('Invalid group call payload',
          category: LogCategory.general, data: {'payload': payload});
      return;
    }

    final spaceId = parts[1];
    final spaceName = parts[2];

    AppLogger.i('Group call notification tapped - navigating to call',
        category: LogCategory.general,
        data: {
          'spaceId': spaceId,
          'spaceName': spaceName,
          'retryCount': retryCount
        });

    // Cancel the notification
    localNotifications.cancel(spaceId.hashCode.abs() % 2147483647);

    // Navigate to group call screen with retry
    navigateToGroupCall(spaceId, spaceName, retryCount: retryCount);
  }
}
