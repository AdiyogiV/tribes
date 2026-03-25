import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/utils/firestore/firestore_recovery.dart';

/// Feed item with metadata for display
class FeedItem {
  final String postId;
  final DateTime timestamp;
  final String source; // 'space', 'profile', 'global'
  final String? sourceId; // spaceId or authorId

  FeedItem({
    required this.postId,
    required this.timestamp,
    required this.source,
    this.sourceId,
  });

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'source': source,
        'sourceId': sourceId,
      };

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
        postId: json['postId'] as String,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
        source: json['source'] as String,
        sourceId: json['sourceId'] as String?,
      );
}

/// Pull-based Feed Service
///
/// Architecture:
/// - Single source of truth: posts/ collection
/// - No fanout: Queries posts directly using user's spaces & following
/// - Guaranteed content: Falls back through multiple sources
/// - Offline-first: Caches feed locally for instant load
class FeedService {
  static final FeedService _instance = FeedService._internal();
  factory FeedService() => _instance;
  FeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache
  List<FeedItem> _cachedFeed = [];
  DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(minutes: 2);

  // Pagination state
  DateTime?
      _oldestPostTime; // Use timestamp for pagination (more reliable with mixed sources)
  bool _hasMorePosts = true;

  // Config
  static const int _pageSize = 10; // Reasonable batch size for mixed content
  static const int _minFeedItems = 5;
  static const int _maxCacheSize =
      100; // Increased to support better scroll-back experience (keeps ~6-7 pages)

  User? get _user => FirebaseAuth.instance.currentUser;

  /// Get feed - NEVER returns empty if content exists anywhere
  ///
  /// Priority:
  /// 1. Cached feed (instant)
  /// 2. Personalized: Spaces + Following
  /// 3. Global: Public posts
  /// 4. Curated: Featured content (future)
  Future<List<String>> getFeed({bool forceRefresh = false}) async {
    // Return cached if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid()) {
      AppLogger.d('Feed: Using cached feed',
          category: LogCategory.performance,
          data: {'count': _cachedFeed.length});
      return _cachedFeed.map((f) => f.postId).toList();
    }

    // Reset pagination on fresh fetch
    _oldestPostTime = null;
    _hasMorePosts = true;

