import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
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

/// Service for handling post-related database operations
class PostDbService {
  // Singleton pattern
  static final PostDbService _instance = PostDbService._internal();
  factory PostDbService() => _instance;
  PostDbService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Live current user - never cached, so logout/login always uses the active account.
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  // REQUEST DEDUPLICATION - Track in-flight requests to prevent simultaneous calls
  final Map<String, Future<DocumentSnapshot>> _inflightRequests = {};

  // SMART CACHING SYSTEM
  final Map<String, CachedPost> _smartPostCache = {};
  final Map<String, StreamSubscription<DocumentSnapshot>> _uploadingListeners =
      {};
  static const int _maxCachedPosts =
      150; // Reduced from 500 to match feed size and prevent excessive memory usage

  // Event bus for post updates
  final StreamController<PostUpdateEvent> _postEventBus =
      StreamController<PostUpdateEvent>.broadcast();

  // Track posts not found to avoid repeated lookups and errors
  final Set<String> _notFoundPosts = {};
  final Set<String> _notFoundSpacePosts = {};

  // Cache mapping from postId to spaceId discovered via reverse lookup
  final Map<String, String> _postSpaceCache = {};

  // Stream for listening to post updates
  Stream<PostUpdateEvent> get _postUpdatesStream => _postEventBus.stream;

  // Static access to post updates stream
  static Stream<PostUpdateEvent> get postUpdates =>
      _instance._postUpdatesStream;

