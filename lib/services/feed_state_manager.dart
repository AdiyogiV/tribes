import 'dart:collection';
import 'package:video_player/video_player.dart';

/// Lightweight state snapshot for posts (not full widgets)
/// This is what production apps (Instagram, TikTok) cache
class PostStateSnapshot {
  final String postId;
  final DateTime savedAt;
  
  // Video state
  final Duration? videoPosition;
  final bool wasPlaying;
  
  // Interaction state
  final int likeCount;
  final bool isLiked;
  final int replyCount;
  
  // Reply data (lightweight references)
  final List<String>? replyIds;
  
  PostStateSnapshot({
    required this.postId,
    required this.savedAt,
    this.videoPosition,
    this.wasPlaying = false,
    required this.likeCount,
    required this.isLiked,
    required this.replyCount,
    this.replyIds,
  });
  
  bool get isExpired {
    // State valid for 5 minutes
    return DateTime.now().difference(savedAt).inMinutes > 5;
  }
}

/// Manages ephemeral state for feed posts
/// 
/// Production apps (Instagram, TikTok) separate data from widgets:
/// - Widgets are lightweight and disposable
/// - State is cached separately for instant restoration
/// - LRU eviction keeps memory bounded
/// 
/// This eliminates the need to keep ALL widgets alive while
/// maintaining smooth scroll-back experience.
class FeedStateManager {
  // Singleton
  static final FeedStateManager _instance = FeedStateManager._internal();
  factory FeedStateManager() => _instance;
  FeedStateManager._internal();
  
  // LRU cache with size limit
  static const int _maxStates = 30; // Keep state for last 30 posts
  final LinkedHashMap<String, PostStateSnapshot> _states = LinkedHashMap();
  
  /// Save post state when scrolling away
  void saveState(PostStateSnapshot state) {
    // Remove if exists (will re-add at end for LRU)
    _states.remove(state.postId);
    
    // Add to end (most recent)
    _states[state.postId] = state;
    
    // Evict oldest if over limit
    while (_states.length > _maxStates) {
      final oldestKey = _states.keys.first;
      _states.remove(oldestKey);
    }
  }
  
  /// Restore post state when scrolling back
  PostStateSnapshot? getState(String postId) {
    final state = _states[postId];
    
    // Remove if expired
    if (state != null && state.isExpired) {
      _states.remove(postId);
      return null;
    }
    
    // Move to end (LRU update)
    if (state != null) {
      _states.remove(postId);
      _states[postId] = state;
    }
    
    return state;
  }
  
  /// Remove state for a specific post
  void removeState(String postId) {
    _states.remove(postId);
  }
  
  /// Clear all states (e.g., on logout)
  void clearAll() {
    _states.clear();
  }
  
  /// Get current cache size (for debugging)
  int get cacheSize => _states.length;
}