    try {
      List<FeedItem> feedItems = [];

      if (_user != null) {
        // Logged in user - get personalized feed
        feedItems = await _fetchPersonalizedFeed(forceRefresh: forceRefresh);

        // If not enough content, blend in global feed
        if (feedItems.length < _minFeedItems) {
          AppLogger.d('Feed: Adding global posts to fill feed',
              category: LogCategory.ui,
              data: {'personalizedCount': feedItems.length});
          final globalItems = await _fetchGlobalFeed(
              limit: _pageSize - feedItems.length, forceRefresh: forceRefresh);
          feedItems.addAll(globalItems);
        }
      } else {
        // Guest user - global feed only
        feedItems = await _fetchGlobalFeed(
            limit: _pageSize, forceRefresh: forceRefresh);
      }

      // Sort by timestamp (newest first)
      feedItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Remove duplicates
      final seen = <String>{};
      feedItems = feedItems.where((item) => seen.add(item.postId)).toList();

      // Update cache and pagination cursor
      _cachedFeed = feedItems;
      _lastFetchTime = DateTime.now();
      _hasMorePosts = feedItems.length >= _minFeedItems;

      // Trim cache if it exceeds max size to prevent memory leaks
      _trimCacheIfNeeded();

      // Store oldest post time for pagination
      if (feedItems.isNotEmpty) {
        _oldestPostTime = feedItems.last.timestamp;
      }

      // Persist to local storage
      await _saveFeedToLocal(feedItems);

      AppLogger.i('Feed: Loaded successfully', category: LogCategory.ui, data: {
        'count': feedItems.length,
        'hasMore': _hasMorePosts,
      });

      return feedItems.map((f) => f.postId).toList();
    } catch (e) {
      AppLogger.e('Feed: Error loading feed', error: e);

      // On error, try to load from local cache
      final localFeed = await _loadFeedFromLocal();
      if (localFeed.isNotEmpty) {
        _cachedFeed = localFeed;
        return localFeed.map((f) => f.postId).toList();
      }

      return [];
    }
  }

  /// Load more posts for pagination
  /// Uses timestamp-based pagination for reliability with mixed sources
  Future<List<String>> loadMore() async {
    if (!_hasMorePosts || _oldestPostTime == null) {
      return [];
    }

    try {
      List<FeedItem> moreItems = [];

      if (_user != null) {
        // For logged-in users, fetch more personalized content
        moreItems = await _fetchPersonalizedFeed(beforeTime: _oldestPostTime);

        // If not enough, supplement with global feed
        if (moreItems.length < _minFeedItems) {
          final globalItems = await _fetchGlobalFeed(
            limit: _pageSize - moreItems.length,
            beforeTime: _oldestPostTime,
          );
          moreItems.addAll(globalItems);
        }
      } else {
        moreItems = await _fetchGlobalFeed(
          limit: _pageSize,
          beforeTime: _oldestPostTime,
        );
      }

      // Sort by timestamp
      moreItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Remove duplicates with existing feed
      final existingIds = _cachedFeed.map((f) => f.postId).toSet();
      moreItems =
          moreItems.where((f) => !existingIds.contains(f.postId)).toList();

      if (moreItems.isNotEmpty) {
        _cachedFeed.addAll(moreItems);
        _oldestPostTime = moreItems.last.timestamp;

        // Trim cache if it exceeds max size to prevent memory leaks
        _trimCacheIfNeeded();
      }

      _hasMorePosts = moreItems.length >= _minFeedItems;

      AppLogger.d('Feed: Loaded more posts',
          category: LogCategory.ui,
          data: {'newCount': moreItems.length, 'hasMore': _hasMorePosts});

      return moreItems.map((f) => f.postId).toList();
    } catch (e) {
      AppLogger.e('Feed: Error loading more', error: e);
      _hasMorePosts = false;
      return [];
    }
  }

  bool get hasMorePosts => _hasMorePosts;

  /// Fetch personalized feed using pull-based queries
  /// Queries posts directly from spaces user is member of + profiles they follow
  Future<List<FeedItem>> _fetchPersonalizedFeed({
    DateTime? beforeTime,
    bool forceRefresh = false,
  }) async {
    if (_user == null) return [];

    final feedItems = <FeedItem>[];

    try {
      // 1. Get user's space IDs (server-first when forceRefresh for true refresh)
      final spaceIds = await _getUserSpaceIds(forceRefresh: forceRefresh);

      // 2. Get user's following IDs
      final followingIds =
          await _getUserFollowingIds(forceRefresh: forceRefresh);

      AppLogger.d('Feed: Fetching from sources',
          category: LogCategory.ui,
          data: {
            'spaceCount': spaceIds.length,
            'followingCount': followingIds.length
          });

      // 3. Query posts from spaces (batch by 10 due to Firestore 'in' limit)
      // Limit to first 30 spaces to avoid too many queries
      final limitedSpaceIds = spaceIds.take(30).toList();
      for (var i = 0; i < limitedSpaceIds.length; i += 10) {
        final batch = limitedSpaceIds.skip(i).take(10).toList();
        if (batch.isEmpty) continue;

        // Query using 'space' field (legacy field name used in PostDbService)
        Query query = _firestore
            .collection('posts')
            .where('contextType', isEqualTo: 'space')
            .where('space', whereIn: batch)
            .orderBy('timestamp', descending: true)
            .limit(_pageSize);

        // Use timestamp for pagination
        if (beforeTime != null) {
          query = query.where('timestamp',
              isLessThan: Timestamp.fromDate(beforeTime));
        }

        final getOpts = forceRefresh
            ? const GetOptions(source: Source.server)
            : const GetOptions(source: Source.serverAndCache);
        final snapshot = await query
            .get(getOpts)
            .timeout(Duration(seconds: forceRefresh ? 15 : 10));

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          // NEW ARCHITECTURE: Skip posts with isRepost flag (old model reposts)
          // Reposts are now handled via reposts collection
          if (data['isRepost'] == true) continue;
          if (_isValidPost(data, doc.id)) {
            feedItems.add(FeedItem(
              postId: doc.id,
              timestamp: (data['timestamp'] as Timestamp).toDate(),
              source: 'space',
              sourceId:
                  data['space'] as String? ?? data['contextId'] as String?,
            ));
          }
        }
      }

      // 4. Query posts from followed profiles (limit to first 30)
      final limitedFollowingIds = followingIds.take(30).toList();
      for (var i = 0; i < limitedFollowingIds.length; i += 10) {
        final batch = limitedFollowingIds.skip(i).take(10).toList();
        if (batch.isEmpty) continue;

        Query query = _firestore
            .collection('posts')
            .where('contextType', isEqualTo: 'profile')
            .where('author', whereIn: batch)
            .orderBy('timestamp', descending: true)
            .limit(_pageSize);

        // Use timestamp for pagination
        if (beforeTime != null) {
          query = query.where('timestamp',
              isLessThan: Timestamp.fromDate(beforeTime));
        }

        final getOpts = forceRefresh
            ? const GetOptions(source: Source.server)
            : const GetOptions(source: Source.serverAndCache);
        final snapshot = await query
            .get(getOpts)
            .timeout(Duration(seconds: forceRefresh ? 15 : 10));

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          // NEW ARCHITECTURE: Skip posts with isRepost flag (old model reposts)
          // Reposts are now handled via reposts collection
          if (data['isRepost'] == true) continue;
          if (_isValidPost(data, doc.id)) {
            feedItems.add(FeedItem(
              postId: doc.id,
              timestamp: (data['timestamp'] as Timestamp).toDate(),
              source: 'profile',
              sourceId: data['author'] as String?,
            ));
          }
        }
      }

      // 5. NEW ARCHITECTURE: Query user's reposts and include original posts in feed
      try {
        Query repostsQuery = _firestore
            .collection('reposts')
            .where('reposterId', isEqualTo: _user!.uid)
            .orderBy('timestamp', descending: true)
            .limit(_pageSize);

        // Use timestamp for pagination
        if (beforeTime != null) {
          repostsQuery = repostsQuery.where('timestamp',
              isLessThan: Timestamp.fromDate(beforeTime));
        }

        final getOpts = forceRefresh
            ? const GetOptions(source: Source.server)
            : const GetOptions(source: Source.serverAndCache);
        final repostsSnapshot = await repostsQuery
            .get(getOpts)
            .timeout(Duration(seconds: forceRefresh ? 15 : 10));

        // Verify original posts exist before adding to feed (prevent broken feed items)
        // Batch check posts to avoid N+1 queries
        final postDbService = PostDbService();
        final postIdsToCheck = repostsSnapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return data?['originalPostId'] as String?;
            })
            .where((id) => id != null)
            .cast<String>()
            .toSet()
            .toList();
        
        // Batch verify posts exist (skip if already known missing)
        final validPostIds = <String>{};
        for (final postId in postIdsToCheck) {
          if (postId == null) continue;
          // Skip if post is known to be missing
          if (postDbService.isPostKnownMissing(postId)) {
            continue;
          }
          try {
            final postDoc = await postDbService.getPost(postId);
            if (postDoc.exists) {
              validPostIds.add(postId);
            }
          } catch (e) {
            // Post not found - skip
            AppLogger.w('Feed: Skipping repost with missing original post', 
                data: {'originalPostId': postId, 'error': e.toString()});
          }
        }
        
        // Add only valid reposts to feed
        for (final repostDoc in repostsSnapshot.docs) {
          final repostData = repostDoc.data() as Map<String, dynamic>;
          final originalPostId = repostData['originalPostId'] as String?;
          final timestamp = repostData['timestamp'] as Timestamp?;
          
          if (originalPostId != null && 
              timestamp != null && 
              validPostIds.contains(originalPostId)) {
            // Add original post to feed (not the repost document)
            feedItems.add(FeedItem(
              postId: originalPostId,
              timestamp: timestamp.toDate(),
              source: 'repost',
              sourceId: repostData['reposterId'] as String?,
            ));
          }
        }
      } catch (e) {
        AppLogger.w('Feed: Error fetching reposts', data: {'error': e.toString()});
        // Continue even if reposts query fails
      }

      // 6. If no spaces or following, return empty (will fall back to global)
      return feedItems;
    } catch (e) {
      AppLogger.e('Feed: Error in personalized fetch', error: e);
      return feedItems;
    }
  }

  /// Fetch global feed (recent posts for discovery)
  /// Uses globalFeed collection for public posts
  Future<List<FeedItem>> _fetchGlobalFeed({
    required int limit,
    DateTime? beforeTime,
    bool forceRefresh = false,
  }) async {
    try {
      // Try globalFeed first (server when forceRefresh, else serverAndCache)
      var feedItems = await _fetchFromGlobalFeedCollection(
          limit: limit, beforeTime: beforeTime, forceRefresh: forceRefresh);

      // If globalFeed is completely empty, log it for debugging
      if (feedItems.isEmpty) {
        AppLogger.i(
            'Feed: globalFeed is empty - functions may not be deployed to production',
            category: LogCategory.ui);
      }

      return feedItems;
    } catch (e) {
      AppLogger.e('Feed: Error fetching global feed', error: e);
      return [];
    }
  }

  /// Fetch from globalFeed collection (primary source - indexed public posts)
  Future<List<FeedItem>> _fetchFromGlobalFeedCollection({
    required int limit,
    DateTime? beforeTime,
    bool forceRefresh = false,
  }) async {
    AppLogger.i('Feed: Querying globalFeed collection',
        category: LogCategory.ui,
        data: {
          'limit': limit,
          'beforeTime': beforeTime?.toIso8601String(),
          'forceRefresh': forceRefresh
        });

    try {
      Query query = _firestore
          .collection('globalFeed')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (beforeTime != null) {
        query = query.where('timestamp',
            isLessThan: Timestamp.fromDate(beforeTime));
      }

      // On forceRefresh use server only so we get fresh data; else serverAndCache.
      // Fall back to cache only if server fails (e.g. offline/slow).
      QuerySnapshot? snapshot;
      final source = forceRefresh ? Source.server : Source.serverAndCache;

      try {
        AppLogger.d('Feed: Fetching globalFeed (source: ${source.name})',
            category: LogCategory.ui);
        snapshot = await query
            .get(GetOptions(source: source))
            .timeout(const Duration(seconds: 15));
        AppLogger.d('Feed: globalFeed fetch succeeded',
            category: LogCategory.ui,
            data: {'docsCount': snapshot.docs.length});
      } catch (e) {
        AppLogger.d('Feed: Fetch failed, trying cache only',
            category: LogCategory.ui, data: {'error': e.toString()});
        try {
          snapshot = await query
              .get(const GetOptions(source: Source.cache))
              .timeout(const Duration(seconds: 5));
          AppLogger.d('Feed: Cache fetch succeeded',
              category: LogCategory.ui,
              data: {'docsCount': snapshot.docs.length});
        } catch (cacheError) {
          AppLogger.w('Feed: Both server and cache failed for globalFeed',
              category: LogCategory.ui,
              data: {
                'serverError': e.toString(),
                'cacheError': cacheError.toString()
              });
          // Firestore may be stuck; attempt recovery in background.
          Future(() async {
            await FirestoreRecovery.attemptRecovery(
                context: 'globalFeed fetch');
          });
          return [];
        }
      }

      final feedItems = <FeedItem>[];
      final postDbService = locator<PostDbService>();

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        // Use postId field if present, otherwise use document ID as fallback
        // (older globalFeed entries used doc.id as the postId but didn't store it as a field)
        final postId = data['postId'] as String? ?? doc.id;

        if (timestamp == null) {
          continue;
        }

        // Skip posts that are known to be missing
        if (postDbService.isPostKnownMissing(postId)) {
          continue;
        }

        // Skip posts that are still uploading (from globalFeed metadata if available)
        if (data['uploading'] == true) {
          continue;
        }

        feedItems.add(FeedItem(
          postId: postId,
          timestamp: timestamp.toDate(),
          source: 'global',
          sourceId: data['contextId'] as String? ?? data['author'] as String?,
        ));
      }

      AppLogger.i('Feed: globalFeed collection returned',
          category: LogCategory.ui, data: {'count': feedItems.length});

      return feedItems;
    } catch (e) {
      AppLogger.e('Feed: Error fetching from globalFeed collection',
          category: LogCategory.ui, error: e);
      return [];
    }
  }

  /// Get user's space IDs (spaces they're a member of)
  /// When forceRefresh: server first for fresh list; else cache-first with timeout.
  Future<List<String>> _getUserSpaceIds({bool forceRefresh = false}) async {
    if (_user == null) return [];

    try {
      QuerySnapshot? snapshot;

      if (forceRefresh) {
        try {
          snapshot = await _firestore
              .collection('userSpaces')
              .doc(_user!.uid)
              .collection('spaces')
              .where('role', whereIn: ['member', 'admin', 'creator', 'owner'])
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          try {
            snapshot = await _firestore
                .collection('userSpaces')
                .doc(_user!.uid)
                .collection('spaces')
                .where('role', whereIn: ['member', 'admin', 'creator', 'owner'])
                .get(const GetOptions(source: Source.cache))
                .timeout(const Duration(seconds: 2));
          } catch (_) {
            return [];
          }
        }
      } else {
        try {
          snapshot = await _firestore
              .collection('userSpaces')
              .doc(_user!.uid)
              .collection('spaces')
              .where('role', whereIn: ['member', 'admin', 'creator', 'owner'])
              .get(const GetOptions(source: Source.cache))
              .timeout(const Duration(seconds: 2));
        } catch (_) {
          try {
            snapshot = await _firestore
                .collection('userSpaces')
                .doc(_user!.uid)
                .collection('spaces')
                .where('role', whereIn: ['member', 'admin', 'creator', 'owner'])
                .get(const GetOptions(source: Source.server))
                .timeout(const Duration(seconds: 3));
          } catch (_) {
            return [];
          }
        }
      }

      return snapshot.docs.map((d) => d.id).toList();
    } catch (e) {
      AppLogger.e('Feed: Error getting user spaces', error: e);
      return [];
    }
  }

  /// Get user's following IDs
  /// When forceRefresh: server first for fresh list; else cache-first with timeout.
  Future<List<String>> _getUserFollowingIds({bool forceRefresh = false}) async {
    if (_user == null) return [];

    try {
      QuerySnapshot? snapshot;

      if (forceRefresh) {
        try {
          snapshot = await _firestore
              .collection('userFollowing')
              .doc(_user!.uid)
              .collection('following')
              .where('status', isEqualTo: 'following')
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          try {
            snapshot = await _firestore
                .collection('userFollowing')
                .doc(_user!.uid)
                .collection('following')
                .where('status', isEqualTo: 'following')
                .get(const GetOptions(source: Source.cache))
                .timeout(const Duration(seconds: 2));
          } catch (_) {
            return [];
          }
        }
      } else {
        try {
          snapshot = await _firestore
              .collection('userFollowing')
              .doc(_user!.uid)
              .collection('following')
              .where('status', isEqualTo: 'following')
              .get(const GetOptions(source: Source.cache))
              .timeout(const Duration(seconds: 2));
        } catch (_) {
          try {
            snapshot = await _firestore
                .collection('userFollowing')
                .doc(_user!.uid)
                .collection('following')
                .where('status', isEqualTo: 'following')
                .get(const GetOptions(source: Source.server))
                .timeout(const Duration(seconds: 3));
          } catch (_) {
            return [];
          }
        }
      }

      return snapshot.docs.map((d) => d.id).toList();
    } catch (e) {
      AppLogger.e('Feed: Error getting user following', error: e);
      return [];
    }
  }

  /// Validate post has required fields and is ready to display
  bool _isValidPost(Map<String, dynamic> data, String postId) {
    // Check for known missing posts first
    if (locator<PostDbService>().isPostKnownMissing(postId)) {
      return false;
    }

    return data['timestamp'] != null &&
        data['author'] != null &&
        data['uploading'] != true;
  }

  /// Check if cache is still valid
  bool _isCacheValid() {
    if (_cachedFeed.isEmpty || _lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheExpiry;
  }

  /// Save feed to local storage for offline access
  Future<void> _saveFeedToLocal(List<FeedItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = items.take(50).map((f) => f.toJson()).toList();
      await prefs.setString('feed_cache', jsonEncode(jsonList));
      await prefs.setInt(
          'feed_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      AppLogger.w('Feed: Error saving to local',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  /// Load feed from local storage
  Future<List<FeedItem>> _loadFeedFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('feed_cache');

      if (jsonStr == null) return [];

      final cacheTime = prefs.getInt('feed_cache_time') ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;

      // Local cache valid for 24 hours
      if (cacheAge > 24 * 60 * 60 * 1000) return [];

      final jsonList = jsonDecode(jsonStr) as List;
      return jsonList
          .map((j) => FeedItem.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.w('Feed: Error loading from local',
          category: LogCategory.performance, data: {'error': e.toString()});
      return [];
    }
  }

  /// Clear all caches (for logout/refresh)
  Future<void> clearCache() async {
    _cachedFeed.clear();
    _lastFetchTime = null;
    _oldestPostTime = null;
    _hasMorePosts = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('feed_cache');
      await prefs.remove('feed_cache_time');
    } catch (e) {
      // Ignore
    }
  }

  /// Invalidate cache (forces refresh on next getFeed call)
  void invalidateCache() {
    _lastFetchTime = null;
  }

  /// Trim cache to max size, keeping newest items
  /// This prevents memory leaks from unbounded cache growth
  void _trimCacheIfNeeded() {
    if (_cachedFeed.length > _maxCacheSize) {
      final itemsToRemove = _cachedFeed.length - _maxCacheSize;
      AppLogger.d('Feed: Trimming cache',
          category: LogCategory.performance,
          data: {
            'before': _cachedFeed.length,
            'removing': itemsToRemove,
            'after': _maxCacheSize
          });

      // Remove oldest items (they're at the end since list is sorted newest first)
      _cachedFeed.removeRange(_maxCacheSize, _cachedFeed.length);

      // Update oldest post time for pagination
      if (_cachedFeed.isNotEmpty) {
        _oldestPostTime = _cachedFeed.last.timestamp;
      }
    }
  }
}
