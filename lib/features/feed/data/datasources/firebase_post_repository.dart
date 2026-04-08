import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/services/post_service.dart';
import 'package:aurogram/features/feed/data/datasources/post_repository.dart';

/// Firebase implementation of the post repository interface
class FirebasePostRepository implements PostRepository {
  final PostService _postService;
  final FirebaseAuth _auth;

  /// Creates a new Firebase post repository
  ///
  /// Uses the provided PostService or creates a default one if not provided
  FirebasePostRepository({PostService? postService, FirebaseAuth? auth})
      : _postService =
            postService ?? PostService(user: FirebaseAuth.instance.currentUser),
        _auth = auth ?? FirebaseAuth.instance;

  @override
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
    // Ensure we have the most up-to-date user before proceeding
    final currentUser = _auth.currentUser;

    // If user is not authenticated, try to refresh authentication
    if (currentUser == null) {
      // Wait for auth state to possibly change (in case of auto sign-in)
      await Future.delayed(Duration(milliseconds: 500));

      // Check again after delay
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        throw Exception('User not authenticated');
      }

      // Create a new PostService with the refreshed user
      return PostService(user: refreshedUser).addSpacePost(
          space, videoPath, thumbnailPath, title, replyTo, addToSpaceFeed, link,
          isProfilePost: isProfilePost);
    }

    // Use existing PostService if user is authenticated
    return _postService.addSpacePost(
        space, videoPath, thumbnailPath, title, replyTo, addToSpaceFeed, link,
        isProfilePost: isProfilePost);
  }

  @override
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
    // Ensure we have the most up-to-date user before proceeding
    final currentUser = _auth.currentUser;

    // If user is not authenticated, try to refresh authentication
    if (currentUser == null) {
      await Future.delayed(Duration(milliseconds: 500));

      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        throw Exception('User not authenticated');
      }

      return PostService(user: refreshedUser).addSpacePostFromBytes(
        space,
        videoBytes,
        thumbnailBytes,
        title,
        replyTo,
        addToSpaceFeed,
        link,
        isProfilePost: isProfilePost,
        videoExtension: videoExtension,
      );
    }

    return _postService.addSpacePostFromBytes(
      space,
      videoBytes,
      thumbnailBytes,
      title,
      replyTo,
      addToSpaceFeed,
      link,
      isProfilePost: isProfilePost,
      videoExtension: videoExtension,
    );
  }

  @override
  Future<String?> addAudioPost(
    String space,
    String audioPath,
    Duration duration,
    String? title,
    String? replyTo,
    bool addToSpaceFeed, {
    bool isProfilePost = false,
  }) async {
    // Ensure we have the most up-to-date user before proceeding
    final currentUser = _auth.currentUser;

    // If user is not authenticated, try to refresh authentication
    if (currentUser == null) {
      // Wait for auth state to possibly change
      await Future.delayed(Duration(milliseconds: 500));

      // Check again after delay
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        throw Exception('User not authenticated');
      }

      // Create a new PostService with the refreshed user
      return PostService(user: refreshedUser).addAudioPost(
          space, audioPath, duration, title, replyTo, addToSpaceFeed,
          isProfilePost: isProfilePost);
    }

    // Use existing PostService if user is authenticated
    return _postService.addAudioPost(
        space, audioPath, duration, title, replyTo, addToSpaceFeed,
        isProfilePost: isProfilePost);
  }

  @override
  Future<bool> updatePostStatus(String postId, bool uploading) {
    return _postService.updatePostStatus(postId, uploading);
  }

  @override
  Future<bool> addToSpaceFeed(String space, String postId, String? title,
      String thumbnail, String video, String? replyTo, String? link) {
    return _postService.addToSpaceFeed(
        space, postId, title, thumbnail, video, replyTo, link);
  }

  @override
  Future<bool> addPostReply(String space, String postId, String? title,
      String thumbnail, String video, String replyTo, String? link) {
    return _postService.addPostReply(
        space, postId, title, thumbnail, video, replyTo, link);
  }

  @override
  Future<bool> deletePost(String postId) {
    return _postService.deleteSpacePost(postId);
  }

  @override
  Future<bool> reportPost(String postId, String reason) {
    return _postService.reportPost(postId, reason);
  }

  @override
  Future<int> getCompressionQueueSize() {
    return _postService.getCompressionQueueSize();
  }

  @override
  Future<void> clearCompressionQueue() {
    return _postService.clearCompressionQueue();
  }

  @override
  Future<void> processCompressionQueue() {
    return _postService.processCompressionQueue();
  }
}
