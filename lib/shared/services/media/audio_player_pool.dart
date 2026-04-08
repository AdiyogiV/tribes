import 'dart:collection';
import 'package:just_audio/just_audio.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Audio player with metadata
class PooledAudioPlayer {
  final AudioPlayer player;
  final DateTime createdAt;
  final String postId;
  DateTime lastAccessedAt;
  
  PooledAudioPlayer({
    required this.player,
    required this.createdAt,
    required this.postId,
    required this.lastAccessedAt,
  });
}

/// LRU Audio Player Pool
/// 
/// Production apps don't keep all audio players alive.
/// Instead, they maintain a small pool (3-5) and dispose old players using LRU eviction.
/// 
/// Benefits:
/// - Bounded memory (max 3 players instead of unbounded)
/// - Players are reusable (same audio can get same player back)
/// - Automatic disposal of unused players
/// - Fast initialization for recent audio (already in pool)
class AudioPlayerPool {
  // Singleton
  static final AudioPlayerPool _instance = AudioPlayerPool._internal();
  factory AudioPlayerPool() => _instance;
  AudioPlayerPool._internal();
  
  // Pool configuration
  // CRITICAL: Must be >= keep-alive window size (currently 40 posts = 20 above + 20 below)
  // Otherwise pool evicts players of kept-alive widgets → disposed player errors
  static const int maxPlayers = 20; // Match keep-alive window (fewer audio posts than video)
  static const Duration playerTTL = Duration(minutes: 5); // Auto-dispose after 5min unused
  
  // Pool storage (LRU via LinkedHashMap insertion order)
  final LinkedHashMap<String, PooledAudioPlayer> _pool = LinkedHashMap();
  
  /// Get player from pool or null if not present
  /// Updates LRU order when accessed
  PooledAudioPlayer? getPlayer(String postId) {
    final pooled = _pool[postId];
    
    if (pooled != null) {
      // Update LRU (move to end)
      _pool.remove(postId);
      pooled.lastAccessedAt = DateTime.now();
      _pool[postId] = pooled;
      
      AppLogger.d('AudioPool: Retrieved from pool',
          category: LogCategory.media,
          data: {'postId': postId, 'poolSize': _pool.length});
    }
    
    return pooled;
  }
  
  /// Add player to pool
  /// Automatically evicts oldest if at capacity
  void addPlayer(String postId, AudioPlayer player) {
    // Remove if already exists (update case)
    final existing = _pool[postId];
    if (existing != null) {
      _pool.remove(postId);
      // Don't dispose - we're updating the same player
    }
    
    // Evict oldest if at capacity
    while (_pool.length >= maxPlayers) {
      final oldestEntry = _pool.entries.first;
      final oldest = oldestEntry.value;
      
      AppLogger.d('AudioPool: Evicting oldest player (LRU)',
          category: LogCategory.media,
          data: {
            'evictedPostId': oldest.postId,
            'age': DateTime.now().difference(oldest.createdAt).inSeconds,
            'reason': 'pool_full'
          });
      
      _disposePlayer(oldest.player);
      _pool.remove(oldestEntry.key);
    }
    
    // Add to pool (at end = most recent)
    final pooled = PooledAudioPlayer(
      player: player,
      createdAt: DateTime.now(),
      postId: postId,
      lastAccessedAt: DateTime.now(),
    );
    
    _pool[postId] = pooled;
    
    AppLogger.i('AudioPool: Added player',
        category: LogCategory.media,
        data: {'postId': postId, 'poolSize': _pool.length});
  }
  
  /// Remove player from pool (when post is manually disposed)
  void removePlayer(String postId) {
    final pooled = _pool.remove(postId);
    if (pooled != null) {
      _disposePlayer(pooled.player);
      
      AppLogger.d('AudioPool: Removed player',
          category: LogCategory.media,
          data: {'postId': postId, 'poolSize': _pool.length});
    }
  }
  
  /// Clean up expired players (called periodically)
  void cleanupExpired() {
    final now = DateTime.now();
    final toRemove = <String>[];
    
    for (final entry in _pool.entries) {
      final pooled = entry.value;
      final age = now.difference(pooled.lastAccessedAt);
      
      if (age > playerTTL) {
        toRemove.add(entry.key);
      }
    }
    
    for (final postId in toRemove) {
      final pooled = _pool.remove(postId);
      if (pooled != null) {
        AppLogger.d('AudioPool: Cleaned up expired player',
            category: LogCategory.media,
            data: {
              'postId': postId,
              'age': now.difference(pooled.lastAccessedAt).inMinutes
            });
        _disposePlayer(pooled.player);
      }
    }
    
    if (toRemove.isNotEmpty) {
      AppLogger.i('AudioPool: Cleanup complete',
          category: LogCategory.media,
          data: {'removed': toRemove.length, 'remaining': _pool.length});
    }
  }
  
  /// Clear entire pool (e.g., on logout or memory warning)
  void clearAll() {
    AppLogger.i('AudioPool: Clearing all players',
        category: LogCategory.media, data: {'count': _pool.length});
    
    for (final pooled in _pool.values) {
      _disposePlayer(pooled.player);
    }
    
    _pool.clear();
  }
  
  /// Get current pool statistics
  Map<String, dynamic> getStats() {
    return {
      'poolSize': _pool.length,
      'maxSize': maxPlayers,
      'utilizationPercent': (_pool.length / maxPlayers * 100).round(),
      'players': _pool.keys.toList(),
    };
  }
  
  /// Safely dispose player
  void _disposePlayer(AudioPlayer player) {
    try {
      player.stop();
      player.dispose();
    } catch (e) {
      // Already disposed or error - ignore
      AppLogger.w('AudioPool: Error disposing player',
          category: LogCategory.media, data: {'error': e.toString()});
    }
  }
  
  /// Check if player exists in pool
  bool hasPlayer(String postId) {
    return _pool.containsKey(postId);
  }
}
