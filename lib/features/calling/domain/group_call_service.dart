import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart' show navigator;
import 'package:aurogram/core/config/agora_config.dart';
import 'package:aurogram/core/logging/app_logger.dart';
// Conditional import: use permission_handler on mobile, stub on web
import 'package:permission_handler/permission_handler.dart'
    if (dart.library.html) 'package:aurogram/platform/permission_handler_stub.dart';
// Conditional import: Agora web SDK loader (only needed on web)
import 'package:aurogram/platform/agora_web_helper_stub.dart'
    if (dart.library.html) 'package:aurogram/platform/agora_web_helper.dart'
    as agora_web;
import 'package:aurogram/models/group_call_participant.dart';
export 'package:aurogram/models/group_call_participant.dart';

/// GroupCallService - Agora-based group calling for grams
class GroupCallService {
  static final GroupCallService _instance = GroupCallService._internal();
  factory GroupCallService() => _instance;
  GroupCallService._internal();

  // Agora engine
  RtcEngine? _engine;
  bool _isInitialized = false;

  // State
  bool _isInCall = false;
  String? _activeSpaceId;
  String? _activeChannelName;
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  int? _localUid;
  DateTime? _callStartTime;

  // Participants - maps Agora UID to participant info
  final Map<int, GroupCallParticipant> _participants = {};
  final _participantsController = StreamController<List<GroupCallParticipant>>.broadcast();

  // Firebase
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Callbacks
  Function()? onCallEnded;
  Function(int participantCount)? onParticipantCountChanged;
  Function(String error)? onError;
  Function()? onJoinedChannel;
  Function(int uid)? onUserJoined;
  Function(int uid)? onUserLeft;
  Function(int quality)? onNetworkQualityChanged; // 0-5, 5 is best

  // Getters
  bool get isInCall => _isInCall;
  String? get activeSpaceId => _activeSpaceId;
  bool get isAudioMuted => _isAudioMuted;
  bool get isVideoMuted => _isVideoMuted;
  bool get hasMediaPermissions => _hasMediaPermissions;
  int? get localUid => _localUid;
  String? get currentUserId => _auth.currentUser?.uid;
  Stream<List<GroupCallParticipant>> get participantsStream => _participantsController.stream;
  List<GroupCallParticipant> get participants => _participants.values.toList();
  RtcEngine? get engine => _engine;

  // Track if we have media permissions (for enabling video/audio later)
  bool _hasMediaPermissions = false;

