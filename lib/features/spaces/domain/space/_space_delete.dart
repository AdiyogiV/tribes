import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/models/space_roles.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import '../space_service.dart';

/// Extension on [SpaceService] for space and post deletion operations.
extension SpaceDelete on SpaceService {
  Future<bool> deleteSpace(String spaceId) async {
    try {
      final user = getCurrentUser();
      final spaceRole = await getSpaceRole(spaceId, user);

      if (spaceRole != SpaceRoles.creator) {
        AppLogger.i(
          'User is not the creator of this space',
          category: LogCategory.general,
          data: {'spaceId': spaceId},
        );
        return false;
      }

      WriteBatch batch = firestore.batch();

      // Delete space document
      batch.delete(spaces.doc(spaceId));

      // Get all users in the space
      QuerySnapshot spaceRolesDocs =
          await spaceRoles.doc(spaceId).collection('roles').get();

      // Delete from userSpaces for users in the space
      for (var roleDoc in spaceRolesDocs.docs) {
        String userId = roleDoc.id;
        batch.delete(userSpaces.doc(userId).collection('spaces').doc(spaceId));
      }

      // Delete space roles
      for (var roleDoc in spaceRolesDocs.docs) {
        batch.delete(roleDoc.reference);
      }

      // Delete posts in the space
      QuerySnapshot spacePosts = await firestore
          .collection('spacePosts')
          .doc(spaceId)
          .collection('posts')
          .get();

      for (var postDoc in spacePosts.docs) {
        await deletePostAndRepliesRecursively(postDoc.id, spaceId, batch);
      }

      // Try to delete space display picture
      try {
        await storage.ref().child('spaces/$spaceId/displayPicture').delete();
      } catch (e) {
        AppLogger.i(
          'No display picture found for space',
          category: LogCategory.general,
          data: {'spaceId': spaceId},
        );
      }

      // Commit the batch
      await batch.commit();

      AppLogger.i(
        'Gram and all its contents deleted successfully',
        category: LogCategory.general,
        data: {'spaceId': spaceId},
      );
      return true;
    } catch (e) {
      AppLogger.e(
        'Error deleting space',
        category: LogCategory.general,
        error: e,
      );
      return false;
    }
  }

  Future<void> deletePostAndRepliesRecursively(
      String postId, String spaceId, WriteBatch batch) async {
    // Delete the post document
    batch.delete(firestore.collection('posts').doc(postId));

    // Delete the post from spacePosts
    batch.delete(firestore
        .collection('spacePosts')
        .doc(spaceId)
        .collection('posts')
        .doc(postId));

    // Get all replies for this post
    QuerySnapshot postReplies = await firestore
        .collection('postReplies')
        .doc(postId)
        .collection('replies')
        .get();

    // Recursively delete each reply
    for (var replyDoc in postReplies.docs) {
      String replyId = replyDoc.id;
      await deletePostAndRepliesRecursively(replyId, spaceId, batch);
    }

    // Delete the postReplies document for this post
    batch.delete(firestore.collection('postReplies').doc(postId));

    // Try to delete storage files
    try {
      await storage.ref().child('posts/$postId/thumbnail.jpg').delete();
    } catch (e) {
      AppLogger.i(
        'No thumbnail found for post',
        category: LogCategory.general,
        data: {'postId': postId},
      );
    }
    try {
      await storage.ref().child('posts/$postId/video.mp4').delete();
    } catch (e) {
      AppLogger.i(
        'No video found for post',
        category: LogCategory.general,
        data: {'postId': postId},
      );
    }
  }

  Future<bool> clearAllPostsInSpace(String spaceId) async {
    try {
      WriteBatch batch = firestore.batch();

      // Get all posts in the space
      QuerySnapshot spacePosts = await firestore
          .collection('spacePosts')
          .doc(spaceId)
          .collection('posts')
          .get();

      for (var postDoc in spacePosts.docs) {
        batch.delete(postDoc.reference);
        await deletePostAndRepliesRecursively(postDoc.id, spaceId, batch);
      }

      // Commit the batch
      await batch.commit();

      AppLogger.i(
        'All posts in the space have been cleared successfully',
        category: LogCategory.general,
        data: {'spaceId': spaceId},
      );
      return true;
    } catch (e) {
      AppLogger.e(
        'Error clearing posts in space',
        category: LogCategory.general,
        error: e,
      );
      return false;
    }
  }
}
