import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:aurogram/core/logging/app_logger.dart';

import 'post_cache.dart';
import 'post_crud.dart';
import 'post_queries.dart';

export 'post_cache.dart' show CachedPost, PostUpdateEvent;
export 'post_crud.dart' show PostCrudMixin;
export 'post_queries.dart' show PostQueriesMixin;

/// Service for handling post-related database operations.
///
/// Orchestrates [PostCacheMixin], [PostCrudMixin], and [PostQueriesMixin].
/// Use [PostDbService.instance] or the default factory constructor.
class PostDbService with PostCacheMixin, PostCrudMixin, PostQueriesMixin {
  // Singleton pattern
  static final PostDbService _instance = PostDbService._internal();
  factory PostDbService() => _instance;
  PostDbService._internal();

  @override
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Live current user - never cached, so logout/login always uses the active account.
  @override
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Stream for listening to post updates
  static Stream<PostUpdateEvent> get postUpdates =>
      _instance.postUpdatesStream;

  // User reference for cleanup operations
  User? get user => currentUser;

  /// Gets a post document by ID with SMART CACHING + REAL-TIME LISTENERS
  Future<DocumentSnapshot> getPost(String? postId) async {
    if (postId == null || postId.trim().isEmpty) {
      throw Exception("Post ID is null or empty");
    }

    if (kDebugMode) {
      final postIdShort = postId.substring(0, 4);
      AppLogger.i(
        '🔍 Cache lookup',
        category: LogCategory.performance,
        data: {
          'postId': postIdShort,
          'inCache': smartPostCache.containsKey(postId),
          'inFlight': inflightRequests.containsKey(postId),
        },
      );
    }

    // CHECK SMART CACHE FIRST
    final cachedPost = smartPostCache[postId];
    if (cachedPost != null && !cachedPost.isExpired) {
      touchCacheEntry(postId, cachedPost);
      if (kDebugMode) {
        final postIdShort = postId.substring(0, 4);
        AppLogger.i(
          '✅ Cache HIT',
          category: LogCategory.performance,
          data: {'postId': postIdShort},
        );
      }
      return cachedPost.document;
    }

    // CHECK FOR IN-FLIGHT REQUEST - Prevent simultaneous calls for same post
    if (inflightRequests.containsKey(postId)) {
      if (kDebugMode) {
        final postIdShort = postId.substring(0, 4);
        AppLogger.i(
          '⏳ Joining inflight request',
          category: LogCategory.performance,
          data: {'postId': postIdShort},
        );
      }
      return await inflightRequests[postId]!;
    }

    // Create and track the request
    if (kDebugMode) {
      final postIdShort = postId.substring(0, 4);
      AppLogger.i(
        '📥 Creating NEW fetch',
        category: LogCategory.performance,
        data: {'postId': postIdShort},
      );
    }
    final requestFuture = _fetchPostFromFirestore(postId);
    inflightRequests[postId] = requestFuture;

    try {
      final result = await requestFuture;
      await handlePostDataUpdate(postId, result);
      if (kDebugMode) {
        final postIdShort = postId.substring(0, 4);
        AppLogger.i(
          '💾 Wrote to cache',
          category: LogCategory.performance,
          data: {'postId': postIdShort},
        );
      }
      return result;
    } finally {
      // Always clean up the in-flight request when done
      inflightRequests.remove(postId);
    }
  }

  /// Synchronous cache peek for instant rendering (returns null if missing/expired)
  DocumentSnapshot? peekPost(String postId) => peekPostInCache(postId);

  /// Batch-fetch posts by ID. Returns map of id -> snapshot (null if missing/error).
  /// Used by Feed to preload first screen so first paint is smooth (prod-style).
  Future<Map<String, DocumentSnapshot?>> getPosts(List<String> postIds) async {
    if (postIds.isEmpty) return {};
    final entries = await Future.wait(
      postIds.map((id) => getPost(id)
          .then<MapEntry<String, DocumentSnapshot?>>((s) => MapEntry(id, s))
          .catchError((_) => MapEntry<String, DocumentSnapshot?>(id, null))),
    );
    return Map.fromEntries(entries);
  }

  /// Internal method to actually fetch from Firestore
  /// Uses cache-first strategy for faster loading, especially on web
  Future<DocumentSnapshot> _fetchPostFromFirestore(String postId) async {
    try {
      DocumentSnapshot? doc;

      // Try cache first for instant loading
      try {
        doc = await firestore
            .collection('posts')
            .doc(postId)
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(milliseconds: 300));

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          // Validate cached data has required fields and is not uploading
          if (data != null &&
              data['timestamp'] != null &&
              data['author'] != null &&
              data['uploading'] != true) {
            return doc;
          }
          // Cache hit but invalid/uploading - need fresh data
          doc = null;
        }
      } catch (_) {
        // Cache miss or error - continue to server
      }

