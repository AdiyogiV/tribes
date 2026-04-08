import 'dart:async' show unawaited, runZonedGuarded, TimeoutException;
import 'package:aurogram/firebase_options.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:aurogram/services/startup_service.dart';
import 'package:aurogram/features/notifications/domain/notification_service.dart';
import 'package:aurogram/services/onboarding_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/storage/app_performance.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/providers/theme_provider.dart';
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/providers/ai_chat_provider.dart';
import 'package:aurogram/shared/services/media/speech_recognition_service.dart';
import 'package:aurogram/shared/services/media/audio_input_service.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_service.dart';
import 'package:aurogram/shared/services/location_service.dart';
import 'package:aurogram/features/feed/presentation/pages/feed_controller.dart';
import 'package:aurogram/utils/app_initializer.dart';
import 'tabs.dart';
import 'package:aurogram/core/storage/memory_manager.dart';
import 'package:aurogram/core/network/network_manager.dart';
import 'package:aurogram/core/network/network_optimizer.dart';
import 'package:aurogram/shared/services/media/media_compression_service.dart';
import 'package:aurogram/core/routing/dynamic_link_navigator.dart';
import 'package:aurogram/pages/helpers/flash.dart';
import 'package:aurogram/platform/platform.dart';

// Conditional imports for mobile-only features
import 'package:aurogram/services/call_service_export.dart';
import 'package:aurogram/features/calling/presentation/pages/incoming_call_screen.dart'
    if (dart.library.html) 'package:aurogram/pages/call/incoming_call_screen_stub.dart';
import 'package:aurogram/core/notifications/fcm_background_handler.dart';

// Global for accessing the navigator during FCM setup
final GlobalKey<NavigatorState> navigatorKey =
    DynamicLinkNavigator.navigatorKey;

// Flag to track if initial dependencies are loaded
bool _initialDependenciesLoaded = false;

// FCM background handler and call notification functions are in
// lib/core/notifications/fcm_background_handler.dart


void main() async {
  // Capture startup errors with improved error zone
  runZonedGuarded<Future<void>>(() async {
    // Start performance tracking
    final startupService = StartupService();
    startupService.recordStartTime();

    // Ensure Flutter is initialized with optimized renderer settings
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize platform services (web vs mobile)
    initializePlatformServices();

    // Pre-warm GPU and native components on startup
    _preWarmComponents();

    // Set up error handling immediately
    AppInitializer.setupErrorHandling();

    // Configure platform-specific optimizations - run in parallel with Firebase init
    unawaited(AppPerformance.configurePlatformSettings());

    // PERFORMANCE OPTIMIZATION: Split initialization into two phases
    // Phase 1 (blocking): Minimal setup needed before UI can show
    // Phase 2 (background): Everything else after UI is visible

    // Phase 1: Initialize Firebase + core dependencies only
    // This is required before runApp() because providers need AuthService registered
    await _initializeMinimalServices().timeout(
      Duration(seconds: 15), // Shorter timeout for minimal services
      onTimeout: () {
        AppLogger.w(
            'Minimal services initialization timed out, continuing with fallback');
        throw TimeoutException('Minimal services timeout');
      },
    ).catchError((e) async {
      AppLogger.e('Error in minimal services, attempting fallback setup: $e');
      await _setupMinimalFallback();
    });

    // Start the app IMMEDIATELY - auth and other services will complete in background
    // FlashScreen will show until auth state resolves
    runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: locator<AuthService>()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SpeechRecognitionService()),
        // AudioInputService - needed for Consumer<AudioInputService> in chat_input_area
        ChangeNotifierProvider(create: (_) => AudioInputService()),
        // FeedController - manages post interaction state (likes, replies, video/audio position)
        ChangeNotifierProvider(create: (_) => FeedController()),
        ChangeNotifierProvider(
          create: (_) {
            try {
              // Get services safely with fallback
              AiChatService? aiService;
              LocationService? locationService;

              try {
                aiService = locator<AiChatService>();
              } catch (e) {
                AppLogger.w('Failed to get AiChatService, using fallback: $e');
                aiService = AiChatService();
              }

              try {
                locationService = locator<LocationService>();
              } catch (e) {
                AppLogger.w(
                    'Failed to get LocationService, using fallback: $e');
                locationService = LocationService();
              }

              final provider = AiChatProvider(
                service: aiService,
                locationService: locationService,
              );
              return provider;
            } catch (e) {
              AppLogger.e('Error creating AiChatProvider: $e');
              // Create a minimal provider that can be initialized later
              return AiChatProvider(
                service: AiChatService(),
                locationService: LocationService(),
              );
            }
          },
        ),
      ],
      child:
          AppRoot(startupService: startupService, navigatorKey: navigatorKey),
    ));

    // Schedule Phase 2 initialization after UI is visible
    // This includes: Firestore settings, OnboardingService, Auth ready signal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startupService.recordFirstFrameTime();
      // Complete auth setup in background - this triggers auth state resolution
      _completeAuthSetup();
      // Then complete remaining initialization
      _completeInitialization(startupService);
    });
  }, (error, stack) {
    AppInitializer.handleUnhandledError(error, stack);
  });
}

