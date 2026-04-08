/// Participant info for group calls
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
