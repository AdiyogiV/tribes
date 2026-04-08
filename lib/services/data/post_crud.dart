import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Mixin providing post CRUD operations (create, read, update, delete)
mixin PostCrudMixin {
  FirebaseFirestore get firestore;
  User? get currentUser;

  // These methods are provided by PostQueriesMixin when both mixins are applied
  // to the same class (PostDbService). Declared here so PostCrudMixin can call them.
  Future<bool> addTextToUserPosts(String postId, String? title, String content,
      String? replyTo, String? link);
  Future<bool> addTextToSpaceFeed(String space, String postId, String? title,
      String content, String? replyTo, String? link);
  Future<bool> addTextPostReply(String space, String replyPostId, String? title,
      String content, String originalPostId, String? link);
  Future<bool> addAudioToUserPosts(String postId, String? title,
      String audioUrl, int durationInSeconds, String? replyTo);
  Future<bool> addAudioToSpaceFeed(String space, String postId, String? title,
      String audioUrl, int durationInSeconds, String? replyTo);
  Future<bool> addAudioPostReply(String space, String replyPostId,
      String? title, String audioUrl, int durationInSeconds, String originalPostId);
  Future<bool> addImageToUserPosts(String postId, String? title,
      String imageUrl, String? replyTo, String? link);
  Future<bool> addImageToSpaceFeed(String space, String postId, String? title,
      String imageUrl, String? replyTo, String? link);
  Future<bool> addImagePostReply(String space, String replyPostId,
      String? title, String imageUrl, String originalPostId, String? link);

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
      if (currentUser == null) {
        AppLogger.e('User not authenticated for post creation',
            category: LogCategory.general);
        return null;
      }

      // For profile posts, space is the user's own ID
      final effectiveSpace = isProfilePost ? currentUser!.uid : space;
      final contextType = isProfilePost ? 'profile' : 'space';

      DocumentReference postDoc = await firestore.collection('posts').add({
        "space": effectiveSpace,
        "author": currentUser!.uid,
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
      if (currentUser == null) {
        AppLogger.e('User not authenticated for post creation',
            category: LogCategory.general);
        return null;
      }

      // For profile posts, space is the user's own ID
      final effectiveSpace = isProfilePost ? currentUser!.uid : space;
      final contextType = isProfilePost ? 'profile' : 'space';

      DocumentReference postDoc = await firestore.collection('posts').add({
        "space": effectiveSpace,
        "author": currentUser!.uid,
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
      if (currentUser == null) {
        AppLogger.e('User not authenticated for audio post creation',
            category: LogCategory.general);
        return null;
      }

      // For profile posts, space is the user's own ID
      final effectiveSpace = isProfilePost ? currentUser!.uid : space;
      final contextType = isProfilePost ? 'profile' : 'space';

      DocumentReference postDoc = await firestore.collection('posts').add({
        "space": effectiveSpace,
        "author": currentUser!.uid,
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
      if (currentUser == null) {
        AppLogger.e('User not authenticated for image post creation',
            category: LogCategory.general);
        return null;
      }

      // For profile posts, space is the user's own ID
      final effectiveSpace = isProfilePost ? currentUser!.uid : space;
      final contextType = isProfilePost ? 'profile' : 'space';

      DocumentReference postDoc = await firestore.collection('posts').add({
        "space": effectiveSpace,
        "author": currentUser!.uid,
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
      String postId, String videoUrl, String thumbnailUrl,
      {Future<void> Function(String, DocumentSnapshot)?
          onCacheUpdate}) async {
    try {
      await firestore.collection('posts').doc(postId).update({
        'video': videoUrl,
        'thumbnail': thumbnailUrl,
        'uploading': false,
      });

      // SMART CACHE UPDATE - Read back and update caches immediately
      try {
        final verification =
            await firestore.collection('posts').doc(postId).get();
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
          await onCacheUpdate?.call(postId, verification);
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
  Future<bool> updatePostThumbnail(String postId, String thumbnailUrl,
      {Future<void> Function(String, DocumentSnapshot)?
          onCacheUpdate}) async {
    try {
      await firestore.collection('posts').doc(postId).update({
        'thumbnail': thumbnailUrl,
      });

      // SMART CACHE UPDATE - Read back and update
      try {
        final verification =
            await firestore.collection('posts').doc(postId).get();
        if (verification.exists) {
          await onCacheUpdate?.call(postId, verification);
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
      String postId, String videoUrl, String thumbnailUrl,
      {Future<void> Function(String, DocumentSnapshot)?
          onCacheUpdate}) async {
    try {
      await firestore.collection('posts').doc(postId).update({
        'video': videoUrl,
        'thumbnail': thumbnailUrl,
      });

      // SMART CACHE UPDATE - Read back and update
      try {
        final verification =
            await firestore.collection('posts').doc(postId).get();
        if (verification.exists) {
          await onCacheUpdate?.call(postId, verification);
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
      await firestore
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
  Future<bool> updatePostStatus(String postId, bool uploading,
      {Future<void> Function(String, DocumentSnapshot)?
          onCacheUpdate}) async {
    try {
      await firestore.collection('posts').doc(postId).update({
        'uploading': uploading,
      });

      // SMART CACHE UPDATE - This is critical for upload status changes
      try {
        final verification =
            await firestore.collection('posts').doc(postId).get();
        if (verification.exists) {
          await onCacheUpdate?.call(postId, verification);
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

}