/// Pre-warm GPU and native components with platform-appropriate memory settings
void _preWarmComponents() {
  if (kIsWeb) {
    // Web browsers have more memory available and handle caching well
    PaintingBinding.instance.imageCache.maximumSize = 100;
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        50 * 1024 * 1024; // 50MB for web
  } else {
    // Very conservative image cache for mobile memory constraints
    // iOS typically kills apps using > 1GB RAM
    PaintingBinding.instance.imageCache.maximumSize =
        10; // Further reduced for safety
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        5 * 1024 * 1024; // 5MB max for mobile
  }

  if (kReleaseMode && !kIsWeb) {
    // Only clear on mobile release - web benefits from keeping cache
    PaintingBinding.instance.imageCache.clear();
  }
}

/// Phase 1: Initialize ONLY the minimal services needed before UI can show
/// This runs BEFORE runApp() and should be as fast as possible
Future<void> _initializeMinimalServices() async {
  // Initialize Firebase - this is required for everything else
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).catchError((error, stack) {
    AppLogger.e(
      'Firebase initialization failed',
      category: LogCategory.general,
      error: error,
      stackTrace: stack,
    );
    throw error;
  });

  // Initialize Firebase App Check - ONLY on MOBILE RELEASE builds
  // Skipped on web for faster startup (adds 0.5-1.5s latency with minimal benefit)
  if (!kDebugMode && !kIsWeb) {
    try {
      AppLogger.i('Initializing Firebase App Check (mobile release)...',
          category: LogCategory.general);

      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );

      // Try to get a token to verify it's working
      try {
        final token = await FirebaseAppCheck.instance.getToken(true);
        AppLogger.i('Firebase App Check activated',
            category: LogCategory.general, data: {'hasToken': token != null});
      } catch (tokenError) {
        AppLogger.w('Firebase App Check token fetch failed',
            category: LogCategory.general,
            data: {'error': tokenError.toString()});
      }
    } catch (e) {
      AppLogger.w('Firebase App Check activation failed: $e',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  } else {
    AppLogger.i('Skipping Firebase App Check',
        category: LogCategory.general,
        data: {
          'reason': kIsWeb ? 'Web platform - faster startup' : 'Debug mode'
        });
  }

  // Register the background message handler (mobile only)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Set up core dependency injection - registers AuthService needed for providers
  // This is synchronous (just registration, no network calls)
  await setupCoreDependencies();
}

/// Phase 2: Complete auth setup AFTER UI is visible
/// This runs in background after first frame, allowing splash screen to appear faster
Future<void> _completeAuthSetup() async {
  try {
    // Configure Firestore settings for optimal performance
    _configureFirestoreSettings();

    // Initialize onboarding service (reads from SharedPreferences)
    await OnboardingService().initialize();

    // Signal AuthService to start processing auth state
    // This triggers checkRegistration() which may make Firestore calls
    AppLogger.d('Main: Marking AuthService as ready (background)', category: LogCategory.auth);
    locator<AuthService>().markReady();

    _initialDependenciesLoaded = true;

    AppLogger.i('Auth setup completed in background',
        category: LogCategory.general);
  } catch (e) {
    AppLogger.e('Error completing auth setup: $e',
        category: LogCategory.general);
    // Still mark as loaded to prevent infinite loading
    _initialDependenciesLoaded = true;
    // Try to mark auth ready anyway
    try {
      locator<AuthService>().markReady();
    } catch (_) {
      AppLogger.w('Main: failed to mark auth ready after error', category: LogCategory.general);
    }
  }
}