  /// Static method to clean up stale call participants for a specific space
  /// This should be called when viewing a space to ensure accurate participant counts
  /// 
  /// Returns true if cleanup was performed, false if no cleanup needed
  static Future<bool> cleanupStaleCallParticipants(String spaceId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final callRef = firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('calls')
          .doc('active');

      final doc = await callRef.get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      final participants = data['participants'] as List<dynamic>? ?? [];
      if (participants.isEmpty) {
        // No participants but document exists - delete it
        await callRef.delete();
        AppLogger.i('🧹 Cleaned up empty call document for space: $spaceId', category: LogCategory.general);
        return true;
      }

      // Check for stale participants (90 second threshold)
      final now = DateTime.now();
      final staleThreshold = now.subtract(const Duration(seconds: 90));
      
      final activeParticipants = participants.where((p) {
        final lastHeartbeat = p['lastHeartbeat'] as String?;
        if (lastHeartbeat == null) {
          // Legacy participant without heartbeat - check joinedAt
          final joinedAt = p['joinedAt'] as String?;
          if (joinedAt != null) {
            try {
              final joinTime = DateTime.parse(joinedAt);
              // If joined more than 2 hours ago without heartbeat, consider stale
              if (joinTime.isBefore(now.subtract(const Duration(hours: 2)))) {
                AppLogger.w('🧹 Removing legacy stale participant: ${p['displayName']}', category: LogCategory.general);
                return false;
              }
            } catch (_) {
              AppLogger.w('GroupCallService: failed to parse joinedAt timestamp',
                  category: LogCategory.general);
            }
          }
          return true; // Keep if we can't determine staleness
        }
        
        try {
          final heartbeatTime = DateTime.parse(lastHeartbeat);
          if (heartbeatTime.isBefore(staleThreshold)) {
            AppLogger.w('🧹 Removing stale participant: ${p['displayName']}', category: LogCategory.general);
            return false;
          }
        } catch (_) {
          AppLogger.w('GroupCallService: failed to parse heartbeat timestamp during stale check',
              category: LogCategory.general);
        }
        return true;
      }).toList();

      if (activeParticipants.isEmpty) {
        // All participants were stale - delete the call
        await callRef.delete();
        AppLogger.i('🧹 Deleted call with all stale participants for space: $spaceId', category: LogCategory.general);
        return true;
      } else if (activeParticipants.length < participants.length) {
        // Some participants were stale - update the list
        await callRef.update({'participants': activeParticipants});
        AppLogger.i('🧹 Removed ${participants.length - activeParticipants.length} stale participants from space: $spaceId', 
            category: LogCategory.general);
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.e('Error cleaning up stale call participants', category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Initialize the Agora engine
  Future<bool> _initializeEngine() async {
    if (_isInitialized && _engine != null) return true;

    try {
      AppLogger.i('Initializing Agora engine... (isWeb: $kIsWeb)', category: LogCategory.general);

      // CRITICAL: On web, we must load the Agora SDK via JavaScript BEFORE creating the engine
      // The SDK is lazy-loaded to reduce initial bundle size
      if (kIsWeb) {
        AppLogger.i('Loading Agora SDK for web...', category: LogCategory.general);
        final sdkLoaded = await agora_web.loadAgoraSDK();
        if (!sdkLoaded) {
          AppLogger.e('Failed to load Agora SDK for web', category: LogCategory.general);
          onError?.call('Failed to load video call SDK. Please refresh the page and try again.');
          return false;
        }
        AppLogger.i('Agora SDK loaded successfully for web', category: LogCategory.general);
      }

      // Request camera/microphone permissions
      // On web: use browser's getUserMedia API
      // On mobile: use permission_handler package
      _hasMediaPermissions = await _requestMediaPermissions();
      if (!_hasMediaPermissions) {
        AppLogger.w('Camera or microphone permission denied - will join with media disabled', category: LogCategory.general);
        // Don't block call - user can still join and listen, or grant permissions later
      }

      AppLogger.i('Creating Agora RTC engine...', category: LogCategory.general);
      final engine = createAgoraRtcEngine();
      _engine = engine;
      
      AppLogger.i('Initializing Agora engine with appId...', category: LogCategory.general);
      await engine.initialize(RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          AppLogger.i('Joined channel: ${connection.channelId}, uid: ${connection.localUid}',
              category: LogCategory.general);
          _localUid = connection.localUid;
          _callStartTime = DateTime.now();
          onJoinedChannel?.call();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          AppLogger.i('User joined: $remoteUid', category: LogCategory.general);
          _addParticipantAndFetchInfo(remoteUid);
          onUserJoined?.call(remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          AppLogger.i('User left: $remoteUid, reason: $reason', category: LogCategory.general);
          _removeParticipant(remoteUid);
          onUserLeft?.call(remoteUid);
          onParticipantCountChanged?.call(_participants.length);
        },
        onUserMuteAudio: (connection, remoteUid, muted) {
          _updateParticipantAudioState(remoteUid, muted);
        },
        onUserMuteVideo: (connection, remoteUid, muted) {
          _updateParticipantVideoState(remoteUid, muted);
        },
        onError: (err, msg) {
          AppLogger.e('Agora error: $err - $msg', category: LogCategory.general);
          onError?.call('Call error: $msg');
        },
        onConnectionLost: (connection) {
          AppLogger.w('Connection lost - Agora will attempt automatic reconnection', category: LogCategory.general);
          // Note: Agora SDK handles reconnection automatically. We don't show a message
          // to avoid misleading users - if reconnection fails, onError will be called
          // via the onConnectionStateChanged handler with the actual failure reason.
        },
        onConnectionStateChanged: (connection, state, reason) {
          AppLogger.i('Connection state: $state, reason: $reason', category: LogCategory.general);
        },
        onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
          // Only track local user's quality (remoteUid == 0)
          if (remoteUid == 0) {
            // txQuality and rxQuality are 0-6, we normalize to 0-5 (invert so higher = better)
            final quality = 5 - (((txQuality.index + rxQuality.index) / 2).round().clamp(0, 5));
            onNetworkQualityChanged?.call(quality);
          }
        },
      ));

      await engine.enableVideo();
      await engine.enableAudio();

      await engine.setVideoEncoderConfiguration(VideoEncoderConfiguration(
        dimensions: VideoDimensions(
          width: AgoraConfig.videoWidth,
          height: AgoraConfig.videoHeight,
        ),
        frameRate: AgoraConfig.videoFrameRate,
        bitrate: AgoraConfig.videoBitrate,
      ));

      _isInitialized = true;
      AppLogger.i('Agora engine initialized successfully', category: LogCategory.general);
      return true;
    } catch (e) {
      AppLogger.e('Failed to initialize Agora engine', category: LogCategory.general, error: e);
      onError?.call('Failed to initialize call: $e');
      _engine = null;
      _isInitialized = false;
      return false;
    }
  }

  /// Request media permissions for camera and microphone
  /// Uses browser APIs on web, permission_handler on mobile
  Future<bool> _requestMediaPermissions() async {
    if (kIsWeb) {
      // On web, use browser's getUserMedia to request permissions
      // This triggers the browser's permission prompt
      try {
        AppLogger.i('Requesting media permissions via browser API...', category: LogCategory.general);
        
        final stream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {
            'facingMode': 'user',
          },
        });
        
        // Permission granted - stop the stream immediately (we just needed to check/request)
        for (final track in stream.getTracks()) {
          await track.stop();
        }
        await stream.dispose();
        
        AppLogger.i('Browser media permissions granted', category: LogCategory.general);
        return true;
      } catch (e) {
        AppLogger.e('Browser media permission denied or error', category: LogCategory.general, error: e);
        // Don't call onError here - we'll allow joining the call without media
        // The user will be notified via the muted state in the UI
        return false;
      }
    } else {
      // On mobile, use permission_handler package
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (cameraStatus.isDenied || micStatus.isDenied) {
        return false;
      }
      return true;
    }
  }

  String _getChannelName(String spaceId) => 'gram_$spaceId';

  Future<String?> _getToken(String channelName, int uid) async {
    if (!AgoraConfig.useTokenAuth) {
      AppLogger.i('Token auth disabled, skipping token fetch', category: LogCategory.general);
      return null;
    }

    try {
      AppLogger.i('Fetching Agora token for channel: $channelName, uid: $uid', category: LogCategory.general);
      
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('generateAgoraToken', options: HttpsCallableOptions(timeout: const Duration(seconds: 10)));
      
      AppLogger.i('Calling generateAgoraToken function...', category: LogCategory.general);
      final result = await callable.call({
        'channelName': channelName,
        'uid': uid,
      });
      AppLogger.i('Token function call completed', category: LogCategory.general);

      // Safely extract token from response
      final data = result.data;
      
      if (data == null) {
        AppLogger.w('Token function returned null data', category: LogCategory.general);
        return null;
      }
      
      if (data is Map) {
        final tokenValue = data['token'];
        if (tokenValue is String && tokenValue.isNotEmpty) {
          AppLogger.i('Token received successfully', category: LogCategory.general, 
              data: {'tokenLength': tokenValue.length});
          return tokenValue;
        }
      }
      
      AppLogger.w('Token function returned invalid response', category: LogCategory.general,
          data: {'dataType': data.runtimeType.toString()});
      return null;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to get Agora token', category: LogCategory.general, error: e);
      AppLogger.d('Token error stacktrace: $stackTrace', category: LogCategory.general);
      final errorStr = e.toString();
      if (errorStr.contains('NOT_FOUND') || errorStr.contains('not-found')) {
        AppLogger.w('Token function not deployed, joining without token', category: LogCategory.general);
        return null;
      }
      // Don't block the call for token errors - allow joining without token
      AppLogger.w('Proceeding without token due to error: $errorStr', category: LogCategory.general);
      return null;
    }
  }

  /// Start or join a group call
  Future<bool> startOrJoinGroupCall({
    required String spaceId,
    required String spaceName,
  }) async {
    if (_isInCall) {
      AppLogger.w('Already in a call', category: LogCategory.general);
      return false;
    }

    try {
      final initialized = await _initializeEngine();
      if (!initialized) return false;

      // Verify engine was created
      final engine = _engine;
      if (engine == null) {
        AppLogger.e('Engine is null after initialization', category: LogCategory.general);
        onError?.call('Failed to initialize call engine');
        return false;
      }

      _activeSpaceId = spaceId;
      _activeChannelName = _getChannelName(spaceId);
      final channelName = _activeChannelName!;

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        onError?.call('You must be logged in to join a call');
        return false;
      }
      
      // Use consistent Agora UID derived from Firebase UID
      final agoraUid = currentUser.uid.hashCode.abs() % 1000000000;
      
      // Get user's display name from Firestore
      String displayName = currentUser.displayName ?? 'User';
      String? avatarUrl;
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        final userData = userDoc.data();
        if (userData != null) {
          displayName = userData['name'] ?? userData['nickname'] ?? displayName;
          avatarUrl = userData['imageUrl'];
        }
      } catch (e) {
        AppLogger.w('Failed to fetch user info', category: LogCategory.general);
      }

      final token = await _getToken(channelName, agoraUid);

      // Enable video/audio based on permissions
      await engine.enableVideo();
      await engine.enableAudio();
      
      if (_hasMediaPermissions) {
        await engine.enableLocalVideo(true);
        await engine.startPreview();
        await engine.enableLocalAudio(true);
        _isAudioMuted = false;
        _isVideoMuted = false;
      } else {
        // No permissions - join with video/audio muted
        AppLogger.i('Joining call with video/audio disabled (no permissions)', category: LogCategory.general);
        await engine.enableLocalVideo(false);
        await engine.enableLocalAudio(false);
        _isAudioMuted = true;
        _isVideoMuted = true;
      }

      AppLogger.i('Joining channel: $channelName with uid: $agoraUid', category: LogCategory.general);
      
      await engine.joinChannel(
        token: token ?? '',
        channelId: channelName,
        uid: agoraUid,
        options: ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishMicrophoneTrack: _hasMediaPermissions,
          publishCameraTrack: _hasMediaPermissions,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      _isInCall = true;
      _localUid = agoraUid;

      // Update Firestore with active call info (including Agora UID mapping)
      await _updateCallPresence(spaceId, true, agoraUid, displayName, avatarUrl);

      AppLogger.i('📞 Joined group call in $spaceName', category: LogCategory.general);

      return true;
    } catch (e) {
      AppLogger.e('Failed to join group call', category: LogCategory.general, error: e);
      onError?.call('Failed to join call: $e');
      _cleanup();
      return false;
    }
  }

  /// Leave the current group call
  Future<void> leaveCall() async {
    if (!_isInCall) return;

    try {
      AppLogger.i('Leaving group call...', category: LogCategory.general);

      final duration = _callStartTime != null 
          ? DateTime.now().difference(_callStartTime!).inSeconds 
          : 0;
      final participantCount = _participants.length + 1;
      final spaceId = _activeSpaceId;

      await _engine?.leaveChannel();
      await _engine?.stopPreview();

      if (spaceId != null) {
        await _updateCallPresence(spaceId, false, null, null, null);
        
        // Save call history to chat
        if (duration > 0) {
          await _saveCallHistory(spaceId, duration, participantCount);
        }
      }

      _cleanup();
      onCallEnded?.call();

      AppLogger.i('Left group call (duration: ${duration}s)', category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Error leaving call', category: LogCategory.general, error: e);
      _cleanup();
    }
  }

  /// Save group call to chat history
  Future<void> _saveCallHistory(String spaceId, int duration, int participantCount) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get user info
      String senderName = 'User';
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        final userData = userDoc.data();
        if (userData != null) {
          senderName = userData['name'] ?? userData['nickname'] ?? 'User';
        }
      } catch (_) {
        AppLogger.w('GroupCallService: failed to fetch sender name for call summary',
            category: LogCategory.general);
      }

      // Format duration
      final durationStr = _formatDuration(duration);
      final content = 'Group call • $durationStr • $participantCount participants';

      // Save to space messages
      await _firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'senderName': senderName,
        'content': content,
        'messageType': 'group_call',
        'callDuration': duration,
        'participantCount': participantCount,
        'reactions': {},
        'readBy': [currentUser.uid],
        'timestamp': FieldValue.serverTimestamp(),
      });

      AppLogger.i('📝 Group call logged to chat: $content', category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Failed to save group call history', category: LogCategory.general, error: e);
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes < 60) {
      return secs > 0 ? '${minutes}m ${secs}s' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  Future<void> toggleAudio() async {
    if (!_isInCall || _engine == null) return;
    
    // If trying to unmute but don't have permissions, request them first
    if (_isAudioMuted && !_hasMediaPermissions) {
      AppLogger.i('Requesting media permissions to enable audio...', category: LogCategory.general);
      _hasMediaPermissions = await _requestMediaPermissions();
      if (!_hasMediaPermissions) {
        onError?.call('Microphone permission required. Please grant permission in browser/system settings.');
        return;
      }
      // Enable local audio track now that we have permissions
      await _engine!.enableLocalAudio(true);
    }
    
    _isAudioMuted = !_isAudioMuted;
    await _engine!.muteLocalAudioStream(_isAudioMuted);
    AppLogger.i('Audio ${_isAudioMuted ? "muted" : "unmuted"}', category: LogCategory.general);
  }

  Future<void> toggleVideo() async {
    if (!_isInCall || _engine == null) return;
    
    // If trying to enable video but don't have permissions, request them first
    if (_isVideoMuted && !_hasMediaPermissions) {
      AppLogger.i('Requesting media permissions to enable video...', category: LogCategory.general);
      _hasMediaPermissions = await _requestMediaPermissions();
      if (!_hasMediaPermissions) {
        onError?.call('Camera permission required. Please grant permission in browser/system settings.');
        return;
      }
      // Enable local video track now that we have permissions
      await _engine!.enableLocalVideo(true);
    }
    
    _isVideoMuted = !_isVideoMuted;
    await _engine!.muteLocalVideoStream(_isVideoMuted);
    if (_isVideoMuted) {
      await _engine!.stopPreview();
    } else {
      await _engine!.startPreview();
    }
    AppLogger.i('Video ${_isVideoMuted ? "off" : "on"}', category: LogCategory.general);
  }

  Future<void> switchCamera() async {
    if (!_isInCall || _engine == null || _isVideoMuted) return;
    try {
      await _engine!.switchCamera();
      AppLogger.i('Camera switched', category: LogCategory.general);
    } catch (e) {
      // May fail on web desktop with single webcam - that's okay
      AppLogger.w('Failed to switch camera (device may have single camera): $e', 
          category: LogCategory.general);
    }
  }

  Future<void> toggleSpeaker(bool enabled) async {
    if (!_isInCall || _engine == null) return;
    // setEnableSpeakerphone is not supported on web (audio output is managed by OS)
    if (kIsWeb) {
      AppLogger.w('toggleSpeaker not supported on web', category: LogCategory.general);
      return;
    }
    try {
      await _engine!.setEnableSpeakerphone(enabled);
      AppLogger.i('Speaker ${enabled ? "enabled" : "disabled"}', category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Failed to toggle speaker', category: LogCategory.general, error: e);
    }
  }

  Future<bool> hasActiveCall(String spaceId) async {
    try {
      final doc = await _firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('calls')
          .doc('active')
          .get();

      if (!doc.exists) return false;
      final data = doc.data();
      final participants = data?['participants'] as List<dynamic>? ?? [];
      return participants.isNotEmpty;
    } catch (e) {
      AppLogger.e('Error checking active call', category: LogCategory.general, error: e);
      return false;
    }
  }

  Stream<Map<String, dynamic>?> activeCallStream(String spaceId) {
    return _firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('calls')
        .doc('active')
        .snapshots()
        .map((doc) => doc.data());
  }

  // Heartbeat timer for keeping call presence alive
  Timer? _heartbeatTimer;
  
  // How often to send heartbeat (30 seconds)
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  
  // Consider a participant stale if no heartbeat for 90 seconds
  static const Duration _staleThreshold = Duration(seconds: 90);

  /// Update call presence in Firestore with Agora UID mapping
  /// Uses transactions to prevent race conditions when multiple users join/leave
  Future<void> _updateCallPresence(String spaceId, bool joining, int? agoraUid, String? displayName, String? avatarUrl) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final callRef = _firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('calls')
          .doc('active');

      if (joining && agoraUid != null) {
        // Use transaction to safely add participant
        await _firestore.runTransaction((transaction) async {
          final doc = await transaction.get(callRef);
          final now = DateTime.now();
          final heartbeatTimestamp = now.toIso8601String();
          
          final newParticipant = {
            'oderId': currentUser.uid,
            'agoraUid': agoraUid,
            'displayName': displayName ?? 'User',
            'avatarUrl': avatarUrl,
            'joinedAt': heartbeatTimestamp,
            'lastHeartbeat': heartbeatTimestamp,
          };

          if (!doc.exists) {
            // Create new call document
            transaction.set(callRef, {
              'channelName': _activeChannelName,
              'startedAt': FieldValue.serverTimestamp(),
              'participants': [newParticipant],
            });
          } else {
            final data = doc.data() ?? {};
            final participants = List<dynamic>.from(data['participants'] ?? []);
            
            // Remove stale participants and any existing entry for this user
            final staleThreshold = now.subtract(_staleThreshold);
            participants.removeWhere((p) {
              if (p['oderId'] == currentUser.uid) return true;
              
              // Check for stale heartbeat
              final lastHeartbeat = p['lastHeartbeat'] as String?;
              if (lastHeartbeat != null) {
                try {
                  final heartbeatTime = DateTime.parse(lastHeartbeat);
                  if (heartbeatTime.isBefore(staleThreshold)) {
                    AppLogger.w('Removing stale participant: ${p['displayName']}', category: LogCategory.general);
                    return true;
                  }
                } catch (_) {
                  AppLogger.w('GroupCallService: failed to parse heartbeat timestamp during join',
                      category: LogCategory.general);
                }
              }
              return false;
            });
            
            participants.add(newParticipant);
            transaction.update(callRef, {'participants': participants});
          }
        });
        
        // Start heartbeat timer
        _startHeartbeat(spaceId, currentUser.uid);
        
        AppLogger.i('✅ Added to call presence: $displayName (agora: $agoraUid)', category: LogCategory.general);
      } else {
        // Use transaction to safely remove participant
        await _firestore.runTransaction((transaction) async {
          final doc = await transaction.get(callRef);
          if (!doc.exists) return;
          
          final data = doc.data() ?? {};
          final participants = List<dynamic>.from(data['participants'] ?? []);
          
          // Also clean up stale participants while we're at it
          final now = DateTime.now();
          final staleThreshold = now.subtract(_staleThreshold);
          
          participants.removeWhere((p) {
            if (p['oderId'] == currentUser.uid) return true;
            
            // Check for stale heartbeat
            final lastHeartbeat = p['lastHeartbeat'] as String?;
            if (lastHeartbeat != null) {
              try {
                final heartbeatTime = DateTime.parse(lastHeartbeat);
                if (heartbeatTime.isBefore(staleThreshold)) {
                  AppLogger.w('Removing stale participant during leave: ${p['displayName']}', category: LogCategory.general);
                  return true;
                }
              } catch (_) {
                AppLogger.w('GroupCallService: failed to parse heartbeat timestamp during leave',
                    category: LogCategory.general);
              }
            }
            return false;
          });

          if (participants.isEmpty) {
            transaction.delete(callRef);
            AppLogger.i('🗑️ Deleted call record (last participant left)', category: LogCategory.general);
          } else {
            transaction.update(callRef, {'participants': participants});
            AppLogger.i('👋 Removed from call presence', category: LogCategory.general);
          }
        });
        
        // Stop heartbeat timer
        _stopHeartbeat();
      }
    } catch (e) {
      AppLogger.e('Error updating call presence', category: LogCategory.general, error: e);
    }
  }
  
  /// Start heartbeat timer to keep call presence alive
  void _startHeartbeat(String spaceId, String oderId) {
    _stopHeartbeat(); // Cancel any existing timer
    
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (!_isInCall || _activeSpaceId != spaceId) {
        _stopHeartbeat();
        return;
      }
      
      try {
        final callRef = _firestore
            .collection('spaces')
            .doc(spaceId)
            .collection('calls')
            .doc('active');
        
        await _firestore.runTransaction((transaction) async {
          final doc = await transaction.get(callRef);
          if (!doc.exists) return;
          
          final data = doc.data() ?? {};
          final participants = List<dynamic>.from(data['participants'] ?? []);
          final now = DateTime.now();
          final staleThreshold = now.subtract(_staleThreshold);
          
          bool updated = false;
          final updatedParticipants = participants.where((p) {
            // Update our heartbeat
            if (p['oderId'] == oderId) {
              p['lastHeartbeat'] = now.toIso8601String();
              updated = true;
              return true;
            }
            
            // Remove stale participants
            final lastHeartbeat = p['lastHeartbeat'] as String?;
            if (lastHeartbeat != null) {
              try {
                final heartbeatTime = DateTime.parse(lastHeartbeat);
                if (heartbeatTime.isBefore(staleThreshold)) {
                  AppLogger.w('Heartbeat cleanup: removing stale ${p['displayName']}', category: LogCategory.general);
                  return false;
                }
              } catch (_) {
                AppLogger.w('GroupCallService: failed to parse heartbeat timestamp during cleanup',
                    category: LogCategory.general);
              }
            }
            return true;
          }).toList();
          
          if (updatedParticipants.isEmpty) {
            transaction.delete(callRef);
          } else if (updated || updatedParticipants.length != participants.length) {
            transaction.update(callRef, {'participants': updatedParticipants});
          }
        });
      } catch (e) {
        AppLogger.w('Heartbeat update failed', category: LogCategory.general);
      }
    });
  }
  
  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Add participant and fetch their info from Firestore
  void _addParticipantAndFetchInfo(int agoraUid) async {
    // Add with placeholder first
    _participants[agoraUid] = GroupCallParticipant(
      agoraUid: agoraUid,
      oderId: '',
      displayName: 'Connecting...',
    );
    _notifyParticipantsChanged();
    onParticipantCountChanged?.call(_participants.length);

    // Fetch actual info from Firestore
    if (_activeSpaceId == null) return;

    try {
      final callDoc = await _firestore
          .collection('spaces')
          .doc(_activeSpaceId!)
          .collection('calls')
          .doc('active')
          .get();

      final data = callDoc.data();
      final participants = data?['participants'] as List<dynamic>? ?? [];
      
      // Find participant by Agora UID
      for (final p in participants) {
        if (p['agoraUid'] == agoraUid) {
          final displayName = p['displayName'] ?? 'User';
          final avatarUrl = p['avatarUrl'];
          final oderId = p['oderId'] ?? '';

          _participants[agoraUid] = GroupCallParticipant(
            agoraUid: agoraUid,
            oderId: oderId,
            displayName: displayName,
            avatarUrl: avatarUrl,
          );
          _notifyParticipantsChanged();
          AppLogger.i('👤 Fetched participant info: $displayName', category: LogCategory.general);
          return;
        }
      }

      // If not found by agoraUid, try to match any participant we don't know yet
      // This handles race conditions where Firestore hasn't updated yet
      await Future.delayed(const Duration(milliseconds: 500));
      
      final updatedDoc = await _firestore
          .collection('spaces')
          .doc(_activeSpaceId!)
          .collection('calls')
          .doc('active')
          .get();

      final updatedData = updatedDoc.data();
      final updatedParticipants = updatedData?['participants'] as List<dynamic>? ?? [];
      
      for (final p in updatedParticipants) {
        if (p['agoraUid'] == agoraUid) {
          _participants[agoraUid] = GroupCallParticipant(
            agoraUid: agoraUid,
            oderId: p['oderId'] ?? '',
            displayName: p['displayName'] ?? 'User',
            avatarUrl: p['avatarUrl'],
          );
          _notifyParticipantsChanged();
          AppLogger.i('👤 Fetched participant info (retry): ${p['displayName']}', category: LogCategory.general);
          return;
        }
      }

      // Still not found - keep as "User"
      _participants[agoraUid] = GroupCallParticipant(
        agoraUid: agoraUid,
        oderId: '',
        displayName: 'User',
      );
      _notifyParticipantsChanged();
      AppLogger.w('⚠️ Could not find participant info for agora uid: $agoraUid', category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Error fetching participant info', category: LogCategory.general, error: e);
      _participants[agoraUid] = GroupCallParticipant(
        agoraUid: agoraUid,
        oderId: '',
        displayName: 'User',
      );
      _notifyParticipantsChanged();
    }
  }

  void _removeParticipant(int uid) {
    final participant = _participants[uid];
    if (participant != null) {
      AppLogger.i('👋 Participant left: ${participant.displayName}', category: LogCategory.general);
    }
    _participants.remove(uid);
    _notifyParticipantsChanged();
  }

  void _updateParticipantAudioState(int uid, bool muted) {
    if (_participants.containsKey(uid)) {
      _participants[uid]!.isAudioMuted = muted;
      _notifyParticipantsChanged();
    }
  }

  void _updateParticipantVideoState(int uid, bool muted) {
    if (_participants.containsKey(uid)) {
      _participants[uid]!.isVideoMuted = muted;
      _notifyParticipantsChanged();
    }
  }

  void _notifyParticipantsChanged() {
    _participantsController.add(_participants.values.toList());
  }

  void _cleanup() {
    _stopHeartbeat();
    _isInCall = false;
    _activeSpaceId = null;
    _activeChannelName = null;
    _isAudioMuted = false;
    _isVideoMuted = false;
    _localUid = null;
    _callStartTime = null;
    _participants.clear();
    _notifyParticipantsChanged();
  }

  Future<void> dispose() async {
    _stopHeartbeat();
    await leaveCall();
    await _engine?.release();
    _engine = null;
    _isInitialized = false;
    await _participantsController.close();
  }
}
