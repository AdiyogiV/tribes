// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_match.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContactMatch _$ContactMatchFromJson(Map<String, dynamic> json) => ContactMatch(
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      phoneHash: json['phoneHash'] as String,
      userId: json['userId'] as String?,
    );

Map<String, dynamic> _$ContactMatchToJson(ContactMatch instance) =>
    <String, dynamic>{
      'name': instance.name,
      'phoneNumber': instance.phoneNumber,
      'phoneHash': instance.phoneHash,
      'userId': instance.userId,
    };

ContactSyncResult _$ContactSyncResultFromJson(Map<String, dynamic> json) =>
    ContactSyncResult(
      onApp: (json['onApp'] as List<dynamic>?)
              ?.map((e) => ContactMatch.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      notOnApp: (json['notOnApp'] as List<dynamic>?)
              ?.map((e) => ContactMatch.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      hasPermission: json['hasPermission'] as bool? ?? true,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$ContactSyncResultToJson(ContactSyncResult instance) =>
    <String, dynamic>{
      'onApp': instance.onApp,
      'notOnApp': instance.notOnApp,
      'hasPermission': instance.hasPermission,
      'error': instance.error,
    };
