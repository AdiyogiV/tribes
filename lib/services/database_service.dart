import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/services/space_service.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:aurogram/models/space_roles.dart';
import 'package:flutter/foundation.dart';

// Conditional import for dart:io
import 'dart:io'
    if (dart.library.html) 'package:aurogram/platform/io_stub.dart';
import 'package:aurogram/platform/file_helper.dart' as file_helper;

class DatabaseService {
  String? uid;
  DatabaseService({this.uid});

  User? user = FirebaseAuth.instance.currentUser;
  final CollectionReference userCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference spacesCollection =
      FirebaseFirestore.instance.collection('spaces');
  final CollectionReference nicknameCollection =
      FirebaseFirestore.instance.collection('nicknames');
  final CollectionReference _postRepliesCollection =
      FirebaseFirestore.instance.collection('postReplies');
  final CollectionReference _postLikesCollection =
      FirebaseFirestore.instance.collection('postLikes');
  final CollectionReference _postsCollection =
      FirebaseFirestore.instance.collection('posts');
  final CollectionReference _notificationsCollection =
      FirebaseFirestore.instance.collection('notifications');

  // Track posts not found to avoid repeated lookups and errors
  final Set<String> _notFoundPosts = {};
  final Set<String> _notFoundSpacePosts = {};

  // Add a cache to avoid redundant Firestore queries
  final Map<String, DocumentSnapshot> _postCache = {};
  final Map<String, DateTime> _postCacheExpiry = {};

  // Cache mapping from postId to spaceId discovered via reverse lookup (static across instances)
  static final Map<String, String> _postSpaceCache = {};

  /* // Method moved to UserService
  Future<bool> checkRegistration() async {
    if (user?.uid == null) {
      return true; // Consider as new user if there's no UID
    }

    try {
      DocumentSnapshot snapshot = await userCollection.doc(user!.uid).get();

      if (!snapshot.exists) {
        return true; // New user if document doesn't exist
      }

      Map<String, dynamic>? userData = snapshot.data() as Map<String, dynamic>?;

      if (userData == null) {
        return true; // New user if data is null
      }

      // Check if 'nickname' field exists and is not empty
      if (userData.containsKey('nickname') &&
          userData['nickname'] != null &&
          userData['nickname'].toString().trim().isNotEmpty) {
        return false; // Existing user with a valid nickname
      }

      return true; // New user if nickname doesn't exist or is empty
    } catch (e) {
      AppLogger.e('Error checking user registration', 
          category: LogCategory.general, error: e);
      return true; // Assume new user in case of error
    }
  }
  */

  /// Create item with display picture
  /// [displayPicture] can be a String file path (mobile) or Uint8List bytes (web)
  Future<String> createItem(
    String name,
    String price,
    dynamic displayPicture, // String path (mobile) or Uint8List (web)
    String space,
  ) async {
    CollectionReference itemCollection =
        FirebaseFirestore.instance.collection('items');
    var item = await itemCollection
        .add({'name': name, 'price': price, 'image': '', space: space});
    String id = item.id;

    // Upload image
    String? imageUrl = await _uploadItemImage(id, displayPicture);
    if (imageUrl != null) {
      await itemCollection.doc(id).set({
        'image': imageUrl,
      }, SetOptions(merge: true));
    }

    await FirebaseFirestore.instance
        .collection('spaceItems')
        .doc(space)
        .collection('items')
        .doc(id)
        .set({
      'name': name,
      'price': price,
      "timestamp": Timestamp.fromDate(DateTime.now()),
    });

    return id;
  }

