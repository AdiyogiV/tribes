import 'dart:typed_data';

/// Repository interface for post-related operations
abstract class PostRepository {
  /// Adds a new post to a space or user profile
  Future<String?> addSpacePost(
    String space,
    String videoPath,
    String thumbnailPath,
    String? title,
    String? replyTo,
    bool addToSpaceFeed,
    String? link, {
    bool isProfilePost = false,
  });

  /// Adds a new post from bytes (for web uploads)
  /// This bypasses compression and uploads directly
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
  });

  /// Adds a new audio post to a space or user profile
  Future<String?> addAudioPost(
    String space,
    String audioPath,
    Duration duration,
    String? title,
    String? replyTo,
    bool addToSpaceFeed, {
    bool isProfilePost = false,
  });

  /// Updates the upload status of a post
  Future<bool> updatePostStatus(String postId, bool uploading);

  /// Adds a post to a space feed
  Future<bool> addToSpaceFeed(String space, String postId, String? title,
      String thumbnail, String video, String? replyTo, String? link);

  /// Adds a reply to a post
  Future<bool> addPostReply(String space, String postId, String? title,
      String thumbnail, String video, String replyTo, String? link);

  /// Deletes a post and all its associated data
  Future<bool> deletePost(String postId);

  /// Reports a post for inappropriate content
  Future<bool> reportPost(String postId, String reason);

  /// Gets the number of queued posts for compression
  Future<int> getCompressionQueueSize();

  /// Clears the compression queue
  Future<void> clearCompressionQueue();

  /// Processes the compression queue
  void processCompressionQueue();
}
