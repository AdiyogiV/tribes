import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/services/media/media_compression_service.dart';
import 'package:aurogram/shared/services/media/media_storage_service.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/core/error/error_handler.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/services/analytics_service.dart';

import 'package:aurogram/platform/file_helper.dart' as file_helper;

/// Service for handling post-related operations
class PostService {
  final User? user;
  final MediaCompressionService _compressionService;
  final MediaStorageService _storageService;
  final PostDbService _postDbService;
  final FirebaseFirestore _firestore;

  /// Creates a new PostService instance with the given dependencies
  ///
  /// If not provided, dependencies will be automatically resolved
  PostService({
    this.user,
    MediaCompressionService? compressionService,
    MediaStorageService? storageService,
    PostDbService? postDbService,
    FirebaseFirestore? firestore,
  })  : _compressionService = compressionService ?? MediaCompressionService(),
        _storageService = storageService ?? MediaStorageService(),
        _postDbService = postDbService ?? PostDbService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  // SECTION: Post Creation and Management

  /// Adds a new post to a space
  ///
  /// Returns the post ID if successful, null otherwise
  ///
  /// Parameters:
  /// - [space]: The ID of the space
  /// - [videoPath]: Local path to the video file
  /// - [thumbnailPath]: Local path to the thumbnail image
  /// - [title]: Optional title for the post
  /// - [replyTo]: Optional post ID this post is replying to
  /// - [addToSpaceFeed]: Whether to add this post to the space feed
  /// - [link]: Optional external link to attach to the post
  /// - [isProfilePost]: If true, creates a profile post with contextType: 'profile'
  Future<String?> addSpacePost(
    String space,
    String videoPath,
    String thumbnailPath,
    String? title,
    String? replyTo,
    bool addToSpaceFeed,
    String? link, {
    bool isProfilePost = false,
  }) async {
    return await ErrorHandler.execute<String?>(() async {
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // For profile posts, use user ID as space
      String fetchedSpace =
          isProfilePost ? user!.uid : await _getFetchedSpace(space, replyTo);
      String? replyToUid = await _getReplyToUid(replyTo);

      String? post = await _postDbService.createPostDocument(
          space: fetchedSpace,
          title: title,
          replyTo: replyTo,
          link: link,
          isProfilePost: isProfilePost);

      if (post == null) {
        throw Exception('Failed to create post document');
      }

      String? permanentVideoPath = await _storageService
          .copyToPermanentLocation(videoPath, 'video_$post.mp4');

      // Ensure thumbnail exists; if not, generate from video
      String effectiveThumbPath = thumbnailPath;
      try {
        if (!kIsWeb && (effectiveThumbPath.isEmpty ||
            !file_helper.fileExistsSync(effectiveThumbPath))) {
          final generated =
              await _compressionService.generateVideoThumbnail(
                file_helper.createIOFile(videoPath));
          if (generated != null && await generated.exists()) {
            effectiveThumbPath = generated.path;
          }
        }
      } catch (_) {
        AppLogger.w('PostService: thumbnail generation failed', category: LogCategory.general);
      }

      String? permanentThumbnailPath = await _storageService
          .copyToPermanentLocation(effectiveThumbPath, 'thumbnail_$post.jpg');

      if (permanentVideoPath == null || permanentThumbnailPath == null) {
        await _firestore.collection('posts').doc(post).delete();
        throw Exception('Failed to copy files to permanent location');
      }

      // Update the post with a local thumbnail path immediately for UI feedback
      try {
        final localThumbPath = permanentThumbnailPath.startsWith('file://')
            ? permanentThumbnailPath
            : 'file://$permanentThumbnailPath';
        await _postDbService.updatePostThumbnail(post, localThumbPath);
      } catch (_) {
        AppLogger.w('PostService: failed to update local thumbnail path', category: LogCategory.general);
      }

      AppLogger.d('Adding post to compression queue',
          category: LogCategory.general,
          data: {
            'postId': post,
            'videoPath': permanentVideoPath,
            'thumbnailPath': permanentThumbnailPath,
            'space': fetchedSpace
          });

      await _compressionService.addToCompressionQueue(
          post,
          permanentVideoPath,
          permanentThumbnailPath,
          fetchedSpace,
          title,
          replyTo,
          replyToUid,
          addToSpaceFeed,
          link,
          user!.uid,
          isProfilePost: isProfilePost);

      AppLogger.d('Triggering compression queue processing',
          category: LogCategory.general, data: {'postId': post});

      _compressionService.processCompressionQueue();

      AppLogger.d('Post upload initiated successfully',
          category: LogCategory.general, data: {'postId': post});

      AnalyticsService().trackPostCreated(
        spaceId: fetchedSpace,
        mediaType: 'video',
      );

      return post;
    }, 'Error adding space post', defaultValue: null);
  }

