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

      WidgetsFlutterBinding.ensureInitialized();
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
      PaintingBinding.instance.imageCache.maximumSize = 10;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 5 * 1024 * 1024;
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

    // App Check – mobile release only
    if (!kDebugMode && !kIsWeb) {
      try {
        AppLogger.i('Initializing Firebase App Check (mobile release)...',
            category: LogCategory.general);
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.deviceCheck,
        );
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

    // FCM background handler (mobile only)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    await setupCoreDependencies();
  }

  // ── Phase 2a: Auth ─────────────────────────────────────────────────────

  static Future<void> _completeAuthSetup() async {
    try {
      _configureFirestoreSettings();
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
        cacheSizeBytes = 10 * 1024 * 1024;
      } else if (PlatformServices.instance.isIOS) {
        cacheSizeBytes = 20 * 1024 * 1024;
      } else {
        cacheSizeBytes = 80 * 1024 * 1024;
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

        startupService.reportStartupPerformance();
        AppInitializer.safelyRunBackgroundTasks(startupService);
      } catch (e) {
        AppLogger.e('Error during background initialization: $e');
      }
    }));
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
