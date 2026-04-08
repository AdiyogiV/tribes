import 'dart:async';
import 'package:aurogram/shared/models/group_call_participant.dart';
export 'package:aurogram/shared/models/group_call_participant.dart';

/// Stub for GroupCallService on web
/// Group calling is not supported on web in Phase 1

/// Stub GroupCallService for web - all group calling features disabled
class GroupCallService {
  static final GroupCallService _instance = GroupCallService._internal();
  factory GroupCallService() => _instance;
  GroupCallService._internal();

  // Stub stream controller
  final _participantsController = StreamController<List<GroupCallParticipant>>.broadcast();

  // Callbacks (never triggered on web)
  Function()? onCallEnded;
  Function(int participantCount)? onParticipantCountChanged;
  Function(String error)? onError;
  Function()? onJoinedChannel;
  Function(int uid)? onUserJoined;
  Function(int uid)? onUserLeft;
  Function(int quality)? onNetworkQualityChanged;

  // Getters - all return false/empty on web
  bool get isInCall => false;
  String? get activeSpaceId => null;
  bool get isAudioMuted => false;
  bool get isVideoMuted => true;
  int? get localUid => null;
  String? get currentUserId => null;
  Stream<List<GroupCallParticipant>> get participantsStream => _participantsController.stream;
  List<GroupCallParticipant> get participants => [];
  dynamic get engine => null;

  /// Start or join group call - not supported on web
  Future<bool> startOrJoinGroupCall({
    required String spaceId,
    required String spaceName,
  }) async {
    onError?.call('Group calling is not available on web');
    return false;
  }

  /// Leave call - no-op on web
  Future<void> leaveCall() async {}

  /// Toggle audio - no-op on web
  Future<void> toggleAudio() async {}

  /// Toggle video - no-op on web
  Future<void> toggleVideo() async {}

  /// Switch camera - no-op on web
  Future<void> switchCamera() async {}

  /// Toggle speaker - no-op on web
  Future<void> toggleSpeaker(bool enabled) async {}

  /// Check if there's an active call - always false on web
  Future<bool> hasActiveCall(String spaceId) async {
    return false;
  }

  /// Stream for active call - empty on web
  Stream<Map<String, dynamic>?> activeCallStream(String spaceId) {
    return Stream.value(null);
  }

  /// Dispose
  Future<void> dispose() async {
    await _participantsController.close();
  }
}
