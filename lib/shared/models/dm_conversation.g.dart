// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dm_conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DmConversation _$DmConversationFromJson(Map<String, dynamic> json) =>
    DmConversation(
      id: json['id'] as String,
      otherUserId: json['otherUserId'] as String,
      participants: (json['participants'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      lastActivity: const TimestampConverter().fromJson(json['lastActivity']),
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      lastMessageContent: json['lastMessageContent'] as String?,
      lastMessageSenderId: json['lastMessageSenderId'] as String?,
      lastMessageSenderName: json['lastMessageSenderName'] as String?,
      displayPicture: json['displayPicture'] as String?,
      spaceType: $enumDecodeNullable(_$SpaceTypeEnumMap, json['spaceType']),
      spaceName: json['spaceName'] as String?,
      contextType: json['contextType'] as String?,
      firstUserMessage: json['firstUserMessage'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      mutedUntil:
          const NullableTimestampConverter().fromJson(json['mutedUntil']),
      status: json['status'] as String?,
      requestedBy: json['requestedBy'] as String?,
    );

Map<String, dynamic> _$DmConversationToJson(DmConversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'otherUserId': instance.otherUserId,
      'participants': instance.participants,
      'lastActivity': const TimestampConverter().toJson(instance.lastActivity),
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'lastMessageContent': instance.lastMessageContent,
      'lastMessageSenderId': instance.lastMessageSenderId,
      'lastMessageSenderName': instance.lastMessageSenderName,
      'displayPicture': instance.displayPicture,
      'spaceType': _$SpaceTypeEnumMap[instance.spaceType],
      'spaceName': instance.spaceName,
      'contextType': instance.contextType,
      'firstUserMessage': instance.firstUserMessage,
      'isPinned': instance.isPinned,
      'isMuted': instance.isMuted,
      'isArchived': instance.isArchived,
      'mutedUntil':
          const NullableTimestampConverter().toJson(instance.mutedUntil),
      'status': instance.status,
      'requestedBy': instance.requestedBy,
    };

const _$SpaceTypeEnumMap = {
  SpaceType.open: 'open',
  SpaceType.public: 'public',
  SpaceType.private: 'private',
  SpaceType.personal: 'personal',
};