/// Configure Firestore settings for optimal performance
void _configureFirestoreSettings() {
  try {
    AppLogger.d('Main: Configuring Firestore settings', category: LogCategory.database);
    // Adjust cache size based on platform
    int cacheSizeBytes;
    if (kIsWeb) {
      cacheSizeBytes =
          10 * 1024 * 1024; // 10MB for web (increased for better caching)
    } else if (PlatformServices.instance.isIOS) {
      cacheSizeBytes = 20 * 1024 * 1024; // 20MB for iOS
    } else {
      cacheSizeBytes = 80 * 1024 * 1024; // 80MB for Android
    }

    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: true,
      cacheSizeBytes: cacheSizeBytes,
      sslEnabled: !kIsWeb,
      ignoreUndefinedProperties: true,
    );

    AppLogger.d('Main: Firestore configured successfully', category: LogCategory.database);
    AppLogger.d('Firestore configured with optimized settings',
        category: LogCategory.database,
        data: {'cacheSizeBytes': cacheSizeBytes, 'isWeb': kIsWeb});
  } catch (e) {
    AppLogger.w('Main: Firestore configuration failed: $e', category: LogCategory.database);
    AppLogger.w('Failed to configure Firestore, using defaults',
        category: LogCategory.database, data: {'error': e.toString()});
  }
}

