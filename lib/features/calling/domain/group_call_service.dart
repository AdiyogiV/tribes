import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/models/group_call_participant.dart';
export 'package:aurogram/shared/models/group_call_participant.dart';

import 'group_call_media.dart';
import 'group_call_signaling.dart';

/// GroupCallService - Agora-based group calling for grams.
///
/// Thin orchestrator that delegates media concerns to [GroupCallMediaManager]
/// and Firestore signaling / participant tracking to [GroupCallSignalingManager].
class GroupCallService {
  static final GroupCallService _instance = GroupCallService._internal();
  factory GroupCallService() => _instance;
  GroupCallService._internal();

  // Delegates
  final _media = GroupCallMediaManager();
  final _signaling = GroupCallSignalingManager();

  // State
  bool _isInCall = false;
  String? _activeSpaceId;
  String? _activeChannelName;
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  int? _localUid;
  DateTime? _callStartTime;

  // Callbacks
  Function()? onCallEnded;
  Function(int participantCount)? onParticipantCountChanged;
  Function(String error)? onError;
  Function()? onJoinedChannel;
  Function(int uid)? onUserJoined;
  Function(int uid)? onUserLeft;
  Function(int quality)? onNetworkQualityChanged;

  // Getters
  bool get isInCall => _isInCall;
  String? get activeSpaceId => _activeSpaceId;
  bool get isAudioMuted => _isAudioMuted;
  bool get isVideoMuted => _isVideoMuted;
  bool get hasMediaPermissions => _media.hasMediaPermissions;
  int? get localUid => _localUid;
  String? get currentUserId => _signaling.currentUserId;
  Stream<List<GroupCallParticipant>> get participantsStream =>
      _signaling.participantsStream;
  List<GroupCallParticipant> get participants => _signaling.participantsList;
  RtcEngine? get engine => _media.engine;

  // -------------------------------------------------------------------------
  // Static helpers
  // -------------------------------------------------------------------------

  /// Clean up stale call participants for a specific space.
  static Future<bool> cleanupStaleCallParticipants(String spaceId) =>
      GroupCallSignalingManager.cleanupStaleCallParticipants(spaceId);

  // -------------------------------------------------------------------------
  // Channel name helper
  // -------------------------------------------------------------------------

  String _getChannelName(String spaceId) => 'gram_$spaceId';

  // -------------------------------------------------------------------------
  // Start / join / leave
  // -------------------------------------------------------------------------

  /// Start or join a group call.
  Future<bool> startOrJoinGroupCall({
    required String spaceId,
    required String spaceName,
  }) async {
    if (_isInCall) {
      AppLogger.w('Already in a call', category: LogCategory.general);
      return false;
    }

    try {
      final initialized = await _media.initializeEngine(
        onJoinChannelSuccess: (uid) {
          _localUid = uid;
          _callStartTime = DateTime.now();
          onJoinedChannel?.call();
        },
        onUserJoined: (remoteUid) {
          _signaling.addParticipantAndFetchInfo(remoteUid, _activeSpaceId);
          onUserJoined?.call(remoteUid);
        },
        onUserOffline: (remoteUid, _) {
          _signaling.removeParticipant(remoteUid);
          onUserLeft?.call(remoteUid);
          onParticipantCountChanged?.call(_signaling.participants.length);
        },
        onUserMuteAudio: (remoteUid, muted) {
          _signaling.updateParticipantAudioState(remoteUid, muted);
        },
        onUserMuteVideo: (remoteUid, muted) {
          _signaling.updateParticipantVideoState(remoteUid, muted);
        },
        onEngineError: (msg) {
          onError?.call(msg);
        },
        onConnectionStateChanged: (state, reason) {
          // Logged inside media manager
        },
        onNetworkQuality: (quality) {
          onNetworkQualityChanged?.call(quality);
        },
      );
      if (!initialized) return false;

      if (_media.engine == null) {
        AppLogger.e('Engine is null after initialization',
            category: LogCategory.general);
        onError?.call('Failed to initialize call engine');
        return false;
      }

      _activeSpaceId = spaceId;
      _activeChannelName = _getChannelName(spaceId);
      final channelName = _activeChannelName!;

      final userId = _signaling.currentUserId;
      if (userId == null) {
        onError?.call('You must be logged in to join a call');
        return false;
      }

      final agoraUid = userId.hashCode.abs() % 1000000000;

      // Fetch display name / avatar
      final userInfo = await _signaling.fetchCurrentUserInfo();

      // Fetch token
      final token = await _media.getToken(channelName, agoraUid);

      // Prepare audio/video
      final muteState = await _media.prepareForJoin();
      _isAudioMuted = muteState.isAudioMuted;
      _isVideoMuted = muteState.isVideoMuted;

      // Join the Agora channel
      await _media.joinChannel(
        channelName: channelName,
        token: token ?? '',
        uid: agoraUid,
        publishMedia: _media.hasMediaPermissions,
      );

      _isInCall = true;
      _localUid = agoraUid;

      // Update Firestore presence
      await _signaling.updateCallPresence(
        spaceId,
        true,
        agoraUid,
        userInfo.displayName,
        userInfo.avatarUrl,
        activeChannelName: _activeChannelName,
        isInCallCheck: () => _isInCall,
        activeSpaceIdGetter: () => _activeSpaceId,
      );

      AppLogger.i('Joined group call in $spaceName',
          category: LogCategory.general);
      return true;
    } catch (e) {
      AppLogger.e('Failed to join group call',
          category: LogCategory.general, error: e);
      onError?.call('Failed to join call: $e');
      _cleanup();
      return false;
    }
  }

