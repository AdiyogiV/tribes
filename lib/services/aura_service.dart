import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Service for managing user aura scores and gamification
class AuraService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // Aura point values for different actions
  static const int AURA_NAMASTE_RECEIVED = 5;
  static const int AURA_POST_REPLY_RECEIVED = 10;
  static const int AURA_POST_LIKE_RECEIVED = 3;
  static const int AURA_CREATE_POST = 2;
  static const int AURA_CREATE_REPLY = 1;
  static const int AURA_PROFILE_COMPLETE = 20;

  /// Award aura points to a user
  ///
  /// [userId] - The user to award points to
  /// [points] - Number of points to award (can be negative to deduct)
  /// [reason] - Description of why points were awarded
  /// [metadata] - Optional additional data about the event
  /// [trackingId] - Optional unique ID to prevent duplicate awards for the same action
  Future<bool> awardAura({
    required String userId,
    required int points,
    required String reason,
    Map<String, dynamic>? metadata,
    String? trackingId,
  }) async {
    try {
      if (points == 0) {
        AppLogger.w('Attempted to award zero points',
            category: LogCategory.general,
            data: {'userId': userId, 'points': points});
        return false;
      }

      // If trackingId provided, check if already awarded/deducted
      if (trackingId != null) {
        DocumentSnapshot trackingDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('auraTracking')
            .doc(trackingId)
            .get();

        if (trackingDoc.exists) {
          AppLogger.d('⚠️ Aura already processed for this action',
              category: LogCategory.general,
              data: {'userId': userId, 'trackingId': trackingId});
          return false; // Already awarded/deducted
        }
      }

      AppLogger.d(
          '🎯 Starting aura ${points > 0 ? "award" : "deduction"} process',
          category: LogCategory.general,
          data: {'userId': userId, 'points': points, 'reason': reason});

      // Update user's total aura score directly
      DocumentReference userRef = _firestore.collection('users').doc(userId);

      await userRef.set({
        'auraScore': FieldValue.increment(points),
        'lastAuraUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Record tracking if trackingId provided
      if (trackingId != null) {
        try {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('auraTracking')
              .doc(trackingId)
              .set({
            'points': points,
            'reason': reason,
            'timestamp': FieldValue.serverTimestamp(),
            'metadata': metadata ?? {},
          });
        } catch (trackingError) {
          AppLogger.w('Failed to record aura tracking (score still updated)',
              category: LogCategory.database,
              data: {'userId': userId, 'error': trackingError.toString()});
        }
      }

      // Record the aura event in history
      try {
        final historyData = {
          'points': points,
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
          'metadata': metadata ?? {},
        };

        // Extract action and affectedUserId from metadata for top-level access
        if (metadata != null) {
          if (metadata.containsKey('action')) {
            historyData['action'] = metadata['action'];
          }
          if (metadata.containsKey('senderUserId')) {
            historyData['affectedUserId'] = metadata['senderUserId'];
          } else if (metadata.containsKey('likerUserId')) {
            historyData['affectedUserId'] = metadata['likerUserId'];
          } else if (metadata.containsKey('replyAuthorUserId')) {
            historyData['affectedUserId'] = metadata['replyAuthorUserId'];
          }
        }

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('auraHistory')
            .add(historyData);
      } catch (historyError) {
        AppLogger.w('Failed to record aura history (score still updated)',
            category: LogCategory.database,
            data: {'userId': userId, 'error': historyError.toString()});
      }

      AppLogger.d(
          '✅ Successfully ${points > 0 ? "awarded" : "deducted"} ${points.abs()} aura ${points > 0 ? "to" : "from"} user $userId for: $reason',
          category: LogCategory.general,
          data: {'userId': userId, 'points': points, 'reason': reason});

      return true;
    } catch (e, stackTrace) {
      AppLogger.e('❌ Error processing aura',
          category: LogCategory.database,
          error: e,
          stackTrace: stackTrace,
          data: {
            'userId': userId,
            'points': points,
            'reason': reason,
            'errorType': e.runtimeType.toString(),
            'errorMessage': e.toString(),
          });
      return false;
    }
  }

  /// Deduct aura points from a user
  Future<bool> deductAura({
    required String userId,
    required int points,
    required String reason,
    Map<String, dynamic>? metadata,
    String? trackingId,
  }) async {
    return await awardAura(
      userId: userId,
      points: -points.abs(), // Ensure negative
      reason: reason,
      metadata: metadata,
      trackingId: trackingId,
    );
  }

  /// Award aura for receiving a namaste (once per sender per day)
  Future<bool> awardNamasteReceived(
      String recipientUserId, String senderUserId) async {
    // Create tracking ID based on date to allow one namaste per sender per day
    final today = DateTime.now().toIso8601String().split('T')[0];
    final trackingId = 'namaste_${senderUserId}_${recipientUserId}_$today';

    return await awardAura(
      userId: recipientUserId,
      points: AURA_NAMASTE_RECEIVED,
      reason: 'Received namaste',
      metadata: {'senderUserId': senderUserId, 'action': 'namaste_received'},
      trackingId: trackingId,
    );
  }

  /// Award aura when someone replies to user's post
  Future<bool> awardPostReplyReceived({
    required String postAuthorUserId,
    required String replyAuthorUserId,
    required String postId,
    required String replyPostId,
  }) async {
    // Don't award aura if user replies to their own post
    if (postAuthorUserId == replyAuthorUserId) return false;

    // Use replyPostId as tracking ID to prevent duplicate awards for the same reply
    final trackingId = 'reply_received_$replyPostId';

    return await awardAura(
      userId: postAuthorUserId,
      points: AURA_POST_REPLY_RECEIVED,
      reason: 'Received reply on post',
      metadata: {
        'replyAuthorUserId': replyAuthorUserId,
        'postId': postId,
        'replyPostId': replyPostId,
        'action': 'post_reply_received',
      },
      trackingId: trackingId,
    );
  }

  /// Award aura when someone likes user's post
  Future<bool> awardPostLikeReceived({
    required String postAuthorUserId,
    required String likerUserId,
    required String postId,
  }) async {
    // Don't award aura if user likes their own post
    if (postAuthorUserId == likerUserId) return false;

    // Use combination of postId and likerId as tracking ID
    final trackingId = 'like_${postId}_$likerUserId';

    return await awardAura(
      userId: postAuthorUserId,
      points: AURA_POST_LIKE_RECEIVED,
      reason: 'Received like on post',
      metadata: {
        'likerUserId': likerUserId,
        'postId': postId,
        'action': 'post_like_received',
      },
      trackingId: trackingId,
    );
  }

  /// Deduct aura when someone unlikes user's post
  Future<bool> deductPostLikeRemoved({
    required String postAuthorUserId,
    required String likerUserId,
    required String postId,
  }) async {
    // Don't deduct if user unliked their own post
    if (postAuthorUserId == likerUserId) return false;

    // Use same tracking ID as the award to remove the tracking
    final trackingId = 'like_${postId}_$likerUserId';

    // Check if aura was ever awarded for this like
    DocumentSnapshot trackingDoc = await _firestore
        .collection('users')
        .doc(postAuthorUserId)
        .collection('auraTracking')
        .doc(trackingId)
        .get();

    if (!trackingDoc.exists) {
      // Never awarded, nothing to deduct
      return false;
    }

    // Delete the tracking document
    await _firestore
        .collection('users')
        .doc(postAuthorUserId)
        .collection('auraTracking')
        .doc(trackingId)
        .delete();

    // Deduct the points
    return await awardAura(
      userId: postAuthorUserId,
      points: -AURA_POST_LIKE_RECEIVED,
      reason: 'Like removed from post',
      metadata: {
        'likerUserId': likerUserId,
        'postId': postId,
        'action': 'post_like_removed',
      },
      trackingId: null, // Don't track the deduction itself
    );
  }

  /// Award aura for creating a post
  Future<bool> awardPostCreated({
    required String authorUserId,
    required String postId,
  }) async {
    // Use postId as tracking ID to prevent duplicate awards
    final trackingId = 'post_created_$postId';

    return await awardAura(
      userId: authorUserId,
      points: AURA_CREATE_POST,
      reason: 'Created post',
      metadata: {
        'postId': postId,
        'action': 'post_created',
      },
      trackingId: trackingId,
    );
  }

  /// Award aura for creating a reply
  Future<bool> awardReplyCreated({
    required String authorUserId,
    required String replyPostId,
    required String originalPostId,
  }) async {
    // Use replyPostId as tracking ID to prevent duplicate awards
    final trackingId = 'reply_created_$replyPostId';

    return await awardAura(
      userId: authorUserId,
      points: AURA_CREATE_REPLY,
      reason: 'Created reply',
      metadata: {
        'replyPostId': replyPostId,
        'originalPostId': originalPostId,
        'action': 'reply_created',
      },
      trackingId: trackingId,
    );
  }

  /// Award one-time bonus for completing profile
  /// Note: Only updates user document directly. auraHistory is backend-only (Firestore rules).
  Future<bool> awardProfileComplete(String userId) async {
    try {
      // Check if already awarded
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

      if (userData?['auraProfileCompleteAwarded'] == true) {
        return false; // Already awarded
      }

      // Check if profile is actually complete
      bool hasName = userData != null &&
          userData['name'] != null &&
          (userData['name'] as String).isNotEmpty;
      bool hasNickname = userData != null &&
          userData['nickname'] != null &&
          (userData['nickname'] as String).isNotEmpty;
      bool hasPicture = userData != null &&
          userData['displayPicture'] != null &&
          (userData['displayPicture'] as String).isNotEmpty;

      if (!hasName || !hasNickname || !hasPicture) {
        return false; // Profile not complete
      }

      // Award the bonus and mark as awarded
      // Note: auraHistory writes are backend-only per Firestore rules,
      // so we only update the user document here
      DocumentReference userRef = _firestore.collection('users').doc(userId);
      await userRef.set({
        'auraScore': FieldValue.increment(AURA_PROFILE_COMPLETE),
        'auraProfileCompleteAwarded': true,
        'lastAuraUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AppLogger.d('Awarded profile completion bonus to user $userId',
          category: LogCategory.general,
          data: {'userId': userId, 'points': AURA_PROFILE_COMPLETE});

      return true;
    } catch (e) {
      AppLogger.e('Error awarding profile completion bonus',
          category: LogCategory.database, error: e, data: {'userId': userId});
      return false;
    }
  }

  /// Check and award profile completion bonus if eligible (via backend callable).
  /// Backend awards aura and writes to auraHistory; avoids double-award and ensures history.
  Future<void> checkAndAwardProfileComplete(String userId) async {
    if (_auth.currentUser?.uid != userId) return;
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('awardAuraAction');
      final result = await callable.call({'action': 'profile_complete'});
      final data = result.data as Map<String, dynamic>?;
      if (data != null &&
          data['success'] == true &&
          data['alreadyAwarded'] != true) {
        AppLogger.d('Profile complete aura awarded',
            category: LogCategory.general, data: {'userId': userId});
      }
    } catch (e) {
      AppLogger.w(
          'Profile complete award callable failed (may already be awarded or profile incomplete)',
          category: LogCategory.general,
          data: {'error': e.toString()});
    }
  }

  /// Get user's current aura score
  Future<int> getUserAuraScore(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return 0;

      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      return userData?['auraScore'] as int? ?? 0;
    } catch (e) {
      AppLogger.e('Error getting user aura score',
          category: LogCategory.database, error: e, data: {'userId': userId});
      return 0;
    }
  }

  /// Get user's aura history (recent events)
  Future<List<Map<String, dynamic>>> getUserAuraHistory(String userId,
      {int limit = 20}) async {
    try {
      QuerySnapshot historySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('auraHistory')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return historySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      AppLogger.e('Error getting user aura history',
          category: LogCategory.database, error: e, data: {'userId': userId});
      return [];
    }
  }

  /// Get aura level info for a given score
  static AuraLevel getAuraLevel(int score) {
    if (score >= 2500) {
      return AuraLevel(
        name: 'Legend',
        icon: '💎',
        minScore: 2500,
        maxScore: null,
        color: 0xFF9C27B0, // Purple
      );
    } else if (score >= 1000) {
      return AuraLevel(
        name: 'Master',
        icon: '👑',
        minScore: 1000,
        maxScore: 2499,
        color: 0xFFFFD700, // Gold
      );
    } else if (score >= 500) {
      return AuraLevel(
        name: 'Expert',
        icon: '⭐',
        minScore: 500,
        maxScore: 999,
        color: 0xFF2196F3, // Blue
      );
    } else if (score >= 100) {
      return AuraLevel(
        name: 'Enthusiast',
        icon: '🔥',
        minScore: 100,
        maxScore: 499,
        color: 0xFFFF5722, // Deep Orange
      );
    } else {
      return AuraLevel(
        name: 'Novice',
        icon: '🌱',
        minScore: 0,
        maxScore: 99,
        color: 0xFF4CAF50, // Green
      );
    }
  }

  /// Get leaderboard (top users by aura score)
  /// Includes all users, even those with zero or no aura score
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 50}) async {
    try {
      // Query all users - we can't use orderBy('auraScore') because
      // Firestore excludes documents that don't have the field
      QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

      // Map and sort in memory to include users without auraScore field
      final users = usersSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return {
          'userId': doc.id,
          'name': data?['name'] ?? 'Unknown',
          'nickname': data?['nickname'] ?? '',
          'displayPicture': data?['displayPicture'] ?? '',
          'auraScore': data?['auraScore'] ?? 0,
        };
      }).toList();

      // Sort by auraScore descending
      users.sort(
          (a, b) => (b['auraScore'] as int).compareTo(a['auraScore'] as int));

      // Return limited results
      return users.take(limit).toList();
    } catch (e) {
      AppLogger.e('Error getting leaderboard',
          category: LogCategory.database, error: e);
      return [];
    }
  }

  /// Get user's rank in leaderboard
  /// Counts all users, including those without auraScore (treated as 0)
  Future<int?> getUserRank(String userId) async {
    try {
      int userScore = await getUserAuraScore(userId);

      // Get all users and count those with higher scores
      QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

      int higherCount = 0;
      for (final doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final score = data?['auraScore'] ?? 0;
        if (score > userScore) {
          higherCount++;
        }
      }

      return higherCount + 1;
    } catch (e) {
      AppLogger.e('Error getting user rank',
          category: LogCategory.database, error: e, data: {'userId': userId});
      return null;
    }
  }
}

/// Model class for aura levels
class AuraLevel {
  final String name;
  final String icon;
  final int minScore;
  final int? maxScore;
  final int color;

  AuraLevel({
    required this.name,
    required this.icon,
    required this.minScore,
    this.maxScore,
    required this.color,
  });

  /// Get progress percentage to next level (0-100)
  double getProgress(int currentScore) {
    if (maxScore == null) return 100.0; // Max level

    int scoreInLevel = currentScore - minScore;
    int levelRange = maxScore! - minScore + 1;

    return (scoreInLevel / levelRange * 100).clamp(0.0, 100.0);
  }

  /// Get points needed for next level
  int? getPointsToNextLevel(int currentScore) {
    if (maxScore == null) return null; // Max level
    return (maxScore! + 1) - currentScore;
  }
}
