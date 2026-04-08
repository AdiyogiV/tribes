import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/core/logging/app_logger.dart';

enum MessageStatus { sending, sent, delivered }

// Typing indicator user
class TypingUser {
  final String userId;
  final String userName;

  TypingUser({
    required this.userId,
    required this.userName,
  });
}

// User that can be mentioned in chat
class MentionableUser {
  final String userId;
  final String name;
  final String? avatar;

  MentionableUser({
    required this.userId,
    required this.name,
    this.avatar,
  });
}

class ChatMessage {
  final String id;
  final String spaceId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final String
      messageType; // 'text', 'image', 'video', 'audio', 'file', 'call', 'namaste', 'shared_content'
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? fileSize;
  final String? replyTo;
  final Map<String, String> reactions; // userId -> reactionType
  final List<String> readBy;
  final DateTime timestamp;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final MessageStatus status;

  // Call-specific fields (for messageType == 'call')
  final String? callType; // 'voice' or 'video'
  final String? callStatus; // 'answered', 'missed', 'rejected', 'cancelled'
  final int? callDuration; // Duration in seconds (for answered calls)
  final bool? isOutgoing; // true if this user initiated the call

  // Shared content fields (for messageType == 'shared_content')
  final Map<String, dynamic>?
      sharedContent; // {type, id, title, subtitle, imageUrl, authorName}
  final bool isForwarded; // true if message was forwarded
  final String? forwardedFrom; // Original message ID if forwarded

  ChatMessage({
    required this.id,
    required this.spaceId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.messageType,
    this.mediaUrl,
    this.thumbnailUrl,
    this.fileSize,
    this.replyTo,
    required this.reactions,
    required this.readBy,
    required this.timestamp,
    this.editedAt,
    this.deletedAt,
    this.status = MessageStatus.sent,
    this.callType,
    this.callStatus,
    this.callDuration,
    this.isOutgoing,
    this.sharedContent,
    this.isForwarded = false,
    this.forwardedFrom,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    try {
      // Simple status - just sent or delivered (no read receipts)
      MessageStatus status = MessageStatus.delivered;
      final senderId = json['senderId'] ?? '';

      return ChatMessage(
        id: json['id'] ?? '',
        spaceId: json['spaceId'] ?? '',
        senderId: senderId,
        senderName: json['senderName'] ?? '',
        senderAvatar: json['senderAvatar'],
        content: json['content'] ?? '',
        messageType: json['messageType'] ?? 'text',
        mediaUrl: json['mediaUrl'],
        thumbnailUrl: json['thumbnailUrl'],
        fileSize: json['fileSize'],
        replyTo: json['replyTo'],
        reactions: Map<String, String>.from(json['reactions'] ?? {}),
        readBy: List<String>.from(json['readBy'] ?? []),
        timestamp: json['timestamp'] != null
            ? (json['timestamp'] as Timestamp).toDate()
            : DateTime.now(),
        editedAt: json['editedAt'] != null
            ? (json['editedAt'] as Timestamp).toDate()
            : null,
        deletedAt: json['deletedAt'] != null
            ? (json['deletedAt'] as Timestamp).toDate()
            : null,
        status: status,
        // Call-specific fields
        callType: json['callType'],
        callStatus: json['callStatus'],
        callDuration: json['callDuration'],
        isOutgoing: json['isOutgoing'],
        // Shared content fields
        sharedContent: json['sharedContent'] != null
            ? Map<String, dynamic>.from(json['sharedContent'])
            : null,
        isForwarded: json['isForwarded'] ?? false,
        forwardedFrom: json['forwardedFrom'],
      );
    } catch (e) {
      AppLogger.e('Error parsing ChatMessage from JSON',
          category: LogCategory.general, error: e);
      // Return a default message to prevent crashes
      return ChatMessage(
        id: json['id'] ?? 'error',
        spaceId: json['spaceId'] ?? '',
        senderId: json['senderId'] ?? '',
        senderName: json['senderName'] ?? 'Unknown',
        content: json['content'] ?? 'Error loading message',
        messageType: 'text',
        reactions: {},
        readBy: [],
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );
    }
  }

  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'spaceId': spaceId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'messageType': messageType,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'fileSize': fileSize,
      'replyTo': replyTo,
      'reactions': reactions,
      'readBy': readBy,
      'timestamp': Timestamp.fromDate(timestamp),
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };

    // Add call-specific fields if this is a call message
    if (messageType == 'call') {
      json['callType'] = callType;
      json['callStatus'] = callStatus;
      json['callDuration'] = callDuration;
      json['isOutgoing'] = isOutgoing;
    }

    // Add shared content fields if this is a shared content message
    if (messageType == 'shared_content' && sharedContent != null) {
      json['sharedContent'] = sharedContent;
    }

    // Add forwarded fields if this is a forwarded message
    if (isForwarded) {
      json['isForwarded'] = true;
      json['forwardedFrom'] = forwardedFrom;
    }

    return json;
  }
}
