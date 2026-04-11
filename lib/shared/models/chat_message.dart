import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/data/converters/timestamp_converter.dart';

part 'chat_message.g.dart';

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

@JsonSerializable()
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
  @TimestampConverter()
  final DateTime timestamp;
  @NullableTimestampConverter()
  final DateTime? editedAt;
  @NullableTimestampConverter()
  final DateTime? deletedAt;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final MessageStatus status;

  // Call-specific fields (for messageType == 'call')
  final String? callType; // 'voice' or 'video'
  final String? callStatus; // 'answered', 'missed', 'rejected', 'cancelled'
  final int? callDuration; // Duration in seconds (for answered calls)
  final bool? isOutgoing; // true if this user initiated the call

  // Shared content fields (for messageType == 'shared_content')
  final Map<String, dynamic>?
      sharedContent; // {type, id, title, subtitle, imageUrl, authorName}
  @JsonKey(defaultValue: false)
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
      // Provide defaults for required fields that may be missing from Firestore
      final safeJson = {
        'id': json['id'] ?? '',
        'spaceId': json['spaceId'] ?? '',
        'senderId': json['senderId'] ?? '',
        'senderName': json['senderName'] ?? '',
        'content': json['content'] ?? '',
        'messageType': json['messageType'] ?? 'text',
        'reactions': json['reactions'] ?? <String, dynamic>{},
        'readBy': json['readBy'] ?? <dynamic>[],
        'timestamp': json['timestamp'] ?? Timestamp.now(),
        ...json, // overlay actual values on top of defaults
        // Re-apply defaults for keys that were explicitly null in json
        if (json['id'] == null) 'id': '',
        if (json['spaceId'] == null) 'spaceId': '',
        if (json['senderId'] == null) 'senderId': '',
        if (json['senderName'] == null) 'senderName': '',
        if (json['content'] == null) 'content': '',
        if (json['messageType'] == null) 'messageType': 'text',
        if (json['reactions'] == null) 'reactions': <String, dynamic>{},
        if (json['readBy'] == null) 'readBy': <dynamic>[],
        if (json['timestamp'] == null) 'timestamp': Timestamp.now(),
      };

      final message = _$ChatMessageFromJson(safeJson);
      // Always override status to delivered (no read receipts in this model)
      return ChatMessage(
        id: message.id,
        spaceId: message.spaceId,
        senderId: message.senderId,
        senderName: message.senderName,
        senderAvatar: message.senderAvatar,
        content: message.content,
        messageType: message.messageType,
        mediaUrl: message.mediaUrl,
        thumbnailUrl: message.thumbnailUrl,
        fileSize: message.fileSize,
        replyTo: message.replyTo,
        reactions: message.reactions,
        readBy: message.readBy,
        timestamp: message.timestamp,
        editedAt: message.editedAt,
        deletedAt: message.deletedAt,
        status: MessageStatus.delivered,
        callType: message.callType,
        callStatus: message.callStatus,
        callDuration: message.callDuration,
        isOutgoing: message.isOutgoing,
        sharedContent: message.sharedContent,
        isForwarded: message.isForwarded,
        forwardedFrom: message.forwardedFrom,
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
    final json = _$ChatMessageToJson(this);

    // Add call-specific fields only for call messages
    if (messageType != 'call') {
      json.remove('callType');
      json.remove('callStatus');
      json.remove('callDuration');
      json.remove('isOutgoing');
    }

    // Remove shared content fields if not a shared content message
    if (messageType != 'shared_content' || sharedContent == null) {
      json.remove('sharedContent');
    }

    // Only include forwarded fields if this is a forwarded message
    if (!isForwarded) {
      json.remove('isForwarded');
      json.remove('forwardedFrom');
    }

    return json;
  }
}
