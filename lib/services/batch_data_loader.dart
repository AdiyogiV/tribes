import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Batch data loader with request deduplication
/// Loads counters, user data, and space data in batches to minimize Firestore queries
class BatchDataLoader {
  static final BatchDataLoader _instance = BatchDataLoader._internal();
  factory BatchDataLoader() => _instance;
  BatchDataLoader._internal();

  final UserService _userService = locator<UserService>();

  // Request deduplication - tracks in-flight requests
  final Map<String, Future<UserData?>> _userRequests = {};
  final Map<String, Future<SpaceData?>> _spaceRequests = {};
  final Map<String, Future<PostCounters?>> _counterRequests = {};

  // Cache with TTL
  final Map<String, UserData> _userCache = {};
  final Map<String, SpaceData> _spaceCache = {};
  final Map<String, PostCounters> _counterCache = {};
  final Map<String, DateTime> _userCacheTime = {};
  final Map<String, DateTime> _spaceCacheTime = {};
  final Map<String, DateTime> _counterCacheTime = {};
  
  static const Duration _cacheDuration = Duration(minutes: 5);
  static const Duration _counterCacheDuration = Duration(minutes: 2);

  /// Load counters for multiple posts in batch
  Future<Map<String, PostCounters>> batchLoadCounters(List<String> postIds) async {
    if (postIds.isEmpty) return {};

    final startTime = DateTime.now();
    final results = <String, PostCounters>{};
    final toFetch = <String>[];

    // Check cache first
    for (final postId in postIds) {
      final cached = _getCachedCounters(postId);
      if (cached != null) {
        results[postId] = cached;
      } else {
        toFetch.add(postId);
      }
    }

    if (toFetch.isEmpty) {
      AppLogger.d(
        'BatchDataLoader: All counters from cache',
        category: LogCategory.performance,
        data: {'count': postIds.length},
      );
      return results;
    }

    AppLogger.d(
      'BatchDataLoader: Loading counters',
      category: LogCategory.performance,
      data: {'total': postIds.length, 'fromCache': results.length, 'toFetch': toFetch.length},
    );

    try {
      // Batch load replies and likes using Firestore batch reads
      final db = FirebaseFirestore.instance;
      
      // Split into chunks of 10 for Firestore's `in` operator limit
      const chunkSize = 10;
      for (var i = 0; i < toFetch.length; i += chunkSize) {
        final chunk = toFetch.skip(i).take(chunkSize).toList();
        
        // Load reply counts in parallel
        final replyFutures = chunk.map((postId) async {
          try {
            final snapshot = await db
                .collection('postReplies')
                .doc(postId)
                .collection('replies')
                .count()
                .get();
            return {postId: snapshot.count ?? 0};
          } catch (e) {
            AppLogger.w('Error loading reply count', data: {'postId': postId, 'error': e.toString()});
            return {postId: 0};
          }
        }).toList();

        // Load like counts in parallel
        final likeFutures = chunk.map((postId) async {
          try {
            final snapshot = await db
                .collection('postLikes')
                .doc(postId)
                .collection('likes')
                .count()
                .get();
            return {postId: snapshot.count ?? 0};
          } catch (e) {
            AppLogger.w('Error loading like count', data: {'postId': postId, 'error': e.toString()});
            return {postId: 0};
          }
        }).toList();

        // Load user's like status if authenticated
        final user = _userService.user;
        final isLikedFutures = user != null
            ? chunk.map((postId) async {
                try {
                  final doc = await db
                      .collection('postLikes')
                      .doc(postId)
                      .collection('likes')
                      .doc(user.uid)
                      .get();
                  return {postId: doc.exists};
                } catch (e) {
                  return {postId: false};
                }
              }).toList()
            : chunk.map((postId) => Future.value({postId: false})).toList();

        // Wait for all queries
        final replyResults = await Future.wait(replyFutures);
        final likeResults = await Future.wait(likeFutures);
        final isLikedResults = await Future.wait(isLikedFutures);

        // Combine results
        for (var j = 0; j < chunk.length; j++) {
          final postId = chunk[j];
          final counters = PostCounters(
            replyCount: replyResults[j][postId] ?? 0,
            likeCount: likeResults[j][postId] ?? 0,
            isLiked: isLikedResults[j][postId] ?? false,
          );
          results[postId] = counters;
          _cacheCounters(postId, counters);
        }
      }

      final duration = DateTime.now().difference(startTime);
      AppLogger.i(
        'BatchDataLoader: Counters loaded',
        category: LogCategory.performance,
        data: {
          'fetched': toFetch.length,
          'total': postIds.length,
          'took_ms': duration.inMilliseconds,
        },
      );
    } catch (e, stack) {
      AppLogger.e('Error batch loading counters', error: e, stackTrace: stack);
    }

    return results;
  }

  /// Load user data with deduplication
  Future<UserData?> loadUser(String userId) async {
    if (userId.isEmpty) return null;

    // Check cache
    final cached = _getCachedUser(userId);
    if (cached != null) return cached;

    // Check if request is already in flight
    if (_userRequests.containsKey(userId)) {
      return _userRequests[userId]!;
    }

    // Create new request with deduplication
    final request = _fetchUser(userId);
    _userRequests[userId] = request;

    try {
      final result = await request;
      return result;
    } finally {
      _userRequests.remove(userId);
    }
  }

