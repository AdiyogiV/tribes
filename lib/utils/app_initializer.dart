import 'dart:async';
import 'dart:io';
import 'package:aurogram/utils/config/app_config.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/memory/memory_manager.dart';
import 'package:aurogram/utils/network/network_manager.dart';
import 'package:aurogram/utils/performance/image_optimizer.dart';
import 'package:aurogram/services/startup_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' as scheduler;
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:aurogram/utils/dependency_injection.dart';

/// Handles app initialization tasks
class AppInitializer {
  /// Set up error handling for Flutter
  static void setupErrorHandling() {
    // Set up error handling immediately
    FlutterError.onError = (FlutterErrorDetails details) {
      // Filter out known Flutter framework bugs that don't affect functionality
      final errorString = details.exception.toString();
      
      // Skip Flutter Web mouse_tracker assertion bug (framework issue, not app issue)
      // This is a known Flutter bug where _debugDuringDeviceUpdate fires incorrectly
      // See: https://github.com/flutter/flutter/issues/84241
      if (kIsWeb && errorString.contains('_debugDuringDeviceUpdate')) {
        // Skip logging this framework bug - it fires every frame and spams logs
        return;
      }
      
      // Skip viewport hitTestChildren null geometry error on web
      // This is a Flutter Web bug where sliver geometry can be null during hit testing
      // The error doesn't block functionality but spams logs on every mouse move
      if (kIsWeb && errorString.contains('Unexpected null value') && 
          details.stack.toString().contains('viewport.dart')) {
        return;
      }
      
      // Skip OverlayPortal hit test error on web
      // This is a Flutter Web bug where OverlayPortal render boxes (used by TextField,
      // DropdownButton, etc.) can be hit-tested before they're laid out
      // The error doesn't block functionality - clicks still work
      if (kIsWeb && errorString.contains('Cannot hit test a render box that has never been laid out') &&
          errorString.contains('_RenderDeferredLayoutBox')) {
        return;
      }
      
      // Print immediately to help with debugging startup issues
      AppLogger.e('Flutter error',
          category: LogCategory.general, error: details.exception);

      // Log the error once the logger is initialized
      try {
        AppLogger.e(
          'Flutter error',
          category: LogCategory.general,
          error: details.exception,
          stackTrace: details.stack,
        );

        // Forward to crashlytics if available
        _forwardErrorToCrashlytics(details);
      } catch (e) {
        // If the logger fails during startup, still print the original error
        AppLogger.e('Error logging failed',
            category: LogCategory.general,
            error: e,
            data: {
              'originalError': details.exception.toString(),
              'stackTrace': details.stack.toString()
            });
      }
    };

    // Setup global error widget to avoid rendering issues
    ErrorWidget.builder =
        (FlutterErrorDetails details) => _buildErrorWidget(details);
  }

