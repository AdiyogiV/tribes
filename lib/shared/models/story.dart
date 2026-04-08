import 'package:cloud_firestore/cloud_firestore.dart';

/// Media type for a story slide
enum StoryMediaType {
  image,
  video,
}

/// A single story slide (24h ephemeral)
class Story {
  final String id;
  final String authorId;
  final String mediaUrl;
  final StoryMediaType mediaType;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// For reshared content: e.g. 'post', 'space', 'insight', 'cosmic'
  final String? sourceType;
  /// Id of the original content (postId, spaceId, etc.)
  final String? sourceId;

  Story({
    required this.id,
    required this.authorId,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.expiresAt,
    this.sourceType,
    this.sourceId,
  });

  factory Story.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Story.fromMap(data, doc.id);
  }

  factory Story.fromMap(Map<String, dynamic> map, String id) {
    final authorId = map['authorId'] as String? ?? '';
    final mediaUrl = map['mediaUrl'] as String? ?? '';
    final mediaTypeStr = map['mediaType'] as String? ?? 'image';
    final mediaType = mediaTypeStr == 'video'
        ? StoryMediaType.video
        : StoryMediaType.image;

    DateTime createdAt = DateTime.now();
    if (map['createdAt'] is Timestamp) {
      createdAt = (map['createdAt'] as Timestamp).toDate();
    }
    DateTime expiresAt = createdAt.add(const Duration(hours: 24));
    if (map['expiresAt'] is Timestamp) {
      expiresAt = (map['expiresAt'] as Timestamp).toDate();
    }

    return Story(
      id: id,
      authorId: authorId,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      createdAt: createdAt,
      expiresAt: expiresAt,
      sourceType: map['sourceType'] as String?,
      sourceId: map['sourceId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType == StoryMediaType.video ? 'video' : 'image',
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      if (sourceType != null) 'sourceType': sourceType,
      if (sourceId != null) 'sourceId': sourceId,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
