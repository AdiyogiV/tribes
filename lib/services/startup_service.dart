import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/firebase_options.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/memory/memory_manager.dart';
import 'package:aurogram/utils/config/app_config.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/utils/performance/image_optimizer.dart';
import 'package:aurogram/utils/performance/asset_generator.dart';
import 'package:aurogram/services/deep_link_service.dart';
import 'package:aurogram/services/audio_service.dart';
import 'package:aurogram/services/chat/chat_notification_service.dart';
import 'package:aurogram/services/call_service_export.dart';
import 'package:aurogram/pages/astrology/daily_insight_page.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/pages/call/incoming_call_screen.dart'
    if (dart.library.html) 'package:aurogram/pages/call/incoming_call_screen_stub.dart';
import 'package:aurogram/pages/call/call_screen.dart'
    if (dart.library.html) 'package:aurogram/pages/call/call_screen_stub.dart';
import 'package:aurogram/pages/call/group_call_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'package:aurogram/platform/flutter_local_notifications_stub.dart';
import 'package:aurogram/platform/platform.dart';

/// Static callback for background notification tap.
/// Must be a top-level function.
@pragma('vm:entry-point')
@pragma('vm:entry-point')
void _onBackgroundNotificationTapped(NotificationResponse response) {
  // This is called when app is in background/terminated and notification is tapped
  // Navigation will be handled by _checkInitialLocalNotification when app starts
  if (kDebugMode) {
    AppLogger.d(
      'Background notification tapped',
      category: LogCategory.messaging,
      data: {'payload': response.payload, 'actionId': response.actionId},
    );
  }
}

/// Handles app startup, Firebase initialization, and performance tracking
class StartupService {
  // Legacy call notification handling is disabled to avoid duplicate flows.
  static const bool _enableLegacyCallNotifications = false;
  // Performance tracking
  final DateTime _startTime = DateTime.now();
  DateTime? _firebaseInitTime;
  DateTime? _dependencyInitTime;
  DateTime? _firstFrameTime;
  
  // Local notifications for foreground notifications
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _localNotificationsInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  // Record app startup time
  void recordStartTime() {
    // Already recorded in constructor
  }

  // Record Firebase initialization time
  void recordFirebaseInitTime() {
    _firebaseInitTime = DateTime.now();
  }

  // Record dependency initialization time
  void recordDependencyInitTime() {
    _dependencyInitTime = DateTime.now();
  }

  // Record first frame time
  void recordFirstFrameTime() {
    _firstFrameTime = DateTime.now();
  }

  Duration get totalStartupTime => _firstFrameTime != null
      ? _firstFrameTime!.difference(_startTime)
      : Duration.zero;

  Duration get firebaseInitDuration => _firebaseInitTime != null
      ? _firebaseInitTime!.difference(_startTime)
      : Duration.zero;

  /// Initialize Firebase with more robust error handling and retries
  Future<void> initializeFirebase() async {
    const int maxRetries = 1; // Reduced from 2 to 1 to speed up initialization
    int retryCount = 0;
    bool initialized = false;

    while (!initialized && retryCount <= maxRetries) {
      try {
        if (retryCount > 0) {
          AppLogger.i('Retrying Firebase initialization (attempt $retryCount)',
              category: LogCategory.general);
          await Future.delayed(
              Duration(milliseconds: 500)); // Reduced delay for faster startup
        } else {
          AppLogger.i('Initializing Firebase', category: LogCategory.general);
        }

        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Initialize Crashlytics only in release mode
        if (!kIsWeb && kReleaseMode) {
          await _initializeCrashlytics();
        }

        // Set up analytics only in release mode and defer non-critical setup
        if (kReleaseMode) {
          FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
          // Defer other analytics setup to post-startup
        }

        // Configure Firestore for better performance and reduced memory usage
        _configureFirestore();

        AppLogger.i('Firebase successfully initialized',
            category: LogCategory.general);

        initialized = true;
        recordFirebaseInitTime();
      } catch (e, stack) {
        retryCount++;

        if (retryCount > maxRetries) {
          AppLogger.e('Failed to initialize Firebase after multiple attempts',
              category: LogCategory.general, error: e, stackTrace: stack);

          // Allow app to continue without Firebase in development
          if (kReleaseMode) {
            rethrow; // In release mode, Firebase is required
          }
          break;
        }

        AppLogger.w('Firebase initialization failed, will retry',
            category: LogCategory.general,
            data: {'attempt': retryCount, 'error': e.toString()});
      }
    }
  }

