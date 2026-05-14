import 'dart:async' show unawaited, runZonedGuarded, TimeoutException;
import 'package:aurogram/firebase_options.dart';
import 'package:aurogram/core/startup/startup_service.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/storage/app_performance.dart';
import 'package:aurogram/core/startup/app_initializer.dart';
import 'package:aurogram/core/network/network_optimizer.dart';
import 'package:aurogram/shared/services/media/media_compression_service.dart';
import 'package:aurogram/core/routing/dynamic_link_navigator.dart';
import 'package:aurogram/shared/services/watch_service.dart';
import 'package:aurogram/shared/services/local_store.dart';
import 'package:aurogram/features/ayurveda/domain/ayurveda_service.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/platform/platform.dart';
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/core/notifications/fcm_background_handler.dart';
import 'package:aurogram/app/app_providers.dart';
import 'package:aurogram/app/app_root.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

/// Tracks whether initial dependencies are loaded.
bool initialDependenciesLoaded = false;

/// Global navigator key shared across the app.
final GlobalKey<NavigatorState> navigatorKey = DynamicLinkNavigator.navigatorKey;

/// Two-phase app bootstrap:
///   Phase 1 (blocking): Firebase + core DI → runApp()
///   Phase 2 (background): Firestore config, auth, remaining services
class AppBootstrap {
  AppBootstrap._();

