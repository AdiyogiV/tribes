import 'package:aurogram/firebase_options.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:aurogram/platform/platform.dart';

// =============================================================================
// STARTUP AUTH: Firebase initialization, Crashlytics, Firestore configuration
// =============================================================================

/// Handles Firebase initialization, Crashlytics setup, and Firestore
/// configuration. Mixed into [StartupService].
mixin StartupAuthMixin {
  /// Initialize Firebase with robust error handling and retries.
  Future<void> initializeFirebase() async {
    const int maxRetries = 1;
    int retryCount = 0;
    bool initialized = false;

    while (!initialized && retryCount <= maxRetries) {
      try {
        if (retryCount > 0) {
          AppLogger.i('Retrying Firebase initialization (attempt $retryCount)',
              category: LogCategory.general);
          await Future.delayed(const Duration(milliseconds: 500));
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

        // Set up analytics only in release mode
        if (kReleaseMode) {
          FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
        }

        // Configure Firestore for better performance
        _configureFirestore();

        AppLogger.i('Firebase successfully initialized',
            category: LogCategory.general);

        initialized = true;
        onFirebaseInitialized();
      } catch (e, stack) {
        retryCount++;

        if (retryCount > maxRetries) {
          AppLogger.e('Failed to initialize Firebase after multiple attempts',
              category: LogCategory.general, error: e, stackTrace: stack);

          if (kReleaseMode) {
            rethrow;
          }
          break;
        }

        AppLogger.w('Firebase initialization failed, will retry',
            category: LogCategory.general,
            data: {'attempt': retryCount, 'error': e.toString()});
      }
    }
  }

  /// Callback for subclasses to record Firebase init timing.
  void onFirebaseInitialized();

  /// Initialize Crashlytics separately for better error isolation.
  Future<void> _initializeCrashlytics() async {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      FlutterError.onError = (FlutterErrorDetails details) {
        FirebaseCrashlytics.instance.recordFlutterError(details);
      };

      AppLogger.i('Crashlytics initialized', category: LogCategory.general);
    } catch (e) {
      AppLogger.w('Failed to initialize Crashlytics, continuing without it',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Configure Firestore for optimal performance based on platform.
  void _configureFirestore() {
    try {
      int cacheSizeBytes;
      if (kIsWeb) {
        cacheSizeBytes = 2 * 1024 * 1024; // 2MB for web
      } else if (PlatformServices.instance.isIOS) {
        cacheSizeBytes = 20 * 1024 * 1024; // 20MB for iOS/macOS
      } else {
        cacheSizeBytes = 80 * 1024 * 1024; // 80MB for Android
      }

      FirebaseFirestore.instance.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: cacheSizeBytes,
        sslEnabled: !kIsWeb,
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
