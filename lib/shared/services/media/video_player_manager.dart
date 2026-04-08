import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Manages video player instances to prevent memory exhaustion
/// iOS limits AVPlayer to ~4 concurrent instances, Android MediaCodec is similar
/// This manager automatically disposes distant videos to stay under the limit
class VideoPlayerManager extends ChangeNotifier {
  static final VideoPlayerManager _instance = VideoPlayerManager._internal();
  factory VideoPlayerManager() => _instance;
  VideoPlayerManager._internal();

  /// Maximum concurrent video players (iOS AVPlayer limit is ~4, we use 3 for safety)
  static const int maxConcurrentPlayers = 3;
  
  /// How far from current index before auto-disposing a video
  static const int disposeDistance = 3;

  /// Active video controllers mapped by post ID
  final Map<String, VideoPlayerController> _activeControllers = {};
  
  /// Post ID to index mapping for distance-based cleanup
  final Map<String, int> _postIndexMap = {};
  
  /// Current scroll position (post index)
  int _currentIndex = 0;
  
  /// Lock for cleanup to prevent concurrent disposal issues
  bool _isCleaningUp = false;

  /// Get the current scroll index
  int get currentIndex => _currentIndex;

  /// Check if a controller exists for a post
  bool hasController(String postId) => _activeControllers.containsKey(postId);

  /// Get a controller for a post (may be null)
  VideoPlayerController? getController(String postId) => _activeControllers[postId];

  /// Update the current scroll position
  void updateScrollPosition(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    
    // Clean up players that are too far from current position
    _cleanupDistantPlayers();
  }

  /// Mark a post as visible - updates index tracking
  void markVisible(int index, String postId) {
    _postIndexMap[postId] = index;
  }

  /// Mark a post as not visible
  void markNotVisible(int index, String postId) {
    // Keep the index mapping for cleanup purposes - will be removed on dispose
  }

  /// Request a video controller for a post
  /// Returns existing controller or creates a new one if capacity allows
  Future<VideoPlayerController?> requestController({
    required String postId,
    required int index,
    required Future<VideoPlayerController?> Function() createController,
  }) async {
    // Update index mapping
    _postIndexMap[postId] = index;
    
    // Return existing controller if available
    if (_activeControllers.containsKey(postId)) {
      AppLogger.d('VideoPlayerManager: Reusing existing controller for $postId',
          category: LogCategory.media);
      return _activeControllers[postId];
    }

    // Check if we have capacity, clean up if needed
    if (_activeControllers.length >= maxConcurrentPlayers) {
      await _cleanupDistantPlayers();
      
      // Still no capacity after cleanup? Force dispose the farthest one
      if (_activeControllers.length >= maxConcurrentPlayers) {
        await _forceDisposeOne(exceptPostId: postId);
      }
    }

    // Initialize the controller
    try {
      final controller = await createController();
      if (controller != null) {
        _activeControllers[postId] = controller;
        AppLogger.i('VideoPlayerManager: Created controller for $postId (${_activeControllers.length}/$maxConcurrentPlayers)',
            category: LogCategory.media);
        notifyListeners();
      }
      return controller;
    } catch (e) {
      AppLogger.e('VideoPlayerManager: Failed to initialize $postId',
          category: LogCategory.media, error: e);
      return null;
    }
  }

  /// Clean up players that are far from current position
  Future<void> _cleanupDistantPlayers() async {
    if (_isCleaningUp) return;
    _isCleaningUp = true;
    
    try {
      final toDispose = <String>[];
      
      // Find controllers that are far from current position
      for (final entry in _activeControllers.entries) {
        final postId = entry.key;
        final index = _postIndexMap[postId];
        
        if (index == null) {
          // No index tracked - dispose it
          toDispose.add(postId);
          continue;
        }
        
        final distance = (index - _currentIndex).abs();
        if (distance > disposeDistance) {
          toDispose.add(postId);
        }
      }
      
      // Dispose distant controllers
      for (final postId in toDispose) {
        await _disposeControllerInternal(postId);
      }
      
      if (toDispose.isNotEmpty) {
        AppLogger.i('VideoPlayerManager: Auto-disposed ${toDispose.length} distant videos (now ${_activeControllers.length}/$maxConcurrentPlayers)',
            category: LogCategory.media);
      }
    } finally {
      _isCleaningUp = false;
    }
  }
  
  /// Force dispose one controller (the farthest from current position)
  Future<void> _forceDisposeOne({String? exceptPostId}) async {
    if (_activeControllers.isEmpty) return;
    
    String? farthestPostId;
    int maxDistance = -1;
    
    for (final entry in _activeControllers.entries) {
      if (entry.key == exceptPostId) continue;
      
      final index = _postIndexMap[entry.key];
      if (index == null) {
        // Unknown index - dispose this one first
        farthestPostId = entry.key;
        break;
      }
      
      final distance = (index - _currentIndex).abs();
      if (distance > maxDistance) {
        maxDistance = distance;
        farthestPostId = entry.key;
      }
    }
    
    if (farthestPostId != null) {
      AppLogger.i('VideoPlayerManager: Force disposing $farthestPostId (distance: $maxDistance)',
          category: LogCategory.media);
      await _disposeControllerInternal(farthestPostId);
    }
  }
  
  /// Internal dispose - doesn't notify (caller handles that)
  Future<void> _disposeControllerInternal(String postId) async {
    final controller = _activeControllers.remove(postId);
    _postIndexMap.remove(postId);
    
    if (controller != null) {
      try {
        // Only pause if initialized - accessing value on disposed controller throws
        if (controller.value.isInitialized) {
          await controller.pause();
        }
      } catch (e) {
        // Controller might already be disposed or in bad state - ignore
      }
      try {
        await controller.dispose();
      } catch (e) {
        AppLogger.w('VideoPlayerManager: Error during dispose of $postId',
            category: LogCategory.media, data: {'error': e.toString()});
      }
    }
  }

  /// Dispose a specific controller (called by widget dispose)
  Future<void> disposeController(String postId) async {
    await _disposeControllerInternal(postId);
    AppLogger.d('VideoPlayerManager: Manual dispose $postId (${_activeControllers.length}/$maxConcurrentPlayers)',
        category: LogCategory.media);
    notifyListeners();
  }

  /// Dispose all controllers (e.g., when leaving feed)
  Future<void> disposeAll() async {
    AppLogger.i('VideoPlayerManager: Disposing all ${_activeControllers.length} controllers',
        category: LogCategory.media);
    
    final postIds = _activeControllers.keys.toList();
    for (final postId in postIds) {
      await _disposeControllerInternal(postId);
    }
    
    _currentIndex = 0;
    notifyListeners();
  }

  /// Get the number of active controllers
  int get activeCount => _activeControllers.length;

  /// Check if we have capacity for more players
  bool get hasCapacity => _activeControllers.length < maxConcurrentPlayers;
  
  /// Debug: Print current state
  void debugPrintState() {
    AppLogger.d('VideoPlayerManager state:', category: LogCategory.media, data: {
      'activeCount': _activeControllers.length,
      'currentIndex': _currentIndex,
      'activePostIds': _activeControllers.keys.toList(),
      'postIndices': _postIndexMap,
    });
  }
}