  // User reference for cleanup operations
  User? get user => _currentUser;

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
          'inCache': _smartPostCache.containsKey(postId),
          'inFlight': _inflightRequests.containsKey(postId),
        },
      );
    }

    // CHECK SMART CACHE FIRST
    final cachedPost = _smartPostCache[postId];
    if (cachedPost != null && !cachedPost.isExpired) {
      _touchCacheEntry(postId, cachedPost);
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
    if (_inflightRequests.containsKey(postId)) {
      if (kDebugMode) {
        final postIdShort = postId.substring(0, 4);
        AppLogger.i(
          '⏳ Joining inflight request',
          category: LogCategory.performance,
          data: {'postId': postIdShort},
        );
      }
      return await _inflightRequests[postId]!;
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
    _inflightRequests[postId] = requestFuture;

    try {
      final result = await requestFuture;
      await _handlePostDataUpdate(postId, result);
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
      _inflightRequests.remove(postId);
    }
  }

  /// Synchronous cache peek for instant rendering (returns null if missing/expired)
  DocumentSnapshot? peekPost(String postId) {
    final cachedPost = _smartPostCache[postId];
    if (cachedPost != null && !cachedPost.isExpired) {
      _touchCacheEntry(postId, cachedPost);
      return cachedPost.document;
    }
    return null;
  }

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
  /// On web, uses shorter timeout and prefers default source for better reliability
  Future<DocumentSnapshot> _fetchPostFromFirestore(String postId) async {
    try {
      DocumentSnapshot? doc;

      // Try cache first for instant loading
      try {
        doc = await _firestore
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
      doc = await _firestore
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

  /// Handle post data update with smart caching and real-time listeners
  Future<void> _handlePostDataUpdate(
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
    _smartPostCache[postId] = cachedPost;
    _enforceCacheLimit();

    if (isUploading) {
      // Set up real-time listener for uploading posts
      await _setupRealTimeListener(postId);
    } else {
      // Remove any existing listener (post finished uploading)
      await _removeRealTimeListener(postId);
    }

    // Emit event for widgets to update
    _postEventBus.add(PostUpdateEvent(
      postId: postId,
      document: document,
      timestamp: now,
    ));
  }

  void _touchCacheEntry(String postId, CachedPost cachedPost) {
    // Refresh LRU order by re-inserting
    _smartPostCache.remove(postId);
    _smartPostCache[postId] = cachedPost;
  }

  void _enforceCacheLimit() {
    if (_smartPostCache.length <= _maxCachedPosts) return;

    // Evict oldest non-uploading entries first (LRU)
    final keys = _smartPostCache.keys.toList(growable: false);
    final evictedKeys = <String>[];

    for (final key in keys) {
      if (_smartPostCache.length <= _maxCachedPosts) break;
      final entry = _smartPostCache[key];
      if (entry == null || entry.isUploading) {
        continue; // Keep uploading posts
      }

      _smartPostCache.remove(key);
      evictedKeys.add(key);

      // Clean up any associated listeners
      _uploadingListeners[key]?.cancel();
      _uploadingListeners.remove(key);
    }

    if (evictedKeys.isNotEmpty) {
      AppLogger.d('PostDbService: Evicted old cache entries (LRU)',
          category: LogCategory.performance,
          data: {
            'evictedCount': evictedKeys.length,
            'remainingCount': _smartPostCache.length,
            'maxSize': _maxCachedPosts,
          });
    }
  }

  /// Set up real-time listener for uploading posts
  Future<void> _setupRealTimeListener(String postId) async {
    // Cancel existing listener if any
    await _removeRealTimeListener(postId);

    try {
      final subscription = _firestore
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
          _smartPostCache[postId] = cachedPost;
          _enforceCacheLimit();

          // If upload finished, remove listener
          if (!isUploading) {
            AppLogger.w('🎉 UPLOAD COMPLETED - Switching to timed cache',
                category: LogCategory.general, data: {'postId': postId});
            _removeRealTimeListener(postId);
          }

          // Emit event
          _postEventBus.add(PostUpdateEvent(
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
        _removeRealTimeListener(postId);
      });

      _uploadingListeners[postId] = subscription;
    } catch (e) {
      AppLogger.e('Failed to setup real-time listener',
          category: LogCategory.general, error: e, data: {'postId': postId});
    }
  }

  /// Remove real-time listener for a post
  Future<void> _removeRealTimeListener(String postId) async {
    final subscription = _uploadingListeners.remove(postId);
    if (subscription != null) {
      await subscription.cancel();
      AppLogger.d('Real-time listener removed',
          category: LogCategory.general, data: {'postId': postId});
    }
  }

  /// SINGLETON SAFETY: Partial cleanup method that doesn't destroy the entire service
  /// WARNING: This is a SINGLETON - dispose() should normally NEVER be called.
  /// This method only clears caches and listeners but keeps the service functional.
  Future<void> dispose() async {
    AppLogger.w(
        '⚠️ PostDbService SINGLETON dispose() called - performing PARTIAL cleanup only',
        category: LogCategory.general,
        data: {
          'activeListeners': _uploadingListeners.length,
          'cachedPosts': _smartPostCache.length,
          'inflightRequests': _inflightRequests.length,
          'warning': 'Singleton dispose should not normally be called'
        });

    // Cancel all real-time listeners but keep the service functional
    final futures = <Future>[];
    for (final subscription in _uploadingListeners.values) {
      futures.add(subscription.cancel());
    }
    await Future.wait(futures);
    _uploadingListeners.clear();

    // Clear caches (but service remains functional for new requests)
    _smartPostCache.clear();
    _inflightRequests.clear();
    _postSpaceCache.clear();

    // SINGLETON SAFETY: DO NOT close event bus to keep service functional
    // Event bus remains open to maintain post update notifications across the app
    AppLogger.w('Event bus preserved to maintain singleton functionality',
        category: LogCategory.general,
        data: {'eventBusClosed': _postEventBus.isClosed});

    AppLogger.w(
        'PostDbService partial cleanup completed - service remains functional',
        category: LogCategory.general);
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    final stablePosts =
        _smartPostCache.values.where((p) => !p.isUploading).length;
    final uploadingPosts =
        _smartPostCache.values.where((p) => p.isUploading).length;

    return {
      'totalCached': _smartPostCache.length,
      'stablePosts': stablePosts,
      'uploadingPosts': uploadingPosts,
      'activeListeners': _uploadingListeners.length,
      'inflightRequests': _inflightRequests.length,
      'spaceCache': _postSpaceCache.length,
    };
  }

  /// Get singleton instance
  static PostDbService get instance => _instance;

  /// Static methods for backward compatibility and convenience
  static Map<String, dynamic> getStaticCacheStats() =>
      _instance.getCacheStats();
  static void clearStaticExpiredCache() => _instance.clearExpiredCache();
  static Future<void> disposeStatic() => _instance.dispose();

  /// Clear expired cache entries manually (called periodically)
  void clearExpiredCache() {
    final expired = <String>[];

    for (final entry in _smartPostCache.entries) {
      if (entry.value.isExpired) {
        expired.add(entry.key);
      }
    }

    for (final postId in expired) {
      _smartPostCache.remove(postId);
    }

    if (expired.isNotEmpty) {
      AppLogger.d('Cleared expired cache entries',
          category: LogCategory.general,
          data: {'clearedCount': expired.length});
    }
  }

  /// Creates a new post document in Firestore
  /// [isProfilePost] - If true, creates a profile post with contextType: 'profile'
  Future<String?> createPostDocument({
    required String space,
    String? title,
    String? replyTo,
    String? link,
    bool isProfilePost = false,
  }) async {
    try {
      if (_currentUser == null) {
        AppLogger.e('User not authenticated for post creation',
            category: LogCategory.general);
        return null;
      }

      // For profile posts, space is the user's own ID
      final effectiveSpace = isProfilePost ? _currentUser!.uid : space;
      final contextType = isProfilePost ? 'profile' : 'space';

      DocumentReference postDoc = await _firestore.collection('posts').add({
        "space": effectiveSpace,
        "author": _currentUser!.uid,
        "title": title,
        "replyTo": replyTo,
        "link": link,
        "uploading": true,
        "postType": "video", // Default to video for existing posts
        "contextType": contextType,
        "isRepost": isProfilePost ? false : null,
        // Write the local thumbnail path for immediate UI feedback; will be overwritten later
        "thumbnail": '',
        "replyCount": 0,
        "timestamp": FieldValue.serverTimestamp(),
      });
      return postDoc.id;
    } catch (e) {
      AppLogger.e('Error creating post document',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return null;
    }
  }

  /// Creates a new text post document in Firestore
  /// [isProfilePost] - If true, creates a profile post with contextType: 'profile'
  Future<String?> createTextPostDocument({
    required String space,
    required String content,
    String? title,
    String? replyTo,
    String? link,
    bool addToSpaceFeed = true,
    bool isProfilePost = false,
  }) async {
    try {
      if (_currentUser == null) {
        AppLogger.e('User not authenticated for post creation',
            category: LogCategory.general);
        return null;
      }

      // For profile posts, space is the user's own ID
      final effectiveSpace = isProfilePost ? _currentUser!.uid : space;
      final contextType = isProfilePost ? 'profile' : 'space';

      DocumentReference postDoc = await _firestore.collection('posts').add({
        "space": effectiveSpace,
        "author": _currentUser!.uid,
        "title": title,
        "content": content,
        "replyTo": replyTo,
        "link": link,
        "uploading": false, // Text posts don't need uploading
        "postType": "text",
        "contextType": contextType,
        "isRepost": isProfilePost ? false : null,
        "replyCount": 0,
        "timestamp": FieldValue.serverTimestamp(),
      });

      String postId = postDoc.id;

      // For profile posts, add to userPosts collection; for space posts, add to spacePosts
      if (isProfilePost) {
        await addTextToUserPosts(postId, title, content, replyTo, link);
      } else if (addToSpaceFeed) {
        await addTextToSpaceFeed(
            effectiveSpace, postId, title, content, replyTo, link);
      }

      // If it's a reply, add to the parent post's replies (always for replies)
      if (replyTo != null && replyTo.isNotEmpty) {
        await addTextPostReply(
            effectiveSpace, postId, title, content, replyTo, link);
      }
      // Aura for creating a post is awarded by backend (awardCreatePostAura trigger)

      return postId;
    } catch (e) {
      AppLogger.e('Error creating text post document',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return null;
    }
  }

  /// Creates a new audio post document in Firestore
  /// [isProfilePost] - If true, creates a profile post with contextType: 'profile'
  Future<String?> createAudioPostDocument({
    required String space,
    required String audioUrl,
    required int durationInSeconds,
    String? title,
    String? replyTo,
    bool addToSpaceFeed = true,
    bool isProfilePost = false,
  }) async {
    try {
      if (_currentUser == null) {
        AppLogger.e('User not authenticated for audio post creation',
            category: LogCategory.general);
        return null;
      }

      // For profile posts, space is the user's own ID
      final effectiveSpace = isProfilePost ? _currentUser!.uid : space;
      final contextType = isProfilePost ? 'profile' : 'space';

      DocumentReference postDoc = await _firestore.collection('posts').add({
        "space": effectiveSpace,
        "author": _currentUser!.uid,
        "title": title,
        "audioUrl": audioUrl,
        "duration": durationInSeconds,
        "replyTo": replyTo,
        "uploading": false, // Audio posts are uploaded before doc creation
        "postType": "audio",
        "contextType": contextType,
        "isRepost": isProfilePost ? false : null,
        "replyCount": 0,
        "timestamp": FieldValue.serverTimestamp(),
      });

      String postId = postDoc.id;

      // For profile posts, add to userPosts collection; for space posts, add to spacePosts
      if (isProfilePost) {
        await addAudioToUserPosts(
            postId, title, audioUrl, durationInSeconds, replyTo);
      } else if (addToSpaceFeed) {
        await addAudioToSpaceFeed(effectiveSpace, postId, title, audioUrl,
            durationInSeconds, replyTo);
      }

      // If it's a reply, add to the parent post's replies
      if (replyTo != null && replyTo.isNotEmpty) {
        await addAudioPostReply(effectiveSpace, postId, title, audioUrl,
            durationInSeconds, replyTo);
      }
      // Aura for creating a post is awarded by backend (awardCreatePostAura trigger)

      return postId;
    } catch (e) {
      AppLogger.e('Error creating audio post document',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return null;
    }
  }

  /// Creates a new image post document in Firestore
  /// [isProfilePost] - If true, creates a profile post with contextType: 'profile'
  Future<String?> createImagePostDocument({
    required String space,
    required String imageUrl,
    String? title,
    String? replyTo,
    String? link,
    bool addToSpaceFeed = true,
    bool isProfilePost = false,
  }) async {
    try {
      if (_currentUser == null) {
        AppLogger.e('User not authenticated for image post creation',
            category: LogCategory.general);
        return null;
      }

      // For profile posts, space is the user's own ID
      final effectiveSpace = isProfilePost ? _currentUser!.uid : space;
      final contextType = isProfilePost ? 'profile' : 'space';

      DocumentReference postDoc = await _firestore.collection('posts').add({
        "space": effectiveSpace,
        "author": _currentUser!.uid,
        "title": title,
        "video":
            imageUrl, // Store in 'video' field for consistency with mediaUrl
        "replyTo": replyTo,
        "link": link,
        "uploading": false, // Image posts are uploaded before doc creation
        "postType": "image",
        "contextType": contextType,
        "isRepost": isProfilePost ? false : null,
        "replyCount": 0,
        "timestamp": FieldValue.serverTimestamp(),
      });

      String postId = postDoc.id;

      // For profile posts, add to userPosts collection; for space posts, add to spacePosts
      if (isProfilePost) {
        await addImageToUserPosts(postId, title, imageUrl, replyTo, link);
      } else if (addToSpaceFeed) {
        await addImageToSpaceFeed(
            effectiveSpace, postId, title, imageUrl, replyTo, link);
      }

      // If it's a reply, add to the parent post's replies
      if (replyTo != null && replyTo.isNotEmpty) {
        await addImagePostReply(
            effectiveSpace, postId, title, imageUrl, replyTo, link);
      }
      // Aura for creating a post is awarded by backend (awardCreatePostAura trigger)

      return postId;
    } catch (e) {
      AppLogger.e('Error creating image post document',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return null;
    }
  }

  /// Updates post document with video and thumbnail URLs and marks as uploaded
  Future<bool> updatePostWithMedia(
      String postId, String videoUrl, String thumbnailUrl) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'video': videoUrl,
        'thumbnail': thumbnailUrl,
        'uploading': false,
      });

      // SMART CACHE UPDATE - Read back and update caches immediately
      try {
        final verification =
            await _firestore.collection('posts').doc(postId).get();
        if (verification.exists) {
          final data = verification.data();
          AppLogger.w('📋 FIRESTORE VERIFICATION READ',
              category: LogCategory.general,
              data: {
                'postId': postId,
                'actual_uploading_value': data?['uploading'],
                'has_video': data?.containsKey('video') == true,
                'has_thumbnail': data?.containsKey('thumbnail') == true
              });

          // Immediately update smart cache and trigger events
          await _handlePostDataUpdate(postId, verification);
        } else {
          AppLogger.e('❌ VERIFICATION FAILED - DOCUMENT NOT FOUND',
              category: LogCategory.general, data: {'postId': postId});
        }
      } catch (verificationError) {
        AppLogger.e('❌ VERIFICATION READ FAILED',
            category: LogCategory.general,
            error: verificationError,
            data: {'postId': postId});
      }

      AppLogger.d('Post marked as uploaded and smart cache updated',
          category: LogCategory.general,
          data: {
            'postId': postId,
            'videoUrl': videoUrl,
            'thumbnailUrl': thumbnailUrl
          });

      return true;
    } catch (e) {
      AppLogger.e('Error updating post with media',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Updates only the thumbnail URL (or path) of a post document. Keeps uploading=true.
  Future<bool> updatePostThumbnail(String postId, String thumbnailUrl) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'thumbnail': thumbnailUrl,
      });

      // SMART CACHE UPDATE - Read back and update
      try {
        final verification =
            await _firestore.collection('posts').doc(postId).get();
        if (verification.exists) {
          await _handlePostDataUpdate(postId, verification);
        }
      } catch (verificationError) {
        AppLogger.e('Failed to update cache after thumbnail update',
            category: LogCategory.general,
            error: verificationError,
            data: {'postId': postId});
      }

      AppLogger.d('Post thumbnail updated and smart cache refreshed',
          category: LogCategory.general,
          data: {'postId': postId, 'thumbnailUrl': thumbnailUrl});

      return true;
    } catch (e) {
      AppLogger.e('Error updating post thumbnail',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Updates both video and thumbnail URLs of a post document
  /// Used for web uploads where media is uploaded directly
  Future<bool> updatePostMedia(
      String postId, String videoUrl, String thumbnailUrl) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'video': videoUrl,
        'thumbnail': thumbnailUrl,
      });

      // SMART CACHE UPDATE - Read back and update
      try {
        final verification =
            await _firestore.collection('posts').doc(postId).get();
        if (verification.exists) {
          await _handlePostDataUpdate(postId, verification);
        }
      } catch (verificationError) {
        AppLogger.e('Failed to update cache after media update',
            category: LogCategory.general,
            error: verificationError,
            data: {'postId': postId});
      }

      AppLogger.d('Post media updated and smart cache refreshed',
          category: LogCategory.general,
          data: {
            'postId': postId,
            'videoUrl': videoUrl,
            'thumbnailUrl': thumbnailUrl
          });

      return true;
    } catch (e) {
      AppLogger.e('Error updating post media',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Creates a notification for post reply (used for web uploads)
  Future<bool> createReplyNotification(
    String recipientUid,
    String replyPostId,
    String originalPostId,
    String authorUid,
  ) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(recipientUid)
          .collection('items')
          .add({
        'type': 'reply',
        'postId': originalPostId,
        'replyPostId': replyPostId,
        'fromUserId': authorUid,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
      return true;
    } catch (e) {
      AppLogger.e('Error creating reply notification',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Updates the upload status of a post
  Future<bool> updatePostStatus(String postId, bool uploading) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'uploading': uploading,
      });

      // SMART CACHE UPDATE - This is critical for upload status changes
      try {
        final verification =
            await _firestore.collection('posts').doc(postId).get();
        if (verification.exists) {
          await _handlePostDataUpdate(postId, verification);
          AppLogger.w('📡 Upload status change processed',
              category: LogCategory.general,
              data: {
                'postId': postId,
                'newUploadingStatus': uploading,
                'willTriggerRealTimeListener': uploading
              });
        }
      } catch (verificationError) {
        AppLogger.e('Failed to update cache after status update',
            category: LogCategory.general,
            error: verificationError,
            data: {'postId': postId});
      }

      AppLogger.d('Post upload status updated and smart cache refreshed',
          category: LogCategory.general,
          data: {'postId': postId, 'uploading': uploading});

      return true;
    } catch (e) {
      AppLogger.e('Error updating post status',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Gets replies to a post
  Future<QuerySnapshot?> getPostReplies(String postId) async {
    try {
      return await _firestore
          .collection('postReplies')
          .doc(postId)
          .collection('replies')
          .orderBy('timestamp', descending: true)
          .get();
    } catch (e) {
      AppLogger.e('Error getting post replies',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return null;
    }
  }

  /// Gets the space ID for a post
  Future<String?> getPostSpace(String postId) async {
    try {
      DocumentSnapshot postDoc = await getPost(postId);
      if (!postDoc.exists) return null;

      return postDoc.get('space') as String?;
    } catch (e) {
      AppLogger.e('Error getting post space',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return null;
    }
  }

  /// Adds a post to a space feed
  Future<bool> addToSpaceFeed(
      String space,
      String postId,
      String? title,
      String thumbnailUrl,
      String videoUrl,
      String? replyTo,
      String? link) async {
    try {
      if (_currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? _currentUser!.uid : space;

      await _firestore
          .collection('spacePosts')
          .doc(space)
          .collection('posts')
          .doc(postId)
          .set({
        "author": _currentUser!.uid,
        "title": title ?? '',
        "thumbnail": thumbnailUrl,
        "replyTo": replyTo,
        "link": link,
        "video": videoUrl,
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update the space's last update timestamp
      await _firestore.collection('spacePosts').doc(space).set({
        "updated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Aura for creating a post is awarded by backend (awardCreateSpacePostAura trigger)

      return true;
    } catch (e) {
      AppLogger.e('Error adding to space feed',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Adds a text post to a space feed
  Future<bool> addTextToSpaceFeed(String space, String postId, String? title,
      String content, String? replyTo, String? link) async {
    try {
      if (_currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? _currentUser!.uid : space;

      await _firestore
          .collection('spacePosts')
          .doc(space)
          .collection('posts')
          .doc(postId)
          .set({
        "author": _currentUser!.uid,
        "title": title ?? '',
        "content": content,
        "replyTo": replyTo,
        "link": link,
        "postType": "text",
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update the space's last update timestamp
      await _firestore.collection('spacePosts').doc(space).set({
        "updated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      AppLogger.e('Error adding text post to space feed',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Adds a text post to user's profile posts collection
  Future<bool> addTextToUserPosts(String postId, String? title, String content,
      String? replyTo, String? link) async {
    try {
      if (_currentUser == null) return false;

      await _firestore
          .collection('userPosts')
          .doc(_currentUser!.uid)
          .collection('posts')
          .doc(postId)
          .set({
        "author": _currentUser!.uid,
        "title": title ?? '',
        "content": content,
        "replyTo": replyTo,
        "link": link,
        "postType": "text",
        "contextType": "profile",
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update user's post count
      await _firestore.collection('userPosts').doc(_currentUser!.uid).set({
        "updated": FieldValue.serverTimestamp(),
        "postCount": FieldValue.increment(1),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      AppLogger.e('Error adding text post to user profile',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Adds an image post to a space feed
  Future<bool> addImageToSpaceFeed(String space, String postId, String? title,
      String imageUrl, String? replyTo, String? link) async {
    try {
      if (_currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? _currentUser!.uid : space;

      await _firestore
          .collection('spacePosts')
          .doc(space)
          .collection('posts')
          .doc(postId)
          .set({
        "author": _currentUser!.uid,
        "title": title ?? '',
        "video": imageUrl, // Store in 'video' field for consistency
        "replyTo": replyTo,
        "link": link,
        "postType": "image",
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update the space's last update timestamp
      await _firestore.collection('spacePosts').doc(space).set({
        "updated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      AppLogger.e('Error adding image post to space feed',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Adds an image post to user's profile posts collection
  Future<bool> addImageToUserPosts(String postId, String? title,
      String imageUrl, String? replyTo, String? link) async {
    try {
      if (_currentUser == null) return false;

      await _firestore
          .collection('userPosts')
          .doc(_currentUser!.uid)
          .collection('posts')
          .doc(postId)
          .set({
        "author": _currentUser!.uid,
        "title": title ?? '',
        "video": imageUrl, // Store in 'video' field for consistency
        "replyTo": replyTo,
        "link": link,
        "postType": "image",
        "contextType": "profile",
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update user's post count
      await _firestore.collection('userPosts').doc(_currentUser!.uid).set({
        "updated": FieldValue.serverTimestamp(),
        "postCount": FieldValue.increment(1),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      AppLogger.e('Error adding image post to user profile',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Adds an audio post to user's profile posts collection
  Future<bool> addAudioToUserPosts(String postId, String? title,
      String audioUrl, int durationInSeconds, String? replyTo) async {
    try {
      if (_currentUser == null) return false;

      await _firestore
          .collection('userPosts')
          .doc(_currentUser!.uid)
          .collection('posts')
          .doc(postId)
          .set({
        "author": _currentUser!.uid,
        "title": title ?? '',
        "audioUrl": audioUrl,
        "duration": durationInSeconds,
        "replyTo": replyTo,
        "postType": "audio",
        "contextType": "profile",
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update user's post count
      await _firestore.collection('userPosts').doc(_currentUser!.uid).set({
        "updated": FieldValue.serverTimestamp(),
        "postCount": FieldValue.increment(1),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      AppLogger.e('Error adding audio post to user profile',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Adds a video post to user's profile posts collection
  Future<bool> addVideoToUserPosts(
      String postId,
      String? title,
      String thumbnailUrl,
      String videoUrl,
      String? replyTo,
      String? link) async {
    try {
      if (_currentUser == null) return false;

      await _firestore
          .collection('userPosts')
          .doc(_currentUser!.uid)
          .collection('posts')
          .doc(postId)
          .set({
        "author": _currentUser!.uid,
        "title": title ?? '',
        "thumbnail": thumbnailUrl,
        "video": videoUrl,
        "replyTo": replyTo,
        "link": link,
        "postType": "video",
        "contextType": "profile",
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update user's post count
      await _firestore.collection('userPosts').doc(_currentUser!.uid).set({
        "updated": FieldValue.serverTimestamp(),
        "postCount": FieldValue.increment(1),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      AppLogger.e('Error adding video post to user profile',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Adds a text post reply
  Future<bool> addTextPostReply(String space, String replyPostId, String? title,
      String content, String originalPostId, String? link) async {
    try {
      if (_currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? _currentUser!.uid : space;

      // Create the reply document
      // Backend Cloud Functions handle:
      // - replyCount increment via awardReplyAura trigger
      // - Aura awards to both post author and reply author
      await _firestore
          .collection('postReplies')
          .doc(originalPostId)
          .collection('replies')
          .doc(replyPostId)
          .set({
        "author": _currentUser!.uid,
        "title": title ?? '',
        "content": content,
        "link": link,
        "postType": "text",
        "timestamp": FieldValue.serverTimestamp()
      });

      return true;
    } catch (e) {
      AppLogger.e('Error adding text post reply',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Adds an audio post to a space feed
  Future<bool> addAudioToSpaceFeed(String space, String postId, String? title,
      String audioUrl, int durationInSeconds, String? replyTo) async {
    try {
      if (_currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? _currentUser!.uid : space;

      await _firestore
          .collection('spacePosts')
          .doc(space)
          .collection('posts')
          .doc(postId)
          .set({
        "author": _currentUser!.uid,
        "title": title ?? '',
        "audioUrl": audioUrl,
        "duration": durationInSeconds,
        "replyTo": replyTo,
        "postType": "audio",
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update the space's last update timestamp
      await _firestore.collection('spacePosts').doc(space).set({
        "updated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      AppLogger.e('Error adding audio post to space feed',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Adds an audio post reply
  Future<bool> addAudioPostReply(
      String space,
      String replyPostId,
      String? title,
      String audioUrl,
      int durationInSeconds,
      String originalPostId) async {
    try {
      if (_currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? _currentUser!.uid : space;

      // Create the reply document
      // Backend Cloud Functions handle:
      // - replyCount increment via awardReplyAura trigger
      // - Aura awards to both post author and reply author
      await _firestore
          .collection('postReplies')
          .doc(originalPostId)
          .collection('replies')
          .doc(replyPostId)
          .set({
        "author": _currentUser!.uid,
        "title": title ?? '',
        "audioUrl": audioUrl,
        "duration": durationInSeconds,
        "postType": "audio",
        "timestamp": FieldValue.serverTimestamp()
      });

      return true;
    } catch (e) {
      AppLogger.e('Error adding audio post reply',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Adds an image post reply
  Future<bool> addImagePostReply(
      String space,
      String replyPostId,
      String? title,
      String imageUrl,
      String originalPostId,
      String? link) async {
    try {
      if (_currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? _currentUser!.uid : space;

      // Create the reply document
      // Backend Cloud Functions handle:
      // - replyCount increment via awardReplyAura trigger
      // - Aura awards to both post author and reply author
      await _firestore
          .collection('postReplies')
          .doc(originalPostId)
          .collection('replies')
          .doc(replyPostId)
          .set({
        "author": _currentUser!.uid,
        "title": title ?? '',
        "video": imageUrl, // Store in 'video' field for consistency
        "link": link,
        "postType": "image",
        "timestamp": FieldValue.serverTimestamp()
      });

      return true;
    } catch (e) {
      AppLogger.e('Error adding image post reply',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Adds a reply to a post
  /// Backend Cloud Functions handle:
  /// - replyCount increment via awardReplyAura trigger
  /// - Aura awards to both post author and reply author
  Future<bool> addPostReply(
      String space,
      String replyPostId,
      String? title,
      String thumbnailUrl,
      String videoUrl,
      String originalPostId,
      String? link) async {
    try {
      if (_currentUser == null) return false;

      // Add reply to postReplies collection
      await _firestore
          .collection('postReplies')
          .doc(originalPostId)
          .collection('replies')
          .doc(replyPostId)
          .set({
        "space": space,
        "author": _currentUser!.uid,
        "title": title ?? '',
        "video": videoUrl,
        "link": link,
        "thumbnail": thumbnailUrl,
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update the space's last activity timestamp for real-time ordering
      await _firestore.collection('spacePosts').doc(space).set({
        "updated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      AppLogger.e('Error adding post reply',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Adds a reply notification for a user
  Future<bool> addUserReply(String recipientUserId, String space, String postId,
      String? title, String thumbnailUrl, String videoUrl, String? link) async {
    try {
      if (_currentUser == null) return false;

      await _firestore
          .collection('userReplies')
          .doc(recipientUserId)
          .collection('replies')
          .doc(postId)
          .set({
        "space": space,
        "author": _currentUser!.uid,
        "title": title ?? '',
        "video": videoUrl,
        "link": link,
        "thumbnail": thumbnailUrl,
        "seen": false,
        "timestamp": FieldValue.serverTimestamp()
      });
      return true;
    } catch (e) {
      AppLogger.e('Error adding user reply notification',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  // OLD CACHE METHOD - REMOVED (using smart cache system now)

  /// Check if a post is known to be missing
  bool isPostKnownMissing(String? postId) {
    if (postId == null) return true;
    return _notFoundPosts.contains(postId);
  }

  /// Mark a post as missing to prevent future fetch attempts
  void markPostAsMissing(String postId) {
    if (postId.isNotEmpty) {
      _notFoundPosts.add(postId);
      // Remove from smart cache if present and cancel listeners
      _smartPostCache.remove(postId);
      _removeRealTimeListener(postId);
    }
  }

  /// Invalidate cache for a specific post (used after deletion)
  void invalidatePostCache(String postId) {
    _smartPostCache.remove(postId);
    _removeRealTimeListener(postId);
    _notFoundPosts.add(postId);

    AppLogger.d('Post cache invalidated and marked as deleted',
        category: LogCategory.general, data: {'postId': postId});
  }

  /// Invalidate cache for an updated post (forces fresh fetch without marking as missing)
  void invalidateUpdatedPostCache(String postId) {
    // Remove from smart cache
    _smartPostCache.remove(postId);

    // Remove space cache entries for this post
    _postSpaceCache.removeWhere((key, value) => key.startsWith('${postId}_'));

    // Remove from not found tracking
    _notFoundPosts.remove(postId);

    // Remove real-time listener
    _removeRealTimeListener(postId);
  }

  // Clean up missing post references in the background
  void cleanupMissingPostReferences(String postId) {
    // Don't await to allow this to run in background
    Future(() async {
      try {
        // Get space ID if available
        String? spaceId = await _getPostSpaceId(postId);
        if (spaceId != null) {
          await cleanupMissingSpacePost(postId, spaceId);
        }

        // Also clean from user feed
        if (user?.uid != null) {
          await deleteErroredPost(postId);
        }
      } catch (cleanupError) {
        // Ignore cleanup errors
        AppLogger.w('Error during background cleanup',
            category: LogCategory.general,
            data: {'error': cleanupError.toString()});
      }
    });
  }

  /// Attempt to get the space ID for a post that might not exist
  Future<String?> _getPostSpaceId(String postId) async {
    // Quick cache hit
    if (_postSpaceCache.containsKey(postId)) {
      AppLogger.d('Space lookup cache hit',
          category: LogCategory.general,
          data: {'postId': postId, 'spaceId': _postSpaceCache[postId]});
      return _postSpaceCache[postId];
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
          _postSpaceCache[postId] = space.id;
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
          _postSpaceCache[postId] = spaceId;
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

  /// Clean up missing post references from space collections
  Future<void> cleanupMissingSpacePost(String postId, String spaceId) async {
    try {
      // Only attempt cleanup once per post-space combination
      final cacheKey = "${postId}_$spaceId";
      if (_notFoundSpacePosts.contains(cacheKey)) {
        return;
      }
      _notFoundSpacePosts.add(cacheKey);

      // Delete the post reference from spacePosts collection
      await FirebaseFirestore.instance
          .collection('spacePosts')
          .doc(spaceId)
          .collection('posts')
          .doc(postId)
          .delete();

      // Log cleanup once
      AppLogger.i('Removed invalid post reference',
          category: LogCategory.general,
          data: {'postId': postId, 'spaceId': spaceId});
    } catch (e) {
      // Silent error - this is just cleanup
    }
  }

  Future<bool> deleteErroredPost(String? postId) async {
    try {
      String? userId = user?.uid;
      if (userId == null || postId == null) {
        return false;
      }

      await FirebaseFirestore.instance
          .collection('userFeed')
          .doc(userId)
          .collection('posts')
          .doc(postId)
          .delete();

      AppLogger.i('Post deleted from user feed',
          category: LogCategory.general,
          data: {'postId': postId, 'userId': userId});
      return true;
    } catch (e) {
      AppLogger.e('Error deleting errored post',
          category: LogCategory.general, error: e);
      return false;
    }
  }
}
