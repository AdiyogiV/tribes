import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import '../user_service.dart';

/// Extension on [UserService] for user blocking operations.
extension UserBlock on UserService {
  Future<void> blockUser(String blockedUserId) async {
    if (user == null) return;

    await blockCollection
        .doc(user!.uid)
        .collection('blocked')
        .doc(blockedUserId)
        .set({
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String unblockedUserId) async {
    if (user == null) return;

    await blockCollection
        .doc(user!.uid)
        .collection('blocked')
        .doc(unblockedUserId)
        .delete();
  }

  Future<bool> isUserBlocked(String userId) async {
    if (user == null) return false;

    final blockDoc = await blockCollection
        .doc(user!.uid)
        .collection('blocked')
        .doc(userId)
        .get();

    return blockDoc.exists;
  }

  Future<bool> isBlockedByUser(String userId) async {
    if (user == null) return false;

    final blockDoc = await blockCollection
        .doc(userId)
        .collection('blocked')
        .doc(user!.uid)
        .get();

    return blockDoc.exists;
  }

  Future<List<String>> getBlockedUsers() async {
    if (user == null) return [];

    final querySnapshot =
        await blockCollection.doc(user!.uid).collection('blocked').get();

    return querySnapshot.docs.map((doc) => doc.id).toList();
  }

  /// Gets list of users who have blocked the current user.
  /// Uses collectionGroup query for efficiency instead of reading all users.
  /// IMPORTANT: Requires a Firestore composite index on blocks/{userId}/blocked
  Future<List<String>> getBlockedByUsers() async {
    if (user == null) return [];

    try {
      // Use collectionGroup query to find all 'blocked' docs where doc.id == current user
      // This is O(k) where k = number of users who blocked this user, instead of O(n) for all users
      final querySnapshot = await firestore
          .collectionGroup('blocked')
          .where(FieldPath.documentId, isEqualTo: user!.uid)
          .get();

      // Extract the parent document IDs (the users who blocked this user)
      final blockedByUsers = querySnapshot.docs
          .map((doc) {
            // Path is: blocks/{blockerId}/blocked/{blockedUserId}
            // We need to extract {blockerId}
            final pathSegments = doc.reference.path.split('/');
            // pathSegments = ['blocks', '{blockerId}', 'blocked', '{blockedUserId}']
            if (pathSegments.length >= 2) {
              return pathSegments[1]; // Return the blocker's userId
            }
            return null;
          })
          .whereType<String>()
          .toList();

      return blockedByUsers;
    } catch (e) {
      AppLogger.e('Error getting blocked-by users',
          category: LogCategory.database, error: e);
      // Fallback: return empty list rather than failing
      return [];
    }
  }
}
