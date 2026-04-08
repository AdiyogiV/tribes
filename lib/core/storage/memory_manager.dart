import 'dart:async';
import 'dart:io';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/config/app_config.dart';

/// Manages memory usage in the application to prevent OOM issues
class MemoryManager {
  // Singleton instance
  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();

  // Cache statistics
  int _defaultCacheSize = 1000; // Default Flutter cache size
  bool _lowMemoryMode = false;
  bool _initialized = false;

  // Callbacks for low memory situations
  final List<VoidCallback> _lowMemoryCallbacks = [];

  // Memory pressure thresholds (in MB) - used for pressure detection
  static const int _highMemoryThreshold = 150; // 150MB
  static const int _criticalMemoryThreshold = 200; // 200MB

  // Caches registered with the memory manager
  final Map<String, int> _registeredCaches = {};

  // Track memory usage history
  final Queue<double> _memoryUsageHistory = Queue<double>();
  static const int _maxHistorySize = 10;

  /// Initialize the memory manager
  Future<void> initialize({bool enableAutoCleanup = true}) async {
    if (_initialized) return;

    try {
      AppLogger.d('Initializing memory manager',
          category: LogCategory.performance);

      // Register with unified timer coordinator for monitoring
      AppLogger.d('Memory manager will be coordinated by TimerCoordinator',
          category: LogCategory.performance);

      _initialized = true;
    } catch (e) {
      AppLogger.w('Error initializing memory manager',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  /// Enable full features of the memory manager (called after app is visible)
  Future<void> enableFullFeatures() async {
    if (!_initialized) return;

    try {
      AppLogger.d('Enabling full memory manager features',
          category: LogCategory.performance);

      // Full features now managed by TimerCoordinator
      AppLogger.d('Memory manager full features enabled via TimerCoordinator',
          category: LogCategory.performance);

      _initialized = true;
    } catch (e) {
      AppLogger.w('Error enabling full memory manager features',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  // Monitoring now handled by TimerCoordinator - these methods are kept for API compatibility

  /// Check current memory pressure (called by TimerCoordinator)
  Future<void> checkMemoryPressure() async {
    try {
      // Get memory usage metrics
      final currentUsage = _getCurrentMemoryUsageMB();

      // Track memory history
      _trackMemoryUsage(currentUsage);

      // Detect rapid memory growth
      if (_detectMemoryPressure()) {
        AppLogger.w('Memory pressure detected',
            category: LogCategory.performance,
            data: {
              'usageMB': currentUsage,
              'threshold': _highMemoryThreshold,
              'historySize': _memoryUsageHistory.length
            });

        // Notify all registered callbacks
        _notifyLowMemory();
      }
    } catch (e) {
      // Ignore errors in monitoring
    }
  }

  /// Add memory usage to history queue
  void _trackMemoryUsage(double memoryUsageMB) {
    _memoryUsageHistory.add(memoryUsageMB);
    if (_memoryUsageHistory.length > _maxHistorySize) {
      _memoryUsageHistory.removeFirst();
    }
  }

  /// Detect if we have memory pressure based on recent history
  bool _detectMemoryPressure() {
    if (_memoryUsageHistory.length < 3) return false;

    // Get the average growth rate across history
    double previousUsage = _memoryUsageHistory.first;
    double latestUsage = _memoryUsageHistory.last;
    double growthRate = (latestUsage - previousUsage) / previousUsage;

    // We consider memory pressure if growth rate > 20% in our tracking period
    // or if we're above the high memory threshold
    return growthRate > 0.2 ||
        (_memoryUsageHistory.isNotEmpty &&
            _memoryUsageHistory.last > _highMemoryThreshold);
  }

  /// Get current memory usage in MB
  double _getCurrentMemoryUsageMB() {
    try {
      // Get actual memory usage from Flutter binding
      final binding = WidgetsBinding.instance;
      if (binding is WidgetsFlutterBinding) {
        // Use image cache size as a proxy for memory usage
        final imageCache = PaintingBinding.instance.imageCache;
        final imageCacheSize =
            imageCache.currentSizeBytes / (1024 * 1024); // MB

        // Estimate total app memory based on cache usage and registered caches
        double estimatedMemoryMB = imageCacheSize;
        for (final cacheSize in _registeredCaches.values) {
          estimatedMemoryMB += (cacheSize / 1024); // Convert KB to MB
        }

        return estimatedMemoryMB.clamp(10.0, 500.0); // Reasonable bounds
      }
    } catch (e) {
      AppLogger.w('Error getting memory usage',
          category: LogCategory.performance, data: {'error': e.toString()});
    }

    // Fallback to conservative estimate
    return 50.0;
  }

  /// Register a cache with the memory manager
  void registerCache(String cacheId, int sizeKb) {
    _registeredCaches[cacheId] = sizeKb;
    AppLogger.d('Cache registered with memory manager',
        category: LogCategory.performance,
        data: {'cacheId': cacheId, 'sizeKb': sizeKb});
  }

  /// Unregister a cache
  void unregisterCache(String cacheId) {
    _registeredCaches.remove(cacheId);
  }

  /// Add a callback to be called when memory is low
  void addLowMemoryCallback(VoidCallback callback) {
    _lowMemoryCallbacks.add(callback);
  }

  /// Remove a previously registered callback
  void removeLowMemoryCallback(VoidCallback callback) {
    _lowMemoryCallbacks.remove(callback);
  }

  /// Clear memory caches based on severity
  void clearMemoryCaches({CleanupType cleanupType = CleanupType.normal}) {
    _notifyLowMemory();

    AppLogger.d('Memory caches cleared',
        category: LogCategory.performance,
        data: {'cleanupType': cleanupType.toString()});
  }

  /// Call all registered callbacks
  void _notifyLowMemory() {
    for (final callback in _lowMemoryCallbacks) {
      try {
        callback();
      } catch (e) {
        AppLogger.w('Error in low memory callback',
            category: LogCategory.performance, data: {'error': e.toString()});
      }
    }
  }

  /// Public method for triggering low memory callbacks
  void notifyLowMemory() {
    _notifyLowMemory();
  }

  /// Monitor frame rate to detect UI jank
  void monitorFrameRate(Duration frameTime) {
    if (frameTime.inMilliseconds > 100) {
      // Clear caches if we see very slow frames
      _notifyLowMemory();
    }
  }

  /// Dispose memory manager resources
  void dispose() {
    // No timers to cancel - managed by TimerCoordinator
    _lowMemoryCallbacks.clear();
    _registeredCaches.clear();
    _memoryUsageHistory.clear();

    AppLogger.d('MemoryManager disposed successfully',
        category: LogCategory.performance);
  }

  /// Optimize image cache size based on device capabilities
  Future<void> optimizeImageCacheForDevice() async {
    try {
      // Default sizes based on platform
      int maxSizeBytes = 30 * 1024 * 1024; // 30MB default
      int maxSizeCount = 100; // 100 images default

      // Check if we can get device info to make better decisions
      if (!kIsWeb) {
        // For mobile, adjust based on total RAM if available
        // This would require device_info_plus package
        maxSizeBytes = 20 * 1024 * 1024; // More conservative 20MB for mobile
        maxSizeCount = 80; // Reduce max count for mobile
      }

      // Apply optimized cache settings
      PaintingBinding.instance.imageCache.maximumSizeBytes = maxSizeBytes;
      PaintingBinding.instance.imageCache.maximumSize = maxSizeCount;

      // Store the values for later reference
      _defaultCacheSize = maxSizeCount;

      AppLogger.d('Image cache optimized',
          category: LogCategory.performance,
          data: {'maxSizeBytes': maxSizeBytes, 'maxSizeCount': maxSizeCount});
    } catch (e) {
      AppLogger.w('Failed to optimize image cache',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  /// Set up system memory warning listeners
  void setupLowMemoryListeners() {
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      try {
        // On iOS/macOS we can listen for memory warnings from the OS
        // Use the WidgetsBinding to listen for didHaveMemoryPressure
        WidgetsBinding.instance.addObserver(_MemoryPressureObserver(this));
        AppLogger.d('Initialized iOS/macOS memory pressure observer',
            category: LogCategory.performance);
      } catch (e) {
        AppLogger.w('Failed to initialize memory pressure observer',
            category: LogCategory.performance, data: {'error': e.toString()});
      }
    }
  }

  /// Periodic cleanup now managed by TimerCoordinator
  void setupPeriodicCleanup() {
    // No-op: TimerCoordinator handles periodic cleanup scheduling
    AppLogger.d('Periodic cleanup managed by TimerCoordinator',
        category: LogCategory.performance);
  }

  /// Handle memory pressure from the system
  void handleMemoryPressure() {
    AppLogger.i('System memory pressure detected',
        category: LogCategory.performance);

    // Enable low memory mode which will reduce cache sizes
    enableLowMemoryMode();

    // Perform aggressive cleanup
    clearMemoryCaches(cleanupType: CleanupType.aggressive);

    // Schedule a delayed restoration of normal operation
    Future.delayed(Duration(minutes: 2), () {
      if (_lowMemoryMode) {
        disableLowMemoryMode();
      }
    });
  }

  /// Enable low memory mode to reduce memory usage
  void enableLowMemoryMode() {
    if (_lowMemoryMode) return;

    _lowMemoryMode = true;
    AppLogger.i('Enabling low memory mode', category: LogCategory.performance);

    // Use critical threshold to determine aggressive cleanup
    if (_memoryUsageHistory.isNotEmpty &&
        _memoryUsageHistory.last > _criticalMemoryThreshold) {
      clearMemoryCaches(cleanupType: CleanupType.aggressive);
    }

    // Try to reduce image cache size by 50%
    try {
      _defaultCacheSize = PaintingBinding.instance.imageCache.maximumSize;
      PaintingBinding.instance.imageCache.maximumSize =
          (_defaultCacheSize * 0.5).round();
      PaintingBinding.instance.imageCache.clear();
    } catch (e) {
      AppLogger.w('Failed to adjust image cache size',
          category: LogCategory.performance, data: {'error': e.toString()});
    }

    // Signal the app to clear other caches
    _notifyLowMemory();
  }

  /// Disable low memory mode when memory usage is back to normal
  void disableLowMemoryMode() {
    if (!_lowMemoryMode) return;

    _lowMemoryMode = false;
    AppLogger.i('Disabling low memory mode', category: LogCategory.performance);

    // Try to restore image cache size
    try {
      if (_defaultCacheSize > 0) {
        PaintingBinding.instance.imageCache.maximumSize = _defaultCacheSize;
      }
    } catch (e) {
      AppLogger.w('Failed to restore image cache size',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  /// Adjust image cache size based on platform and configuration
  void adjustImageCache() {
    try {
      final appConfig = AppConfig();
      int cacheSize = 100;
      int cacheSizeMb = 30;

      // Determine device memory class for better tuning
      // This is a rough estimate based on platform
      final DeviceMemoryClass memoryClass = _estimateDeviceMemoryClass();

      if (kIsWeb) {
        // Use smaller cache for web platform
        cacheSize = 30;
        cacheSizeMb = 15;
      } else if (memoryClass == DeviceMemoryClass.low) {
        // Low-end devices need smaller caches
        cacheSize = 50;
        cacheSizeMb = 20;
      } else if (memoryClass == DeviceMemoryClass.medium) {
        // Medium devices
        cacheSize = 100;
        cacheSizeMb = 30;
      } else {
        // High-end devices can use larger caches
        cacheSize = appConfig.getInt('image_cache_size', defaultValue: 150);
        cacheSizeMb = appConfig.getInt('image_cache_size_mb', defaultValue: 50);
      }

      // Apply the calculated sizes
      PaintingBinding.instance.imageCache.maximumSize = cacheSize;
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          cacheSizeMb * 1024 * 1024;

      AppLogger.d(
          'Image cache configured: ${PaintingBinding.instance.imageCache.maximumSize} images, '
          '$cacheSizeMb MB',
          category: LogCategory.performance,
          data: {'deviceMemoryClass': memoryClass.toString()});
    } catch (e) {
      AppLogger.e('Error adjusting image cache',
          category: LogCategory.performance, error: e);
    }
  }

  /// Estimate the device memory class based on platform and environment
  DeviceMemoryClass _estimateDeviceMemoryClass() {
    if (kIsWeb) {
      return DeviceMemoryClass.medium; // Conservative estimate for web
    }

    if (Platform.isAndroid) {
      // Older Android devices typically have less memory
      return DeviceMemoryClass.medium;
    } else if (Platform.isIOS) {
      // Newer iOS devices typically have more memory
      return DeviceMemoryClass.high;
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      // Desktop platforms generally have more memory
      return DeviceMemoryClass.high;
    }

    // Default to medium for unknown platforms
    return DeviceMemoryClass.medium;
  }

  /// Clear image cache to reclaim memory
  /// [aggressive] - If true, clears all images including actively used ones
  Future<void> clearImageCache({bool aggressive = false}) async {
    try {
      // Start with clearing memory cache
      if (aggressive) {
        // Clear everything in PaintingBinding
        PaintingBinding.instance.imageCache.clear();
        // Reduce maximum size temporarily
        final oldSize = PaintingBinding.instance.imageCache.maximumSize;
        PaintingBinding.instance.imageCache.maximumSize = 1;
        await Future.delayed(const Duration(milliseconds: 50));
        // Restore cache size
        PaintingBinding.instance.imageCache.maximumSize = oldSize;
      } else {
        // Standard cleanup - clear only unused images
        PaintingBinding.instance.imageCache.clearLiveImages();
      }

      // Schedule recreation of key images a short time after cleanup
      // This helps ensure important images are loaded back into memory
      if (aggressive) {
        Timer(Duration(milliseconds: 500), () {
          try {
            // Trigger a signal for image widgets to reload visible images
            _notifyLowMemory();
          } catch (e) {
            // Ignore errors
          }
        });
      }

      // Log the result
      AppLogger.d('Image cache cleared',
          category: LogCategory.performance, data: {'aggressive': aggressive});
    } catch (e) {
      AppLogger.w('Failed to clear image cache',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }
}

/// Observer for memory pressure signals from the OS
class _MemoryPressureObserver with WidgetsBindingObserver {
  final MemoryManager memoryManager;

  _MemoryPressureObserver(this.memoryManager);

  @override
  void didHaveMemoryPressure() {
    memoryManager.handleMemoryPressure();
  }
}

/// Device memory class for better cache tuning
enum DeviceMemoryClass {
  /// Low-end devices with limited memory
  low,

  /// Mid-range devices with adequate memory
  medium,

  /// High-end devices with ample memory
  high,
}

/// Type of memory cleanup to perform
enum CleanupType {
  /// Light cleanup - retain most cached items
  light,

  /// Normal cleanup - balanced approach
  normal,

  /// Aggressive cleanup - clear almost everything
  aggressive,
}
