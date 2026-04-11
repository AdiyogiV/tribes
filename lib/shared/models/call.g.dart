// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Call _$CallFromJson(Map<String, dynamic> json) => Call(
      id: json['id'] as String,
      callerId: json['callerId'] as String,
      callerName: json['callerName'] as String,
      callerAvatar: json['callerAvatar'] as String?,
      calleeId: json['calleeId'] as String,
      calleeName: json['calleeName'] as String,
      calleeAvatar: json['calleeAvatar'] as String?,
      type: $enumDecode(_$CallTypeEnumMap, json['type']),
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      status: json['status'] as String,
      answeredAt:
          const NullableTimestampConverter().fromJson(json['answeredAt']),
      endedAt: const NullableTimestampConverter().fromJson(json['endedAt']),
    );

Map<String, dynamic> _$CallToJson(Call instance) => <String, dynamic>{
      'id': instance.id,
      'callerId': instance.callerId,
      'callerName': instance.callerName,
      'callerAvatar': instance.callerAvatar,
      'calleeId': instance.calleeId,
      'calleeName': instance.calleeName,
      'calleeAvatar': instance.calleeAvatar,
      'type': _$CallTypeEnumMap[instance.type]!,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'status': instance.status,
      'answeredAt':
          const NullableTimestampConverter().toJson(instance.answeredAt),
      'endedAt': const NullableTimestampConverter().toJson(instance.endedAt),
    };

const _$CallTypeEnumMap = {
  CallType.voice: 'voice',
  CallType.video: 'video',
};