  /// Leave the current group call.
  Future<void> leaveCall() async {
    if (!_isInCall) return;

    try {
      AppLogger.i('Leaving group call...', category: LogCategory.general);

      final duration = _callStartTime != null
          ? DateTime.now().difference(_callStartTime!).inSeconds
          : 0;
      final participantCount = _signaling.participants.length + 1;
      final spaceId = _activeSpaceId;

      await _media.leaveChannel();

      if (spaceId != null) {
        await _signaling.updateCallPresence(
          spaceId,
          false,
          null,
          null,
          null,
          activeChannelName: _activeChannelName,
          isInCallCheck: () => _isInCall,
          activeSpaceIdGetter: () => _activeSpaceId,
        );

        if (duration > 0) {
          await _signaling.saveCallHistory(spaceId, duration, participantCount);
        }
      }

      _cleanup();
      onCallEnded?.call();

      AppLogger.i('Left group call (duration: ${duration}s)',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Error leaving call',
          category: LogCategory.general, error: e);
      _cleanup();
    }
  }

  // -------------------------------------------------------------------------
  // Media controls (delegated)
  // -------------------------------------------------------------------------

  Future<void> toggleAudio() async {
    if (!_isInCall || _media.engine == null) return;
    _isAudioMuted = await _media.toggleAudio(
      isCurrentlyMuted: _isAudioMuted,
      onError: (msg) => onError?.call(msg),
    );
  }

  Future<void> toggleVideo() async {
    if (!_isInCall || _media.engine == null) return;
    _isVideoMuted = await _media.toggleVideo(
      isCurrentlyMuted: _isVideoMuted,
      onError: (msg) => onError?.call(msg),
    );
  }

  Future<void> switchCamera() async {
    if (!_isInCall || _media.engine == null || _isVideoMuted) return;
    await _media.switchCamera();
  }

  Future<void> toggleSpeaker(bool enabled) async {
    if (!_isInCall || _media.engine == null) return;
    await _media.toggleSpeaker(enabled);
  }

  // -------------------------------------------------------------------------
  // Signaling queries (delegated)
  // -------------------------------------------------------------------------

  Future<bool> hasActiveCall(String spaceId) =>
      _signaling.hasActiveCall(spaceId);

  Stream<Map<String, dynamic>?> activeCallStream(String spaceId) =>
      _signaling.activeCallStream(spaceId);

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  void _cleanup() {
    _signaling.stopHeartbeat();
    _isInCall = false;
    _activeSpaceId = null;
    _activeChannelName = null;
    _isAudioMuted = false;
    _isVideoMuted = false;
    _localUid = null;
    _callStartTime = null;
    _signaling.clearParticipants();
  }

  Future<void> dispose() async {
    _signaling.stopHeartbeat();
    await leaveCall();
    await _media.release();
    await _signaling.dispose();
  }
}
