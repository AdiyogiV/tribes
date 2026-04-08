import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart' as scheduler;
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Utility class for optimizing app performance
class AppPerformance {
  /// Configure platform-specific settings for optimal performance
  static Future<void> configurePlatformSettings() async {
    try {
      // Set preferred orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Enable skia rendering optimization on supported platforms
      // Platform checks must be inside kIsWeb guard - dart:io Platform crashes on web
      if (!kIsWeb) {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
        );

        // Configure platform-specific optimizations (safe inside !kIsWeb block)
        if (Platform.isIOS || Platform.isMacOS) {
          _configureIOSRendering();
        } else if (Platform.isAndroid) {
          _configureAndroidRendering();
        }
      }
    } catch (e) {
      AppLogger.w('Error configuring platform settings: $e',
          category: LogCategory.performance, data: {'error': e.toString()});
      // Continue without platform optimizations
    }
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
    } catch (e) {
      AppLogger.w('Error configuring iOS/macOS rendering: $e',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  /// Configure Android-specific optimizations
  static void _configureAndroidRendering() {
    try {
      // Enable high refresh rate on supported devices
      FlutterDisplayMode.setHighRefreshRate().catchError((e) {
        AppLogger.w('High refresh rate not supported',
            category: LogCategory.performance, data: {'error': e.toString()});
        return null;
      });
    } catch (e) {
      AppLogger.w('Error configuring Android rendering: $e',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  /// Optimize image cache settings based on device memory
  static void optimizeImageCache(int availableMemoryMB) {
    final int cacheSize = _calculateOptimalCacheSize(availableMemoryMB);

    try {
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          cacheSize * 1024 * 1024;
      PaintingBinding.instance.imageCache.maximumSize =
          _calculateOptimalImageCount(availableMemoryMB);

      AppLogger.d(
          'Image cache optimized: ${cacheSize}MB, ${PaintingBinding.instance.imageCache.maximumSize} images',
          category: LogCategory.performance);
    } catch (e) {
      AppLogger.w('Failed to optimize image cache: $e',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  /// Calculate optimal image cache size based on device memory
  static int _calculateOptimalCacheSize(int availableMemoryMB) {
    // Low-end devices: <2GB RAM
    if (availableMemoryMB < 2048) return 15;

    // Mid-range devices: 2-4GB RAM
    if (availableMemoryMB < 4096) return 30;

    // High-end devices: >4GB RAM
    return 50;
  }

  /// Calculate optimal image count based on device memory
  static int _calculateOptimalImageCount(int availableMemoryMB) {
    // Low-end devices: <2GB RAM
    if (availableMemoryMB < 2048) return 30;

    // Mid-range devices: 2-4GB RAM
    if (availableMemoryMB < 4096) return 50;

    // High-end devices: >4GB RAM
    return 100;
  }
}
