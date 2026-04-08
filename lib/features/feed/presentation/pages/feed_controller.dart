import 'package:flutter/foundation.dart';
import 'package:aurogram/services/feed_state_manager.dart';
import 'package:aurogram/services/batch_data_loader.dart';

/// Post interaction state (separate from widget)
/// This is what production apps (Instagram, TikTok) do - keep state outside widgets
class PostInteractionState {
  int likeCount;
  bool isLiked;
  int replyCount;
  Duration? videoPosition;
  Duration? audioPosition;

  // NEW: Store user and space data to avoid repeated fetches
  UserData? userData;
  SpaceData? spaceData;

  PostInteractionState({
    this.likeCount = 0,
    this.isLiked = false,
    this.replyCount = 0,
    this.videoPosition,
    this.audioPosition,
    this.userData,
    this.spaceData,
  });

  /// Convert to snapshot for FeedStateManager persistence
  PostStateSnapshot toSnapshot(String postId) {
    return PostStateSnapshot(
      postId: postId,
      savedAt: DateTime.now(),
      likeCount: likeCount,
      isLiked: isLiked,
      replyCount: replyCount,
      videoPosition: videoPosition,
      wasPlaying: false, // Not tracking play state for now
    );
  }

  /// Restore from snapshot
  factory PostInteractionState.fromSnapshot(PostStateSnapshot? snapshot) {
    if (snapshot == null) {
      return PostInteractionState();
    }

    return PostInteractionState(
      likeCount: snapshot.likeCount,
      isLiked: snapshot.isLiked,
      replyCount: snapshot.replyCount,
      videoPosition: snapshot.videoPosition,
    );
  }

  /// Create a copy with updated values
  PostInteractionState copyWith({
    int? likeCount,
    bool? isLiked,
    int? replyCount,
    Duration? videoPosition,
    Duration? audioPosition,
    UserData? userData,
    SpaceData? spaceData,
  }) {
    return PostInteractionState(
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      replyCount: replyCount ?? this.replyCount,
      videoPosition: videoPosition ?? this.videoPosition,
      audioPosition: audioPosition ?? this.audioPosition,
      userData: userData ?? this.userData,
      spaceData: spaceData ?? this.spaceData,
    );
  }
}

/// Feed Controller - Manages state for all posts in feed
///
/// Production apps (Instagram, TikTok) hoist state outside widgets:
/// - Widgets are disposable and lightweight
/// - State persists in controller
/// - Fast rebuild when scrolling back
/// - No need for AutomaticKeepAlive
class FeedController extends ChangeNotifier {
  final Map<String, PostInteractionState> _postStates = {};
  final FeedStateManager _stateManager = FeedStateManager();
  final BatchDataLoader _batchLoader = BatchDataLoader();

  /// Get or create state for a post
  /// Tries to restore from FeedStateManager on first access
  PostInteractionState getPostState(String postId) {
    if (!_postStates.containsKey(postId)) {
      // Try to restore from persistent cache
      final snapshot = _stateManager.getState(postId);
      _postStates[postId] = PostInteractionState.fromSnapshot(snapshot);
    }
    return _postStates[postId]!;
  }

  /// Check if state exists (without creating)
  bool hasState(String postId) {
    return _postStates.containsKey(postId);
  }

  /// Batch load counters for multiple posts
  /// This should be called when posts enter the viewport
  Future<void> batchLoadCounters(List<String> postIds) async {
    if (postIds.isEmpty) return;

    final counters = await _batchLoader.batchLoadCounters(postIds);

    for (final entry in counters.entries) {
      final state = getPostState(entry.key);
      state.likeCount = entry.value.likeCount;
      state.replyCount = entry.value.replyCount;
      state.isLiked = entry.value.isLiked;
    }
    // NO notifyListeners() - posts will read state when they build
  }

  /// Load user data for a post (with deduplication)
  Future<UserData?> loadUserData(String userId) async {
    return await _batchLoader.loadUser(userId);
  }

  /// Load space data for a post (with deduplication)
  Future<SpaceData?> loadSpaceData(String spaceId) async {
    return await _batchLoader.loadSpace(spaceId);
  }

  /// Store user data in post state
  void setUserData(String postId, UserData userData) {
    getPostState(postId).userData = userData;
  }

  /// Store space data in post state
  void setSpaceData(String postId, SpaceData spaceData) {
    getPostState(postId).spaceData = spaceData;
  }

  /// Get user data from post state (if cached)
  UserData? getUserData(String postId) {
    return _postStates[postId]?.userData;
  }

  /// Get space data from post state (if cached)
  SpaceData? getSpaceData(String postId) {
    return _postStates[postId]?.spaceData;
  }

  /// Update like count (no rebuild - local state only)
  void updateLike(String postId, int count, bool isLiked) {
    getPostState(postId).likeCount = count;
    getPostState(postId).isLiked = isLiked;
    // NO notifyListeners() - individual posts manage their own UI updates
    // This prevents one post's like from rebuilding the entire feed
  }

  /// Update reply count (no rebuild - local state only)
  void updateReplyCount(String postId, int count) {
    getPostState(postId).replyCount = count;
    // NO notifyListeners() - individual posts manage their own UI updates
    // This prevents one post's reply count from rebuilding the entire feed
  }

  /// Update video position (no notification needed - internal state)
  void updateVideoPosition(String postId, Duration position) {
    getPostState(postId).videoPosition = position;
    // No notifyListeners - position updates are frequent and internal
  }

  /// Update audio position (no notification needed - internal state)
  void updateAudioPosition(String postId, Duration position) {
    getPostState(postId).audioPosition = position;
    // No notifyListeners - position updates are frequent and internal
  }

  /// Save state when widget disposes
  /// Moves state from active memory to FeedStateManager (LRU cache)
  void onPostDisposed(String postId) {
    final state = _postStates[postId];
    if (state != null) {
      // Persist to FeedStateManager
      _stateManager.saveState(state.toSnapshot(postId));

      // Remove from active states (will restore if needed)
      _postStates.remove(postId);
    }
  }

  /// Trim states no longer in feed
  /// Called after feed loads or pagination to prevent unbounded growth
  void trimStatesForFeed(List<String> currentFeedIds) {
    final feedIdSet = currentFeedIds.toSet();
    final toRemove =
        _postStates.keys.where((id) => !feedIdSet.contains(id)).toList();

    // Save to FeedStateManager before removing
    for (final id in toRemove) {
      final state = _postStates[id];
      if (state != null) {
        _stateManager.saveState(state.toSnapshot(id));
      }
      _postStates.remove(id);
    }

    // NO notifyListeners() - this is cleanup, posts manage their own UI
    // Removed states are already off-screen, no UI update needed
  }

  /// Clear all states (e.g., on logout)
  void clearAll() {
    _postStates.clear();
    _stateManager.clearAll();
    _batchLoader.clearCache();
    // NO notifyListeners() - called during logout when UI is transitioning anyway
    // Individual widgets will be disposed naturally during the logout flow
  }

  /// Get cache statistics (for debugging)
  Map<String, dynamic> getStats() {
    return {
      'activeStates': _postStates.length,
      'cachedStates': _stateManager.cacheSize,
      'totalStates': _postStates.length + _stateManager.cacheSize,
      'batchLoader': _batchLoader.getCacheStats(),
    };
  }
}
