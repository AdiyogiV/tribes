import 'dart:collection';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Video controller with metadata
class PooledController {
  final VideoPlayerController controller;
  final DateTime createdAt;
  final String postId;
  DateTime lastAccessedAt;

  PooledController({
    required this.controller,
    required this.createdAt,
    required this.postId,
    required this.lastAccessedAt,
  });
}

/// LRU Video Controller Pool
///
/// Production apps (TikTok, Instagram) don't keep all video controllers alive.
/// Instead, they maintain a small pool (5-10) and dispose old controllers using LRU eviction.
///
/// Benefits:
/// - Bounded memory (max 5 controllers = ~500MB instead of unbounded)
/// - Controllers are reusable (same video can get same controller back)
/// - Automatic disposal of unused controllers
/// - Fast initialization for recent videos (already in pool)
class VideoControllerPool {
  // Singleton
  static final VideoControllerPool _instance = VideoControllerPool._internal();
  factory VideoControllerPool() => _instance;
  VideoControllerPool._internal();

  // Pool configuration
  // Simple LRU: Keep only 5 most recent controllers
  // Production apps (Instagram/TikTok) use small pools (3-7 controllers)
  // Visible video + 2-3 ahead/behind = enough for smooth UX
  static int maxControllers =
      kIsWeb ? 7 : 4; // Smaller pool on mobile to avoid decoder pressure
  static const Duration controllerTTL = Duration(minutes: 3); // Faster cleanup

  // Pool storage (LRU via LinkedHashMap insertion order)
  final LinkedHashMap<String, PooledController> _pool = LinkedHashMap();

  /// Get controller from pool or null if not present
  /// Updates LRU order when accessed
  PooledController? getController(String postId) {
    final pooled = _pool[postId];

    if (pooled != null) {
      // Update LRU (move to end)
      _pool.remove(postId);
      pooled.lastAccessedAt = DateTime.now();
      _pool[postId] = pooled;

      AppLogger.d('VideoPool: Retrieved from pool',
          category: LogCategory.media,
          data: {'postId': postId, 'poolSize': _pool.length});
    }

    return pooled;
  }

  /// Take controller from pool (removes it) for ownership transfer
  PooledController? takeController(String postId) {
    final pooled = _pool.remove(postId);
    if (pooled != null) {
      AppLogger.d('VideoPool: Taken from pool',
          category: LogCategory.media,
          data: {'postId': postId, 'poolSize': _pool.length});
    }
    return pooled;
  }

  /// Add controller to pool
  /// Automatically evicts oldest if at capacity
  void addController(String postId, VideoPlayerController controller) {
    // Remove if already exists (update case)
    final existing = _pool[postId];
    if (existing != null) {
      _pool.remove(postId);
      // Don't dispose - we're updating the same controller
    }

    // Evict oldest if at capacity
    while (_pool.length >= maxControllers) {
      final oldestEntry = _pool.entries.first;
      final oldest = oldestEntry.value;

      AppLogger.d('VideoPool: Evicting oldest controller (LRU)',
          category: LogCategory.media,
          data: {
            'evictedPostId': oldest.postId,
            'age': DateTime.now().difference(oldest.createdAt).inSeconds,
            'reason': 'pool_full'
          });

      _disposeController(oldest.controller);
      _pool.remove(oldestEntry.key);
    }

    // Add to pool (at end = most recent)
    final pooled = PooledController(
      controller: controller,
      createdAt: DateTime.now(),
      postId: postId,
      lastAccessedAt: DateTime.now(),
    );

    _pool[postId] = pooled;

    AppLogger.i('VideoPool: Added controller',
        category: LogCategory.media,
        data: {'postId': postId, 'poolSize': _pool.length});
  }

  /// Remove controller from pool (when post is manually disposed)
  void removeController(String postId) {
    final pooled = _pool.remove(postId);
    if (pooled != null) {
      _disposeController(pooled.controller);

      AppLogger.d('VideoPool: Removed controller',
          category: LogCategory.media,
          data: {'postId': postId, 'poolSize': _pool.length});
    }
  }

  /// Clean up expired controllers (called periodically)
  void cleanupExpired() {
    final now = DateTime.now();
    final toRemove = <String>[];

    for (final entry in _pool.entries) {
      final pooled = entry.value;
      final age = now.difference(pooled.lastAccessedAt);

      if (age > controllerTTL) {
        toRemove.add(entry.key);
      }
    }

    for (final postId in toRemove) {
      final pooled = _pool.remove(postId);
      if (pooled != null) {
        AppLogger.d('VideoPool: Cleaned up expired controller',
            category: LogCategory.media,
            data: {
              'postId': postId,
              'age': now.difference(pooled.lastAccessedAt).inMinutes
            });
        _disposeController(pooled.controller);
      }
    }

    if (toRemove.isNotEmpty) {
      AppLogger.i('VideoPool: Cleanup complete',
          category: LogCategory.media,
          data: {'removed': toRemove.length, 'remaining': _pool.length});
    }
  }

  /// Clear entire pool (e.g., on logout or memory warning)
  void clearAll() {
    AppLogger.i('VideoPool: Clearing all controllers',
        category: LogCategory.media, data: {'count': _pool.length});

    for (final pooled in _pool.values) {
      _disposeController(pooled.controller);
    }

    _pool.clear();
  }

  /// Get current pool statistics
  Map<String, dynamic> getStats() {
    return {
      'poolSize': _pool.length,
      'maxSize': maxControllers,
      'utilizationPercent': (_pool.length / maxControllers * 100).round(),
      'controllers': _pool.keys.toList(),
    };
  }

  /// Safely dispose controller
  void _disposeController(VideoPlayerController controller) {
    try {
      controller.pause();
      controller.dispose();
    } catch (e) {
      // Already disposed or error - ignore
      AppLogger.w('VideoPool: Error disposing controller',
          category: LogCategory.media, data: {'error': e.toString()});
    }
  }

  /// Check if controller exists in pool
  bool hasController(String postId) {
    return _pool.containsKey(postId);
  }
}
