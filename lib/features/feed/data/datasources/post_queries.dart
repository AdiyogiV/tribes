import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Mixin providing post feed/query operations: space feeds, user posts, replies, and cleanup
mixin PostQueriesMixin {
  FirebaseFirestore get firestore;
  User? get currentUser;

  /// Gets the space ID for a post
  Future<String?> getPostSpace(String postId,
      {required Future<DocumentSnapshot> Function(String) getPost}) async {
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

  /// Gets replies to a post
  Future<QuerySnapshot?> getPostReplies(String postId) async {
    try {
      return await firestore
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

  // ── Stream queries (used by presentation layer) ────────────────────

  /// Streams all posts for a given space, ordered newest-first.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamPostsBySpace(
      String spaceId) {
    return firestore
        .collection('posts')
        .where('space', isEqualTo: spaceId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Streams a user's replies subcollection.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserReplies(String uid) {
    return firestore
        .collection('userReplies')
        .doc(uid)
        .collection('replies')
        .orderBy('timestamp')
        .snapshots();
  }

  /// Streams profile posts for a user from the `posts` collection.
  ///
  /// When [repostsOnly] is true, only returns reposts (isRepost == true).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamProfilePosts(
    String uid, {
    int limit = 50,
    bool repostsOnly = false,
  }) {
    Query<Map<String, dynamic>> query = firestore
        .collection('posts')
        .where('author', isEqualTo: uid)
        .where('contextType', isEqualTo: 'profile')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (repostsOnly) {
      query = query.where('isRepost', isEqualTo: true);
    }

    return query.snapshots();
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
      if (currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? currentUser!.uid : space;

      await firestore
          .collection('spacePosts')
          .doc(space)
          .collection('posts')
          .doc(postId)
          .set({
        "author": currentUser!.uid,
        "title": title ?? '',
        "thumbnail": thumbnailUrl,
        "replyTo": replyTo,
        "link": link,
        "video": videoUrl,
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update the space's last update timestamp
      await firestore.collection('spacePosts').doc(space).set({
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
      if (currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? currentUser!.uid : space;

      await firestore
          .collection('spacePosts')
          .doc(space)
          .collection('posts')
          .doc(postId)
          .set({
        "author": currentUser!.uid,
        "title": title ?? '',
        "content": content,
        "replyTo": replyTo,
        "link": link,
        "postType": "text",
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update the space's last update timestamp
      await firestore.collection('spacePosts').doc(space).set({
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
      if (currentUser == null) return false;

      await firestore
          .collection('userPosts')
          .doc(currentUser!.uid)
          .collection('posts')
          .doc(postId)
          .set({
        "author": currentUser!.uid,
        "title": title ?? '',
        "content": content,
        "replyTo": replyTo,
        "link": link,
        "postType": "text",
        "contextType": "profile",
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update user's post count
      await firestore.collection('userPosts').doc(currentUser!.uid).set({
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
      if (currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? currentUser!.uid : space;

      await firestore
          .collection('spacePosts')
          .doc(space)
          .collection('posts')
          .doc(postId)
          .set({
        "author": currentUser!.uid,
        "title": title ?? '',
        "video": imageUrl, // Store in 'video' field for consistency
        "replyTo": replyTo,
        "link": link,
        "postType": "image",
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update the space's last update timestamp
      await firestore.collection('spacePosts').doc(space).set({
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
      if (currentUser == null) return false;

      await firestore
          .collection('userPosts')
          .doc(currentUser!.uid)
          .collection('posts')
          .doc(postId)
          .set({
        "author": currentUser!.uid,
        "title": title ?? '',
        "video": imageUrl, // Store in 'video' field for consistency
        "replyTo": replyTo,
        "link": link,
        "postType": "image",
        "contextType": "profile",
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update user's post count
      await firestore.collection('userPosts').doc(currentUser!.uid).set({
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
      if (currentUser == null) return false;

      await firestore
          .collection('userPosts')
          .doc(currentUser!.uid)
          .collection('posts')
          .doc(postId)
          .set({
        "author": currentUser!.uid,
        "title": title ?? '',
        "audioUrl": audioUrl,
        "duration": durationInSeconds,
        "replyTo": replyTo,
        "postType": "audio",
        "contextType": "profile",
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update user's post count
      await firestore.collection('userPosts').doc(currentUser!.uid).set({
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
      if (currentUser == null) return false;

      await firestore
          .collection('userPosts')
          .doc(currentUser!.uid)
          .collection('posts')
          .doc(postId)
          .set({
        "author": currentUser!.uid,
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
      await firestore.collection('userPosts').doc(currentUser!.uid).set({
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
      if (currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? currentUser!.uid : space;

      // Create the reply document
      // Backend Cloud Functions handle:
      // - replyCount increment via awardReplyAura trigger
      // - Aura awards to both post author and reply author
      await firestore
          .collection('postReplies')
          .doc(originalPostId)
          .collection('replies')
          .doc(replyPostId)
          .set({
        "author": currentUser!.uid,
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
      if (currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? currentUser!.uid : space;

      await firestore
          .collection('spacePosts')
          .doc(space)
          .collection('posts')
          .doc(postId)
          .set({
        "author": currentUser!.uid,
        "title": title ?? '',
        "audioUrl": audioUrl,
        "duration": durationInSeconds,
        "replyTo": replyTo,
        "postType": "audio",
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update the space's last update timestamp
      await firestore.collection('spacePosts').doc(space).set({
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
      if (currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? currentUser!.uid : space;

      // Create the reply document
      // Backend Cloud Functions handle:
      // - replyCount increment via awardReplyAura trigger
      // - Aura awards to both post author and reply author
      await firestore
          .collection('postReplies')
          .doc(originalPostId)
          .collection('replies')
          .doc(replyPostId)
          .set({
        "author": currentUser!.uid,
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
      if (currentUser == null) return false;

      // Ensure space is not empty
      space = space.isEmpty ? currentUser!.uid : space;

      // Create the reply document
      // Backend Cloud Functions handle:
      // - replyCount increment via awardReplyAura trigger
      // - Aura awards to both post author and reply author
      await firestore
          .collection('postReplies')
          .doc(originalPostId)
          .collection('replies')
          .doc(replyPostId)
          .set({
        "author": currentUser!.uid,
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
      if (currentUser == null) return false;

      // Add reply to postReplies collection
      await firestore
          .collection('postReplies')
          .doc(originalPostId)
          .collection('replies')
          .doc(replyPostId)
          .set({
        "space": space,
        "author": currentUser!.uid,
        "title": title ?? '',
        "video": videoUrl,
        "link": link,
        "thumbnail": thumbnailUrl,
        "timestamp": FieldValue.serverTimestamp()
      });

      // Update the space's last activity timestamp for real-time ordering
      await firestore.collection('spacePosts').doc(space).set({
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
      if (currentUser == null) return false;

      await firestore
          .collection('userReplies')
          .doc(recipientUserId)
          .collection('replies')
          .doc(postId)
          .set({
        "space": space,
        "author": currentUser!.uid,
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

  /// Clean up missing post references in the background
  void cleanupMissingPostReferences(
    String postId, {
    required Future<String?> Function(String) getPostSpaceId,
    required Future<void> Function(String, String) cleanupSpacePost,
    required Future<bool> Function(String?) deleteFromUserFeed,
  }) {
    // Don't await to allow this to run in background
    Future(() async {
      try {
        // Get space ID if available
        String? spaceId = await getPostSpaceId(postId);
        if (spaceId != null) {
          await cleanupSpacePost(postId, spaceId);
        }

        // Also clean from user feed
        if (currentUser?.uid != null) {
          await deleteFromUserFeed(postId);
        }
      } catch (cleanupError) {
        // Ignore cleanup errors
        AppLogger.w('Error during background cleanup',
            category: LogCategory.general,
            data: {'error': cleanupError.toString()});
      }
    });
  }

  /// Clean up missing post references from space collections
  Future<void> cleanupMissingSpacePost(
      String postId, String spaceId, Set<String> notFoundSpacePosts) async {
    try {
      // Only attempt cleanup once per post-space combination
      final cacheKey = "${postId}_$spaceId";
      if (notFoundSpacePosts.contains(cacheKey)) {
        return;
      }
      notFoundSpacePosts.add(cacheKey);

      // Delete the post reference from spacePosts collection
      await firestore
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
      final userId = currentUser?.uid;
      if (userId == null || postId == null) {
        return false;
      }

      await firestore
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
