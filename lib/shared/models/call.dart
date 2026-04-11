import 'package:json_annotation/json_annotation.dart';
import 'package:aurogram/shared/data/converters/timestamp_converter.dart';

part 'call.g.dart';

/// Call state enum with intermediate states for better conflict resolution
enum CallState {
  idle,
  ringing, // Outgoing call ringing
  incoming, // Incoming call
  answering, // Device is answering (intermediate state)
  connecting, // Call connecting
  connected, // Call active
  ending, // Call is ending (intermediate state)
  ended, // Call ended
}

/// Call type enum
enum CallType {
  @JsonValue('voice')
  voice,
  @JsonValue('video')
  video,
}

/// Call model with generated JSON serialization.
@JsonSerializable()
class Call {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final String calleeId;
  final String calleeName;
  final String? calleeAvatar;
  final CallType type;
  @TimestampConverter()
  final DateTime createdAt;
  final String status; // 'ringing', 'answered', 'ended', 'missed', 'rejected'
  @NullableTimestampConverter()
  final DateTime? answeredAt;
  @NullableTimestampConverter()
  final DateTime? endedAt;

  Call({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.calleeId,
    required this.calleeName,
    this.calleeAvatar,
    required this.type,
    required this.createdAt,
    required this.status,
    this.answeredAt,
    this.endedAt,
  });

  factory Call.fromJson(Map<String, dynamic> json) => _$CallFromJson({
        ...json,
        // Provide defaults for required fields from Firestore
        'id': json['id'] ?? '',
        'callerId': json['callerId'] ?? '',
        'callerName': json['callerName'] ?? 'Unknown',
        'calleeId': json['calleeId'] ?? '',
        'calleeName': json['calleeName'] ?? 'Unknown',
        'type': json['type'] ?? 'voice',
        'status': json['status'] ?? 'ringing',
      });

  Map<String, dynamic> toJson() => _$CallToJson(this);

  bool get isVideo => type == CallType.video;
  bool get isVoice => type == CallType.voice;
}