  /// Adds a new video post from bytes (for web uploads)
  /// This method bypasses the compression queue and uploads directly
  /// 
  /// Parameters:
  /// - [space]: The ID of the space
  /// - [videoBytes]: Video file as bytes
  /// - [thumbnailBytes]: Thumbnail image as bytes (optional on web)
  /// - [title]: Optional title for the post
  /// - [replyTo]: Optional post ID this post is replying to
  /// - [addToSpaceFeed]: Whether to add this post to the space feed
  /// - [link]: Optional external link to attach to the post
  /// - [isProfilePost]: If true, creates a profile post with contextType: 'profile'
  Future<String?> addSpacePostFromBytes(
    String space,
    Uint8List videoBytes,
    Uint8List? thumbnailBytes,
    String? title,
    String? replyTo,
    bool addToSpaceFeed,
    String? link, {
    bool isProfilePost = false,
    String videoExtension = 'mp4',
  }) async {
    return await ErrorHandler.execute<String?>(() async {
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // For profile posts, use user ID as space
      String fetchedSpace =
          isProfilePost ? user!.uid : await _getFetchedSpace(space, replyTo);
      String? replyToUid = await _getReplyToUid(replyTo);

      // Create post document first
      String? post = await _postDbService.createPostDocument(
          space: fetchedSpace,
          title: title,
          replyTo: replyTo,
          link: link,
          isProfilePost: isProfilePost);

      if (post == null) {
        throw Exception('Failed to create post document');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Upload video directly (no compression on web)
      String videoStoragePath = isProfilePost
          ? 'users/$fetchedSpace/videos/video_${post}_$timestamp.$videoExtension'
          : 'spaces/$fetchedSpace/videos/video_${post}_$timestamp.$videoExtension';

      String? videoUrl = await _storageService.uploadFromBytes(
        videoBytes,
        videoStoragePath,
        contentType: 'video/$videoExtension',
      );

      if (videoUrl == null) {
        await _firestore.collection('posts').doc(post).delete();
        throw Exception('Failed to upload video');
      }

      // Upload thumbnail if provided
      String? thumbnailUrl;
      if (thumbnailBytes != null) {
        String thumbStoragePath = isProfilePost
            ? 'users/$fetchedSpace/thumbnails/thumb_${post}_$timestamp.jpg'
            : 'spaces/$fetchedSpace/thumbnails/thumb_${post}_$timestamp.jpg';

        thumbnailUrl = await _storageService.uploadFromBytes(
          thumbnailBytes,
          thumbStoragePath,
          contentType: 'image/jpeg',
        );
      }

      // Use video URL as thumbnail if no thumbnail provided (web fallback)
      thumbnailUrl ??= videoUrl;

      // Update post with media URLs
      await _postDbService.updatePostMedia(post, videoUrl, thumbnailUrl);
      await _postDbService.updatePostStatus(post, false); // Mark as uploaded

      // Add to space feed or as reply
      if (replyTo != null) {
        await _postDbService.addPostReply(
          fetchedSpace,
          post,
          title,
          thumbnailUrl,
          videoUrl,
          replyTo,
          link,
        );
        
        // Notify original post author
        if (replyToUid != null && replyToUid != user!.uid) {
          await _postDbService.createReplyNotification(
            replyToUid,
            post,
            replyTo,
            user!.uid,
          );
        }
      } else if (addToSpaceFeed) {
        await _postDbService.addToSpaceFeed(
          fetchedSpace,
          post,
          title,
          thumbnailUrl,
          videoUrl,
          replyTo,
          link,
        );
      }

      AppLogger.i('Web post upload complete',
          category: LogCategory.media,
          data: {'postId': post, 'videoUrl': videoUrl});

      AnalyticsService().trackPostCreated(
        spaceId: fetchedSpace,
        mediaType: 'video',
      );

      return post;
    }, 'Error adding space post from bytes', defaultValue: null);
  }

  /// Adds a new audio post to a space
  ///
  /// Returns the post ID if successful, null otherwise
  ///
  /// Parameters:
  /// - [space]: The ID of the space
  /// - [audioPath]: Local path to the audio file
  /// - [duration]: Duration of the audio recording
  /// - [title]: Optional title for the post
  /// - [replyTo]: Optional post ID this post is replying to
  /// - [addToSpaceFeed]: Whether to add this post to the space feed
  /// - [isProfilePost]: If true, creates a profile post with contextType: 'profile'
  Future<String?> addAudioPost(
    String space,
    String audioPath,
    Duration duration,
    String? title,
    String? replyTo,
    bool addToSpaceFeed, {
    bool isProfilePost = false,
  }) async {
    return await ErrorHandler.execute<String?>(() async {
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // For profile posts, use user ID as space
      String fetchedSpace =
          isProfilePost ? user!.uid : await _getFetchedSpace(space, replyTo);

      // Upload audio file first - for profile posts, store in user's folder
      String audioFileName =
          'audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      String storageAudioPath = isProfilePost
          ? 'users/$fetchedSpace/audio/$audioFileName'
          : 'spaces/$fetchedSpace/audio/$audioFileName';

      String? audioUrl = await _storageService.uploadToStorage(
        audioPath,
        storageAudioPath,
      );

      if (audioUrl == null) {
        throw Exception('Failed to upload audio file');
      }

      // Create the audio post document
      String? post = await _postDbService.createAudioPostDocument(
        space: fetchedSpace,
        audioUrl: audioUrl,
        durationInSeconds: duration.inSeconds,
        title: title,
        replyTo: replyTo,
        addToSpaceFeed: addToSpaceFeed,
        isProfilePost: isProfilePost,
      );

      if (post == null) {
        throw Exception('Failed to create audio post document');
      }

      AnalyticsService().trackPostCreated(
        spaceId: fetchedSpace,
        mediaType: 'audio',
      );

      AppLogger.d('Audio post created successfully',
          category: LogCategory.general,
          data: {
            'postId': post,
            'duration': duration.inSeconds,
            'audioUrl': audioUrl
          });

      return post;
    }, 'Error adding audio post', defaultValue: null);
  }

  /// Updates the upload status of a post
  Future<bool> updatePostStatus(String postId, bool uploading) async {
    return await ErrorHandler.execute<bool>(
        () => _postDbService.updatePostStatus(postId, uploading),
        'Error updating post status',
        defaultValue: false);
  }

  /// Starts the compression queue processing
  Future<void> processCompressionQueue() async {
    await ErrorHandler.execute(
        () async => _compressionService.processCompressionQueue(),
        'Error processing compression queue');
  }

  /// Adds a post to a space feed
  Future<bool> addToSpaceFeed(String fetchedSpace, String post, String? title,
      String thumbnail, String video, String? replyTo, String? link) async {
    return await ErrorHandler.execute<bool>(
        () => _postDbService.addToSpaceFeed(
            fetchedSpace, post, title, thumbnail, video, replyTo, link),
        'Error adding to space feed',
        defaultValue: false);
  }

  /// Adds a reply to a post
  Future<bool> addPostReply(String fetchedSpace, String post, String? title,
      String thumbnail, String video, String replyTo, String? link) async {
    return await ErrorHandler.execute<bool>(
        () => _postDbService.addPostReply(
            fetchedSpace, post, title, thumbnail, video, replyTo, link),
        'Error adding post reply',
        defaultValue: false);
  }

  // SECTION: Post Deletion

  /// Deletes a post and all its associated data
  Future<bool> deleteSpacePost(String postId) async {
    return await ErrorHandler.execute<bool>(() async {
      DocumentSnapshot postDoc = await _postDbService.getPost(postId);

      if (!postDoc.exists) {
        ErrorHandler.logInfo('Post does not exist');
        return false;
      }

      final Map<String, dynamic>? postData =
          postDoc.data() as Map<String, dynamic>?;
      final String? replyTo = postData?['replyTo'] as String?;
      final String space = postData?['space'] as String? ?? '';
      String? replyToUid;

      WriteBatch batch = _firestore.batch();

      if (replyTo != null) {
        DocumentSnapshot replyToDoc = await _postDbService.getPost(replyTo);
        if (replyToDoc.exists) {
          final Map<String, dynamic>? replyToData =
              replyToDoc.data() as Map<String, dynamic>?;
          replyToUid = replyToData?['author'] as String?;

          // Delete from postReplies collection
          // Backend Cloud Function (onReplyDeleted) will decrement replyCount
          DocumentReference replyRef = _firestore
              .collection('postReplies')
              .doc(replyTo)
              .collection("replies")
              .doc(postId);
          batch.delete(replyRef);

          if (replyToUid != null) {
            // Delete from userReplies collection
            DocumentReference userReplyRef = _firestore
                .collection('userReplies')
                .doc(replyToUid)
                .collection("replies")
                .doc(postId);
            batch.delete(userReplyRef);
          }
        }
      }

      // Delete from spacePosts collection
      DocumentReference spacePostRef = _firestore
          .collection('spacePosts')
          .doc(space)
          .collection("posts")
          .doc(postId);
      batch.delete(spacePostRef);

      // Delete the post document
      DocumentReference postRef = _firestore.collection('posts').doc(postId);
      batch.delete(postRef);

      await batch.commit();

      // CRITICAL FIX: Invalidate cache after successful deletion
      // This ensures notification validation will detect the post as missing
      _postDbService.invalidatePostCache(postId);

      await _storageService.deleteStorageFile('posts/$postId/thumbnail.jpg');
      await _storageService.deleteStorageFile('posts/$postId/video.mp4');

      ErrorHandler.logInfo('Post deleted successfully');
      return true;
    }, 'Error deleting post', defaultValue: false);
  }

  // SECTION: Post Moderation

  /// Reports a post for inappropriate content
  Future<bool> reportPost(String postId, String reason) async {
    return await ErrorHandler.execute<bool>(() async {
      if (user == null) return false;
      await _firestore.collection('reports').add({
        'postId': postId,
        'reportedBy': user!.uid,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    }, 'Error reporting post', defaultValue: false);
  }

  // SECTION: Queue Management

  /// Clears the compression queue
  Future<void> clearCompressionQueue() async {
    await ErrorHandler.execute(
        () async => _compressionService.clearCompressionQueue(),
        'Error clearing compression queue');
  }

  /// Gets the size of the compression queue
  Future<int> getCompressionQueueSize() async {
    return await ErrorHandler.execute<int>(
        () => _compressionService.getCompressionQueueSize(),
        'Error getting compression queue size',
        defaultValue: 0);
  }

  // SECTION: Helper Methods

  /// Gets the space associated with a reply
  Future<String> _getFetchedSpace(String space, String? replyTo) async {
    if (replyTo != null) {
      DocumentSnapshot replyDoc = await _postDbService.getPost(replyTo);
      return replyDoc.get('space') as String? ?? space;
    }
    return space;
  }

  /// Gets the user ID of the author of a post
  Future<String?> _getReplyToUid(String? replyTo) async {
    if (replyTo == null) return null;
    DocumentSnapshot replyDoc = await _postDbService.getPost(replyTo);
    return replyDoc.get('author') as String?;
  }
}
