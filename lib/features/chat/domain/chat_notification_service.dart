import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:aurogram/features/feed/data/datasources/space_db_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/chat/presentation/widgets/in_app_chat_notification.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/core/routing/page_factory.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';

class ChatNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SpaceDbService _spaceDbService = SpaceDbService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Track last notification time per space to prevent spam
  final Map<String, DateTime> _lastNotificationTime = {};

  // Global navigator key for navigation
  GlobalKey<NavigatorState>? _navigatorKey;

  // Notification overlay state
  BuildContext? _overlayContext;

  // **NEW**: Track currently active chat to suppress notifications
  static String? _currentActiveChatSpaceId;

  // **NEW**: Track if user is in chat list to still show notifications but maybe different
  static bool _isInChatList = false;

  // Collections
  CollectionReference get _users => _firestore.collection('users');

  static final ChatNotificationService _instance =
      ChatNotificationService._internal();
  factory ChatNotificationService() => _instance;

  ChatNotificationService._internal() {
    _initializeLocalNotifications();
  }

  User? get _currentUser => _auth.currentUser;

  /// Set navigator key for navigation
  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  /// Set overlay context for in-app notifications
  void setOverlayContext(BuildContext context) {
    _overlayContext = context;
  }

  /// **NEW**: Set the currently active chat space ID
  /// Call this when user enters a chat screen
  static void setActiveChat(String? spaceId) {
    _currentActiveChatSpaceId = spaceId;
    AppLogger.d('🔔 Active chat set to: $spaceId',
        category: LogCategory.messaging);
  }

  /// **NEW**: Clear the active chat (call when leaving chat screen)
  static void clearActiveChat() {
    _currentActiveChatSpaceId = null;
    AppLogger.d('🔔 Active chat cleared', category: LogCategory.messaging);
  }

  /// **NEW**: Set if user is viewing chat list
  static void setInChatList(bool isInList) {
    _isInChatList = isInList;
  }

  /// **NEW**: Check if user is currently viewing a specific chat
  static bool isViewingChat(String spaceId) {
    return _currentActiveChatSpaceId == spaceId;
  }

  /// **NEW**: Check if user is in chat list view
  static bool get isInChatListView => _isInChatList;

  /// Initialize local notifications for chat
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
  }

  /// Handle notification tap - navigate to chat
  void _handleNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final spaceId = response.payload!;
      AppLogger.i('🔔 Local notification tapped',
          category: LogCategory.messaging, data: {'spaceId': spaceId});
      _navigateToChatWithRetry(spaceId);
    }
  }

  /// Navigate to chat screen
  Future<void> _navigateToChat(String spaceId) async {
    try {
      AppLogger.i('🔔 _navigateToChat called',
          category: LogCategory.messaging, data: {'spaceId': spaceId});

      if (_navigatorKey?.currentContext == null) {
        AppLogger.w('🔔 Navigator context not available',
            category: LogCategory.messaging);
        return;
      }

      final context = _navigatorKey!.currentContext!;
      final chatService = SpaceChatService();
      final isDM = chatService.isDirectMessage(spaceId);

      AppLogger.i('🔔 Getting conversation info',
          category: LogCategory.messaging,
          data: {'isDM': isDM, 'spaceId': spaceId});

      String? otherUserId;
      dynamic space;

      if (isDM) {
        // For DMs, we don't need to fetch from spaces collection
        // Just get the other user ID from the conversation ID
        otherUserId = chatService.getOtherUserId(spaceId);
        AppLogger.i('🔔 DM conversation, otherUserId: $otherUserId',
            category: LogCategory.messaging);

        // Create a minimal space object for the chat screen
        // The chat screen will handle fetching user details
        space = null; // SpaceChatScreen can handle null space for DMs
      } else {
        // For group chats, fetch the space info
        space = await _spaceDbService.getSpace(spaceId);
      }

      AppLogger.i('🔔 Navigating to chat screen',
          category: LogCategory.messaging,
          data: {'spaceId': spaceId, 'isDM': isDM, 'otherUserId': otherUserId});

      // Navigate to chat screen
      Navigator.of(context).push(
        PageFactory.route(RouteNames.spaceChatScreen, arguments: {
          'spaceId': spaceId,
          'space': space,
          'otherUserId': otherUserId,
        }),
      );

      AppLogger.i('🔔 Navigation successful', category: LogCategory.messaging);
    } catch (e, stack) {
      AppLogger.e('🔔 Error navigating to chat',
          category: LogCategory.messaging, error: e, stackTrace: stack);
    }
  }

  /// Send chat notification (in-app only - push notifications are handled by backend)
  /// This method is now only for showing in-app notifications when the user is viewing another chat
  Future<void> sendChatNotification({
    required String spaceId,
    required String senderId,
    required String senderName,
    required String messageContent,
    required String messageType,
  }) async {
    try {
      // Don't send notifications for own messages
      if (_currentUser?.uid == senderId) return;

      // **IMPROVED**: Check if user is currently viewing this chat
      if (isViewingChat(spaceId)) {
        AppLogger.d('🔔 Suppressing notification - user viewing this chat',
            category: LogCategory.messaging, data: {'spaceId': spaceId});
        return;
      }

      // Rate limiting: Don't send more than 1 notification per 3 seconds per space
      final now = DateTime.now();
      final lastNotification = _lastNotificationTime[spaceId];
      if (lastNotification != null &&
          now.difference(lastNotification).inSeconds < 3) {
        return;
      }

      // Get space name for notification
      String spaceName = 'Chat';
      String? spaceAvatar;

      final chatService = SpaceChatService();
      if (!chatService.isDirectMessage(spaceId)) {
        try {
          final space = await _spaceDbService.getSpace(spaceId);
          spaceName = space.name ?? 'Chat';
          spaceAvatar = space.displayPicture;
        } catch (e) {
          AppLogger.w('Failed to get space for notification',
              category: LogCategory.messaging,
              data: {'spaceId': spaceId, 'error': e.toString()});
        }
      } else {
        spaceName = senderName;
      }

      // Get sender avatar
      String? senderAvatar;
      try {
        final senderDoc = await _users.doc(senderId).get();
        final senderData = senderDoc.data() as Map<String, dynamic>?;
        senderAvatar = senderData?['displayPicture'] as String?;
      } catch (e) {
        AppLogger.w('Failed to get sender avatar for notification',
            category: LogCategory.messaging,
            data: {'senderId': senderId, 'error': e.toString()});
      }

      // Show in-app notification only (backend handles push notifications)
      await _showInAppNotification(
        title: spaceName,
        body: _formatNotificationBody(senderName, messageContent, messageType),
        avatarUrl: senderAvatar ?? spaceAvatar,
        spaceId: spaceId,
      );

      // Update last notification time
      _lastNotificationTime[spaceId] = now;
    } catch (e) {
      AppLogger.e('Error showing in-app chat notification',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Show in-app notification banner
  Future<void> _showInAppNotification({
    required String title,
    required String body,
    String? avatarUrl,
    required String spaceId,
  }) async {
    try {
      // **IMPROVED**: Double check we're not viewing this chat
      if (isViewingChat(spaceId)) {
        AppLogger.d('🔔 Suppressing in-app notification - user in chat',
            category: LogCategory.messaging);
        return;
      }

      if (_overlayContext == null) {
        // Fallback to local notification if overlay context not available
        await _showLocalNotification(
          title: title,
          body: body,
          spaceId: spaceId,
        );
        return;
      }

      final overlayState = ChatNotificationOverlay.of(_overlayContext!);
      if (overlayState != null) {
        overlayState.showNotification(
          title: title,
          body: body,
          avatarUrl: avatarUrl,
          spaceId: spaceId,
          onTap: () => _navigateToChat(spaceId),
        );
      } else {
        // Fallback to local notification
        await _showLocalNotification(
          title: title,
          body: body,
          spaceId: spaceId,
        );
      }
    } catch (e) {
      AppLogger.e('Error showing in-app notification',
          category: LogCategory.messaging, error: e);
      // Fallback to local notification
      await _showLocalNotification(
        title: title,
        body: body,
        spaceId: spaceId,
      );
    }
  }

  /// Format notification body based on message type
  String _formatNotificationBody(
      String senderName, String content, String messageType) {
    switch (messageType) {
      case 'text':
        // Truncate long messages
        final displayContent =
            content.length > 50 ? '${content.substring(0, 50)}...' : content;
        return '$senderName: $displayContent';
      case 'image':
        return '$senderName sent a photo';
      case 'video':
        return '$senderName sent a video';
      case 'audio':
        return '$senderName sent an audio message';
      case 'file':
        return '$senderName sent a file';
      default:
        return '$senderName sent a message';
    }
  }

  /// Handle FCM foreground message
  Future<void> handleForegroundMessage(RemoteMessage message) async {
    try {
      final data = message.data;
      final notification = message.notification;

      if (data['type'] != 'chat' && data['type'] != 'message') {
        return; // Not a chat notification
      }

      final spaceId = data['spaceId'] as String?;
      final senderName =
          notification?.title ?? data['senderName'] as String? ?? 'Someone';
      final messageContent =
          notification?.body ?? data['messageContent'] as String? ?? '';
      final messageType = data['messageType'] as String? ?? 'text';
      final senderAvatar = data['senderAvatar'] as String?;

      if (spaceId == null) return;

      // **IMPROVED**: Check if viewing this chat
      if (isViewingChat(spaceId)) {
        AppLogger.d('🔔 Suppressing foreground message - user in chat',
            category: LogCategory.messaging, data: {'spaceId': spaceId});
        return;
      }

      // Show in-app notification
      await _showInAppNotification(
        title: senderName,
        body: _formatNotificationBody(senderName, messageContent, messageType),
        avatarUrl: senderAvatar,
        spaceId: spaceId,
      );
    } catch (e) {
      AppLogger.e('Error handling foreground message',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Handle FCM background message tap
  Future<void> handleBackgroundMessageTap(RemoteMessage message) async {
    try {
      final data = message.data;
      final spaceId = data['spaceId'] as String?;

      AppLogger.i('🔔 Chat notification tapped',
          category: LogCategory.messaging,
          data: {'spaceId': spaceId, 'data': data.toString()});

      if (spaceId != null) {
        // Use retry mechanism since navigator might not be ready yet
        _navigateToChatWithRetry(spaceId);
      } else {
        AppLogger.w('🔔 No spaceId in notification data',
            category: LogCategory.messaging);
      }
    } catch (e) {
      AppLogger.e('Error handling background message tap',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Navigate to chat with retry for app startup timing
  void _navigateToChatWithRetry(String spaceId, {int retryCount = 0}) {
    AppLogger.i('🔔 Attempting chat navigation (attempt ${retryCount + 1})',
        category: LogCategory.messaging,
        data: {'spaceId': spaceId, 'hasNavigatorKey': _navigatorKey != null});

    if (_navigatorKey?.currentState == null) {
      if (retryCount < 10) {
        // Retry with increasing delays (500ms, 1s, 1.5s, etc.)
        final delay = Duration(milliseconds: 500 * (retryCount + 1));
        AppLogger.i(
            '🔔 Navigator not ready, retrying in ${delay.inMilliseconds}ms',
            category: LogCategory.messaging);
        Future.delayed(delay, () {
          _navigateToChatWithRetry(spaceId, retryCount: retryCount + 1);
        });
        return;
      } else {
        AppLogger.e('🔔 Navigation failed: navigator not ready after retries',
            category: LogCategory.messaging);
        return;
      }
    }

    _navigateToChat(spaceId);
  }

  /// Show local notification (for background/terminated state)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String spaceId,
  }) async {
    try {
      // Group notifications by space
      final notificationId = spaceId.hashCode;

      final androidDetails = AndroidNotificationDetails(
        'chat_messages',
        'Chat Messages',
        channelDescription: 'Notifications for new chat messages',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        autoCancel: true,
        groupKey: 'chat_messages',
        setAsGroupSummary: false,
        styleInformation: BigTextStyleInformation(body),
        tag: spaceId, // Use spaceId as tag for grouping
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
        threadIdentifier: 'chat_messages',
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: spaceId,
      );
    } catch (e) {
      AppLogger.e('Error showing local notification',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Initialize chat notifications (called at app startup)
  void initialize() {
    AppLogger.i('Chat notification service initialized',
        category: LogCategory.messaging);
    // Push notifications are now handled by backend Cloud Function (onNewChatMessage)
    // This service only handles in-app notifications and navigation
  }

  /// Cleanup resources
  void dispose() {
    _lastNotificationTime.clear();
    _currentActiveChatSpaceId = null;
    _isInChatList = false;
    AppLogger.i('Chat notification service disposed',
        category: LogCategory.messaging);
  }
}