      // Fetch from server with timeout
      // 10s to handle many parallel fetches (feed loads 15+ posts at once)
      doc = await firestore
          .collection('posts')
          .doc(postId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException("Post fetch timeout: $postId");
      });

      if (!doc.exists) {
        AppLogger.w('Post not found in Firestore',
            category: LogCategory.general, data: {'postId': postId});
        throw Exception("Post not found: $postId");
      }

      // Validate that the post has required fields
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || data['timestamp'] == null || data['author'] == null) {
        AppLogger.w('Post incomplete - missing required fields',
            category: LogCategory.general,
            data: {
              'postId': postId,
              'hasData': data != null,
              'fields': data?.keys.toList()
            });
        // Return the document so UI can render a stable placeholder and
        // real-time listeners can update when the post becomes complete.
        return doc;
      }

      return doc;
    } catch (e) {
      // NO CACHING - Just log and rethrow errors
      if (e is TimeoutException) {
        AppLogger.w('Timeout getting post',
            category: LogCategory.network, data: {'postId': postId});
      } else if (!e.toString().contains('Post not found')) {
        AppLogger.e('Error getting post',
            category: LogCategory.general, error: e, data: {'postId': postId});
      }
      rethrow;
    }
  }

  // ──────────────────────────────────────────────
  // CRUD pass-throughs (delegate to PostCrudMixin but supply onCacheUpdate)
  // ──────────────────────────────────────────────

  @override
  Future<bool> updatePostWithMedia(
      String postId, String videoUrl, String thumbnailUrl,
      {Future<void> Function(String, DocumentSnapshot)? onCacheUpdate}) {
    return super.updatePostWithMedia(
      postId,
      videoUrl,
      thumbnailUrl,
      onCacheUpdate: onCacheUpdate ?? handlePostDataUpdate,
    );
  }

  @override
  Future<bool> updatePostThumbnail(String postId, String thumbnailUrl,
      {Future<void> Function(String, DocumentSnapshot)? onCacheUpdate}) {
    return super.updatePostThumbnail(
      postId,
      thumbnailUrl,
      onCacheUpdate: onCacheUpdate ?? handlePostDataUpdate,
    );
  }

  @override
  Future<bool> updatePostMedia(
      String postId, String videoUrl, String thumbnailUrl,
      {Future<void> Function(String, DocumentSnapshot)? onCacheUpdate}) {
    return super.updatePostMedia(
      postId,
      videoUrl,
      thumbnailUrl,
      onCacheUpdate: onCacheUpdate ?? handlePostDataUpdate,
    );
  }

  @override
  Future<bool> updatePostStatus(String postId, bool uploading,
      {Future<void> Function(String, DocumentSnapshot)? onCacheUpdate}) {
    return super.updatePostStatus(
      postId,
      uploading,
      onCacheUpdate: onCacheUpdate ?? handlePostDataUpdate,
    );
  }

  // ──────────────────────────────────────────────
  // Query pass-throughs (delegate to PostQueriesMixin with getPost callback)
  // ──────────────────────────────────────────────

  @override
  Future<String?> getPostSpace(String postId,
      {Future<DocumentSnapshot> Function(String)? getPost}) {
    return super.getPostSpace(postId, getPost: getPost ?? this.getPost);
  }

  // ──────────────────────────────────────────────
  // Cache management helpers (public API)
  // ──────────────────────────────────────────────

  /// Check if a post is known to be missing
  bool isPostKnownMissing(String? postId) {
    if (postId == null) return true;
    return notFoundPosts.contains(postId);
  }

  /// Mark a post as missing to prevent future fetch attempts
  void markPostAsMissing(String postId) {
    if (postId.isNotEmpty) {
      notFoundPosts.add(postId);
      // Remove from smart cache if present and cancel listeners
      smartPostCache.remove(postId);
      removeRealTimeListener(postId);
    }
  }

  /// Invalidate cache for a specific post (used after deletion)
  void invalidatePostCache(String postId) {
    smartPostCache.remove(postId);
    removeRealTimeListener(postId);
    notFoundPosts.add(postId);

    AppLogger.d('Post cache invalidated and marked as deleted',
        category: LogCategory.general, data: {'postId': postId});
  }

  /// Invalidate cache for an updated post (forces fresh fetch without marking as missing)
  void invalidateUpdatedPostCache(String postId) {
    // Remove from smart cache
    smartPostCache.remove(postId);

    // Remove space cache entries for this post
    postSpaceCache.removeWhere((key, value) => key.startsWith('${postId}_'));

    // Remove from not found tracking
    notFoundPosts.remove(postId);

    // Remove real-time listener
    removeRealTimeListener(postId);
  }

  /// Attempt to get the space ID for a post that might not exist
  Future<String?> _getPostSpaceId(String postId) async {
    // Quick cache hit
    if (postSpaceCache.containsKey(postId)) {
      AppLogger.d('Space lookup cache hit',
          category: LogCategory.general,
          data: {'postId': postId, 'spaceId': postSpaceCache[postId]});
      return postSpaceCache[postId];
    }
    try {
      // Try multiple collections where space references may exist

      // Try spacePosts collection (reverse lookup)
      final spaces =
          await FirebaseFirestore.instance.collection('spacePosts').get();
      for (var space in spaces.docs) {
        final postsRef = space.reference.collection('posts').doc(postId);
        final postDoc = await postsRef.get();
        if (postDoc.exists) {
          postSpaceCache[postId] = space.id;
          AppLogger.i('Space lookup found in spacePosts',
              category: LogCategory.general,
              data: {'postId': postId, 'spaceId': space.id});
          return space.id;
        }
      }

      // If user is logged in, check their feed
      if (user?.uid != null) {
        final userFeedRef = FirebaseFirestore.instance
            .collection('userFeed')
            .doc(user!.uid)
            .collection('posts')
            .doc(postId);

        final userFeedDoc = await userFeedRef.get();
        if (userFeedDoc.exists && userFeedDoc.data()?['space'] != null) {
          final spaceId = userFeedDoc.data()?['space'] as String;
          postSpaceCache[postId] = spaceId;
          AppLogger.i('Space lookup found in userFeed',
              category: LogCategory.general,
              data: {'postId': postId, 'spaceId': spaceId});
          return spaceId;
        }
      }
    } catch (e) {
      // Ignore errors in lookup
    }
    return null;
  }

  /// Clean up missing post references in the background
  @override
  void cleanupMissingPostReferences(
    String postId, {
    Future<String?> Function(String)? getPostSpaceId,
    Future<void> Function(String, String)? cleanupSpacePost,
    Future<bool> Function(String?)? deleteFromUserFeed,
  }) {
    super.cleanupMissingPostReferences(
      postId,
      getPostSpaceId: getPostSpaceId ?? _getPostSpaceId,
      cleanupSpacePost: cleanupSpacePost ??
          (id, spaceId) =>
              cleanupMissingSpacePost(id, spaceId, notFoundSpacePosts),
      deleteFromUserFeed: deleteFromUserFeed ?? deleteErroredPost,
    );
  }

  // ──────────────────────────────────────────────
  // Singleton lifecycle
  // ──────────────────────────────────────────────

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() => getCacheStatistics();

  /// Get singleton instance
  static PostDbService get instance => _instance;

  /// Static methods for backward compatibility and convenience
  static Map<String, dynamic> getStaticCacheStats() =>
      _instance.getCacheStats();
  static void clearStaticExpiredCache() => _instance.clearExpiredCache();
  static Future<void> disposeStatic() => _instance.dispose();

  /// Clear expired cache entries manually (called periodically)
  void clearExpiredCache() => clearExpiredCacheEntries();

  /// SINGLETON SAFETY: Partial cleanup method that doesn't destroy the entire service
  /// WARNING: This is a SINGLETON - dispose() should normally NEVER be called.
  /// This method only clears caches and listeners but keeps the service functional.
  Future<void> dispose() async {
    AppLogger.w(
        '⚠️ PostDbService SINGLETON dispose() called - performing PARTIAL cleanup only',
        category: LogCategory.general,
        data: {
          'activeListeners': uploadingListeners.length,
          'cachedPosts': smartPostCache.length,
          'inflightRequests': inflightRequests.length,
          'warning': 'Singleton dispose should not normally be called'
        });

    // Cancel all real-time listeners but keep the service functional
    final futures = <Future>[];
    for (final subscription in uploadingListeners.values) {
      futures.add(subscription.cancel());
    }
    await Future.wait(futures);
    uploadingListeners.clear();

    // Clear caches (but service remains functional for new requests)
    smartPostCache.clear();
    inflightRequests.clear();
    postSpaceCache.clear();

    // SINGLETON SAFETY: DO NOT close event bus to keep service functional
    // Event bus remains open to maintain post update notifications across the app
    AppLogger.w('Event bus preserved to maintain singleton functionality',
        category: LogCategory.general,
        data: {'eventBusClosed': postEventBus.isClosed});

    AppLogger.w(
        'PostDbService partial cleanup completed - service remains functional',
        category: LogCategory.general);
  }
}