  /// Upload item image - handles both path (mobile) and bytes (web)
  Future<String?> _uploadItemImage(String itemId, dynamic source) async {
    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference storageRef =
          storage.ref().child('items/$itemId/displayPicture.jpg');

      if (source is Uint8List) {
        // Web: upload from bytes
        await storageRef.putData(
            source, SettableMetadata(contentType: 'image/jpeg'));
      } else if (source is String && !kIsWeb) {
        // Mobile: upload from file path
        await storageRef.putFile(file_helper.createIOFile(source));
      } else {
        return null;
      }

      return await storageRef.getDownloadURL();
    } catch (e) {
      AppLogger.e('Error uploading item image',
          category: LogCategory.general, error: e);
      return null;
    }
  }

  /* // Method moved to SpaceService
  Future<bool> isExistsSpaceMember(
    String space,
    String member,
  ) async {
    var role = await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .doc(member)
        .get();
    if (role.data() != null)
      return true;
    else
      return false;
  }
  */

  /* // Method moved to SpaceService
  Future<bool> addSpaceMember(
    String space,
    String member,
  ) async {
    var role = 'requested';
    int spaceType = await getSpaceType(space);
    // Public: open (0), public (1). Private: private (2), personal (3)
    if (spaceType == 0 || spaceType == 1) {
      role = 'member';
    }

    await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .doc(member)
        .set({
      'role': '$role',
      "timestamp": Timestamp.fromDate(DateTime.now()),
    });
    await FirebaseFirestore.instance
        .collection('userSpaces')
        .doc(member)
        .collection('spaces')
        .doc(space)
        .set({
      'role': '$role',
      "timestamp": Timestamp.fromDate(DateTime.now()),
    }); //owner
    return true;
  }
  */

  /* // Method moved to SpaceService
  Future<bool> makeAdmin(String space, String userId) async {
    try {
      // Check if the user is already an admin or creator
      DocumentSnapshot roleDoc = await FirebaseFirestore.instance
          .collection('spaceRoles')
          .doc(space)
          .collection('roles')
          .doc(userId)
          .get();

      if (!roleDoc.exists) {
        AppLogger.w('User is not a member of space', 
            category: LogCategory.general, 
            data: {'userId': userId, 'spaceId': space});
        return false;
      }

      String currentRole = roleDoc['role'];
      if (currentRole == 'admin' || currentRole == 'creator') {
        AppLogger.w('User is already an admin or creator', 
            category: LogCategory.general, 
            data: {'userId': userId, 'spaceId': space});
        return false;
      }

      // Update the user's role to admin in spaceRoles collection
      await FirebaseFirestore.instance
          .collection('spaceRoles')
          .doc(space)
          .collection('roles')
          .doc(userId)
          .update({
        'role': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update the user's role to admin in userSpaces collection
      await FirebaseFirestore.instance
          .collection('userSpaces')
          .doc(userId)
          .collection('spaces')
          .doc(space)
          .update({
        'role': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.i('User promoted to admin', 
          category: LogCategory.general, 
          data: {'userId': userId, 'spaceId': space});
      return true;
    } catch (e) {
      AppLogger.e('Error making user admin', 
          category: LogCategory.general, error: e, 
          data: {'userId': userId, 'spaceId': space});
      return false;
    }
  }
  */

  /* // Method moved to SpaceService
  Future<bool> removeSpaceMember(
    String space,
    String member,
  ) async {
    var role = await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .doc(member)
        .get();
    if (role.data() == null) return true; //member

    await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .doc(member)
        .delete();

    await FirebaseFirestore.instance
        .collection('userSpaces')
        .doc(member)
        .collection('spaces')
        .doc(space)
        .delete();

    return true;
  }
  */

  Future<bool> approveSpaceMember(String space, String member) async {
    try {
      var role = 'member';

      await FirebaseFirestore.instance
          .collection('spaceRoles')
          .doc(space)
          .collection('roles')
          .doc(member)
          .set({
        'role': role,
        "timestamp": Timestamp.fromDate(DateTime.now()),
      });
      await FirebaseFirestore.instance
          .collection('userSpaces')
          .doc(member)
          .collection('spaces')
          .doc(space)
          .set({
        'role': role,
        "timestamp": Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      AppLogger.e('Space operation error',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  Future<bool> rejectSpaceMember(String space, String member) async {
    try {
      await FirebaseFirestore.instance
          .collection('spaceRoles')
          .doc(space)
          .collection('roles')
          .doc(member)
          .delete();
      await FirebaseFirestore.instance
          .collection('userSpaces')
          .doc(member)
          .collection('spaces')
          .doc(space)
          .delete();
      return true;
    } catch (e) {
      AppLogger.e('Error rejecting space member',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  Future<bool> addUserItem(
    String usr,
    String item,
  ) async {
    var role = await FirebaseFirestore.instance
        .collection('userItems')
        .doc(user?.uid)
        .collection('items')
        .doc(item)
        .get();
    if (role.data() != null) return true; //member

    await FirebaseFirestore.instance
        .collection('userItems')
        .doc(user?.uid)
        .collection('items')
        .doc(item)
        .set({"timestamp": Timestamp.fromDate(DateTime.now())});
    return true;
  }

  Future<QuerySnapshot> getSpaceFollower(
    String space,
  ) async {
    var followers = await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .where('role', isEqualTo: 'follower')
        .get();

    return followers;
  }

  /// DEPRECATED: Use PostDbService.getPost() instead
  /// This method is kept for backward compatibility with any remaining callers
  Future<DocumentSnapshot> getPost(String? post) async {
    // Delegate to PostDbService for consistent behavior
    return await locator<PostDbService>().getPost(post);
  }

  // Add post to cache with expiry and LRU eviction
  void _addToPostCache(String postId, DocumentSnapshot doc) {
    // Increase cache size for better performance
    final maxCacheSize = 200; // Increased from 50

    // Check if cache is full
    if (_postCache.length >= maxCacheSize) {
      // Find oldest cache entry
      String? oldestKey;
      DateTime? oldestTime;

      _postCacheExpiry.forEach((key, time) {
        if (oldestTime == null || time.isBefore(oldestTime!)) {
          oldestKey = key;
          oldestTime = time;
        }
      });

      // Remove oldest entry
      if (oldestKey != null) {
        _postCache.remove(oldestKey);
        _postCacheExpiry.remove(oldestKey);
      }
    }

    // Add to cache with 15 minute expiry (extended from 5)
    _postCache[postId] = doc;
    _postCacheExpiry[postId] = DateTime.now().add(Duration(minutes: 15));
  }

  /// Check if a post is known to be missing
  bool isPostKnownMissing(String? postId) {
    if (postId == null) return true;
    return _notFoundPosts.contains(postId);
  }

  // Clean up missing post references in the background
  // Note: userFeed cleanup removed as that collection is deprecated
  void _cleanupMissingPostReferences(String postId) {
    // Don't await to allow this to run in background
    Future(() async {
      try {
        // Get space ID if available and clean up spacePosts reference
        String? spaceId = await _getPostSpaceId(postId);
        if (spaceId != null) {
          await cleanupMissingSpacePost(postId, spaceId);
        }
      } catch (cleanupError) {
        // Ignore cleanup errors
        AppLogger.w('Error during cleanup',
            category: LogCategory.general,
            data: {'error': cleanupError.toString()});
      }
    });
  }

  /// Attempt to get the space ID for a post
  /// First checks the post document itself, then falls back to spacePosts collection
  Future<String?> _getPostSpaceId(String postId) async {
    // Quick cache hit
    if (_postSpaceCache.containsKey(postId)) {
      return _postSpaceCache[postId];
    }
    try {
      // First, try to get the space directly from the post document
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();

      if (postDoc.exists) {
        final data = postDoc.data();
        final spaceId = data?['space'] as String?;
        if (spaceId != null && spaceId.isNotEmpty) {
          _postSpaceCache[postId] = spaceId;
          return spaceId;
        }
      }

      // Fallback: Try spacePosts collection (reverse lookup) - expensive, avoid if possible
      final spaces =
          await FirebaseFirestore.instance.collection('spacePosts').get();
      for (var space in spaces.docs) {
        final postsRef = space.reference.collection('posts').doc(postId);
        final spacePostDoc = await postsRef.get();
        if (spacePostDoc.exists) {
          _postSpaceCache[postId] = space.id;
          return space.id;
        }
      }
    } catch (e) {
      // Ignore errors in lookup
    }
    return null;
  }

  /// Public helper to find the space ID for a given post by reverse lookup.
  /// Returns null if no space reference is found.
  Future<String?> findPostSpaceId(String postId) async {
    return await _getPostSpaceId(postId);
  }

  /// Logs a detailed diagnostic snapshot for a given post (structure and references)
  /// Only runs in debug mode to avoid expensive Firestore reads in production
  Future<void> logPostDiagnostics(String postId,
      {String source = 'unknown'}) async {
    // Skip in release builds - this is expensive and only useful for debugging
    if (!kDebugMode) return;

    // Further limit: only log once per post per session
    final cacheKey = 'diag_$postId';
    if (_notFoundPosts.contains(cacheKey)) return;
    _notFoundPosts.add(cacheKey);

    AppLogger.d('Post diagnostic requested',
        category: LogCategory.general,
        data: {'postId': postId, 'source': source});
  }

  Future<DocumentSnapshot> getUser(String user) async {
    return await FirebaseFirestore.instance.collection('users').doc(user).get();
  }

  Future<DocumentSnapshot> getSpace(String space) async {
    return await FirebaseFirestore.instance
        .collection('spaces')
        .doc(space)
        .get();
  }

  /* // Method moved to SpaceService
  Future<int> getSpaceType(String spaceId) async {
    DocumentSnapshot space = await spacesCollection.doc(spaceId).get();
    return (space.data() as Map<String, dynamic>)['spaceType'];
  }
  */

  Future<DocumentSnapshot> getItem(String item) async {
    return await FirebaseFirestore.instance.collection('items').doc(item).get();
  }

  Future<String> getPostSpace(String? post) async {
    DocumentSnapshot postdocuments = await getPost(post);
    return postdocuments['space'];
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getPostReplies(
      String post) async {
    return await _postRepliesCollection
        .doc(post)
        .collection('replies')
        .orderBy('timestamp', descending: true)
        .get();
  }

  Future<bool> isUserSpaceOwner(String space) async {
    SpaceRoles role = await getSpaceRole(space);
    if (role == SpaceRoles.owner || role == SpaceRoles.creator) {
      return true;
    }
    return false;
  }

  Future<bool> isMember(
    String space,
  ) async {
    SpaceRoles role = await getSpaceRole(space);
    if (role == SpaceRoles.member ||
        role == SpaceRoles.admin ||
        role == SpaceRoles.creator ||
        role == SpaceRoles.owner) {
      return true;
    }
    return false;
  }

  Future<bool> isAdmin(
    String space,
  ) async {
    SpaceRoles role = await getSpaceRole(space);
    if (role == SpaceRoles.admin ||
        role == SpaceRoles.creator ||
        role == SpaceRoles.owner) {
      return true;
    }
    return false;
  }

  Future<bool> checkSpaceFeedPostingPermissions(String spaceId) async {
    try {
      // Get the space using the existing getSpace function
      Space space = await SpaceService().getSpace(spaceId);

      // Get the user's role in the space
      SpaceRoles role = await getSpaceRole(spaceId);

      if (space.adminOnlyPosting) {
        // If adminOnlyPosting is true, only admins and creators can post
        return role == SpaceRoles.admin || role == SpaceRoles.creator;
      } else {
        // If adminOnlyPosting is false, members, admins, and creators can post
        return role == SpaceRoles.member ||
            role == SpaceRoles.admin ||
            role == SpaceRoles.creator;
      }
    } catch (e) {
      AppLogger.e('Error checking space feed permissions',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  Future<SpaceRoles> getSpaceRole(String? space) async {
    DocumentSnapshot spaceRoledocuments = await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .doc(user?.uid)
        .get();
    if (spaceRoledocuments.data() == null) return SpaceRoles.none;
    return SpaceRoles.values.firstWhere((element) =>
        element.toString() == "SpaceRoles.${spaceRoledocuments['role']}");
  }

  // Note: searchSpaces removed - use SearchService.searchSpaces() instead
  // for centralized search with smart matching and privacy filtering

  Future<QuerySnapshot> getAllSpaceRoles(String space) async {
    QuerySnapshot spaceRoledocuments = await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .get();
    return spaceRoledocuments;
  }

  Future<QuerySnapshot> getSpaceMembersWithRoles(
      String space, List<String> roles) async {
    QuerySnapshot roleSnapshot = await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .where('role', whereIn: roles)
        .get();

    return roleSnapshot;
  }

  // ============================================================================
  // DEPRECATED FEED METHODS
  // These methods use the old fanout-based userFeed collection.
  // New code should use FeedService which queries posts/ directly.
  // Kept for backward compatibility during migration.
  // ============================================================================

  /// @deprecated Use FeedService instead - this queries the old userFeed collection
  /// Get posts from users that the current user is following
  /// These are posts marked with showOnProfile=true from followed users' personal grams
  @Deprecated('Use FeedService.getFeed() instead')
  Future<List<QueryDocumentSnapshot>> getFollowedUsersPosts(int limit) async {
    if (user?.uid == null) return [];

    try {
      // Get list of users this user is following
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('userFollowing')
          .doc(user!.uid)
          .collection('following')
          .get();

      if (followingSnapshot.docs.isEmpty) return [];

      // Get personal gram IDs for followed users
      final followedUserIds = followingSnapshot.docs.map((d) => d.id).toList();

      // Batch query for profile posts - get from personal grams where showOnProfile=true
      // Note: Firestore limits whereIn to 10 items, so we may need multiple queries
      final List<QueryDocumentSnapshot> allPosts = [];

      for (int i = 0; i < followedUserIds.length; i += 10) {
        final batch = followedUserIds.skip(i).take(10).toList();

        final postsSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where('author', whereIn: batch)
            .where('showOnProfile', isEqualTo: true)
            .orderBy('timestamp', descending: true)
            .limit(limit)
            .get();

        allPosts.addAll(postsSnapshot.docs);
      }

      // Sort by timestamp and limit
      allPosts.sort((a, b) {
        final aTime = (a.data() as Map)['timestamp'] as Timestamp?;
        final bTime = (b.data() as Map)['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return allPosts.take(limit).toList();
    } catch (e) {
      AppLogger.w('Error fetching followed users posts',
          category: LogCategory.general, data: {'error': e.toString()});
      return [];
    }
  }

  /// @deprecated Use FeedService.getFeed() instead
  @Deprecated(
      'Use FeedService.getFeed() instead - queries old userFeed collection')
  Future<List<QueryDocumentSnapshot>> getUserFeed(int limit) async {
    if (user?.uid == null) {
      return getGlobalFeed(limit);
    }

    try {
      QuerySnapshot feedPosts = await FirebaseFirestore.instance
          .collection('userFeed')
          .doc(user!.uid)
          .collection('posts')
          .where('seen', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return feedPosts.docs;
    } catch (e) {
      AppLogger.w('getUserFeed deprecated - use FeedService',
          category: LogCategory.general);
      return [];
    }
  }

  /// @deprecated No longer used - seen/unseen tracking removed in pull-based architecture
  @Deprecated('Seen tracking removed - use FeedService.getFeed() instead')
  Future<List<QueryDocumentSnapshot>> getUserFeedSeen(int limit) async {
    AppLogger.w('getUserFeedSeen deprecated - seen tracking removed',
        category: LogCategory.general);
    return [];
  }

  /// Get global feed posts (used by discovery page)
  /// Note: For main feed, use FeedService.getFeed() instead
  Future<List<QueryDocumentSnapshot>> getGlobalFeed(int limit) async {
    try {
      QuerySnapshot globalFeedPosts = await FirebaseFirestore.instance
          .collection('globalFeed')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return globalFeedPosts.docs;
    } catch (e) {
      AppLogger.e('Error fetching global feed',
          category: LogCategory.general, error: e);
      return [];
    }
  }

  /// @deprecated Seen tracking removed in pull-based feed architecture
  /// No-op method kept for backward compatibility with player widgets
  @Deprecated('Seen tracking removed - this is now a no-op')
  Future<bool> markPostAsSeen(String? postId) async {
    // No-op: Seen tracking is no longer used in pull-based architecture
    // Posts are fetched directly from posts/ collection without seen/unseen state
    return true;
  }

  /// @deprecated userFeed collection deprecated
  @Deprecated('userFeed collection deprecated')
  Future<bool> deleteErroredPost(String? postId) async {
    // No-op: userFeed collection is deprecated
    return true;
  }

  /// Like or unlike a post
  /// Backend Cloud Functions handle:
  /// - likeCount increment/decrement
  /// - Aura awards
  /// - Notifications
  Future<bool> likePost(String postId) async {
    try {
      String? userId = user?.uid;
      if (userId == null) {
        return false; // User is not authenticated
      }

      DocumentReference likeRef =
          _postLikesCollection.doc(postId).collection('likes').doc(userId);

      // Check if already liked
      final likeDoc = await likeRef.get();

      if (likeDoc.exists) {
        // Unlike - delete the like document
        // Backend will decrement likeCount via Cloud Function
        await likeRef.delete();
        AppLogger.d('Post unliked',
            category: LogCategory.general, data: {'postId': postId});
        return false; // Returns false to indicate unliked
      } else {
        // Like - create the like document
        // Backend will increment likeCount, send notification, and award aura via Cloud Functions
        await likeRef.set({'timestamp': FieldValue.serverTimestamp()});
        AppLogger.d('Post liked',
            category: LogCategory.general, data: {'postId': postId});
        return true; // Returns true to indicate liked
      }
    } catch (e) {
      AppLogger.e('Error in likePost', category: LogCategory.general, error: e);
      return false;
    }
  }

  Future<int> getLikeCount(String postId) async {
    try {
      DocumentSnapshot postDoc = await _postsCollection.doc(postId).get();
      return postDoc.exists
          ? (postDoc.data() as Map<String, dynamic>)['likeCount'] ?? 0
          : 0;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      return 0;
    }
  }

  /// Get repost count for a post
  /// Works for both profile and space posts by querying reposts collection directly
  /// This is more reliable than reading from post document (which might be in different collections)
  Future<int> getRepostCount(String postId) async {
    try {
      // Query reposts collection directly - works for both profile and space posts
      // This is the source of truth for repost counts
      final aggregateSnapshot = await FirebaseFirestore.instance
          .collection('reposts')
          .where('originalPostId', isEqualTo: postId)
          .count()
          .get();
      
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      // Fallback: try reading from post document (for backward compatibility)
      // This works for profile posts that are in top-level posts collection
      try {
        DocumentSnapshot postDoc = await _postsCollection.doc(postId).get();
        return postDoc.exists
            ? (postDoc.data() as Map<String, dynamic>)['repostCount'] ?? 0
            : 0;
      } catch (fallbackError) {
        if (kDebugMode) {
          AppLogger.e('Error getting repost count', category: LogCategory.general, error: fallbackError);
        }
        return 0;
      }
    }
  }

  Future<bool> isPostLikedByUser(post) async {
    // Return false for logged-out users without querying Firestore
    if (user?.uid == null) {
      return false;
    }

    DocumentSnapshot likeDoc = await FirebaseFirestore.instance
        .collection('postLikes')
        .doc(post)
        .collection('likes')
        .doc(user!.uid)
        .get();

    return likeDoc.exists;
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
      if (kDebugMode) {
        AppLogger.d('', category: LogCategory.general);
      }
    } catch (e) {
      // Silent error - this is just cleanup
    }
  }

  /// @deprecated No longer needed - userFeed collection deprecated
  @Deprecated('userFeed collection deprecated - use FeedService')
  Future<List<String>> batchValidateUserFeedPosts(String userId,
      {int limit = 50}) async {
    return [];
  }

  /// @deprecated No longer needed - userFeed collection deprecated
  @Deprecated('userFeed collection deprecated - use FeedService')
  Future<List<String>> validateAndCleanupFeedPosts(String userId,
      {int limit = 50}) async {
    return [];
  }

  /// @deprecated No longer needed - userFeed collection deprecated
  @Deprecated('userFeed collection deprecated - use FeedService')
  Future<void> batchCleanupInvalidFeedPosts(
      String userId, List<String> invalidPostIds) async {
    // No-op: userFeed collection is deprecated
  }

  /// @deprecated Use FeedService.loadMore() instead
  @Deprecated('userFeed collection deprecated - use FeedService.loadMore()')
  Future<List<QueryDocumentSnapshot>> getUserFeedNextBatch(
      String lastPostId, int limit) async {
    return [];
  }

  /// @deprecated Seen tracking removed
  @Deprecated('Seen tracking removed - use FeedService')
  Future<List<QueryDocumentSnapshot>> getUserFeedSeenNextBatch(
      String lastPostId, int limit) async {
    return [];
  }

  /// Get the next batch of posts from the global feed, starting after the given post ID
  Future<List<QueryDocumentSnapshot>> getGlobalFeedNextBatch(
      String lastPostId, int limit) async {
    try {
      // Get the last post's timestamp to use as a starting point
      DocumentSnapshot lastPostRef = await FirebaseFirestore.instance
          .collection('globalFeed')
          .doc(lastPostId)
          .get();

      if (!lastPostRef.exists) {
        return [];
      }

      // Use the timestamp for pagination
      final lastTimestamp = lastPostRef['timestamp'];
      if (lastTimestamp == null) return [];

      // Query for posts older than the last one
      QuerySnapshot globalFeedPosts = await FirebaseFirestore.instance
          .collection('globalFeed')
          .orderBy('timestamp', descending: true)
          .startAfter([lastTimestamp])
          .limit(limit)
          .get();

      return globalFeedPosts.docs;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      return [];
    }
  }

  /// @deprecated No longer needed - pull-based feed queries posts/ directly
  /// Returns postIds unchanged (no validation needed when fetching from canonical source)
  @Deprecated(
      'Not needed in pull-based architecture - posts are fetched directly')
  Future<List<String>> validatePostIds(List<String> postIds,
      {bool priorityValidation = false}) async {
    // No validation needed: In pull-based architecture, posts are fetched
    // directly from the canonical posts/ collection, so they're always valid
    return postIds;
  }

  /// Mark a post as missing to prevent future fetch attempts
  void markPostAsMissing(String postId) {
    if (postId.isNotEmpty) {
      _notFoundPosts.add(postId);
    }
  }

  /// Delete a notification when referenced content is missing
  ///
  /// WARNING: This should only be used in very specific cases where we're
  /// absolutely certain the notification is invalid and should be permanently
  /// removed. Most notification widgets now show notifications with fallback
  /// data instead of deleting them, which provides a better user experience.
  ///
  /// Consider showing the notification with fallback data instead of deleting it.
  Future<void> deleteInvalidNotification(
      String userId, String notificationId) async {
    try {
      if (userId.isEmpty || notificationId.isEmpty) return;

      await _notificationsCollection
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      if (kDebugMode) {
        AppLogger.i('Deleted invalid notification',
            category: LogCategory.general,
            data: {'notificationId': notificationId, 'userId': userId});
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
    }
  }

  /// MEMORY LEAK FIX: Dispose method to clean up all cache Maps and Sets
  void dispose() {
    AppLogger.d('DatabaseService - Disposing cache resources',
        category: LogCategory.general,
        data: {
          'postCache': _postCache.length,
          'notFoundPosts': _notFoundPosts.length,
          'staticPostSpaceCache': _postSpaceCache.length,
        });

    // Clear all instance-level caches
    _notFoundPosts.clear();
    _notFoundSpacePosts.clear();
    _postCache.clear();
    _postCacheExpiry.clear();

    AppLogger.d('DatabaseService cache resources disposed successfully',
        category: LogCategory.general);
  }

  /// STATIC CACHE CLEANUP: Periodic cleanup for static _postSpaceCache to prevent leaks
  static void cleanupStaticCache() {
    const int maxStaticCacheSize = 200; // Limit static cache size

    if (_postSpaceCache.length > maxStaticCacheSize) {
      // Remove oldest 50% of entries when limit exceeded
      final entriesToRemove =
          _postSpaceCache.length - (maxStaticCacheSize ~/ 2);
      final keysToRemove = _postSpaceCache.keys.take(entriesToRemove).toList();

      for (final key in keysToRemove) {
        _postSpaceCache.remove(key);
      }

      AppLogger.d('Static postSpaceCache cleanup completed',
          category: LogCategory.general,
          data: {
            'removedEntries': entriesToRemove,
            'remainingEntries': _postSpaceCache.length
          });
    }
  }

  /// Get static cache statistics for monitoring
  static Map<String, dynamic> getStaticCacheStats() {
    return {
      'postSpaceCache': _postSpaceCache.length,
      'maxRecommendedSize': 200,
    };
  }
}
