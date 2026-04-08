import 'package:cloud_firestore/cloud_firestore.dart';

typedef ReplyCallback = void Function(String post);

class PostData {
  final String? author;
  final String? space;
  final String? contextType;
  final bool? uploading;
  final String? video;
  final String? title;
  final String? thumbnail;
  final String? link;
  final String? content;
  final String? postType;
  final String? audioUrl;
  final int? durationInSeconds;
  final Timestamp? timestamp;
  final String? replyTo;
  final bool isRepost;
  final String? originalPostId;
  final String? originalAuthorId;
  final String? originalAuthorName;
  final String? quotedPostId;
  final Map<String, dynamic>? quotedPostData;

  const PostData({
    required this.author,
    required this.space,
    required this.contextType,
    required this.uploading,
    required this.video,
    required this.title,
    required this.thumbnail,
    required this.link,
    required this.content,
    required this.postType,
    required this.audioUrl,
    required this.durationInSeconds,
    required this.timestamp,
    required this.replyTo,
    this.isRepost = false,
    this.originalPostId,
    this.originalAuthorId,
    this.originalAuthorName,
    this.quotedPostId,
    this.quotedPostData,
  });

  factory PostData.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return PostData(
      author: data['author'] as String?,
      uploading: data['uploading'] as bool? ?? false,
      title: data['title'] as String?,
      space: data['space'] as String?,
      contextType: data['contextType'] as String?,
      timestamp: data['timestamp'] as Timestamp?,
      video: data['video'] as String?,
      thumbnail: data['thumbnail'] as String?,
      link: data['link'] as String?,
      content: data['content'] as String?,
      audioUrl: data['audioUrl'] as String?,
      durationInSeconds: data['duration'] as int?,
      postType: data['postType'] as String? ?? 'video',
      replyTo: data['replyTo'] as String?,
      isRepost: data['isRepost'] as bool? ?? false,
      originalPostId: data['originalPostId'] as String?,
      originalAuthorId: data['originalAuthorId'] as String?,
      originalAuthorName: data['originalAuthorName'] as String?,
      quotedPostId: data['quotedPostId'] as String?,
      quotedPostData: data['quotedPostData'] as Map<String, dynamic>?,
    );
  }

  PostData copyWith({
    String? author,
    String? space,
    String? contextType,
    bool? uploading,
    String? video,
    String? title,
    String? thumbnail,
    String? link,
    String? content,
    String? postType,
    String? audioUrl,
    int? durationInSeconds,
    Timestamp? timestamp,
    String? replyTo,
    bool? isRepost,
    String? originalPostId,
    String? originalAuthorId,
    String? originalAuthorName,
    String? quotedPostId,
    Map<String, dynamic>? quotedPostData,
  }) {
    return PostData(
      author: author ?? this.author,
      space: space ?? this.space,
      contextType: contextType ?? this.contextType,
      uploading: uploading ?? this.uploading,
      video: video ?? this.video,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      link: link ?? this.link,
      content: content ?? this.content,
      postType: postType ?? this.postType,
      audioUrl: audioUrl ?? this.audioUrl,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      timestamp: timestamp ?? this.timestamp,
      replyTo: replyTo ?? this.replyTo,
      isRepost: isRepost ?? this.isRepost,
      originalPostId: originalPostId ?? this.originalPostId,
      originalAuthorId: originalAuthorId ?? this.originalAuthorId,
      originalAuthorName: originalAuthorName ?? this.originalAuthorName,
      quotedPostId: quotedPostId ?? this.quotedPostId,
      quotedPostData: quotedPostData ?? this.quotedPostData,
    );
  }
}

class ParentPostData {
  final String? parentAuthorName;
  final int parentChainCount;
  final List<DocumentSnapshot>? parentPostSnapshots;

  const ParentPostData({
    required this.parentAuthorName,
    required this.parentChainCount,
    required this.parentPostSnapshots,
  });

  static const empty = ParentPostData(
      parentAuthorName: null, parentChainCount: 0, parentPostSnapshots: null);
}