  /// Configure platform specific settings for optimal performance
  static Future<void> configurePlatformSettings() async {
    try {
      // Set preferred orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Enable skia rendering optimization on supported platforms
      if (!kIsWeb) {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
        );
      }

      // Configure renderer on iOS/macOS to improve stability
      if (Platform.isIOS || Platform.isMacOS) {
        _configureIOSRendering();
      } else if (Platform.isAndroid) {
        // Android-specific optimizations
        try {
          await FlutterDisplayMode.setHighRefreshRate();
        } catch (e) {
          // Ignore if high refresh rate is not supported
          AppLogger.w('High refresh rate not supported',
              category: LogCategory.performance, data: {'error': e.toString()});
        }
      }
    } catch (e) {
      AppLogger.w('Error configuring platform settings',
          category: LogCategory.general, data: {'error': e.toString()});
      // Continue without platform optimizations
    }
  }

  /// Initialize app configuration with proper error handling
  static Future<void> initializeAppConfig() async {
    try {
      if (locator.isRegistered<AppConfig>()) {
        final appConfig = locator<AppConfig>();
        // Make sure to await the initialization
        await appConfig.initialize();
        AppLogger.i('AppConfig initialized successfully',
            category: LogCategory.general);
      }
    } catch (e) {
      AppLogger.w('Failed to initialize AppConfig: $e',
          category: LogCategory.general, data: {'error': e.toString()});
    }

    // Run network and memory initialization in parallel
    await Future.wait([
      _initializeNetworkManager(),
      _initializeMemoryManager(),
    ], eagerError: false);
  }

  /// Initialize network manager with error handling
  static Future<void> _initializeNetworkManager() async {
    try {
      if (locator.isRegistered<NetworkManager>()) {
        final networkManager = locator<NetworkManager>();
        await networkManager.initialize();
      }
    } catch (e) {
      AppLogger.w('Failed to initialize NetworkManager: $e',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Initialize memory manager with error handling
  static Future<void> _initializeMemoryManager() async {
    try {
      if (locator.isRegistered<MemoryManager>()) {
        final memoryManager = locator<MemoryManager>();
        await memoryManager.initialize(enableAutoCleanup: !kIsWeb);

        // Initialize ImageOptimizer with memory manager
        ImageOptimizer.initialize(memoryManager);
      }
    } catch (e) {
      AppLogger.w('Failed to initialize MemoryManager: $e',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Safely run background initialization tasks
  static void safelyRunBackgroundTasks(StartupService startupService) {
    // Wrap in another try-catch to prevent initialization errors from affecting the UI
    runZonedGuarded(() async {
      await startupService.initializeBackgroundTasks();
    }, (error, stack) {
      AppLogger.e('Background initialization error',
          category: LogCategory.general, error: error);
      // Log but don't crash the app
      AppLogger.w(
        'Error during background initialization',
        category: LogCategory.general,
        data: {'error': error.toString()},
      );
    });
  }

  /// Configure iOS/macOS rendering for better performance
  static void _configureIOSRendering() {
    try {
      // Reduce image cache size to prevent memory pressure
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          30 * 1024 * 1024; // 30MB
      PaintingBinding.instance.imageCache.maximumSize = 50; // 50 images max

      // Configure scheduler for better performance
      scheduler.timeDilation = 1.0; // Ensure animations run at normal speed

      // Enable high refresh rate on iOS devices that support it
      if (Platform.isIOS) {
        _safelyEnableHighRefreshRate();
      }
    } catch (e) {
      AppLogger.w('Error configuring iOS/macOS rendering',
          category: LogCategory.general, data: {'error': e.toString()});
      // Continue without custom rendering settings
    }
  }

  /// Safely enable high refresh rate without crashing
  static void _safelyEnableHighRefreshRate() {
    try {
      // This is for Android (fixed logic from original code)
      if (Platform.isAndroid) {
        FlutterDisplayMode.setHighRefreshRate().catchError((e) {
          AppLogger.w('High refresh rate not supported',
              category: LogCategory.performance, data: {'error': e.toString()});
          return null;
        });
      }
    } catch (e) {
      // Ignore if not supported
      AppLogger.w('Failed to set refresh rate',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  /// Forward errors to Crashlytics if available
  static void _forwardErrorToCrashlytics(FlutterErrorDetails details) {
    if (!kIsWeb && !kDebugMode) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    }
  }

  /// Build a user-friendly error widget for Flutter errors
  static Widget _buildErrorWidget(FlutterErrorDetails details) {
    // Simpler error widget that doesn't consume much memory
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 36),
              const SizedBox(height: 16),
              const Text(
                'An error occurred',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kDebugMode
                    ? details.exception.toString()
                    : 'Please restart the app',
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle unhandled errors that bubble up to the zone
  static void handleUnhandledError(Object error, StackTrace stack) {
    // Log error
    AppLogger.e('Unhandled error',
        category: LogCategory.general,
        error: error,
        data: {'stackTrace': stack.toString()});

    // Report to crash reporting
    if (!kIsWeb && !kDebugMode) {
      FirebaseCrashlytics.instance.recordError(error, stack);
    }

    // Log to app logger if available
    try {
      AppLogger.e(
        'Unhandled error',
        category: LogCategory.general,
        error: error,
        stackTrace: stack,
      );
    } catch (e) {
      // Fallback if logger fails
      AppLogger.e('Error logging unhandled error',
          category: LogCategory.general, error: e);
    }
  }
}
