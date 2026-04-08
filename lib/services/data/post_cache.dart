import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Cached post data with metadata
class CachedPost {
  final DocumentSnapshot document;
  final DateTime cachedAt;
  final bool isUploading;

  CachedPost({
    required this.document,
    required this.cachedAt,
    required this.isUploading,
  });

  bool get isExpired {
    final now = DateTime.now();
    // Uploading posts don't expire (use real-time listeners)
    if (isUploading) return false;
    // Stable posts expire after 30 seconds
    return now.difference(cachedAt).inSeconds > 30;
  }
}

/// Event for post updates
class PostUpdateEvent {
  final String postId;
  final DocumentSnapshot document;
  final DateTime timestamp;

  PostUpdateEvent({
    required this.postId,
    required this.document,
    required this.timestamp,
  });
}

/// Mixin that provides smart post caching with LRU eviction and real-time listeners
mixin PostCacheMixin {
  FirebaseFirestore get firestore;

  // REQUEST DEDUPLICATION - Track in-flight requests to prevent simultaneous calls
  final Map<String, Future<DocumentSnapshot>> inflightRequests = {};

  // SMART CACHING SYSTEM
  final Map<String, CachedPost> smartPostCache = {};
  final Map<String, StreamSubscription<DocumentSnapshot>> uploadingListeners =
      {};
  static const int maxCachedPosts =
      150; // Reduced from 500 to match feed size and prevent excessive memory usage

  // Event bus for post updates
  final StreamController<PostUpdateEvent> postEventBus =
      StreamController<PostUpdateEvent>.broadcast();

  // Track posts not found to avoid repeated lookups and errors
  final Set<String> notFoundPosts = {};
  final Set<String> notFoundSpacePosts = {};

  // Cache mapping from postId to spaceId discovered via reverse lookup
  final Map<String, String> postSpaceCache = {};

  /// Stream of post update events
  Stream<PostUpdateEvent> get postUpdatesStream => postEventBus.stream;

  /// Synchronous cache peek for instant rendering (returns null if missing/expired)
  DocumentSnapshot? peekPostInCache(String postId) {
    final cachedPost = smartPostCache[postId];
    if (cachedPost != null && !cachedPost.isExpired) {
      touchCacheEntry(postId, cachedPost);
      return cachedPost.document;
    }
    return null;
  }

  void touchCacheEntry(String postId, CachedPost cachedPost) {
    // Refresh LRU order by re-inserting
    smartPostCache.remove(postId);
    smartPostCache[postId] = cachedPost;
  }

  void enforceCacheLimit() {
    if (smartPostCache.length <= maxCachedPosts) return;

    // Evict oldest non-uploading entries first (LRU)
    final keys = smartPostCache.keys.toList(growable: false);
    final evictedKeys = <String>[];

    for (final key in keys) {
      if (smartPostCache.length <= maxCachedPosts) break;
      final entry = smartPostCache[key];
      if (entry == null || entry.isUploading) {
        continue; // Keep uploading posts
      }

      smartPostCache.remove(key);
      evictedKeys.add(key);

      // Clean up any associated listeners
      uploadingListeners[key]?.cancel();
      uploadingListeners.remove(key);
    }

    if (evictedKeys.isNotEmpty) {
      AppLogger.d('PostDbService: Evicted old cache entries (LRU)',
          category: LogCategory.performance,
          data: {
            'evictedCount': evictedKeys.length,
            'remainingCount': smartPostCache.length,
            'maxSize': maxCachedPosts,
          });
    }
  }

  /// Handle post data update with smart caching and real-time listeners
  Future<void> handlePostDataUpdate(
      String postId, DocumentSnapshot document) async {
    if (!document.exists) return;

    final data = document.data() as Map<String, dynamic>?;
    if (data == null) return;

    final isUploading = data['uploading'] as bool? ?? false;
    final now = DateTime.now();

    // Create cached post
    final cachedPost = CachedPost(
      document: document,
      cachedAt: now,
      isUploading: isUploading,
    );

    // Update smart cache
    smartPostCache[postId] = cachedPost;
    enforceCacheLimit();

    if (isUploading) {
      // Set up real-time listener for uploading posts
      await setupRealTimeListener(postId);
    } else {
      // Remove any existing listener (post finished uploading)
      await removeRealTimeListener(postId);
    }

    // Emit event for widgets to update
    postEventBus.add(PostUpdateEvent(
      postId: postId,
      document: document,
      timestamp: now,
    ));
  }

  /// Set up real-time listener for uploading posts
  Future<void> setupRealTimeListener(String postId) async {
    // Cancel existing listener if any
    await removeRealTimeListener(postId);

    try {
      final subscription = firestore
          .collection('posts')
          .doc(postId)
          .snapshots()
          .listen((DocumentSnapshot snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          final isUploading = data?['uploading'] as bool? ?? false;

          AppLogger.w('📡 REAL-TIME UPDATE RECEIVED',
              category: LogCategory.general,
              data: {
                'postId': postId,
                'uploading': isUploading,
                'hasVideo': data?.containsKey('video') ?? false,
                'hasThumbnail': data?.containsKey('thumbnail') ?? false
              });

          // Update cache
          final cachedPost = CachedPost(
            document: snapshot,
            cachedAt: DateTime.now(),
            isUploading: isUploading,
          );
          smartPostCache[postId] = cachedPost;
          enforceCacheLimit();

          // If upload finished, remove listener
          if (!isUploading) {
            AppLogger.w('🎉 UPLOAD COMPLETED - Switching to timed cache',
                category: LogCategory.general, data: {'postId': postId});
            removeRealTimeListener(postId);
          }

          // Emit event
          postEventBus.add(PostUpdateEvent(
            postId: postId,
            document: snapshot,
            timestamp: DateTime.now(),
          ));
        }
      }, onError: (error) {
        AppLogger.e('Real-time listener error',
            category: LogCategory.general,
            error: error,
            data: {'postId': postId});
        removeRealTimeListener(postId);
      });

      uploadingListeners[postId] = subscription;
    } catch (e) {
      AppLogger.e('Failed to setup real-time listener',
          category: LogCategory.general, error: e, data: {'postId': postId});
    }
  }

  /// Remove real-time listener for a post
  Future<void> removeRealTimeListener(String postId) async {
    final subscription = uploadingListeners.remove(postId);
    if (subscription != null) {
      await subscription.cancel();
      AppLogger.d('Real-time listener removed',
          category: LogCategory.general, data: {'postId': postId});
    }
  }

  /// Clear expired cache entries manually (called periodically)
  void clearExpiredCacheEntries() {
    final expired = <String>[];

    for (final entry in smartPostCache.entries) {
      if (entry.value.isExpired) {
        expired.add(entry.key);
      }
    }

    for (final postId in expired) {
      smartPostCache.remove(postId);
    }

    if (expired.isNotEmpty) {
      AppLogger.d('Cleared expired cache entries',
          category: LogCategory.general,
          data: {'clearedCount': expired.length});
    }
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStatistics() {
    final stablePosts =
        smartPostCache.values.where((p) => !p.isUploading).length;
    final uploadingPostsCount =
        smartPostCache.values.where((p) => p.isUploading).length;

    return {
      'totalCached': smartPostCache.length,
      'stablePosts': stablePosts,
      'uploadingPosts': uploadingPostsCount,
      'activeListeners': uploadingListeners.length,
      'inflightRequests': inflightRequests.length,
      'spaceCache': postSpaceCache.length,
    };
  }
}