/// Minimal fallback setup if critical services fail
Future<void> _setupMinimalFallback() async {
  try {
    AppLogger.w('Setting up minimal fallback configuration');

    // Just ensure Firebase is initialized - nothing else
    if (!Firebase.apps.isNotEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    _initialDependenciesLoaded = false; // Mark as not fully loaded
    AppLogger.i('Minimal fallback setup complete');
  } catch (e) {
    AppLogger.e('Even minimal fallback failed: $e');
    // Continue anyway - let the app try to start
  }
}

/// Complete the initialization process after UI is visible
Future<void> _completeInitialization(StartupService startupService) async {
  // Run non-critical initialization tasks sequentially, waiting for idle frames
  unawaited(Future(() async {
    try {
      // Phase 1: Config (lightweight)
      await AppInitializer.initializeAppConfig();

      // Phase 2: Core services - wait for idle frame to avoid blocking UI
      await WidgetsBinding.instance.endOfFrame;
      await setupRemainingDependencies();

      // Phase 3: Network services - wait for idle frame
      await WidgetsBinding.instance.endOfFrame;
      if (locator.isRegistered<NetworkOptimizer>()) {
        unawaited(locator<NetworkOptimizer>().initialize());
      }

      // Phase 4: Heavy media services - wait for idle frame
      await WidgetsBinding.instance.endOfFrame;
      if (locator.isRegistered<MediaCompressionService>()) {
        final mediaService = locator<MediaCompressionService>();
        mediaService.migrateAndCleanupUploads();
      }

      startupService.reportStartupPerformance();
      AppInitializer.safelyRunBackgroundTasks(startupService);
    } catch (e) {
      AppLogger.e('Error during background initialization: $e');
      // Continue - don't crash the app
    }
  }));
}

/// Root widget that manages app initialization state
class AppRoot extends StatefulWidget {
  final StartupService startupService;
  final GlobalKey<NavigatorState> navigatorKey;

  const AppRoot(
      {super.key, required this.startupService, required this.navigatorKey});

  @override
  AppRootState createState() => AppRootState();
}

class AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  bool _appInitialized = false;
  final NotificationService _notificationService = NotificationService();
  final CallService _callService = CallService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Defer initialization to first frame for faster perceived performance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    // Set initialized immediately to show UI faster
    if (mounted && !_appInitialized) {
      setState(() {
        _appInitialized = true;
      });
    }

    try {
      // Check if core dependencies are loaded
      if (!_initialDependenciesLoaded) {
        // Wait for next frame instead of arbitrary delay
        await WidgetsBinding.instance.endOfFrame;
      }

      // Run initialization in background - execute sequentially to avoid memory spike
      unawaited(Future(() async {
        // Initialize notifications first (includes FCM)
        await _initializeNotifications();

        // Initialize network services (dynamic links)
        await _initializeNetwork();

        // Wait for idle frame before memory-heavy operations
        await WidgetsBinding.instance.endOfFrame;
        await _initializeMemory();

        // Cleanup old notifications periodically
        _notificationService.cleanupOldNotifications();

        AppLogger.i('App initialization complete',
            category: LogCategory.general);
      }));
    } catch (e) {
      // Log error but continue
      AppLogger.e('Error during app initialization',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  // Initialize notification services
  Future<void> _initializeNotifications() async {
    try {
      // Initialize CallService for voice/video calls on ALL platforms (including web)
      // This sets up the Firestore listener for incoming calls
      await _initializeCallService();

      // Only initialize mobile-specific notification services on mobile platforms
      if (!kIsWeb && PlatformServices.instance.isMobile) {
        // Initialize the new centralized NotificationService
        await _notificationService.initialize(widget.navigatorKey);

        // Also set up the old StartupService for backward compatibility
        // This will be gradually phased out
        await widget.startupService.setupFirebaseMessaging(widget.navigatorKey);
      } else if (kIsWeb) {
        // On web, we skip mobile-specific notifications but CallService is already initialized above
        AppLogger.i(
            'Web platform: CallService initialized, skipping mobile notification services',
            category: LogCategory.messaging);
      }
    } catch (e) {
      AppLogger.w('Notification init error',
          category: LogCategory.messaging, data: {'error': e.toString()});
    }
  }

  // Initialize call service for voice/video calls
  Future<void> _initializeCallService() async {
    try {
      AppLogger.i('📞 Initializing CallService (isWeb: $kIsWeb)',
          category: LogCategory.general);

      await _callService.initialize();

      AppLogger.i(
          '📞 CallService initialized, setting up onIncomingCall callback',
          category: LogCategory.general);

      // Set up message callback for user notifications
      _callService.setMessageCallback((message) {
        final navigatorState = widget.navigatorKey.currentState;
        if (navigatorState != null) {
          ScaffoldMessenger.of(navigatorState.context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });

      // Listen for incoming calls
      _callService.onIncomingCall = (call) {
        AppLogger.i('📞 onIncomingCall triggered!',
            category: LogCategory.general,
            data: {
              'callId': call.id,
              'callerId': call.callerId,
              'callerName': call.callerName,
              'callType': call.type.toString(),
              'isWeb': kIsWeb,
            });

        // Check if navigator is available
        final navigatorState = widget.navigatorKey.currentState;
        if (navigatorState == null) {
          AppLogger.e('📞 Cannot show incoming call: Navigator state is null!',
              category: LogCategory.general);
          return;
        }

        AppLogger.i('📞 Navigating to IncomingCallScreen',
            category: LogCategory.general);

        // Navigate to incoming call screen
        navigatorState.push(
          MaterialPageRoute(
            builder: (context) => IncomingCallScreen(call: call),
          ),
        );

        AppLogger.i('📞 Navigation to IncomingCallScreen completed',
            category: LogCategory.general);
      };

      AppLogger.i('📞 CallService fully initialized with incoming call handler',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('📞 CallService init error',
          category: LogCategory.general,
          error: e,
          data: {'error': e.toString()});
    }
  }

  // Initialize network services (dynamic links)
  Future<void> _initializeNetwork() async {
    try {
      await widget.startupService.setupDynamicLinks(widget.navigatorKey);
    } catch (e) {
      AppLogger.w('Network init error',
          category: LogCategory.network, data: {'error': e.toString()});
    }
  }

  // Initialize memory management (cache pruning)
  Future<void> _initializeMemory() async {
    try {
      if (locator.isRegistered<CacheService>()) {
        unawaited(locator<CacheService>().pruneCache());
      }
    } catch (e) {
      AppLogger.w('Memory init error',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle state changes more efficiently
    widget.startupService.handleAppLifecycleChange(state);

    // Free up resources when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (locator.isRegistered<MemoryManager>()) {
        final memoryManager = locator<MemoryManager>();
        final cleanupType = state == AppLifecycleState.paused
            ? CleanupType.normal
            : CleanupType.light;
        memoryManager.clearMemoryCaches(cleanupType: cleanupType);
      }
    }

    // When resuming, check if we need to refresh data
    if (state == AppLifecycleState.resumed) {
      // Check network status
      if (locator.isRegistered<NetworkManager>()) {
        final networkManager = locator<NetworkManager>();
        networkManager.checkInternetAccess().then((isOnline) {
          if (isOnline) {
            // Background refresh if we came back online
            AppLogger.d('App resumed with internet connection, refreshing data',
                category: LogCategory.network);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      title: 'Aurogram',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getMaterialTheme(isDarkMode: isDark),
      builder: (context, child) {
        // Wrap with CupertinoTheme for consistent styling
        return CupertinoTheme(
          data: AppTheme.getCupertinoTheme(isDarkMode: isDark),
          child: MediaQuery(
            // Disable animation scaling for better performance
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.0),
            ),
            child: child!,
          ),
        );
      },
      home: _buildStartupScreen(),
    );
  }

  Widget _buildStartupScreen() {
    if (!_appInitialized) {
      return const FlashScreen();
    }

    return TabHandler();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationService.dispose();
    _callService.dispose();
    super.dispose();
  }
}
