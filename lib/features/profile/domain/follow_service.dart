import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Service for managing follow relationships
///
/// NEW ARCHITECTURE (v2):
/// Uses dedicated collections for cleaner data model:
/// - /userFollowing/{userId}/following/{targetUserId} - who the user follows
/// - /userFollowers/{userId}/followers/{followerId} - who follows the user
///
/// This replaces the old profile gram approach where following was implemented
/// as joining a user's profile gram with 'follower' role.
class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Live current user - never cached, so logout/login always uses the active account.
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  // Cache for follow status to reduce reads
  final Map<String, bool> _followCache = {};
  final Map<String, int> _followerCountCache = {};
  final Map<String, int> _followingCountCache = {};

  /// Follow status enum values
  static const String statusPending = 'pending';
  static const String statusFollowing = 'following';

  /// Follow a user
  ///
  /// For public profiles: writes status='following' directly (instant follow)
  /// For private profiles: writes status='pending' (request that needs approval)
  Future<bool> followUser(String targetUserId,
      {bool targetIsPrivate = false}) async {
    if (_currentUser == null) return false;
    if (_currentUser!.uid == targetUserId) return false; // Can't follow self

    try {
      final currentUserId = _currentUser!.uid;

      // Public profiles: instant follow. Private profiles: pending request.
      final status = targetIsPrivate ? statusPending : statusFollowing;

      await _firestore
          .collection('userFollowing')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .set({
        'timestamp': FieldValue.serverTimestamp(),
        'targetUserId': targetUserId,
        'status': status,
      });

      // Update local cache
      _followCache['$currentUserId:$targetUserId'] = true;
      _followerCountCache.remove(targetUserId);
      _followingCountCache.remove(currentUserId);

      AppLogger.i('Follow ${targetIsPrivate ? "request sent" : "completed"}',
          category: LogCategory.general,
          data: {
            'follower': currentUserId,
            'followed': targetUserId,
            'status': status
          });

      return true;
    } catch (e) {
      AppLogger.e('Error following user',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Cancel a pending follow request
  Future<bool> cancelFollowRequest(String targetUserId) async {
    return unfollowUser(targetUserId); // Same operation
  }

  /// Unfollow a user
  ///
  /// Frontend only deletes from the user's own userFollowing collection.
  /// Backend Cloud Function (onUnfollow) handles:
  /// - Deleting the follower record from target's userFollowers collection
  /// - Decrementing followerCount/followingCount on both user documents
  Future<bool> unfollowUser(String targetUserId) async {
    if (_currentUser == null) return false;

    try {
      final currentUserId = _currentUser!.uid;

      // Only delete from current user's following collection
      // Backend handles everything else (followers record, counts)
      await _firestore
          .collection('userFollowing')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .delete();

      // Update local cache optimistically
      _followCache['$currentUserId:$targetUserId'] = false;
      _followerCountCache.remove(targetUserId);
      _followingCountCache.remove(currentUserId);

      AppLogger.i('User unfollowed successfully',
          category: LogCategory.general,
          data: {'unfollower': currentUserId, 'unfollowed': targetUserId});

      return true;
    } catch (e) {
      AppLogger.e('Error unfollowing user',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Check if current user is following a target user
  Future<bool> isFollowing(String targetUserId) async {
    if (_currentUser == null) return false;
    if (_currentUser!.uid == targetUserId) return false;

    final cacheKey = '${_currentUser!.uid}:$targetUserId';

    // Check cache first
    if (_followCache.containsKey(cacheKey)) {
      return _followCache[cacheKey]!;
    }

    try {
      final doc = await _firestore
          .collection('userFollowing')
          .doc(_currentUser!.uid)
          .collection('following')
          .doc(targetUserId)
          .get();

      final isFollowing = doc.exists;
      _followCache[cacheKey] = isFollowing;
      return isFollowing;
    } catch (e) {
      AppLogger.e('Error checking follow status',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Get detailed follow status: null (not following), 'pending', or 'following'
  /// Always fetches fresh from Firestore (status can change via backend)
  Future<String?> getFollowStatus(String targetUserId) async {
    if (_currentUser == null) return null;
    if (_currentUser!.uid == targetUserId) return null;

    try {
      final doc = await _firestore
          .collection('userFollowing')
          .doc(_currentUser!.uid)
          .collection('following')
          .doc(targetUserId)
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      return data?['status'] as String? ??
          statusFollowing; // Legacy docs without status are following
    } catch (e) {
      AppLogger.e('Error getting follow status',
          category: LogCategory.general, error: e);
      return null;
    }
  }

  /// Clear cache for a specific user (call after follow/unfollow action)
  void clearCacheForUser(String targetUserId) {
    if (_currentUser == null) return;
    final cacheKey = '${_currentUser!.uid}:$targetUserId';
    _followCache.remove(cacheKey);
    final reverseCacheKey = '$targetUserId:${_currentUser!.uid}';
    _followCache.remove(reverseCacheKey);
  }

  /// Check if current user is a confirmed follower (status = 'following')
  Future<bool> isConfirmedFollower(String targetUserId) async {
    final status = await getFollowStatus(targetUserId);
    return status == statusFollowing;
  }

  /// Stream of whether current user is following target user
  Stream<bool> isFollowingStream(String targetUserId) {
    if (_currentUser == null || _currentUser!.uid == targetUserId) {
      return Stream.value(false);
    }

    return _firestore
        .collection('userFollowing')
        .doc(_currentUser!.uid)
        .collection('following')
        .doc(targetUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Get follower count for a user
  /// Set forceRefresh=true to bypass cache (e.g., on pull-to-refresh)
  Future<int> getFollowerCount(String userId,
      {bool forceRefresh = false}) async {
    // Check cache unless forcing refresh
    if (!forceRefresh && _followerCountCache.containsKey(userId)) {
      return _followerCountCache[userId]!;
    }

    try {
      // Read from user document (denormalized count)
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return 0;

      final data = userDoc.data();
      final count = (data?['followerCount'] as int?) ?? 0;

      _followerCountCache[userId] = count;
      return count;
    } catch (e) {
      AppLogger.e('Error getting follower count',
          category: LogCategory.general, error: e);
      return 0;
    }
  }

  /// Get following count for a user
  /// Set forceRefresh=true to bypass cache (e.g., on pull-to-refresh)
  Future<int> getFollowingCount(String userId,
      {bool forceRefresh = false}) async {
    // Check cache unless forcing refresh
    if (!forceRefresh && _followingCountCache.containsKey(userId)) {
      return _followingCountCache[userId]!;
    }

    try {
      // Read from user document (denormalized count)
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return 0;

      final data = userDoc.data();
      final count = (data?['followingCount'] as int?) ?? 0;

      _followingCountCache[userId] = count;
      return count;
    } catch (e) {
      AppLogger.e('Error getting following count',
          category: LogCategory.general, error: e);
      return 0;
    }
  }

  /// Get followers list for a user
  Future<List<String>> getFollowers(String userId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('userFollowers')
          .doc(userId)
          .collection('followers')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      AppLogger.e('Error getting followers list',
          category: LogCategory.general, error: e);
      return [];
    }
  }

  /// Get following list for a user
  Future<List<String>> getFollowing(String userId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('userFollowing')
          .doc(userId)
          .collection('following')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      AppLogger.e('Error getting following list',
          category: LogCategory.general, error: e);
      return [];
    }
  }

  /// Check if current user and target user have mutual follow (friends)
  /// Returns true only if BOTH users follow each other with status='following'
  Future<bool> isMutualFollow(String targetUserId) async {
    if (_currentUser == null) return false;
    if (_currentUser!.uid == targetUserId) return false;

    try {
      final currentUserId = _currentUser!.uid;

      // Check both directions in parallel:
      // 1. Your following status (from userFollowing - you own this)
      // 2. Their follow status (from userFollowers - backend-managed, public read)
      final results = await Future.wait([
        _firestore
            .collection('userFollowing')
            .doc(currentUserId)
            .collection('following')
            .doc(targetUserId)
            .get(),
        _firestore
            .collection('userFollowers')
            .doc(currentUserId)
            .collection('followers')
            .doc(targetUserId)
            .get(),
      ]);

      final youFollowThem = results[0];
      final theyFollowYou = results[1];

      // Both must exist
      if (!youFollowThem.exists || !theyFollowYou.exists) {
        return false;
      }

      // Both must have status='following' (not pending)
      final yourStatus =
          youFollowThem.data()?['status'] as String? ?? statusFollowing;
      final theirStatus =
          theyFollowYou.data()?['status'] as String? ?? statusFollowing;

      return yourStatus == statusFollowing && theirStatus == statusFollowing;
    } catch (e) {
      AppLogger.e('Error checking mutual follow',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Check if target user follows the current user
  /// Uses userFollowers collection (backend-managed, has public read access)
  Future<bool> isFollowedBy(String targetUserId) async {
    if (_currentUser == null) return false;
    if (_currentUser!.uid == targetUserId) return false;

    final currentUserId = _currentUser!.uid;

    try {
      // Check userFollowers/{currentUserId}/followers/{targetUserId}
      // This collection is maintained by backend and has public read access
      final doc = await _firestore
          .collection('userFollowers')
          .doc(currentUserId)
          .collection('followers')
          .doc(targetUserId)
          .get();

      if (!doc.exists) return false;

      // Only count as "following" if status is confirmed (not pending)
      final status = doc.data()?['status'] as String? ?? statusFollowing;
      return status == statusFollowing;
    } catch (e) {
      AppLogger.e(
          'isFollowedBy: Error checking if $targetUserId follows $currentUserId',
          category: LogCategory.general,
          error: e);
      return false;
    }
  }

  /// Check if target user has a PENDING follow request to the current user
  /// Returns true if they've requested to follow us but we haven't approved yet
  /// This is useful to show "Accept/Decline" on their profile
  Future<bool> hasPendingRequestToMe(String targetUserId) async {
    if (_currentUser == null) return false;
    if (_currentUser!.uid == targetUserId) return false;

    final currentUserId = _currentUser!.uid;

    try {
      // Check their following document for us
      // userFollowing/{targetUserId}/following/{currentUserId}
      final doc = await _firestore
          .collection('userFollowing')
          .doc(targetUserId)
          .collection('following')
          .doc(currentUserId)
          .get();

      if (!doc.exists) return false;

      // Check if status is 'pending'
      final status = doc.data()?['status'] as String? ?? statusFollowing;
      return status == statusPending;
    } catch (e) {
      AppLogger.e(
          'hasPendingRequestToMe: Error checking pending request from $targetUserId',
          category: LogCategory.general,
          error: e);
      return false;
    }
  }

  /// Get follower count tier string (e.g., "10+", "100+", "1K+")
  /// We don't show exact counts to reduce vanity metrics
  String getFollowerTier(int count) {
    if (count < 10) return count.toString();
    if (count < 100) return '${(count ~/ 10) * 10}+';
    if (count < 1000) return '${(count ~/ 100) * 100}+';
    if (count < 10000) return '${(count / 1000).toStringAsFixed(1)}K+';
    return '${(count ~/ 1000)}K+';
  }

  /// Clear caches (call on logout or user switch)
  void clearCache() {
    _followCache.clear();
    _followerCountCache.clear();
    _followingCountCache.clear();
  }
}
