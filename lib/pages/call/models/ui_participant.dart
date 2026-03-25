class UiParticipant {
  final int agoraUid;
  final String oderId;
  final String displayName;
  final String? avatarUrl;
  final bool isLocal;
  bool isAudioMuted = false;
  bool isVideoMuted = false;

  UiParticipant({
    required this.agoraUid,
    required this.oderId,
    required this.displayName,
    this.avatarUrl,
    this.isLocal = false,
    this.isAudioMuted = false,
    this.isVideoMuted = false,
  });
}
