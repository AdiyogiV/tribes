// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
      id: json['id'] as String,
      spaceId: json['spaceId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      senderAvatar: json['senderAvatar'] as String?,
      content: json['content'] as String,
      messageType: json['messageType'] as String,
      mediaUrl: json['mediaUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
      replyTo: json['replyTo'] as String?,
      reactions: Map<String, String>.from(json['reactions'] as Map),
      readBy:
          (json['readBy'] as List<dynamic>).map((e) => e as String).toList(),
      timestamp: const TimestampConverter().fromJson(json['timestamp']),
      editedAt: const NullableTimestampConverter().fromJson(json['editedAt']),
      deletedAt: const NullableTimestampConverter().fromJson(json['deletedAt']),
      callType: json['callType'] as String?,
      callStatus: json['callStatus'] as String?,
      callDuration: (json['callDuration'] as num?)?.toInt(),
      isOutgoing: json['isOutgoing'] as bool?,
      sharedContent: json['sharedContent'] as Map<String, dynamic>?,
      isForwarded: json['isForwarded'] as bool? ?? false,
      forwardedFrom: json['forwardedFrom'] as String?,
    );

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'spaceId': instance.spaceId,
      'senderId': instance.senderId,
      'senderName': instance.senderName,
      'senderAvatar': instance.senderAvatar,
      'content': instance.content,
      'messageType': instance.messageType,
      'mediaUrl': instance.mediaUrl,
      'thumbnailUrl': instance.thumbnailUrl,
      'fileSize': instance.fileSize,
      'replyTo': instance.replyTo,
      'reactions': instance.reactions,
      'readBy': instance.readBy,
      'timestamp': const TimestampConverter().toJson(instance.timestamp),
      'editedAt': const NullableTimestampConverter().toJson(instance.editedAt),
      'deletedAt':
          const NullableTimestampConverter().toJson(instance.deletedAt),
      'callType': instance.callType,
      'callStatus': instance.callStatus,
      'callDuration': instance.callDuration,
      'isOutgoing': instance.isOutgoing,
      'sharedContent': instance.sharedContent,
      'isForwarded': instance.isForwarded,
      'forwardedFrom': instance.forwardedFrom,
    };
