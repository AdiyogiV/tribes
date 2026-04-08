import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'package:aurogram/platform/flutter_local_notifications_stub.dart';
import 'package:aurogram/models/notification.dart';
import 'package:aurogram/core/config/app_config.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/chat/domain/chat_notification_service.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/core/routing/page_factory.dart';
import 'package:aurogram/platform/platform.dart';

part 'notification/notification_channels.dart';
part 'notification/notification_tokens.dart';
part 'notification/notification_handler.dart';
part 'notification/notification_navigation.dart';

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

  // Getters
  User? get _currentUser => _auth.currentUser;
  Stream<AppNotification> get notificationStream =>
      _notificationStreamController.stream;
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  int get unreadCount => _unreadCount;

  // Track if permissions have been requested
  bool _permissionsRequested = false;

  /// Initialize the notification service WITHOUT requesting permissions.
  /// Permissions should be requested later at a contextual moment.
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;

    _navigatorKey = navigatorKey;

    try {
      // Initialize local notifications with channels
      await _initializeLocalNotifications();

      // Set up FCM handlers (work even without permission)
      _setupFCMHandlers();

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenToFirestore);

      // Start listening to unread count
      _startUnreadCountListener();

      _initialized = true;
      AppLogger.i('NotificationService initialized (permissions deferred)',
          category: LogCategory.messaging);

      // Check if permissions already granted and register token proactively
      _checkAndRegisterExistingPermissions();
    } catch (e, stack) {
      AppLogger.e('NotificationService initialization failed',
          category: LogCategory.messaging, error: e, stackTrace: stack);
    }
  }

  /// Check if permissions are already granted and register token if so.
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
        _permissionsRequested = true;

        // Register token in background to not block initialization
        unawaited(_registerFCMToken());
      } else if (kIsWeb) {
        AppLogger.i(
            'Web: Permissions not granted, will request when appropriate',
            category: LogCategory.messaging);

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
        AppLogger.i('Android: Permissions not granted, requesting proactively',
            category: LogCategory.messaging);

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

  /// Request notification permissions at a contextual moment.
  /// Returns true if permission was granted.
  Future<bool> requestPermissions({bool showRationale = true}) async {
    if (_permissionsRequested) {
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
        await _registerFCMToken();
      }

      return granted;
    } catch (e, stack) {
      AppLogger.e('Failed to request notification permissions',
          category: LogCategory.messaging, error: e, stackTrace: stack);
      return false;
    }
  }

  /// Check if notification permissions have been granted (without prompting).
  Future<bool> hasPermission() async {
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      AppLogger.w('Error checking notification permission: $e',
          category: LogCategory.messaging);
      return false;
    }
  }

  /// Check if permissions have been requested before.
  bool get permissionsRequested => _permissionsRequested;

  /// Update current route for smart notification filtering.
  void setCurrentRoute(String? route) {
    _currentRoute = route;
  }

  /// Update current chat space for notification suppression.
  void setCurrentChatSpace(String? spaceId) {
    _currentChatSpaceId = spaceId;
  }

  /// Clear current chat space when leaving chat.
  void clearCurrentChatSpace() {
    _currentChatSpaceId = null;
  }

  /// Dispose resources.
  void dispose() {
    _notificationStreamController.close();
    _unreadCountController.close();
  }
}

/// Background notification handler (must be top-level).
@pragma('vm:entry-point')
void _backgroundNotificationHandler(NotificationResponse response) {
  if (kDebugMode) {
    AppLogger.d(
      'Background notification tapped',
      category: LogCategory.messaging,
      data: {'payload': response.payload, 'actionId': response.actionId},
    );
  }

  // Store the response for when the app fully initializes
  _pendingBackgroundNotification = response;
}

/// Pending notification from background tap - checked on app initialization.
NotificationResponse? _pendingBackgroundNotification;
