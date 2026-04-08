import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/storage/memory_manager.dart';
import 'package:aurogram/core/config/app_config.dart';
import 'package:aurogram/core/storage/image_optimizer.dart';
import 'package:aurogram/core/storage/asset_generator.dart';
import 'package:aurogram/platform/platform.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

// =============================================================================
// STARTUP CONFIG: Background tasks, feature flags, lifecycle, performance
// =============================================================================

/// Handles background initialization tasks, app updates, asset preloading,
/// app lifecycle management, and performance reporting. Mixed into [StartupService].
mixin StartupConfigMixin {
  /// Handle background initialization tasks more efficiently.
  Future<void> initializeBackgroundTasks() async {
    try {
      await Future.wait([
        _checkForAppUpdates(),
        _generateAndPreloadAssets(),
      ], eagerError: false);

      AppLogger.i('Background startup tasks completed',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.w('Error during background initialization',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Check if the app has updates available.
  Future<void> _checkForAppUpdates() async {
    try {
      if (kIsWeb) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

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

        if (locator.isRegistered<AppConfig>()) {
          final appConfig = locator.get<AppConfig>();
          final Map<String, dynamic> updateInfo = {
            'update_available': true,
            'latest_version': latestVersion,
            'force_update': forceUpdate
          };
          appConfig.storeLocalConfig(updateInfo);
        }
      }
    } catch (e) {
      AppLogger.w('Failed to check for app updates',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Generate and preload assets.
  Future<void> _generateAndPreloadAssets() async {
    try {
      await AssetGenerator.generateDefaultAssets();
      await _preloadCriticalAssets();
    } catch (e) {
      AppLogger.w('Error during asset generation and preloading',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  /// Preload critical assets in the background.
  Future<void> _preloadCriticalAssets() async {
    try {
      if (!locator.isRegistered<AppConfig>()) return;

      final appConfig = locator.get<AppConfig>();
      final shouldPreload =
          appConfig.getBool('prefetch_assets', defaultValue: true);

      if (!shouldPreload) return;

      final criticalAssets = [
        'assets/images/logo.png',
        'assets/images/placeholder.png',
        'assets/images/error.png',
        'assets/images/user.png',
      ];

      if (locator.isRegistered<MemoryManager>()) {
        try {
          final existingAssets = <String>[];

          for (final asset in criticalAssets) {
            try {
              await rootBundle.load(asset);
              existingAssets.add(asset);
            } catch (e) {
              AppLogger.d('Asset not found during preloading check',
                  category: LogCategory.performance, data: {'asset': asset});
            }
          }

          if (existingAssets.isNotEmpty) {
            await ImageOptimizer.preloadAssetImages(existingAssets);
          }
        } catch (e) {
          AppLogger.w('Error checking assets during preload',
              category: LogCategory.performance,
              data: {'error': e.toString()});
        }
      }
    } catch (e) {
      AppLogger.w('Failed to preload critical assets',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  /// Report startup performance metrics.
  ///
  /// Requires concrete getters from the host class.
  void reportStartupPerformanceWithTiming({
    required Duration totalStartupTime,
    required Duration firebaseInitDuration,
    required DateTime? firstFrameTime,
    required DateTime? firebaseInitTime,
    required DateTime? dependencyInitTime,
  }) {
    final total = totalStartupTime.inMilliseconds;
    final firebase = firebaseInitDuration.inMilliseconds;
    final firstFrameToStart = firstFrameTime != null && firebaseInitTime != null
        ? firstFrameTime.difference(firebaseInitTime).inMilliseconds
        : 0;

    Map<String, dynamic> performanceData = {
      'total_startup_ms': total,
      'firebase_init_ms': firebase,
      'first_frame_to_start_ms': firstFrameToStart,
    };

    if (dependencyInitTime != null && firebaseInitTime != null) {
      performanceData['dependency_init_ms'] =
          dependencyInitTime.difference(firebaseInitTime).inMilliseconds;
    }

    AppLogger.i('App startup performance',
        category: LogCategory.performance, data: performanceData);

    _sendStartupPerformanceAnalytics(performanceData);
  }

  /// Send startup performance data to analytics.
  void _sendStartupPerformanceAnalytics(Map<String, dynamic> performanceData) {
    try {
      if (kReleaseMode) {
        FirebaseAnalytics.instance.logEvent(
          name: 'app_startup_performance',
          parameters: Map<String, Object>.from(performanceData),
        );

        FirebaseAnalytics.instance.logEvent(
          name: 'app_startup_timing',
          parameters: {
            'timing_name': 'total_startup',
            'timing_ms': performanceData['total_startup_ms'] as int,
          },
        );
      }
    } catch (e) {
      AppLogger.w('Failed to send startup performance analytics',
          category: LogCategory.analytics, data: {'error': e.toString()});
    }
  }

  /// Handle app lifecycle changes to manage resources effectively.
  Future<void> handleAppLifecycleChange(AppLifecycleState state) async {
    AppLogger.d('App lifecycle state changed to: ${state.toString()}',
        category: LogCategory.general);

    switch (state) {
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.inactive:
        if (!kIsWeb && (PlatformServices.instance.isIOS)) {
          _cleanupMetalResources();
        }
        break;
      case AppLifecycleState.paused:
        await _releaseResources();
        break;
      case AppLifecycleState.detached:
        if (!kIsWeb && PlatformServices.instance.isIOS) {
          await _releaseResources(aggressive: true);
        }
        break;
      default:
        break;
    }
  }

  /// Release resources when app goes to background.
  Future<void> _releaseResources({bool aggressive = false}) async {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (locator.isRegistered<MemoryManager>()) {
        final memoryManager = locator<MemoryManager>();
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

  /// Special cleanup for Metal resources on iOS/macOS.
  void _cleanupMetalResources() {
    try {
      final imageCache = PaintingBinding.instance.imageCache;
      final currentMaxSize = imageCache.maximumSize;

      imageCache.maximumSize = 10;
      imageCache.clear();

      Future.delayed(Duration(milliseconds: 100), () {
        PaintingBinding.instance.imageCache.maximumSize = currentMaxSize;
      });
    } catch (e) {
      AppLogger.w('Error cleaning up Metal resources',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }
}
