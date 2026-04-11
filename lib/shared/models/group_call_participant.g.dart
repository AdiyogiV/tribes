// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_call_participant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroupCallParticipant _$GroupCallParticipantFromJson(
        Map<String, dynamic> json) =>
    GroupCallParticipant(
      agoraUid: (json['agoraUid'] as num).toInt(),
      oderId: json['oderId'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      isAudioMuted: json['isAudioMuted'] as bool? ?? false,
      isVideoMuted: json['isVideoMuted'] as bool? ?? false,
    );

Map<String, dynamic> _$GroupCallParticipantToJson(
        GroupCallParticipant instance) =>
    <String, dynamic>{
      'agoraUid': instance.agoraUid,
      'oderId': instance.oderId,
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
      'isAudioMuted': instance.isAudioMuted,
      'isVideoMuted': instance.isVideoMuted,
    };