  static void run() {
    runZonedGuarded<Future<void>>(() async {
      final startupService = StartupService();
      startupService.recordStartTime();

      // In debug mode, use MarionetteBinding so AI agents (Wibey, Code Puppy)
      // can inspect widgets, tap, scroll, type, and take screenshots via MCP.
      // In release mode, use the standard binding — zero overhead.
      if (kDebugMode) {
        MarionetteBinding.ensureInitialized();
      } else {
        WidgetsFlutterBinding.ensureInitialized();
      }
      initializePlatformServices();
      _preWarmComponents();
      AppInitializer.setupErrorHandling();
      unawaited(AppPerformance.configurePlatformSettings());

      // Phase 1: blocking – Firebase + core DI
      await _initializeMinimalServices().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          AppLogger.w('Minimal services initialization timed out');
          throw TimeoutException('Minimal services timeout');
        },
      ).catchError((e) async {
        AppLogger.e('Error in minimal services, attempting fallback: $e');
        await _setupMinimalFallback();
      });

      // Show UI immediately
      runApp(AppProviders.wrap(
        child: AppRoot(
          startupService: startupService,
          navigatorKey: navigatorKey,
        ),
      ));

      // Phase 2: background – after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        startupService.recordFirstFrameTime();
        _completeAuthSetup();
        _completeInitialization(startupService);
      });
    }, (error, stack) {
      AppInitializer.handleUnhandledError(error, stack);
    });
  }

  // ── Pre-warm ───────────────────────────────────────────────────────────

  static void _preWarmComponents() {
    if (kIsWeb) {
      PaintingBinding.instance.imageCache.maximumSize = 100;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
    } else {
      // 50 images / 30MB — prevents constant re-decoding during scroll.
      // iOS may further tune in _configureIOSRendering; Android keeps these.
      PaintingBinding.instance.imageCache.maximumSize = 50;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024;
    }
    if (kReleaseMode && !kIsWeb) {
      PaintingBinding.instance.imageCache.clear();
    }
  }

  // ── Phase 1: Minimal services ──────────────────────────────────────────

  static Future<void> _initializeMinimalServices() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).catchError((error, stack) {
      AppLogger.e('Firebase initialization failed',
          category: LogCategory.general, error: error, stackTrace: stack);
      throw error;
    });

    // CRITICAL: Firestore settings must be applied IMMEDIATELY after
    // Firebase.initializeApp() and BEFORE any code touches
    // FirebaseFirestore.instance. The Firestore SDK locks settings on
    // first use and silently ignores any later .settings = assignment.
    // Previously this ran from _completeAuthSetup() (post-runApp), which
    // meant persistenceEnabled was never actually applied — leaving the
    // app with zero offline cache and a 10s wait on every cold read.
    _configureFirestoreSettings();

    // App Check – activate with appropriate provider per build mode.
    //
    // DEBUG MODE: Native AppDelegate.swift installs AppCheckDebugProviderFactory
    // which prints a debug token to console on first launch. Add that token in
    // Firebase Console > App Check > [iOS app] > Manage debug tokens to make
    // App Check pass for this dev install. We do NOT also call
    // FirebaseAppCheck.activate() from Dart in debug — the native factory
    // already covers it and a second activation triggers a redundant token
    // exchange.
    //
    // App Check: only activate in release mode on mobile.
    // Debug builds skip App Check entirely — the iOS app isn't registered
    // in Firebase Console, so both DeviceCheck and DebugProvider fail with
    // 400 "App not registered" and spam the console.
    if (!kIsWeb && !kDebugMode) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: const AndroidPlayIntegrityProvider(),
          providerApple: const AppleDeviceCheckProvider(),
        );
        unawaited(FirebaseAppCheck.instance.getToken(true).then((token) {
          AppLogger.i('App Check activated',
              category: LogCategory.general,
              data: {'hasToken': token != null});
        }).catchError((e) {
          AppLogger.w('App Check token fetch failed',
              category: LogCategory.general,
              data: {'error': e.toString()});
        }));
      } catch (e) {
        AppLogger.w('App Check activation failed: $e',
            category: LogCategory.general);
      }
    } else {
      AppLogger.i('App Check: disabled (debug or web)',
          category: LogCategory.general);
    }

    // FCM background handler (mobile only)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    await setupCoreDependencies();
  }

  // ── Phase 2a: Auth ─────────────────────────────────────────────────────

  static Future<void> _completeAuthSetup() async {
    try {
      await OnboardingService().initialize();

      AppLogger.d('Marking AuthService as ready (background)',
          category: LogCategory.auth);
      locator<AuthService>().markReady();
      initialDependenciesLoaded = true;

      AppLogger.i('Auth setup completed in background',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Error completing auth setup: $e',
          category: LogCategory.general);
      initialDependenciesLoaded = true;
      try {
        locator<AuthService>().markReady();
      } catch (_) {
        AppLogger.w('Failed to mark auth ready after error',
            category: LogCategory.general);
      }
    }
  }

  static void _configureFirestoreSettings() {
    try {
      int cacheSizeBytes;
      if (kIsWeb) {
        cacheSizeBytes = 10 * 1024 * 1024; // 10 MB – browser quota limited
      } else if (PlatformServices.instance.isIOS) {
        cacheSizeBytes = 100 * 1024 * 1024; // 100 MB – was 20 MB, too small for chat-heavy app
      } else {
        cacheSizeBytes = 100 * 1024 * 1024; // 100 MB
      }

      FirebaseFirestore.instance.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: cacheSizeBytes,
        sslEnabled: !kIsWeb,
        ignoreUndefinedProperties: true,
      );
      AppLogger.d('Firestore configured',
          category: LogCategory.database,
          data: {'cacheSizeBytes': cacheSizeBytes, 'isWeb': kIsWeb});
    } catch (e) {
      AppLogger.w('Firestore configuration failed, using defaults',
          category: LogCategory.database, data: {'error': e.toString()});
    }
  }

  // ── Phase 2b: Remaining services ───────────────────────────────────────

  static Future<void> _completeInitialization(
      StartupService startupService) async {
    unawaited(Future(() async {
      try {
        await AppInitializer.initializeAppConfig();

        await WidgetsBinding.instance.endOfFrame;
        await setupRemainingDependencies();

        await WidgetsBinding.instance.endOfFrame;
        if (locator.isRegistered<NetworkOptimizer>()) {
          unawaited(locator<NetworkOptimizer>().initialize());
        }

        await WidgetsBinding.instance.endOfFrame;
        if (locator.isRegistered<MediaCompressionService>()) {
          locator<MediaCompressionService>().migrateAndCleanupUploads();
        }

        // Initialize local health DB (offline-first, before watch bridge)
        // sqflite is not available on web — skip initialization
        if (!kIsWeb) {
          await LocalStore.instance.initialize();
          LocalStore.instance.startSyncTimer();
        }

        // Initialize Apple Watch companion bridge (iOS only, no-op elsewhere)
        WatchService.instance.initialize();
        AyurvedaService().listenForWatchNadi();

        // Proactively load sky positions and send to watch.
        // This ensures applicationContext is populated BEFORE the watch
        // requests fullSync (watch waits 4s after launch).
        unawaited(_sendSkyToWatch());

        startupService.reportStartupPerformance();

        AppInitializer.safelyRunBackgroundTasks(startupService);
      } catch (e) {
        AppLogger.e('Error during background initialization: $e');
      }
    }));
  }

  // ── Watch sky sync ─────────────────────────────────────────────────────

  /// Load sky positions, muhurat, and panchang from cache/backend
  /// and push to watch via applicationContext BEFORE the watch asks.
  /// Also listens for fullSync requests at the app level.
  static Future<void> _sendSkyToWatch() async {
    try {
      // Check if watch is paired BEFORE doing any work
      final watchPaired = await WatchService.instance.isWatchPaired();
      if (!watchPaired) {
        AppLogger.i('Bootstrap: Watch not paired, skipping sky/muhurat/panchang sync',
            category: LogCategory.general);
        // Still load sky positions for in-app use, but don't send to watch
        final skyService = SkyPositionsService();
        await skyService.fetchPositions();
        await skyService.fetchGlobalMuhurat();
        return;
      }

      final skyService = SkyPositionsService();

      // 1) Sky positions
      final skyOk = await skyService.fetchPositions();
      if (skyOk) {
        final positions = skyService.getPositionsForDate(DateTime.now());
        if (positions != null && positions.isNotEmpty) {
          AppLogger.i('Bootstrap: Sending sky to watch',
              category: LogCategory.general,
              data: {'planetCount': positions.length});
          await WatchService.instance.sendSkyPositions(positions);
        }

        // Also send panchang if available
        final panchang = skyService.getTodayPanchang();
        if (panchang != null) {
          AppLogger.i('Bootstrap: Sending panchang to watch',
              category: LogCategory.general);
          await WatchService.instance.sendPanchang(panchang);
        }
      } else {
        AppLogger.w('Bootstrap: Sky fetch failed — watch will have no sky data',
            category: LogCategory.general);
      }

      // 2) Muhurat (global, fetched separately)
      final muhuratOk = await skyService.fetchGlobalMuhurat();
      if (muhuratOk) {
        final muhurat = skyService.globalMuhurat;
        if (muhurat != null) {
          final windows = WatchService.extractMuhuratWindows(muhurat);
          if (windows.isNotEmpty) {
            AppLogger.i('Bootstrap: Sending muhurat to watch',
                category: LogCategory.general,
                data: {'windowCount': windows.length});
            await WatchService.instance.sendMuhurat(windows);
          }
        }
      }

      // 3) Listen for watch fullSync requests at the app level.
      // This ensures the watch gets data even if CosmicDashboard is not mounted.
      WatchService.instance.onWatchData.listen((data) {
        if (data['request'] == 'fullSync') {
          AppLogger.i('Bootstrap: Watch requested fullSync',
              category: LogCategory.general);
          final pos = skyService.getPositionsForDate(DateTime.now());
          if (pos != null && pos.isNotEmpty) {
            WatchService.instance.sendSkyPositions(pos);
          }
          final muh = skyService.globalMuhurat;
          if (muh != null) {
            final wins = WatchService.extractMuhuratWindows(muh);
            if (wins.isNotEmpty) {
              WatchService.instance.sendMuhurat(wins);
            }
          }
          final pan = skyService.getTodayPanchang();
          if (pan != null) {
            WatchService.instance.sendPanchang(pan);
          }
        }
      });
    } catch (e) {
      AppLogger.w('Bootstrap: Failed to send data to watch',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  // ── Fallback ───────────────────────────────────────────────────────────

  static Future<void> _setupMinimalFallback() async {
    try {
      AppLogger.w('Setting up minimal fallback configuration');
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      initialDependenciesLoaded = false;
      AppLogger.i('Minimal fallback setup complete');
    } catch (e) {
      AppLogger.e('Even minimal fallback failed: $e');
    }
  }
}