  Future<UserData?> _fetchUser(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      final userData = UserData(
        uid: userId,
        displayName: data['displayName'] as String? ?? data['name'] as String? ?? 'User',
        photoUrl: data['displayPicture'] as String?,
      );

      _cacheUser(userId, userData);
      return userData;
    } catch (e) {
      AppLogger.w('Error loading user', data: {'userId': userId, 'error': e.toString()});
      return null;
    }
  }

  /// Load space data with deduplication
  Future<SpaceData?> loadSpace(String spaceId) async {
    if (spaceId.isEmpty) return null;

    // Check cache
    final cached = _getCachedSpace(spaceId);
    if (cached != null) return cached;

    // Check if request is already in flight
    if (_spaceRequests.containsKey(spaceId)) {
      return _spaceRequests[spaceId]!;
    }

    // Create new request with deduplication
    final request = _fetchSpace(spaceId);
    _spaceRequests[spaceId] = request;

    try {
      final result = await request;
      return result;
    } finally {
      _spaceRequests.remove(spaceId);
    }
  }

  Future<SpaceData?> _fetchSpace(String spaceId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      final spaceData = SpaceData(
        id: spaceId,
        name: data['name'] as String? ?? 'Gram',
      );

      _cacheSpace(spaceId, spaceData);
      return spaceData;
    } catch (e) {
      AppLogger.w('Error loading space', data: {'spaceId': spaceId, 'error': e.toString()});
      return null;
    }
  }

  /// Batch load users - loads multiple users in parallel with deduplication
  Future<Map<String, UserData>> batchLoadUsers(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    final uniqueIds = userIds.toSet().toList();
    final futures = uniqueIds.map((id) => loadUser(id)).toList();
      final results = await Future.wait(futures);

    final map = <String, UserData>{};
    for (var i = 0; i < uniqueIds.length; i++) {
      final result = results[i];
      if (result != null) {
        map[uniqueIds[i]] = result;
      }
    }
    return map;
  }

  /// Batch load spaces - loads multiple spaces in parallel with deduplication
  Future<Map<String, SpaceData>> batchLoadSpaces(List<String> spaceIds) async {
    if (spaceIds.isEmpty) return {};

    final uniqueIds = spaceIds.toSet().toList();
    final futures = uniqueIds.map((id) => loadSpace(id)).toList();
      final results = await Future.wait(futures);

    final map = <String, SpaceData>{};
    for (var i = 0; i < uniqueIds.length; i++) {
      final result = results[i];
      if (result != null) {
        map[uniqueIds[i]] = result;
      }
    }
    return map;
  }

  // Cache helpers
  UserData? _getCachedUser(String userId) {
    final cached = _userCache[userId];
    final time = _userCacheTime[userId];
    if (cached != null && time != null) {
      if (DateTime.now().difference(time) < _cacheDuration) {
        return cached;
      }
      _userCache.remove(userId);
      _userCacheTime.remove(userId);
    }
    return null;
  }

  SpaceData? _getCachedSpace(String spaceId) {
    final cached = _spaceCache[spaceId];
    final time = _spaceCacheTime[spaceId];
    if (cached != null && time != null) {
      if (DateTime.now().difference(time) < _cacheDuration) {
        return cached;
      }
      _spaceCache.remove(spaceId);
      _spaceCacheTime.remove(spaceId);
    }
    return null;
  }

  PostCounters? _getCachedCounters(String postId) {
    final cached = _counterCache[postId];
    final time = _counterCacheTime[postId];
    if (cached != null && time != null) {
      if (DateTime.now().difference(time) < _counterCacheDuration) {
        return cached;
      }
      _counterCache.remove(postId);
      _counterCacheTime.remove(postId);
    }
    return null;
  }

  void _cacheUser(String userId, UserData data) {
    _userCache[userId] = data;
    _userCacheTime[userId] = DateTime.now();
  }

  void _cacheSpace(String spaceId, SpaceData data) {
    _spaceCache[spaceId] = data;
    _spaceCacheTime[spaceId] = DateTime.now();
  }

  void _cacheCounters(String postId, PostCounters counters) {
    _counterCache[postId] = counters;
    _counterCacheTime[postId] = DateTime.now();
  }

  /// Clear all caches
  void clearCache() {
    _userCache.clear();
    _spaceCache.clear();
    _counterCache.clear();
    _userCacheTime.clear();
    _spaceCacheTime.clear();
    _counterCacheTime.clear();
  }

  /// Get cache stats for debugging
  Map<String, int> getCacheStats() {
    return {
      'users': _userCache.length,
      'spaces': _spaceCache.length,
      'counters': _counterCache.length,
      'inFlightUsers': _userRequests.length,
      'inFlightSpaces': _spaceRequests.length,
      'inFlightCounters': _counterRequests.length,
    };
  }
}

/// User data model
class UserData {
  final String uid;
  final String displayName;
  final String? photoUrl;

  const UserData({
    required this.uid,
    required this.displayName,
    this.photoUrl,
  });
}

/// Space data model
class SpaceData {
  final String id;
  final String name;

  const SpaceData({
    required this.id,
    required this.name,
  });
}

/// Post counters model
class PostCounters {
  final int replyCount;
  final int likeCount;
  final bool isLiked;

  const PostCounters({
    required this.replyCount,
    required this.likeCount,
    required this.isLiked,
  });
}