  /// Initialize Crashlytics separately for better error isolation
  Future<void> _initializeCrashlytics() async {
    try {
      // Enable Crashlytics data collection
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      // Pass all uncaught errors to Crashlytics
      FlutterError.onError = (FlutterErrorDetails details) {
        FirebaseCrashlytics.instance.recordFlutterError(details);
      };

      AppLogger.i('Crashlytics initialized', category: LogCategory.general);
    } catch (e) {
      // Continue if Crashlytics fails - this allows the app to work
      // even if error reporting is unavailable
      AppLogger.w('Failed to initialize Crashlytics, continuing without it',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Handle background initialization tasks more efficiently
  Future<void> initializeBackgroundTasks() async {
    try {
      // Run these tasks in parallel for faster startup
      await Future.wait([
        _checkForAppUpdates(),
        _generateAndPreloadAssets(),
      ], eagerError: false);

      AppLogger.i('Background startup tasks completed',
          category: LogCategory.general);
    } catch (e) {
      // Don't let background task failures crash the app
      AppLogger.w('Error during background initialization',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Check if the app has updates available
  Future<void> _checkForAppUpdates() async {
    try {
      if (kIsWeb) {
        // Web platform always has the latest version
        return;
      }

      // Get package info
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Check for app updates using Firebase Remote Config
      final remoteConfig = FirebaseRemoteConfig.instance;
      final latestVersion = remoteConfig.getString('latest_app_version');
      final forceUpdate = remoteConfig.getBool('force_update_required');

      if (latestVersion.isNotEmpty && latestVersion != currentVersion) {
        AppLogger.i('App update available',
            category: LogCategory.general,
            data: {
              'current_version': currentVersion,
              'latest_version': latestVersion,
              'force_update': forceUpdate
            });

        // Store update info to display later
        if (locator.isRegistered<AppConfig>()) {
          final appConfig = locator.get<AppConfig>();
          // Update config values safely using local map to avoid touching private fields
          final Map<String, dynamic> updateInfo = {
            'update_available': true,
            'latest_version': latestVersion,
            'force_update': forceUpdate
          };

          // Store update info safely
          appConfig.storeLocalConfig(updateInfo);
        }
      }
    } catch (e) {
      // Don't crash if update check fails
      AppLogger.w('Failed to check for app updates',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Generate and preload assets
  Future<void> _generateAndPreloadAssets() async {
    try {
      // Generate missing assets first
      await AssetGenerator.generateDefaultAssets();

      // Then preload critical assets
      await _preloadCriticalAssets();
    } catch (e) {
      AppLogger.w('Error during asset generation and preloading',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  /// Preload critical assets in the background
  Future<void> _preloadCriticalAssets() async {
    try {
      if (!locator.isRegistered<AppConfig>()) {
        AppLogger.w('AppConfig not available for asset preloading',
            category: LogCategory.performance);
        return;
      }

      final appConfig = locator.get<AppConfig>();
      final shouldPreload =
          appConfig.getBool('prefetch_assets', defaultValue: true);

      if (!shouldPreload) {
        AppLogger.d('Asset preloading disabled by config',
            category: LogCategory.performance);
        return;
      }

      // Create a list of critical assets to preload with fallbacks
      final criticalAssets = [
        'assets/images/logo.png',
        'assets/images/placeholder.png',
        'assets/images/error.png',
        'assets/images/user.png',
      ];

      // Use the optimized asset preloader to load assets efficiently
      if (locator.isRegistered<MemoryManager>()) {
        try {
          // First check which assets actually exist to avoid errors
          final existingAssets = <String>[];

          for (final asset in criticalAssets) {
            try {
              await rootBundle.load(asset);
              existingAssets.add(asset);
            } catch (e) {
              // Asset doesn't exist, don't add to list
              AppLogger.d('Asset not found during preloading check',
                  category: LogCategory.performance, data: {'asset': asset});
            }
          }

          // Only preload assets that exist
          if (existingAssets.isNotEmpty) {
            await ImageOptimizer.preloadAssetImages(existingAssets);
            AppLogger.d('Preloaded ${existingAssets.length} existing assets',
                category: LogCategory.performance);
          } else {
            AppLogger.w('No assets found to preload',
                category: LogCategory.performance);
          }
        } catch (e) {
          AppLogger.w('Error checking assets during preload',
              category: LogCategory.performance, data: {'error': e.toString()});
        }
      } else {
        AppLogger.w('MemoryManager not available for asset preloading',
            category: LogCategory.performance);
      }

      AppLogger.d('Critical assets preloading completed',
          category: LogCategory.performance);
    } catch (e) {
      // Don't crash if preloading fails
      AppLogger.w('Failed to preload critical assets',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;
    
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS settings - legacy call actions disabled to avoid duplicates
      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: const [],
      );

      final initialized = await _localNotifications.initialize(
        InitializationSettings(android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
      );

      _localNotificationsInitialized = initialized ?? false;
      
      // Check if app was launched from a local notification
      await _checkInitialLocalNotification();
    } catch (e) {
      AppLogger.w('Local notifications init failed', category: LogCategory.messaging, data: {'error': e.toString()});
    }
  }
  
  /// Check if app was launched from a local notification (e.g., incoming call, group call)
  Future<void> _checkInitialLocalNotification() async {
    try {
      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true && 
          launchDetails?.notificationResponse != null) {
        final payload = launchDetails!.notificationResponse!.payload ?? '';
        final actionId = launchDetails.notificationResponse!.actionId;
        
        AppLogger.i('📱 App launched from local notification', 
            category: LogCategory.messaging, 
            data: {'payload': payload, 'actionId': actionId});
        
        // Handle incoming call notification with delay for app to fully initialize
        if (_enableLegacyCallNotifications && payload.startsWith('incoming_call:')) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            _handleIncomingCallNotificationTap(payload, actionId: actionId);
          });
        }
        // Handle group call notification
        else if (payload.startsWith('group_call:')) {
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
  
  /// Handle group call local notification tap from launch
  void _handleGroupCallLocalNotificationTap(String payload, {String? actionId}) {
    // Handle dismiss action
    if (actionId == 'dismiss_group_call') {
      AppLogger.d('📞 Group call notification dismissed', 
          category: LogCategory.messaging);
      return;
    }
    
    // Parse payload: group_call:spaceId:spaceName:participantCount
    final parts = payload.split(':');
    if (parts.length < 3) {
      AppLogger.w('Invalid group call payload', 
          category: LogCategory.messaging, data: {'payload': payload});
      return;
    }
    
    final spaceId = parts[1];
    final spaceName = parts.length > 2 ? parts[2] : 'Group Call';
    
    AppLogger.i('📞 Navigating to group call from notification', 
        category: LogCategory.messaging,
        data: {'spaceId': spaceId, 'spaceName': spaceName, 'actionId': actionId});
    
    // Navigate with retry
    _handleGroupCallNotificationTap(
      {'spaceId': spaceId, 'spaceName': spaceName}, 
      _navigatorKey!,
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload ?? '';
    final actionId = response.actionId;
    
    AppLogger.d('Notification tapped', category: LogCategory.messaging, 
        data: {'payload': payload, 'actionId': actionId});
    
    if (payload == 'dailyAstroInsight') {
      _navigateToDailyInsight();
    } else if (_enableLegacyCallNotifications && payload.startsWith('incoming_call:')) {
      _handleIncomingCallNotificationTap(payload, actionId: actionId);
    }
  }
  
  /// Handle incoming call notification tap or action button press
  void _handleIncomingCallNotificationTap(String payload, {String? actionId}) {
    // Parse payload: incoming_call:callId:callerId:callerName:callerAvatar:callType
    final parts = payload.split(':');
    if (parts.length < 6) {
      AppLogger.w('Invalid incoming call payload', category: LogCategory.messaging);
      return;
    }
    
    final callId = parts[1];
    final callerId = parts[2];
    final callerName = parts[3];
    final callerAvatar = parts[4].isNotEmpty ? parts[4] : null;
    final callType = parts[5];
    
    // Handle action buttons
    if (actionId == 'decline_call') {
      AppLogger.i('📞 User declined call from notification', category: LogCategory.messaging);
      _handleDeclineCallFromNotification(callId);
      return;
    }
    
    if (actionId == 'answer_call') {
      AppLogger.i('📞 User answered call from notification', category: LogCategory.messaging);
      // Navigate to incoming call screen and auto-answer
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
    
    // Regular tap - navigate to incoming call screen
    _navigateToIncomingCall(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      callType: callType,
    );
  }
  
  /// Handle decline call action from notification
  Future<void> _handleDeclineCallFromNotification(String callId) async {
    try {
      // Cancel the notification immediately
      await cancelCallNotification(callId);
      
      final callService = CallService();
      
      // Check if CallService has this call as incoming
      if (callService.state == CallState.incoming && 
          callService.currentCall?.id == callId) {
        await callService.rejectCall();
      } else {
        // Directly update Firestore if CallService doesn't have the call
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .update({
          'status': 'rejected',
          'endedAt': FieldValue.serverTimestamp(),
        });
        AppLogger.i('Rejected call directly via Firestore', category: LogCategory.messaging);
      }
    } catch (e) {
      AppLogger.e('Failed to decline call from notification', 
          category: LogCategory.messaging, error: e);
    }
  }
  
  /// Navigate to incoming call screen with validation
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
      } else {
        AppLogger.e('Failed to navigate to incoming call: navigator not ready', 
            category: LogCategory.messaging);
      }
      return;
    }
    
    // CRITICAL: Validate call status before navigating
    // This prevents showing call screen for cancelled/ended calls
    final isCallValid = await _validateCallStatus(callId);
    if (!isCallValid) {
      AppLogger.w('Call is no longer valid, not showing incoming call screen', 
          category: LogCategory.messaging, data: {'callId': callId});
      
      // Cancel the notification since call is no longer valid
      await cancelCallNotification(callId);
      
      // Show a brief message to the user if app is in foreground
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
    
    // Ensure CallService is aware of this incoming call
    // This is important when navigating from notification tap
    final callService = CallService();
    if (callService.state == CallState.idle && callService.currentCall == null) {
      AppLogger.d('Setting up CallService for incoming call from notification', 
          category: LogCategory.messaging);
      // The CallService will pick this up via its Firestore listener,
      // but we manually set it up to ensure immediate availability
      callService.setupIncomingCall(call);
    }
    
    // Cancel notification since we're handling the call now
    await cancelCallNotification(callId);
    
    // If auto-answering, go directly to call screen
    if (autoAnswer) {
      _navigatorKey?.currentState?.push(
        CupertinoPageRoute(
          builder: (context) => CallScreen(
            calleeId: callerId,
            calleeName: callerName,
            calleeAvatar: callerAvatar,
            callType: callType == 'video' ? CallType.video : CallType.voice,
            isIncoming: true,
          ),
        ),
      );
    } else {
      _navigatorKey?.currentState?.push(
        CupertinoPageRoute(
          builder: (context) => IncomingCallScreen(call: call),
        ),
      );
    }
  }
  
  /// Validate if call is still valid (status == 'ringing') in Firestore
  Future<bool> _validateCallStatus(String callId) async {
    try {
      final callDoc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(callId)
          .get();
      
      if (!callDoc.exists) {
        AppLogger.w('Call document does not exist', 
            category: LogCategory.messaging, data: {'callId': callId});
        return false;
      }
      
      final status = callDoc.data()?['status'] as String?;
      final isValid = status == 'ringing';
      
      AppLogger.d('Call status validation', 
          category: LogCategory.messaging, 
          data: {'callId': callId, 'status': status, 'isValid': isValid});
      
      return isValid;
    } catch (e) {
      AppLogger.e('Failed to validate call status', 
          category: LogCategory.messaging, error: e);
      // On error, return false to be safe (don't show stale call)
      return false;
    }
  }
  
  /// Show a brief message when user tries to answer an ended call
  void _showCallEndedMessage() {
    final context = _navigatorKey?.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This call has ended'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  /// Cancel incoming call notification by call ID
  /// This should be called when call ends, is cancelled, or rejected
  static Future<void> cancelCallNotification(String callId) async {
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      final notificationId = _getNotificationIdForCall(callId);
      await localNotifications.cancel(notificationId);
      AppLogger.d('Cancelled call notification', 
          category: LogCategory.messaging, data: {'callId': callId, 'notificationId': notificationId});
    } catch (e) {
      AppLogger.w('Failed to cancel call notification', 
          category: LogCategory.messaging, data: {'error': e.toString()});
    }
  }
  
  /// Generate consistent notification ID from call ID (matches main.dart)
  static int _getNotificationIdForCall(String callId) {
    return callId.hashCode.abs() % 2147483647;
  }
  
  /// Navigate to daily insight page with retry for app startup timing
  void _navigateToDailyInsight({
    int retryCount = 0,
    int? cardIndex,
    String? insightDate,
  }) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      AppLogger.w('Cannot navigate: user not authenticated', category: LogCategory.messaging);
      return;
    }
    
    // Retry if navigator not ready (up to 5 times with increasing delays)
    if (_navigatorKey?.currentState == null) {
      if (retryCount < 5) {
        Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)), () {
          _navigateToDailyInsight(
            retryCount: retryCount + 1,
            cardIndex: cardIndex,
            insightDate: insightDate,
          );
        });
      } else {
        AppLogger.e('Navigation failed: navigator not ready', category: LogCategory.messaging);
      }
      return;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _navigatorKey?.currentState?.push(
          MaterialPageRoute(
            builder: (_) => DailyInsightPage(
              uid: userId,
              highlightCardIndex: cardIndex,
              insightDate: insightDate,
            ),
          ),
        );
      } catch (e, stack) {
        AppLogger.e('Navigation error', category: LogCategory.messaging, error: e, stackTrace: stack);
      }
    });
  }

  /// Show local notification (for foreground display)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_localNotificationsInitialized) {
      await _initializeLocalNotifications();
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
        title, body, details,
        payload: payload,
      );
    } catch (e) {
      AppLogger.e('🔔 Local notification error', category: LogCategory.messaging, error: e);
    }
  }

  /// Set up Firebase Messaging WITHOUT requesting permissions
  /// Permissions are requested later at a contextual moment via NotificationService.requestPermissions()
  Future<void> setupFirebaseMessaging(
      GlobalKey<NavigatorState> navigatorKey) async {
    if (kIsWeb) {
      AppLogger.i('FCM setup for web - limited functionality',
          category: LogCategory.messaging);
      return;
    }

    try {
      _navigatorKey = navigatorKey;
      
      await _initializeLocalNotifications();
      
      // NOTE: Permission request removed - now handled contextually via NotificationService.requestPermissions()
      // This improves UX by asking for permissions after user has seen value in the app
      AppLogger.d('FCM setup initialized (permissions deferred to contextual moment)', category: LogCategory.messaging);

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenToFirestore);
      
      // Proactively try to register FCM token if permissions already granted
      _tryRegisterExistingToken();

      // Set up chat notifications
      final chatNotificationService = ChatNotificationService();
      chatNotificationService.initialize();
      chatNotificationService.setNavigatorKey(navigatorKey);
      
      // Foreground messages
      FirebaseMessaging.onMessage.listen((message) => _handleForegroundMessage(message, chatNotificationService, navigatorKey));

      // Background tap (app was in background)
      FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleMessageTap(message, chatNotificationService, navigatorKey));

      // Initial message (app opened from terminated state via notification)
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.d('App opened via notification', 
            category: LogCategory.messaging,
            data: {'type': initialMessage.data['type']});
        // Longer delay for cold start - app needs time to fully initialize
        _handleNotificationWithRetry(initialMessage, chatNotificationService, navigatorKey);
      }
    } catch (e, stack) {
      AppLogger.e('🔔 FCM setup error', category: LogCategory.messaging, error: e, stackTrace: stack);
    }
  }

