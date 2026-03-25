import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// All notification types supported by the app
enum NotificationType {
  reply,
  namaste,
  invite,
  request,
  like,
  newSpacePost,
  addedToGroup,
  chat,
  message,
  dailyAstroInsight,
  follow,
  followRequest,
  followAccepted,
  mutualFollow, // Both users now follow each other - friends!
  incomingCall, // Incoming voice or video call
  missedCall, // Missed call notification
  groupCall, // Group call notification in a gram
  anonymousMessage, // Secret message received
  unknown,
}

/// Extension to convert string to NotificationType
extension NotificationTypeExtension on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.reply:
        return 'reply';
      case NotificationType.namaste:
        return 'namaste';
      case NotificationType.invite:
        return 'invite';
      case NotificationType.request:
        return 'request';
      case NotificationType.like:
        return 'like';
      case NotificationType.newSpacePost:
        return 'newSpacePost';
      case NotificationType.addedToGroup:
        return 'addedtogroup';
      case NotificationType.chat:
        return 'chat';
      case NotificationType.message:
        return 'message';
      case NotificationType.dailyAstroInsight:
        return 'dailyAstroInsight';
      case NotificationType.follow:
        return 'follow';
      case NotificationType.followRequest:
        return 'followRequest';
      case NotificationType.followAccepted:
        return 'followAccepted';
      case NotificationType.mutualFollow:
        return 'mutualFollow';
      case NotificationType.incomingCall:
        return 'incoming_call';
      case NotificationType.missedCall:
        return 'missed_call';
      case NotificationType.groupCall:
        return 'group_call';
      case NotificationType.anonymousMessage:
        return 'anonymousMessage';
      case NotificationType.unknown:
        return 'unknown';
    }
  }

  static NotificationType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'reply':
        return NotificationType.reply;
      case 'namaste':
        return NotificationType.namaste;
      case 'invite':
        return NotificationType.invite;
      case 'request':
        return NotificationType.request;
      case 'like':
        return NotificationType.like;
      case 'newspacepost':
        return NotificationType.newSpacePost;
      case 'addedtogroup':
        return NotificationType.addedToGroup;
      case 'chat':
        return NotificationType.chat;
      case 'message':
        return NotificationType.message;
      case 'dailyastroinsight':
        return NotificationType.dailyAstroInsight;
      case 'follow':
        return NotificationType.follow;
      case 'followrequest':
        return NotificationType.followRequest;
      case 'followaccepted':
        return NotificationType.followAccepted;
      case 'mutualfollow':
        return NotificationType.mutualFollow;
      case 'incoming_call':
      case 'incomingcall':
        return NotificationType.incomingCall;
      case 'missed_call':
      case 'missedcall':
        return NotificationType.missedCall;
      case 'group_call':
      case 'groupcall':
        return NotificationType.groupCall;
      case 'anonymousmessage':
        return NotificationType.anonymousMessage;
      default:
        return NotificationType.unknown;
    }
  }
}

/// Unified notification model that handles all notification types
@immutable
class AppNotification {
  final String id;
  final NotificationType type;
  final DateTime timestamp;
  final bool read;
  final Map<String, dynamic> data;

  // Common fields
  final String? authorId;
  final String? authorName;
  final String? authorPicture;
  final String? spaceId;
  final String? spaceName;
  final String? postId;

  // Chat-specific fields
  final String? messageContent;
  final String? messageType;
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;

  // Daily insight specific fields
  final String? cardType;
  final int? cardIndex;
  final int? totalCards;
  final String? title;
  final String? preview;
  final String? insightId;
  final String? date;

  // Invite/Request specific
  final String? inviterId;
  final String? requestorId;

  // Like specific
  final String? likerId;
  final String? likerName;

  const AppNotification({
    required this.id,
    required this.type,
    required this.timestamp,
    this.read = false,
    this.data = const {},
    this.authorId,
    this.authorName,
    this.authorPicture,
    this.spaceId,
    this.spaceName,
    this.postId,
    this.messageContent,
    this.messageType,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.cardType,
    this.cardIndex,
    this.totalCards,
    this.title,
    this.preview,
    this.insightId,
    this.date,
    this.inviterId,
    this.requestorId,
    this.likerId,
    this.likerName,
  });

