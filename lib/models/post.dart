import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for post context type - where the post lives
enum PostContextType {
  /// Post on user's profile (their personal content)
  profile,

  /// Post in a space/group
  space,
}

/// Enum for post media type
enum PostType {
  video,
  audio,
  text,
  image,
}

/// Post model for the app.
///
/// Posts can exist in two contexts:
/// - Profile posts: User's personal content (contextType: profile)
/// - Space posts: Content in a group/community (contextType: space)
class Post {
  final String id;
  final String authorId;
  final String? authorName;
  final String? authorAvatar;

  /// The type of context this post belongs to
  final PostContextType contextType;

  /// For space posts, this is the spaceId. For profile posts, this is null.
  final String? contextId;

  final PostType postType;
  final String? title;
  final String? content;
  final String? mediaUrl;
  final String? thumbnail;
  final String? audioUrl;
  final int? duration;
  final String? link;

  /// Post this is replying to (for threads)
  final String? replyTo;

  /// Repost count (denormalized, backend-controlled)
  final int repostCount;

  /// Quote post fields
  final String? quotedPostId;
  final Map<String, dynamic>? quotedPostData;

  final int likeCount;
  final int replyCount;
  final bool uploading;
  final DateTime? timestamp;

  Post({
    required this.id,
    required this.authorId,
    this.authorName,
    this.authorAvatar,
    required this.contextType,
    this.contextId,
    required this.postType,
    this.title,
    this.content,
    this.mediaUrl,
    this.thumbnail,
    this.audioUrl,
    this.duration,
    this.link,
    this.replyTo,
    this.repostCount = 0,
    this.quotedPostId,
    this.quotedPostData,
    this.likeCount = 0,
    this.replyCount = 0,
    this.uploading = false,
    this.timestamp,
  });

  /// Create a Post from Firestore document
  factory Post.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Post.fromJson(data, doc.id);
  }

  /// Create a Post from JSON map
  factory Post.fromJson(Map<String, dynamic> json, String id) {
    // Determine context type - default to space for backward compatibility
    PostContextType contextType;
    final contextTypeStr = json['contextType'] as String?;
    if (contextTypeStr == 'profile') {
      contextType = PostContextType.profile;
    } else {
      contextType = PostContextType.space;
    }

    // Determine post type
    PostType postType;
    final postTypeStr = json['postType'] as String?;
    switch (postTypeStr) {
      case 'audio':
        postType = PostType.audio;
        break;
      case 'text':
        postType = PostType.text;
        break;
      case 'image':
        postType = PostType.image;
        break;
      case 'video':
      default:
        postType = PostType.video;
    }

    // Parse timestamp
    DateTime? timestamp;
    if (json['timestamp'] is Timestamp) {
      timestamp = (json['timestamp'] as Timestamp).toDate();
    }

    return Post(
      id: id,
      authorId: json['author'] as String? ?? '',
      authorName: json['authorName'] as String?,
      authorAvatar: json['authorAvatar'] as String?,
      contextType: contextType,
      contextId: json['contextId'] as String? ?? json['space'] as String?,
      postType: postType,
      title: json['title'] as String?,
      content: json['content'] as String?,
      mediaUrl: json['video'] as String?,
      thumbnail: json['thumbnail'] as String?,
      audioUrl: json['audioUrl'] as String?,
      duration: json['duration'] as int?,
      link: json['link'] as String?,
      replyTo: json['replyTo'] as String?,
      repostCount: json['repostCount'] as int? ?? 0,
      quotedPostId: json['quotedPostId'] as String?,
      quotedPostData: json['quotedPostData'] as Map<String, dynamic>?,
      likeCount: json['likeCount'] as int? ?? 0,
      replyCount: json['replyCount'] as int? ?? 0,
      uploading: json['uploading'] as bool? ?? false,
      timestamp: timestamp,
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'author': authorId,
      if (authorName != null) 'authorName': authorName,
      if (authorAvatar != null) 'authorAvatar': authorAvatar,
      'contextType':
          contextType == PostContextType.profile ? 'profile' : 'space',
      if (contextId != null) 'contextId': contextId,
      'postType': postType.name,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (mediaUrl != null) 'video': mediaUrl,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (duration != null) 'duration': duration,
      if (link != null) 'link': link,
      if (replyTo != null) 'replyTo': replyTo,
      'repostCount': repostCount,
      if (quotedPostId != null) 'quotedPostId': quotedPostId,
      if (quotedPostData != null) 'quotedPostData': quotedPostData,
      'likeCount': likeCount,
      'replyCount': replyCount,
      'uploading': uploading,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  /// Check if this is a profile post
  bool get isProfilePost => contextType == PostContextType.profile;

  /// Check if this is a space post
  bool get isSpacePost => contextType == PostContextType.space;

  /// Check if this is a reply to another post
  bool get isReply => replyTo != null && replyTo!.isNotEmpty;

  /// Check if this is a quote post
  bool get isQuotePost => quotedPostId != null && quotedPostId!.isNotEmpty;

  /// Check if this is a video post
  bool get isVideo => postType == PostType.video;

  /// Check if this is an audio post
  bool get isAudio => postType == PostType.audio;

  /// Check if this is a text post
  bool get isText => postType == PostType.text;

  /// Check if this is an image post
  bool get isImage => postType == PostType.image;

  /// Create a copy with updated values
  Post copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    PostContextType? contextType,
    String? contextId,
    PostType? postType,
    String? title,
    String? content,
    String? mediaUrl,
    String? thumbnail,
    String? audioUrl,
    int? duration,
    String? link,
    String? replyTo,
    int? repostCount,
    String? quotedPostId,
    Map<String, dynamic>? quotedPostData,
    int? likeCount,
    int? replyCount,
    bool? uploading,
    DateTime? timestamp,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      contextType: contextType ?? this.contextType,
      contextId: contextId ?? this.contextId,
      postType: postType ?? this.postType,
      title: title ?? this.title,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnail: thumbnail ?? this.thumbnail,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      link: link ?? this.link,
      replyTo: replyTo ?? this.replyTo,
      repostCount: repostCount ?? this.repostCount,
      quotedPostId: quotedPostId ?? this.quotedPostId,
      quotedPostData: quotedPostData ?? this.quotedPostData,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      uploading: uploading ?? this.uploading,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
