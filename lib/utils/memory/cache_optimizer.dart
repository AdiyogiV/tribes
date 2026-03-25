import 'package:flutter/foundation.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// A utility class for optimizing cache and memory usage throughout the app
class CacheOptimizer {
  /// Maximum time to keep items in memory cache (2 hours)
  static const Duration _maxCacheAge = Duration(hours: 2);

  /// Maximum number of items to keep in cache per category
  static const int _defaultMaxItemsPerCategory = 100;

  /// A map of category-specific cache limits
  static final Map<String, int> _categoryLimits = {
    'posts': 50,
    'users': 30,
    'media': 20,
    'comments': 100,
  };

  /// Start periodic cache cleanup - now managed by TimerCoordinator
  static void startPeriodicCleanup() {
    // No-op: TimerCoordinator handles scheduling
    AppLogger.d('Cache optimizer using unified timer coordination',
        category: LogCategory.performance);
  }

  /// Stop periodic cache cleanup - now managed by TimerCoordinator
  static void stopPeriodicCleanup() {
    // No-op: TimerCoordinator handles cleanup
    AppLogger.d('Cache optimizer cleanup managed by timer coordinator',
        category: LogCategory.performance);
  }

  /// Trigger immediate cache cleanup
  static void triggerCleanup() {
    if (kDebugMode) {
      AppLogger.d('Manual cache cleanup triggered',
          category: LogCategory.performance);
    }

    // This would ideally call into your various cache services
    // For example: locator<CacheService>().cleanExpiredItems();
  }

  /// Get the maximum items allowed for a specific category
  static int getMaxItemsForCategory(String category) {
    return _categoryLimits[category] ?? _defaultMaxItemsPerCategory;
  }

  /// Determine if an item should be evicted based on its age
  static bool shouldEvictBasedOnAge(DateTime createdAt) {
    final age = DateTime.now().difference(createdAt);
    return age > _maxCacheAge;
  }

  /// Dispose all resources - called when shutting down
  static void dispose() {
    // Nothing to dispose now - TimerCoordinator handles everything
    AppLogger.d('Cache optimizer disposed (managed by timer coordinator)',
        category: LogCategory.performance);
  }

  /// Calculate memory-efficient page size for pagination
  /// based on item type and device memory constraints
  static int calculateOptimalPageSize(String itemType,
      {int availableMemoryMB = 4096}) {
    // Default page sizes by item type
    final Map<String, int> defaultPageSizes = {
      'posts': 10,
      'comments': 20,
      'users': 15,
      'media': 5,
    };

    // Base page size
    int basePageSize = defaultPageSizes[itemType] ?? 10;

    // Adjust based on available memory
    if (availableMemoryMB < 2048) {
      // Low memory devices (reduce by 50%)
      return (basePageSize * 0.5).round();
    } else if (availableMemoryMB > 6144) {
      // High memory devices (increase by 50%)
      return (basePageSize * 1.5).round();
    }

    // Default for mid-range devices
    return basePageSize;
  }

  /// Estimate memory usage of a collection
  static int estimateCollectionMemoryUsage(
      String collectionType, int itemCount) {
    // Approximate sizes in KB per item type
    final Map<String, int> approximateSizesKB = {
      'posts': 50, // Post with metadata
      'comments': 5, // Comment with text
      'users': 20, // User profile data
      'media': 500, // Media item (thumbnail)
    };

    final int sizePerItem = approximateSizesKB[collectionType] ?? 10;
    return sizePerItem * itemCount;
  }
}