  /// Handle foreground FCM messages
  void _handleForegroundMessage(RemoteMessage message, ChatNotificationService chatService, GlobalKey<NavigatorState> navigatorKey) {
    final type = message.data['type'];
    
    switch (type) {
      case 'chat':
      case 'message':
        chatService.handleForegroundMessage(message);
        break;
      case 'incoming_call':
        // For foreground, CallService already handles via Firestore listener
        // Legacy call notifications are disabled to avoid duplicate flows
        if (_enableLegacyCallNotifications) {
          _handleIncomingCallNotification(message, navigatorKey);
        }
        break;
      case 'group_call':
        // NOTE: NotificationService already handles this via its own FCM listener
        // Don't duplicate here - just log and return
        AppLogger.d('📞 Group call foreground message handled by NotificationService', 
            category: LogCategory.messaging);
        return; // Return early, NotificationService handles this
      case 'dailyAstroInsight':
        _showLocalNotification(
          title: message.notification?.title ?? 'Your Daily Insight 🌟',
          body: message.notification?.body ?? 'Your daily astrology insight is ready.',
          payload: 'dailyAstroInsight',
        );
        break;
      case 'follow':
      case 'followRequest':
      case 'followAccepted':
        // Show dialog with View Profile action
        if (message.notification != null && navigatorKey.currentContext != null) {
          final userId = message.data['authorId'] as String? ?? message.data['fromUserId'] as String?;
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
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => UserProfilePage(uid: userId),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        }
        break;
      case 'mutualFollow':
        // Show dialog with three actions for new friends
        if (message.notification != null && navigatorKey.currentContext != null) {
          final userId = message.data['authorId'] as String? ?? message.data['fromUserId'] as String?;
          showCupertinoDialog(
            context: navigatorKey.currentContext!,
            builder: (context) => CupertinoAlertDialog(
              title: Text(message.notification!.title ?? 'You\'re Now Friends!'),
              content: Text(message.notification!.body ?? ''),
              actions: [
                if (userId != null) ...[
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    child: const Text('See Compatibility'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => UserProfilePage(uid: userId),
                        ),
                      );
                    },
                  ),
                  CupertinoDialogAction(
                    child: const Text('See Profile'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => UserProfilePage(uid: userId),
                        ),
                      );
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
        // Show generic notification dialog
        if (message.notification != null && navigatorKey.currentContext != null) {
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
  
  /// Handle incoming call notification (foreground)
  /// Note: In foreground, CallService's Firestore listener usually handles this
  /// This is a backup to ensure the incoming call screen is shown
  void _handleIncomingCallNotification(RemoteMessage message, GlobalKey<NavigatorState> navigatorKey) {
    final data = message.data;
    final callId = data['callId'] as String?;
    final callerId = data['callerId'] as String?;
    final callerName = data['callerName'] as String? ?? 'Someone';
    final callerAvatar = data['callerAvatar'] as String?;
    final callType = data['callType'] as String? ?? 'voice';
    
    if (callId == null || callerId == null) {
      AppLogger.w('Invalid incoming call notification data', category: LogCategory.messaging);
      return;
    }
    
    // Check if CallService already has this call (Firestore listener may have caught it)
    final callService = CallService();
    if (callService.state == CallState.incoming && callService.currentCall?.id == callId) {
      AppLogger.d('Incoming call already being handled by CallService', category: LogCategory.messaging);
      return;
    }
    
    AppLogger.i('📞 Showing incoming call screen from FCM notification', category: LogCategory.messaging);
    
    // Navigate to incoming call screen
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
      
      navigatorKey.currentState!.push(
        CupertinoPageRoute(
          builder: (context) => IncomingCallScreen(call: call),
        ),
      );
    }
  }

  /// Handle notification tap (background or terminated state)
  void _handleMessageTap(RemoteMessage message, ChatNotificationService chatService, GlobalKey<NavigatorState> navigatorKey) {
    final type = message.data['type'];
    
    AppLogger.i('📱 _handleMessageTap called', 
        category: LogCategory.messaging,
        data: {'type': type, 'data': message.data});
    
    if (type == 'chat' || type == 'message') {
      chatService.handleBackgroundMessageTap(message);
    } else if (type == 'incoming_call') {
      // Legacy call notification taps are disabled to avoid duplicate flows
      if (_enableLegacyCallNotifications) {
        _handleIncomingCallNotification(message, navigatorKey);
      }
    } else if (type == 'group_call') {
      // Handle group call notification tap - navigate to group call screen
      _handleGroupCallNotificationTap(message.data, navigatorKey);
    } else {
      _handleNotificationNavigation(message.data, navigatorKey);
    }
  }
  
  /// Handle group call notification tap - navigate to group call screen
  void _handleGroupCallNotificationTap(Map<String, dynamic> data, GlobalKey<NavigatorState> navigatorKey, {int retryCount = 0}) {
    final spaceId = data['spaceId'] as String?;
    final spaceName = data['spaceName'] as String? ?? 'Group Call';
    
    AppLogger.i('📞 Group call notification tapped', 
        category: LogCategory.messaging,
        data: {'spaceId': spaceId, 'spaceName': spaceName});
    
    if (spaceId == null) {
      AppLogger.w('📞 Invalid group call notification - missing spaceId', 
          category: LogCategory.messaging);
      return;
    }
    
    if (navigatorKey.currentState == null) {
      if (retryCount < 15) {
        AppLogger.d('📞 Navigator not ready, retrying... (attempt ${retryCount + 1})', 
            category: LogCategory.messaging);
        Future.delayed(Duration(milliseconds: 500 + (retryCount * 200)), () {
          _handleGroupCallNotificationTap(data, navigatorKey, retryCount: retryCount + 1);
        });
        return;
      }
      AppLogger.e('📞 Failed to navigate to group call - navigator not ready after retries', 
          category: LogCategory.messaging);
      return;
    }
    
    // Import is at top of file, navigate to group call screen
    navigatorKey.currentState!.push(
      CupertinoPageRoute(
        builder: (_) => GroupCallScreen(
          spaceId: spaceId,
          spaceName: spaceName,
        ),
      ),
    );
  }
  
  /// Handle notification with retry mechanism for cold start
  void _handleNotificationWithRetry(RemoteMessage message, ChatNotificationService chatService, GlobalKey<NavigatorState> navigatorKey, {int attempt = 0}) {
    
    if (navigatorKey.currentState == null) {
      if (attempt < 15) {
        // Retry with increasing delays up to 15 attempts (total ~15 seconds)
        Future.delayed(Duration(milliseconds: 500 + (attempt * 200)), () {
          _handleNotificationWithRetry(message, chatService, navigatorKey, attempt: attempt + 1);
        });
        return;
      }
      AppLogger.e('🔔 Failed to handle notification: navigator not ready after retries', 
          category: LogCategory.messaging);
      return;
    }
    
    // Navigator is ready, handle the tap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleMessageTap(message, chatService, navigatorKey);
    });
  }

  /// Save FCM token to Firestore (multi-device support)
  Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      final snapshot = await userDoc.get();
      
      if (snapshot.exists) {
        final existingTokens = (snapshot.data()?['fcmTokens'] as List<dynamic>?)?.cast<String>() ?? [];
        
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
      AppLogger.e('🔔 Token save failed', category: LogCategory.messaging, error: e);
    }
  }
  
  /// Try to register existing FCM token if permissions already granted
  Future<void> _tryRegisterExistingToken() async {
    if (kIsWeb) return;
    
    try {
      // Check if permissions already granted
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        AppLogger.d('Notification permissions not yet granted, skipping token registration', 
            category: LogCategory.messaging);
        return;
      }
      
      // For iOS, wait for APNs token with LIMITED retries (reduced from 20 to 5)
      // to avoid blocking startup for too long
      if (!kIsWeb && PlatformServices.instance.isIOS) {
        String? apnsToken;
        for (int i = 0; i < 5; i++) {
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken != null) {
            AppLogger.d('APNs token obtained on startup attempt ${i + 1}', 
                category: LogCategory.messaging);
            break;
          }
          // Fixed 500ms delay (reduced from progressive delay)
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        if (apnsToken == null) {
          AppLogger.w('APNs token not available after 5 attempts - will retry later', 
              category: LogCategory.messaging);
          // Continue anyway - FCM might still work, or we'll retry later
        }
      }
      
      // Get and save FCM token with shorter timeout
      final token = await FirebaseMessaging.instance.getToken()
          .timeout(const Duration(seconds: 10));
      
      if (token != null && token.isNotEmpty) {
        await _saveTokenToFirestore(token);
        AppLogger.i('FCM token proactively registered on startup', category: LogCategory.messaging);
      } else {
        AppLogger.w('FCM token is null or empty on startup', category: LogCategory.messaging);
      }
    } catch (e) {
      AppLogger.e('Failed to proactively register FCM token', 
          category: LogCategory.messaging, error: e);
    }
  }