  /// Create from Firestore document
  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    data['id'] = doc.id;
    return AppNotification.fromMap(data);
  }

  /// Create from map data
  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final typeString = map['type'] as String?;
    final type = NotificationTypeExtension.fromString(typeString);

    DateTime timestamp;
    if (map['timestamp'] is Timestamp) {
      timestamp = (map['timestamp'] as Timestamp).toDate();
    } else if (map['createdAt'] is Timestamp) {
      timestamp = (map['createdAt'] as Timestamp).toDate();
    } else {
      timestamp = DateTime.now();
    }

    // Helper to safely parse int from either int or String (FCM sends all values as strings)
    int? parseIntSafe(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    return AppNotification(
      id: map['id'] as String? ?? '',
      type: type,
      timestamp: timestamp,
      read: map['read'] as bool? ?? false,
      data: map,
      authorId: map['author'] as String? ?? map['authorId'] as String? ?? map['fromUserId'] as String?,
      authorName: map['authorName'] as String?,
      authorPicture: map['authorPic'] as String? ?? map['authorPicture'] as String?,
      spaceId: map['space'] as String? ?? map['spaceId'] as String?,
      spaceName: map['spaceName'] as String?,
      postId: map['postId'] as String?,
      messageContent: map['messageContent'] as String? ?? map['content'] as String?,
      messageType: map['messageType'] as String?,
      senderId: map['senderId'] as String?,
      senderName: map['senderName'] as String?,
      senderAvatar: map['senderAvatar'] as String?,
      cardType: map['cardType'] as String?,
      cardIndex: parseIntSafe(map['cardIndex']),
      totalCards: parseIntSafe(map['totalCards']),
      title: map['title'] as String?,
      preview: map['preview'] as String?,
      insightId: map['insightId'] as String?,
      date: map['date'] as String?,
      inviterId: map['inviter'] as String?,
      requestorId: map['requestor'] as String?,
      likerId: map['liker'] as String?,
      likerName: map['likerName'] as String?,
    );
  }

  /// Create a copy with updated fields
  AppNotification copyWith({
    String? id,
    NotificationType? type,
    DateTime? timestamp,
    bool? read,
    Map<String, dynamic>? data,
    String? authorId,
    String? authorName,
    String? authorPicture,
    String? spaceId,
    String? spaceName,
    String? postId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
      data: data ?? this.data,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorPicture: authorPicture ?? this.authorPicture,
      spaceId: spaceId ?? this.spaceId,
      spaceName: spaceName ?? this.spaceName,
      postId: postId ?? this.postId,
      messageContent: messageContent,
      messageType: messageType,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      cardType: cardType,
      cardIndex: cardIndex,
      totalCards: totalCards,
      title: title,
      preview: preview,
      insightId: insightId,
      date: date,
      inviterId: inviterId,
      requestorId: requestorId,
      likerId: likerId,
      likerName: likerName,
    );
  }

  /// Check if this is a social notification
  bool get isSocialNotification =>
      type == NotificationType.reply ||
      type == NotificationType.like ||
      type == NotificationType.namaste ||
      type == NotificationType.newSpacePost;

  /// Check if this is a group-related notification
  bool get isGroupNotification =>
      type == NotificationType.invite ||
      type == NotificationType.request ||
      type == NotificationType.addedToGroup;

  /// Check if this is a chat notification
  bool get isChatNotification =>
      type == NotificationType.chat || type == NotificationType.message;

  /// Check if this is an astrology notification
  bool get isAstroNotification => type == NotificationType.dailyAstroInsight;

  /// Check if this is a 1:1 call notification
  bool get isCallNotification =>
      type == NotificationType.incomingCall || type == NotificationType.missedCall;

  /// Check if this is a group call notification
  bool get isGroupCallNotification => type == NotificationType.groupCall;

  /// Get display title
  String get displayTitle {
    switch (type) {
      case NotificationType.reply:
        return '${authorName ?? 'Someone'} replied to your post';
      case NotificationType.namaste:
        return '${authorName ?? 'Someone'} greets you with namaste!';
      case NotificationType.invite:
        return 'You\'ve been invited to ${spaceName ?? 'a gram'}';
      case NotificationType.request:
        return '${authorName ?? 'Someone'} wants to join ${spaceName ?? 'your gram'}';
      case NotificationType.like:
        return '${likerName ?? 'Someone'} liked your post';
      case NotificationType.newSpacePost:
        return '${authorName ?? 'Someone'} added a new post';
      case NotificationType.addedToGroup:
        return 'You were added to ${spaceName ?? 'a gram'}';
      case NotificationType.chat:
      case NotificationType.message:
        return senderName ?? spaceName ?? 'New message';
      case NotificationType.dailyAstroInsight:
        return title ?? 'Your Daily Insight 🌟';
      case NotificationType.follow:
        return '${data['fromUserName'] ?? 'Someone'} started following you';
      case NotificationType.followRequest:
        return '${data['fromUserName'] ?? 'Someone'} wants to follow you';
      case NotificationType.followAccepted:
        return '${data['fromUserName'] ?? 'Someone'} accepted your follow request';
      case NotificationType.mutualFollow:
        return '🎉 You and ${data['fromUserName'] ?? 'Someone'} are now friends!';
      case NotificationType.incomingCall:
        final callerName = data['callerName'] ?? title ?? 'Someone';
        return callerName;
      case NotificationType.missedCall:
        final callerName = data['callerName'] ?? title ?? 'Someone';
        return 'Missed call from $callerName';
      case NotificationType.groupCall:
        return spaceName ?? 'Group Call';
      case NotificationType.anonymousMessage:
        return 'New anonymous message';
      case NotificationType.unknown:
        return 'New notification';
    }
  }

  /// Get display body text
  String get displayBody {
    switch (type) {
      case NotificationType.reply:
        return 'in ${spaceName ?? 'a gram'}';
      case NotificationType.namaste:
        return 'Tap to greet them back';
      case NotificationType.invite:
        return 'Tap to view the invite';
      case NotificationType.request:
        return 'Tap to review the request';
      case NotificationType.like:
        return 'in ${spaceName ?? 'a gram'}';
      case NotificationType.newSpacePost:
        return 'in ${spaceName ?? 'a gram'}';
      case NotificationType.addedToGroup:
        return 'Tap to view the gram';
      case NotificationType.chat:
      case NotificationType.message:
        return _formatChatBody();
      case NotificationType.dailyAstroInsight:
        return preview ?? 'Tap to read your personalized insight';
      case NotificationType.follow:
        return 'Tap to view their profile';
      case NotificationType.followRequest:
        return 'Tap to accept or decline';
      case NotificationType.followAccepted:
        return 'Tap to view their profile';
      case NotificationType.mutualFollow:
        return 'Tap to see your compatibility';
      case NotificationType.incomingCall:
        final callType = data['callType'] ?? 'voice';
        return callType == 'video' 
            ? '📹 Incoming video call...' 
            : '📞 Incoming voice call...';
      case NotificationType.missedCall:
        final callType = data['callType'] ?? 'voice';
        return callType == 'video' 
            ? '📹 Missed video call' 
            : '📞 Missed voice call';
      case NotificationType.groupCall:
        final callerName = data['callerName'] ?? 'Someone';
        return '📞 $callerName started a call';
      case NotificationType.anonymousMessage:
        return preview ?? 'Tap to see what they said';
      case NotificationType.unknown:
        return '';
    }
  }

  String _formatChatBody() {
    final sender = senderName ?? 'Someone';
    switch (messageType) {
      case 'image':
        return '$sender sent a photo';
      case 'video':
        return '$sender sent a video';
      case 'audio':
        return '$sender sent an audio message';
      case 'file':
        return '$sender sent a file';
      default:
        final content = messageContent ?? '';
        final truncated = content.length > 50 ? '${content.substring(0, 50)}...' : content;
        return '$sender: $truncated';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Legacy classes for backward compatibility
@immutable
class ReplyNotification {
  final String ogid;
  final String reid;

  const ReplyNotification({required this.ogid, required this.reid});
}

class FollowNotification {
  final String ogid;
  final String reid;

  const FollowNotification({required this.ogid, required this.reid});
}
