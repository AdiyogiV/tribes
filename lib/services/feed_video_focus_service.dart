import 'package:flutter/foundation.dart';

/// Ensures only one feed video plays at a time.
/// MainPlayer registers on init, unregisters on dispose, calls requestFocus when visible and enableVideoAutoplay.
class FeedVideoFocusService {
  final Map<String, VoidCallback> _pauseCallbacks = {};
  String? _focusedPostId;

  /// Register a video player's pause callback for [postId].
  void register(String postId, VoidCallback onPause) {
    if (postId.isEmpty) return;
    _pauseCallbacks[postId] = onPause;
  }

  /// Unregister the callback for [postId] (e.g. on MainPlayer dispose).
  void unregister(String postId) {
    if (postId.isEmpty) return;
    _pauseCallbacks.remove(postId);
    if (_focusedPostId == postId) _focusedPostId = null;
  }

  /// Request focus for [postId]. Pauses the previously focused video if different.
  void requestFocus(String? postId) {
    if (postId == null || postId.isEmpty) return;
    if (_focusedPostId != null && _focusedPostId != postId) {
      final onPause = _pauseCallbacks[_focusedPostId];
      if (onPause != null) {
        onPause();
      }
    }
    _focusedPostId = postId;
  }

  /// Check if [postId] currently has focus (should be the only playing video).
  bool hasFocus(String? postId) {
    if (postId == null || postId.isEmpty) return false;
    return _focusedPostId == postId;
  }
}