  /// Set up deep linking and related services
  Future<void> setupDynamicLinks(GlobalKey<NavigatorState> navigatorKey) async {
    try {
      // Initialize deep link handling (Universal Links, App Links)
      await DeepLinkService().initialize();
      await AudioService().initialize();
      AppLogger.i('Deep links ready', category: LogCategory.general);
    } catch (e, stack) {
      AppLogger.e('Deep links setup error', category: LogCategory.general, error: e, stackTrace: stack);
    }
  }

  /// Handle navigation based on notification type
  void _handleNotificationNavigation(Map<String, dynamic> data, GlobalKey<NavigatorState> navigatorKey) {
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'dailyAstroInsight':
        // Extract cardIndex and insightDate for deep linking
        final cardIndexStr = data['cardIndex'] as String?;
        final cardIndex = cardIndexStr != null ? int.tryParse(cardIndexStr) : null;
        final insightDate = data['date'] as String? ?? data['insightId'] as String?;
        _navigateToDailyInsight(
          cardIndex: cardIndex,
          insightDate: insightDate,
        );
        break;
      // Chat/message types are handled by ChatNotificationService
      // Add other notification type handlers here as needed
    }
  }


  /// Report startup performance metrics
  void reportStartupPerformance() {
    final total = totalStartupTime.inMilliseconds;
    final firebase = firebaseInitDuration.inMilliseconds;
    final firstFrameToStart =
        _firstFrameTime != null && _firebaseInitTime != null
            ? _firstFrameTime!.difference(_firebaseInitTime!).inMilliseconds
            : 0;

    Map<String, dynamic> performanceData = {
      'total_startup_ms': total,
      'firebase_init_ms': firebase,
      'first_frame_to_start_ms': firstFrameToStart,
    };

    // Get more detailed timing information if available
    if (_dependencyInitTime != null && _firebaseInitTime != null) {
      performanceData['dependency_init_ms'] =
          _dependencyInitTime!.difference(_firebaseInitTime!).inMilliseconds;
    }

    // Log performance statistics
    AppLogger.i('App startup performance',
        category: LogCategory.performance, data: performanceData);

    // Send startup performance analytics
    _sendStartupPerformanceAnalytics(performanceData);
  }

  /// Send startup performance data to analytics
  void _sendStartupPerformanceAnalytics(Map<String, dynamic> performanceData) {
    try {
      if (kReleaseMode) {
        FirebaseAnalytics.instance.logEvent(
          name: 'app_startup_performance',
          parameters: Map<String, Object>.from(performanceData),
        );

        // Send specific timing events
        FirebaseAnalytics.instance.logEvent(
          name: 'app_startup_timing',
          parameters: {
            'timing_name': 'total_startup',
            'timing_ms': performanceData['total_startup_ms'] as int,
          },
        );
      }
    } catch (e) {
      // Don't crash if analytics fails
      AppLogger.w('Failed to send startup performance analytics',
          category: LogCategory.analytics, data: {'error': e.toString()});
    }
  }

  /// Handle app lifecycle changes to manage resources effectively
  Future<void> handleAppLifecycleChange(AppLifecycleState state) async {
    AppLogger.d('App lifecycle state changed to: ${state.toString()}',
        category: LogCategory.general);

    switch (state) {
      case AppLifecycleState.resumed:
        // App is visible and ready to receive user input
        // Restore any resources that were released
        break;
      case AppLifecycleState.inactive:
        // App is inactive but still visible to the user
        // Early resource release to improve transition performance
        if (!kIsWeb && (PlatformServices.instance.isIOS)) {
          // On iOS/macOS, aggressively clean up GPU resources when going inactive
          // This helps prevent Metal drawable errors
          _cleanupMetalResources();
        }
        break;
      case AppLifecycleState.paused:
        // App is not visible to the user (in background)
        // Release resources to improve system performance
        await _releaseResources();
        break;
      case AppLifecycleState.detached:
        // App is detached from any host views
        // On Android, DON'T aggressively clear image caches here - it causes
        // race conditions with Impeller's GPU image decoder and Mali GPU drivers,
        // leading to "pthread_mutex_lock called on destroyed mutex" crashes.
        // The Android OS will handle memory cleanup when the process is killed.
        if (!kIsWeb && PlatformServices.instance.isIOS) {
          await _releaseResources(aggressive: true);
        }
        // On Android and web, just let the process die naturally - no aggressive cleanup
        break;
      default:
        break;
    }
  }

  /// Release resources when app goes to background
  Future<void> _releaseResources({bool aggressive = false}) async {
    try {
      // Clear image cache to reduce memory usage
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Notify memory manager of low memory situation
      if (locator.isRegistered<MemoryManager>()) {
        final memoryManager = locator<MemoryManager>();
        // Use more aggressive cleanup in detached state
        if (aggressive) {
          memoryManager.clearMemoryCaches(cleanupType: CleanupType.aggressive);
        } else {
          memoryManager.clearMemoryCaches();
        }
      }
    } catch (e) {
      AppLogger.w('Error releasing resources',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Special cleanup for Metal resources on iOS/macOS
  void _cleanupMetalResources() {
    try {
      // Reduce image cache size to minimum
      final imageCache = PaintingBinding.instance.imageCache;
      final currentMaxSize = imageCache.maximumSize;

      // Temporarily reduce cache size to force eviction
      imageCache.maximumSize = 10;
      imageCache.clear();

      // Restore original size
      Future.delayed(Duration(milliseconds: 100), () {
        PaintingBinding.instance.imageCache.maximumSize = currentMaxSize;
      });
    } catch (e) {
      AppLogger.w('Error cleaning up Metal resources',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Configure Firestore for optimal performance based on platform
  void _configureFirestore() {
    try {
      // Adjust cache size based on platform - use more conservative values
      int cacheSizeBytes;
      if (kIsWeb) {
        cacheSizeBytes = 2 * 1024 * 1024; // 2MB for web
      } else if (PlatformServices.instance.isIOS) {
        cacheSizeBytes = 20 * 1024 * 1024; // 20MB for iOS/macOS
      } else {
        cacheSizeBytes = 80 * 1024 * 1024; // 80MB for Android
      }

      // Apply optimized settings (persistence enabled by default in newer SDK)
      FirebaseFirestore.instance.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: cacheSizeBytes,
        sslEnabled: !kIsWeb, // SSL only for non-web
        ignoreUndefinedProperties: true,
      );

      AppLogger.d('Firestore configured with optimized settings',
          category: LogCategory.database,
          data: {'cacheSizeBytes': cacheSizeBytes, 'isWeb': kIsWeb});
    } catch (e) {
      AppLogger.w('Failed to configure Firestore, using defaults',
          category: LogCategory.database, data: {'error': e.toString()});
    }
  }
}
