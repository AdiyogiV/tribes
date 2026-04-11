import 'package:json_annotation/json_annotation.dart';

part 'group_call_participant.g.dart';

/// Participant info for group calls with generated JSON serialization.
@JsonSerializable()
class GroupCallParticipant {
  final int agoraUid;
  final String oderId;
  final String displayName;
  final String? avatarUrl;
  bool isAudioMuted;
  bool isVideoMuted;

  GroupCallParticipant({
    required this.agoraUid,
    required this.oderId,
    required this.displayName,
    this.avatarUrl,
    this.isAudioMuted = false,
    this.isVideoMuted = false,
  });

  factory GroupCallParticipant.fromJson(Map<String, dynamic> json) =>
      _$GroupCallParticipantFromJson(json);

  Map<String, dynamic> toJson() => _$GroupCallParticipantToJson(this);

  GroupCallParticipant copyWith({
    String? displayName,
    String? avatarUrl,
    bool? isAudioMuted,
    bool? isVideoMuted,
  }) {
    return GroupCallParticipant(
      agoraUid: agoraUid,
      oderId: oderId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isAudioMuted: isAudioMuted ?? this.isAudioMuted,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
    );
  }
}
