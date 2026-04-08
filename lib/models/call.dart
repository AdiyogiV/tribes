import 'package:cloud_firestore/cloud_firestore.dart';

/// Call state enum with intermediate states for better conflict resolution
enum CallState {
  idle,
  ringing, // Outgoing call ringing
  incoming, // Incoming call
  answering, // NEW: Device is answering (intermediate state)
  connecting, // Call connecting
  connected, // Call active
  ending, // NEW: Call is ending (intermediate state)
  ended, // Call ended
}

/// Call type enum
enum CallType { voice, video }

/// Call model
class Call {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final String calleeId;
  final String calleeName;
  final String? calleeAvatar;
  final CallType type;
  final DateTime createdAt;
  final String status; // 'ringing', 'answered', 'ended', 'missed', 'rejected'
  final DateTime? answeredAt;
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

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      id: json['id'] ?? '',
      callerId: json['callerId'] ?? '',
      callerName: json['callerName'] ?? 'Unknown',
      callerAvatar: json['callerAvatar'],
      calleeId: json['calleeId'] ?? '',
      calleeName: json['calleeName'] ?? 'Unknown',
      calleeAvatar: json['calleeAvatar'],
      type: json['type'] == 'video' ? CallType.video : CallType.voice,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: json['status'] ?? 'ringing',
      answeredAt: (json['answeredAt'] as Timestamp?)?.toDate(),
      endedAt: (json['endedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'callerId': callerId,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
        'calleeId': calleeId,
        'calleeName': calleeName,
        'calleeAvatar': calleeAvatar,
        'type': type == CallType.video ? 'video' : 'voice',
        'createdAt': Timestamp.fromDate(createdAt),
        'status': status,
        'answeredAt':
            answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
        'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      };

  bool get isVideo => type == CallType.video;
  bool get isVoice => type == CallType.voice;
}
