import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/services/device_manager.dart';
import 'package:aurogram/services/follow_service.dart';

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

/// CallService handles voice/video calls using WebRTC
///
/// Uses Google's FREE STUN servers for NAT traversal
/// Firestore for signaling (offer/answer/ICE candidates)
class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // WebRTC
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // ICE servers - Google's FREE STUN servers
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ]
  };

  // State
  CallState _state = CallState.idle;
  Call? _currentCall;
  StreamSubscription? _callStatusSubscription;
  StreamSubscription? _iceCandidateSubscription;
  StreamSubscription? _incomingCallSubscription;
  StreamSubscription? _authStateSubscription;
  bool _isCleaningUp = false;

  // Call history tracking
  DateTime? _callConnectedAt;
  String? _lastCallStatus;
  final SpaceChatService _chatService = SpaceChatService();

  // Callbacks
  Function(CallState state)? onCallStateChanged;
  Function(Call call)? onIncomingCall;
  Function(MediaStream stream)? onLocalStream;
  Function(MediaStream stream)? onRemoteStream;

  // Getters
  User? get _currentUser => _auth.currentUser;
  CallState get state => _state;
  Call? get currentCall => _currentCall;
  bool get isInCall =>
      _state == CallState.connected || _state == CallState.connecting;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  // Timer for incoming call timeout
  Timer? _incomingCallTimeoutTimer;

  // Lock to prevent concurrent call operations
  bool _isStartingCall = false;

  // Mute states
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;

  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isSpeakerOn => _isSpeakerOn;

  /// Check if local stream has video tracks (camera capability)
  bool get hasVideoTrack {
    if (_localStream == null) return false;
    final videoTracks = _localStream!.getVideoTracks();
    return videoTracks.isNotEmpty;
  }

  /// Check if camera can be enabled (has video track and it's currently off)
  bool get canEnableCamera => hasVideoTrack && _isCameraOff;

  // Web camera switching - track available video devices
  List<MediaDeviceInfo> _videoDevices = [];
  int _currentVideoDeviceIndex = 0;

  // Permission error callback - allows UI to show user-friendly messages
  Function(String error)? onPermissionError;

  /// Request media permissions before starting a call
  /// On web, this triggers the browser permission prompt
  /// Returns true if permissions are granted, false otherwise
  Future<bool> requestMediaPermissions({bool video = true}) async {
    try {
      AppLogger.i(
          '📹 Requesting media permissions (video: $video, isWeb: $kIsWeb)',
          category: LogCategory.general);

      // Use flutter_webrtc's navigator to request permissions
      // This works on both web and mobile
      final constraints = {
        'audio': true,
        'video': video
            ? {
                'facingMode': 'user',
              }
            : false,
      };

      final stream = await navigator.mediaDevices.getUserMedia(constraints);

      // Permission granted - stop the stream immediately
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();

      AppLogger.i('📹 Media permissions granted',
          category: LogCategory.general);
      return true;
    } catch (e) {
      AppLogger.e('📹 Media permissions denied or unavailable',
          category: LogCategory.general, error: e);

      // Provide specific error message for UI
      String errorMessage =
          'Camera and microphone access is required for video calls.';
      if (e.toString().contains('NotAllowedError') ||
          e.toString().contains('Permission denied')) {
        errorMessage =
            'Camera/microphone permission was denied. Please allow access in your browser settings and try again.';
      } else if (e.toString().contains('NotFoundError')) {
        errorMessage =
            'No camera or microphone found. Please connect a device and try again.';
      } else if (e.toString().contains('NotReadableError')) {
        errorMessage =
            'Camera or microphone is already in use by another application.';
      } else if (e.toString().contains('OverconstrainedError')) {
        errorMessage = 'Camera does not meet the required constraints.';
      } else if (e.toString().contains('SecurityError') ||
          e.toString().contains('Only secure origins')) {
        errorMessage =
            'Video calls require a secure connection (HTTPS). Please use HTTPS to access this site.';
      }

      onPermissionError?.call(errorMessage);
      return false;
    }
  }

  /// Check if we have media permissions without prompting
  /// Note: On web, this may not be accurate as browsers handle this differently
  Future<bool> hasMediaPermissions({bool video = true}) async {
    // On web, we can't reliably check without prompting
    // So we just return true and let the actual call handle errors
    if (kIsWeb) {
      return true; // Will be verified when actually starting the call
    }

    // On mobile, permissions are handled by permission_handler package
    // But since we use flutter_webrtc, it handles this internally
    return true;
  }

  /// Force reset state to idle (use when state gets stuck)
  Future<void> forceResetState() async {
    AppLogger.w('Force resetting call state from $_state to idle',
        category: LogCategory.general);

    _incomingCallTimeoutTimer?.cancel();
    _incomingCallTimeoutTimer = null;
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;

    await _callStatusSubscription?.cancel();
    _callStatusSubscription = null;

    await _iceCandidateSubscription?.cancel();
    _iceCandidateSubscription = null;

    await _answerSubscription?.cancel();
    _answerSubscription = null;

    await _disposeWebRTC();

    _currentCall = null;
    _isCleaningUp = false;
    _isStartingCall = false;
    _answerProcessed = false;
    _setState(CallState.idle);
  }

  /// Initialize the call service
  Future<void> initialize() async {
    try {
      AppLogger.i('📞 CallService.initialize() starting (isWeb: $kIsWeb)',
          category: LogCategory.general,
          data: {'isWeb': kIsWeb, 'currentUser': _currentUser?.uid});

      // Listen for incoming calls
      _listenForIncomingCalls();

      // Listen for auth state changes with proper cleanup on account switch
      _authStateSubscription?.cancel();
      User? _previousUser = _currentUser;

      _authStateSubscription = _auth.authStateChanges().listen((user) async {
        final previousUser = _previousUser;
        _previousUser = user;

        AppLogger.i('📞 Auth state changed in CallService (isWeb: $kIsWeb)',
            category: LogCategory.general,
            data: {
              'hasUser': user != null,
              'userId': user?.uid,
              'previousUserId': previousUser?.uid,
              'hasSubscription': _incomingCallSubscription != null
            });

        // If user changed or logged out, cleanup active call
        if (previousUser != null &&
            (user == null || user.uid != previousUser.uid)) {
          AppLogger.i('📞 User changed or logged out - cleaning up active call',
              category: LogCategory.general);

          // If we're in an active call, end it properly
          if (_state != CallState.idle && _currentCall != null) {
            try {
              // Update call status to reflect user disconnect
              await _firestore
                  .collection('calls')
                  .doc(_currentCall!.id)
                  .update({
                'status': 'ended',
                'endedAt': FieldValue.serverTimestamp(),
                'endedReason': 'user_switched_account',
              });
            } catch (e) {
              AppLogger.w('Failed to update call status on account switch',
                  category: LogCategory.general);
            }
          }

          // Force cleanup all resources
          await forceResetState();

          // Cancel all listeners
          await _incomingCallSubscription?.cancel();
          _incomingCallSubscription = null;

          // Clean up device on sign out
          if (user == null) {
            await DeviceManager.cleanupOnSignOut();
          }
        }

        // If new user logged in, reinitialize listeners
        if (user != null &&
            (previousUser == null || user.uid != previousUser.uid)) {
          AppLogger.i('📞 New user logged in - reinitializing call service',
              category: LogCategory.general);
          // Clear cached device ID for new user
          _cachedDeviceId = null;
          await initialize();
        } else if (user != null && _incomingCallSubscription == null) {
          AppLogger.i(
              '📞 Auth state changed - setting up incoming call listener (isWeb: $kIsWeb)',
              category: LogCategory.general);
          _listenForIncomingCalls();
        } else if (user == null) {
          AppLogger.i('📞 User logged out - cancelling incoming call listener',
              category: LogCategory.general);
          _incomingCallSubscription?.cancel();
          _incomingCallSubscription = null;
        }
      });

      AppLogger.i(
          '📞 CallService initialized successfully (WebRTC, isWeb: $kIsWeb)',
          category: LogCategory.general,
          data: {
            'isWeb': kIsWeb,
            'hasIncomingSubscription': _incomingCallSubscription != null
          });
    } catch (e) {
      AppLogger.e('📞 Failed to initialize CallService (isWeb: $kIsWeb)',
          category: LogCategory.general, error: e, data: {'isWeb': kIsWeb});
    }
  }

  /// Re-initialize the incoming call listener (call after login)
  void reinitializeListener() {
    AppLogger.i('📞 Reinitializing incoming call listener (isWeb: $kIsWeb)',
        category: LogCategory.general,
        data: {
          'isWeb': kIsWeb,
          'currentUser': _currentUser?.uid,
          'hasExistingSubscription': _incomingCallSubscription != null,
          'hasOnIncomingCallback': onIncomingCall != null,
        });
    _listenForIncomingCalls();
  }

  /// Dispose resources - called when service is being destroyed
  Future<void> dispose() async {
    AppLogger.d('Disposing CallService', category: LogCategory.general);

    // Cancel all timers
    _incomingCallTimeoutTimer?.cancel();
    _connectionTimeoutTimer?.cancel();

    // Cancel all subscriptions
    await _incomingCallSubscription?.cancel();
    _incomingCallSubscription = null;
    await _authStateSubscription?.cancel();
    _authStateSubscription = null;
    await _callStatusSubscription?.cancel();
    _callStatusSubscription = null;
    await _iceCandidateSubscription?.cancel();
    _iceCandidateSubscription = null;
    await _answerSubscription?.cancel();
    _answerSubscription = null;

    // Clean up WebRTC
    await _disposeWebRTC();

    // Clear callbacks to prevent memory leaks
    onCallStateChanged = null;
    onIncomingCall = null;
    onLocalStream = null;
    onRemoteStream = null;
  }

  /// Dispose WebRTC resources safely with proper sequencing
  /// This order is critical to prevent GPU driver crashes and memory leaks
  Future<void> _disposeWebRTC() async {
    try {
      // Step 1: Clear peer connection handlers FIRST to prevent callbacks during cleanup
      final peerConnection = _peerConnection;
      if (peerConnection != null) {
        peerConnection.onTrack = null;
        peerConnection.onConnectionState = null;
        peerConnection.onIceConnectionState = null;
        peerConnection.onIceCandidate = null;
      }

      // Step 2: Stop all tracks before disposing stream
      // This releases camera/microphone resources
      final localStream = _localStream;
      if (localStream != null) {
        final tracks = localStream.getTracks();
        for (final track in tracks) {
          try {
            await track.stop();
          } catch (e) {
            AppLogger.w('Error stopping track ${track.kind}: $e',
                category: LogCategory.general);
          }
        }

        // Small delay to allow hardware to release
        await Future.delayed(const Duration(milliseconds: 50));

        try {
          await localStream.dispose();
        } catch (e) {
          AppLogger.w('Error disposing local stream: $e',
              category: LogCategory.general);
        }
      }
      _localStream = null;

      // Step 3: Clear remote stream reference (no disposal needed)
      _remoteStream = null;

      // Step 4: Close peer connection AFTER streams are disposed
      if (peerConnection != null) {
        try {
          // Small delay to ensure streams are fully released
          await Future.delayed(const Duration(milliseconds: 50));
          await peerConnection.close();
        } catch (e) {
          AppLogger.w('Error closing peer connection: $e',
              category: LogCategory.general);
        }
      }
      _peerConnection = null;

      // Step 5: Final delay to allow GPU/EGL cleanup
      await Future.delayed(const Duration(milliseconds: 100));

      AppLogger.d('WebRTC resources disposed successfully',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Error disposing WebRTC',
          category: LogCategory.general, error: e);
    }
  }

  /// Listen for incoming calls
  void _listenForIncomingCalls() {
    // Cancel existing subscription if any
    _incomingCallSubscription?.cancel();
    _incomingCallSubscription = null;

    if (_currentUser == null) {
      AppLogger.w(
          '📞 Cannot listen for incoming calls: user not logged in (isWeb: $kIsWeb)',
          category: LogCategory.general);
      return;
    }

    final userId = _currentUser!.uid;
    AppLogger.i(
        '📞 Setting up incoming call Firestore listener for user: $userId (isWeb: $kIsWeb)',
        category: LogCategory.general,
        data: {'userId': userId, 'isWeb': kIsWeb});

    _incomingCallSubscription = _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: userId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen(
      (snapshot) {
        AppLogger.d(
            '📞 Incoming call snapshot received - docChanges: ${snapshot.docChanges.length}, docs: ${snapshot.docs.length}',
            category: LogCategory.general,
            data: {
              'docChanges': snapshot.docChanges.length,
              'totalDocs': snapshot.docs.length
            });

        for (final change in snapshot.docChanges) {
          AppLogger.d(
              '📞 Processing doc change - type: ${change.type}, docId: ${change.doc.id}',
              category: LogCategory.general);

          if (change.type == DocumentChangeType.added) {
            final call = Call.fromJson({
              'id': change.doc.id,
              ...change.doc.data()!,
            });

            AppLogger.i(
                '📞 Incoming call document detected: ${call.id} from ${call.callerName}',
                category: LogCategory.general,
                data: {
                  'callId': call.id,
                  'callerId': call.callerId,
                  'callerName': call.callerName,
                  'callType': call.type.toString(),
                  'currentState': _state.toString(),
                  'hasOnIncomingCallback': onIncomingCall != null,
                });

            // Only process if we're not already in a call
            // Also check if call is in 'answering' state (another device might be answering)
            if (_state == CallState.idle) {
              AppLogger.i(
                  '📞 Processing incoming call - state is idle, will trigger onIncomingCall callback',
                  category: LogCategory.general);
              _handleIncomingCall(call);
            } else {
              AppLogger.w(
                  '📞 Ignoring incoming call - already in call state: $_state',
                  category: LogCategory.general,
                  data: {'currentState': _state.toString()});
            }
          }
        }
      },
      onError: (error) {
        AppLogger.e('📞 Error in incoming call listener (isWeb: $kIsWeb)',
            category: LogCategory.general, error: error);
        // Retry after a delay
        Future.delayed(const Duration(seconds: 5), () {
          if (_currentUser != null && _incomingCallSubscription == null) {
            AppLogger.i('📞 Retrying incoming call listener setup',
                category: LogCategory.general);
            _listenForIncomingCalls();
          }
        });
      },
    );

    AppLogger.i(
        '📞 Incoming call Firestore listener active for user: $userId (isWeb: $kIsWeb)',
        category: LogCategory.general,
        data: {
          'userId': userId,
          'isWeb': kIsWeb,
          'subscriptionActive': _incomingCallSubscription != null
        });
  }

  /// Handle incoming call
  void _handleIncomingCall(Call call) async {
    AppLogger.i('📞 _handleIncomingCall starting (isWeb: $kIsWeb)',
        category: LogCategory.general,
        data: {
          'callId': call.id,
          'callerName': call.callerName,
          'callType': call.type.toString(),
          'hasOnIncomingCallback': onIncomingCall != null,
        });

    _currentCall = call;
    _setState(CallState.incoming);

    // CRITICAL: Trigger the onIncomingCall callback to show the UI
    if (onIncomingCall != null) {
      AppLogger.i(
          '📞 Triggering onIncomingCall callback to show incoming call UI',
          category: LogCategory.general);
      onIncomingCall!(call);
      AppLogger.i('📞 onIncomingCall callback completed',
          category: LogCategory.general);
    } else {
      AppLogger.e(
          '📞 WARNING: onIncomingCall callback is NULL! Incoming call UI will NOT be shown!',
          category: LogCategory.general,
          data: {'callId': call.id, 'callerName': call.callerName});
    }

    // Native CallKit UI removed; rely on in-app UI + notifications

    // Listen for call status changes (e.g., caller hangs up before we answer)
    _listenForCallStatusAsReceiver(call.id);

    // Set a timeout - if not answered within 60 seconds, mark as missed
    _incomingCallTimeoutTimer?.cancel();
    _incomingCallTimeoutTimer = Timer(const Duration(seconds: 60), () {
      if (_state == CallState.incoming) {
        AppLogger.w('📞 Incoming call timed out (60s without response)',
            category: LogCategory.general);
        missCall();
      }
    });

    AppLogger.i(
        '📞 Incoming ${call.type.name} call from ${call.callerName} - handler complete',
        category: LogCategory.general);
  }

  /// Public method to set up an incoming call from notification tap
  void setupIncomingCall(Call call) {
    if (_state != CallState.idle || _currentCall != null) {
      AppLogger.d('CallService already has a call, skipping setup',
          category: LogCategory.general);
      return;
    }

    AppLogger.i(
        'Setting up incoming call from notification: ${call.callerName}',
        category: LogCategory.general);
    _handleIncomingCall(call);
  }

  /// Listen for call status changes as the receiver (before answering)
  /// This handles when the caller hangs up before the callee answers
  void _listenForCallStatusAsReceiver(String callId) {
    _callStatusSubscription?.cancel();

    AppLogger.d('Setting up receiver status listener for call: $callId',
        category: LogCategory.general);

    _callStatusSubscription =
        _firestore.collection('calls').doc(callId).snapshots().listen(
      (snapshot) {
        // Handle document deletion
        if (!snapshot.exists) {
          AppLogger.w('Call document deleted while ringing',
              category: LogCategory.general);
          _cleanup('call_deleted');
          return;
        }

        final data = snapshot.data();
        if (data == null) {
          AppLogger.w('Call document has null data while ringing',
              category: LogCategory.general);
          _cleanup('call_deleted');
          return;
        }

        final status = data['status'] as String?;
        AppLogger.d('Receiver status update: $status',
            category: LogCategory.general);

        // Caller ended/cancelled the call before we answered
        if (status == 'ended' ||
            status == 'missed' ||
            status == 'cancelled' ||
            status == 'failed') {
          AppLogger.i('Caller ended call while ringing (status: $status)',
              category: LogCategory.general);
          _cleanup('caller_ended_$status');
        }
      },
      onError: (error) {
        AppLogger.e('Receiver status listener error',
            category: LogCategory.general, error: error);
        _cleanup('listener_error');
      },
    );
  }

  /// Get device ID (cached for performance)
  String? _cachedDeviceId;
  Future<String> _getDeviceId() async {
    _cachedDeviceId ??= await DeviceManager.getDeviceId();
    return _cachedDeviceId!;
  }

  /// Start an outgoing call with deduplication
  Future<bool> startCall({
    required String calleeId,
    required String calleeName,
    String? calleeAvatar,
    required CallType type,
  }) async {
    // Prevent concurrent call attempts (race condition protection)
    if (_isStartingCall) {
      AppLogger.w('Cannot start call: another call is being started',
          category: LogCategory.general);
      return false;
    }

    if (_currentUser == null) {
      AppLogger.w('Cannot start call: user is null',
          category: LogCategory.general);
      return false;
    }

    if (calleeId == _currentUser!.uid) {
      AppLogger.w('Cannot call yourself', category: LogCategory.general);
      return false;
    }

    // Check if users are mutual followers (required for calls)
    final followService = FollowService();
    final isMutual = await followService.isMutualFollow(calleeId);
    if (!isMutual) {
      AppLogger.w('Cannot call: users are not mutual followers',
          category: LogCategory.general);
      throw Exception('You can only call people who follow you back');
    }

    if (isInCall || _state != CallState.idle) {
      AppLogger.w('Cannot start call: already in call (state: $_state)',
          category: LogCategory.general);
      return false;
    }

    _isStartingCall = true;

    try {
      _isCleaningUp = false;

      // CRITICAL: Check for existing in-progress calls (not 'answered' — that can be stale from a previous ended call)
      final existingCalls = await _firestore
          .collection('calls')
          .where('callerId', isEqualTo: _currentUser!.uid)
          .where('calleeId', isEqualTo: calleeId)
          .where('status', whereIn: ['ringing', 'connecting', 'answering'])
          .limit(1)
          .get();

      if (existingCalls.docs.isNotEmpty) {
        final existingCallDoc = existingCalls.docs.first;
        final status = existingCallDoc.data()['status'] as String?;

        AppLogger.w('Call already exists to $calleeName (status: $status)',
            category: LogCategory.general);

        // If call is still in progress, reuse it instead of creating new one
        if (status == 'ringing' ||
            status == 'connecting' ||
            status == 'answering') {
          final existingCall = Call.fromJson({
            'id': existingCallDoc.id,
            ...existingCallDoc.data(),
          });
          _currentCall = existingCall;
          _setState(CallState.ringing);
          _isStartingCall = false;

          // Set up listeners for existing call
          _listenForAnswer(existingCall.id);
          _listenForCallStatus(existingCall.id);

          return true;
        }
      }

      _setState(CallState.ringing);

      // Get caller info
      final callerDoc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();
      final callerData = callerDoc.data() ?? {};
      final callerName =
          callerData['name'] ?? callerData['nickname'] ?? 'Unknown';
      final callerAvatar = callerData['displayPicture'];

      // Create call document with device ID
      final callRef = _firestore.collection('calls').doc();
      final deviceId = await _getDeviceId();

      final call = Call(
        id: callRef.id,
        callerId: _currentUser!.uid,
        callerName: callerName,
        callerAvatar: callerAvatar,
        calleeId: calleeId,
        calleeName: calleeName,
        calleeAvatar: calleeAvatar,
        type: type,
        createdAt: DateTime.now(),
        status: 'ringing',
      );

      _currentCall = call;

      // Use transaction to ensure atomic creation and prevent duplicates
      await _firestore.runTransaction((transaction) async {
        // Double-check no in-progress call was created in the meantime (exclude 'answered' — may be stale)
        final recentCalls = await _firestore
            .collection('calls')
            .where('callerId', isEqualTo: _currentUser!.uid)
            .where('calleeId', isEqualTo: calleeId)
            .where('status', whereIn: ['ringing', 'connecting', 'answering'])
            .limit(1)
            .get();

        if (recentCalls.docs.isNotEmpty) {
          throw Exception('Call already exists');
        }

        transaction.set(callRef, {
          ...call.toJson(),
          'callerDeviceId': deviceId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      // Initialize WebRTC - always request video, but disable camera for voice calls
      // This unified approach allows upgrading voice calls to video mid-call
      try {
        await _initializeWebRTC(startWithCameraOff: type == CallType.voice);
      } catch (webrtcError) {
        AppLogger.e('WebRTC initialization failed during call start',
            category: LogCategory.general, error: webrtcError);
        // Update call status to reflect failure
        await callRef.update({'status': 'failed'});
        rethrow;
      }

      // Create and send offer
      await _createOffer(callRef.id);

      // Listen for answer
      _listenForAnswer(callRef.id);

      // Listen for call status
      _listenForCallStatus(callRef.id);

      AppLogger.i('📞 Started ${type.name} call to $calleeName',
          category: LogCategory.general);

      _isStartingCall = false;
      return true;
    } catch (e) {
      AppLogger.e('Failed to start call',
          category: LogCategory.general, error: e);
      _isStartingCall = false;
      await _cleanup('start_failed');
      return false;
    }
  }

  /// Answer an incoming call with atomic transaction to prevent race conditions
  Future<bool> answerCall() async {
    final call = _currentCall;
    if (call == null || _state != CallState.incoming) {
      AppLogger.w(
          'Cannot answer call: no current call or wrong state (state: $_state)',
          category: LogCategory.general);
      return false;
    }

    try {
      _incomingCallTimeoutTimer?.cancel();
      _incomingCallTimeoutTimer = null;

      _isCleaningUp = false;
      _setState(CallState.answering); // Use intermediate state

      AppLogger.d('📞 Answering call: ${call.id}',
          category: LogCategory.general);

      final callRef = _firestore.collection('calls').doc(call.id);
      final deviceId = await _getDeviceId();

      // Use transaction to atomically claim the call
      Map<String, dynamic>? offerData;

      try {
        final result = await _firestore.runTransaction((transaction) async {
          final callDoc = await transaction.get(callRef);

          if (!callDoc.exists) {
            throw Exception('Call no longer exists');
          }

          final data = callDoc.data()!;
          final currentStatus = data['status'] as String?;

          // CRITICAL: Only allow answering if status is still 'ringing'
          if (currentStatus != 'ringing' && currentStatus != 'answering') {
            throw Exception(
                'Call already answered or ended (status: $currentStatus)');
          }

          // Check if another device is already answering (optimistic lock)
          final answeringDeviceId = data['answeringDeviceId'] as String?;
          if (answeringDeviceId != null && answeringDeviceId != deviceId) {
            // Another device is answering - check timestamp
            final answeringTimestamp = data['answeringTimestamp'] as Timestamp?;
            if (answeringTimestamp != null) {
              final timeSinceAnswering =
                  DateTime.now().difference(answeringTimestamp.toDate());
              // If another device started answering < 3 seconds ago, let it proceed
              if (timeSinceAnswering.inSeconds < 3) {
                throw Exception('Another device is answering this call');
              }
            }
          }

          // Atomically claim the call
          transaction.update(callRef, {
            'answeringDeviceId': deviceId,
            'answeringTimestamp': FieldValue.serverTimestamp(),
            'status': 'answering', // New intermediate state
          });

          return data['offer'] as Map<String, dynamic>?;
        });

        offerData = result;
      } catch (e) {
        // Handle transaction conflicts
        if (e.toString().contains('already answered') ||
            e.toString().contains('Another device')) {
          AppLogger.w('Call answered by another device',
              category: LogCategory.general);
          await _cleanup('answered_by_other_device');
          _showMessageToUser?.call('Call was answered on another device');
          return false;
        }
        rethrow;
      }

      // If offer not available yet, wait for it
      if (offerData == null) {
        offerData = await _waitForOffer(call.id, maxWaitSeconds: 5);
        if (offerData == null) {
          // Release claim and fail
          try {
            await callRef.update({
              'answeringDeviceId': FieldValue.delete(),
              'answeringTimestamp': FieldValue.delete(),
              'status': 'ringing',
            });
          } catch (_) {}
          throw Exception('Offer not available');
        }
      }

      // Initialize WebRTC - always request video, but disable camera for voice calls
      // This unified approach allows upgrading voice calls to video mid-call
      AppLogger.d('📞 Initializing WebRTC...', category: LogCategory.general);
      await _initializeWebRTC(startWithCameraOff: call.isVoice);

      final peerConnection = _peerConnection;
      if (peerConnection == null) {
        throw Exception('Peer connection not initialized');
      }

      // IMPORTANT: Set up ICE candidate handler BEFORE creating answer
      AppLogger.d('📞 Setting up ICE candidate handler for callee...',
          category: LogCategory.general);
      peerConnection.onIceCandidate = (candidate) {
        if (candidate.candidate != null && _peerConnection != null) {
          AppLogger.d('📞 Callee: Sending ICE candidate',
              category: LogCategory.general);
          _sendIceCandidate(call.id, 'calleeCandidates', candidate);
        }
      };

      // Set remote description (the offer)
      AppLogger.d('📞 Setting remote description (offer)...',
          category: LogCategory.general);
      await peerConnection.setRemoteDescription(
        RTCSessionDescription(offerData['sdp'], offerData['type']),
      );

      // Create and send answer
      AppLogger.d('📞 Creating answer...', category: LogCategory.general);
      final answer = await peerConnection.createAnswer();

      AppLogger.d('📞 Setting local description (answer)...',
          category: LogCategory.general);
      await peerConnection.setLocalDescription(answer);

      // Finalize answer with another transaction
      await _firestore.runTransaction((transaction) async {
        final callDoc = await transaction.get(callRef);
        if (!callDoc.exists) {
          throw Exception('Call no longer exists');
        }

        final data = callDoc.data()!;
        final answeringDeviceId = data['answeringDeviceId'] as String?;

        // Verify we're still the answering device
        if (answeringDeviceId != null && answeringDeviceId != deviceId) {
          throw Exception('Call answered by another device');
        }

        // Update to answered state
        transaction.update(callRef, {
          'status': 'answered',
          'answeredAt': FieldValue.serverTimestamp(),
          'answeredByDeviceId': deviceId,
          'answer': {
            'sdp': answer.sdp,
            'type': answer.type,
          },
          // Clear answering fields
          'answeringDeviceId': FieldValue.delete(),
          'answeringTimestamp': FieldValue.delete(),
        });
      });

      // Only set to connecting if we're not already connected
      // (onTrack may have already transitioned us to connected after setRemoteDescription)
      if (_state != CallState.connected) {
        _setState(CallState.connecting);
      }

      // Listen for ICE candidates from caller
      _listenForIceCandidatesOnly(call.id, 'callerCandidates');

      // Listen for call status changes
      _listenForCallStatus(call.id);

      AppLogger.i('📞 Successfully answered call from ${call.callerName}',
          category: LogCategory.general);

      return true;
    } catch (e) {
      AppLogger.e('Failed to answer call',
          category: LogCategory.general, error: e);
      // Don't reject if it was a call-not-found error - just cleanup locally
      if (e.toString().contains('no longer') ||
          e.toString().contains('already answered') ||
          e.toString().contains('Another device')) {
        await _cleanup('call_unavailable');
      } else {
        await rejectCall();
      }
      return false;
    }
  }

  /// Wait for offer to be available in call document
  Future<Map<String, dynamic>?> _waitForOffer(String callId,
      {int maxWaitSeconds = 5}) async {
    final callRef = _firestore.collection('calls').doc(callId);
    const maxAttempts = 10; // 10 attempts * 500ms = 5 seconds max wait

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final callDoc = await callRef.get();

      if (!callDoc.exists) {
        throw Exception('Call no longer exists');
      }

      final offerData = callDoc.data()?['offer'] as Map<String, dynamic>?;
      if (offerData != null) {
        AppLogger.d('📞 Offer found on attempt $attempt',
            category: LogCategory.general);
        return offerData;
      }

      if (attempt < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return null;
  }

  /// Callback for showing messages to user (set by UI)
  Function(String message)? _showMessageToUser;

  /// Set callback for showing user messages
  void setMessageCallback(Function(String message)? callback) {
    _showMessageToUser = callback;
  }

  /// Initialize WebRTC with comprehensive error handling
  /// Always requests video capability, but can start with camera disabled for "voice" calls
  /// This allows upgrading voice calls to video mid-call
  Future<void> _initializeWebRTC({bool startWithCameraOff = false}) async {
    try {
      // Always request video - unified call architecture
      // Camera will be disabled after initialization if startWithCameraOff is true
      final mediaConstraints = {
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      };

      AppLogger.i(
          '📹 Requesting media: audio=true, video=true (cameraOff: $startWithCameraOff)',
          category: LogCategory.general);

      // Track if we fell back to audio-only (for adding recvonly video transceiver)
      bool fellBackToAudioOnly = false;

      try {
        _localStream =
            await navigator.mediaDevices.getUserMedia(mediaConstraints);
        final videoTracks = _localStream!.getVideoTracks();
        final audioTracks = _localStream!.getAudioTracks();
        AppLogger.i(
            '📹 Got local stream: ${videoTracks.length} video, ${audioTracks.length} audio tracks',
            category: LogCategory.general);
      } catch (e) {
        AppLogger.e('Failed to get user media - permission may be denied',
            category: LogCategory.general, error: e);

        // Provide specific error message for UI
        String errorMessage = 'Failed to access camera/microphone.';
        final errorStr = e.toString();

        if (errorStr.contains('NotAllowedError') ||
            errorStr.contains('Permission denied') ||
            errorStr.contains('PermissionDeniedError')) {
          // Check if it's a system-level denial (macOS) vs browser denial
          if (errorStr.contains('denied by system') ||
              errorStr.contains('system')) {
            errorMessage = kIsWeb
                ? 'Camera access blocked by your operating system. On Mac: Go to System Settings → Privacy & Security → Camera/Microphone → Enable your browser. Then restart the browser.'
                : 'Camera access blocked by your operating system. Please enable camera access in your device settings.';
          } else {
            errorMessage = kIsWeb
                ? 'Camera/microphone permission was denied. Please click the camera icon in your browser\'s address bar to allow access, then try again.'
                : 'Camera/microphone permission was denied. Please enable it in your device settings.';
          }
        } else if (errorStr.contains('NotFoundError') ||
            errorStr.contains('DevicesNotFoundError')) {
          errorMessage =
              'No camera or microphone found. Please connect a device and try again.';
        } else if (errorStr.contains('NotReadableError') ||
            errorStr.contains('TrackStartError')) {
          errorMessage =
              'Camera or microphone is already in use by another application.';
        } else if (errorStr.contains('OverconstrainedError')) {
          errorMessage = 'Camera does not support the required settings.';
        } else if (errorStr.contains('SecurityError') ||
            errorStr.contains('Only secure origins')) {
          errorMessage = 'Video calls require a secure connection (HTTPS).';
        }

        // Try audio-only fallback if video permission denied
        AppLogger.i(
            '📹 Attempting audio-only fallback (will still receive remote video)',
            category: LogCategory.general);
        try {
          _localStream = await navigator.mediaDevices.getUserMedia({
            'audio': true,
            'video': false,
          });
          fellBackToAudioOnly = true;
          AppLogger.i('📹 Audio-only fallback successful',
              category: LogCategory.general);

          // Notify UI that we fell back to audio-only
          onPermissionError?.call(
              'Video access denied. Continuing with audio only. $errorMessage');
        } catch (audioError) {
          // Even audio failed
          AppLogger.e('📹 Audio-only fallback also failed',
              category: LogCategory.general, error: audioError);
          onPermissionError?.call(errorMessage);
          rethrow;
        }
      }

      if (_localStream == null) {
        throw Exception('Failed to acquire local media stream');
      }

      onLocalStream?.call(_localStream!);

      // Create peer connection with error handling
      try {
        _peerConnection = await createPeerConnection(_iceServers);
      } catch (e) {
        AppLogger.e('Failed to create peer connection',
            category: LogCategory.general, error: e);
        rethrow;
      }

      if (_peerConnection == null) {
        throw Exception('Failed to create peer connection');
      }

      // Add local tracks safely
      final tracks = _localStream!.getTracks();
      for (final track in tracks) {
        try {
          _peerConnection!.addTrack(track, _localStream!);
        } catch (e) {
          AppLogger.w('Failed to add track: ${track.kind} - $e',
              category: LogCategory.general);
          // Continue - don't fail entire call for single track
        }
      }

      // CRITICAL: If we fell back to audio-only, add a receive-only video transceiver
      // so the SDP offer includes video and the remote peer will send us their video.
      if (fellBackToAudioOnly) {
        try {
          AppLogger.i(
              '📹 Adding recvonly video transceiver to receive remote video',
              category: LogCategory.general);
          await _peerConnection!.addTransceiver(
            kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init:
                RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
          );
        } catch (e) {
          AppLogger.w('Failed to add recvonly video transceiver: $e',
              category: LogCategory.general);
          // Continue - call will work without receiving video
        }
      }

      // If this is a "voice" call (startWithCameraOff), disable camera track immediately
      // This allows the call to start as audio-only but enables video upgrade capability
      if (startWithCameraOff && !fellBackToAudioOnly) {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          AppLogger.i(
              '📹 Disabling camera for voice call (can be enabled later)',
              category: LogCategory.general);
          videoTracks[0].enabled = false;
          _isCameraOff = true;
        }
      }

      // Handle remote stream
      _peerConnection!.onTrack = (event) {
        final trackKind = event.track.kind;
        final streamCount = event.streams.length;
        final trackEnabled = event.track.enabled;

        AppLogger.i(
            '📞 onTrack: received $trackKind track (enabled: $trackEnabled, streams: $streamCount)',
            category: LogCategory.general);

        if (event.streams.isNotEmpty) {
          final newStream = event.streams[0];

          // Update remote stream (onTrack can fire multiple times for different tracks)
          // Always use the latest stream reference to ensure we have all tracks
          final streamChanged = _remoteStream?.id != newStream.id;
          _remoteStream = newStream;

          final videoTracks = _remoteStream!.getVideoTracks().length;
          final audioTracks = _remoteStream!.getAudioTracks().length;
          final enabledVideoTracks = _remoteStream!
              .getVideoTracks()
              .where((track) => track.enabled)
              .length;

          AppLogger.i(
              '📞 Remote stream ${streamChanged ? "updated" : "track added"}: $videoTracks video tracks ($enabledVideoTracks enabled), $audioTracks audio tracks',
              category: LogCategory.general);

          // Warn if video track is disabled
          if (videoTracks > 0 && enabledVideoTracks == 0) {
            AppLogger.w(
                '📞 WARNING: Remote video tracks exist but all are disabled!',
                category: LogCategory.general);
          }

          // Always notify UI when tracks are added/updated (even if stream ID didn't change)
          // This ensures UI updates when video track arrives after audio track
          onRemoteStream?.call(_remoteStream!);

          // Transition to connected when we receive tracks
          // This is especially important on web where connection state callbacks may not fire reliably
          // Include CallState.answering: callee can get tracks when setRemoteDescription(offer) runs, before we set state to connecting
          if ((_state == CallState.answering ||
                  _state == CallState.connecting ||
                  _state == CallState.ringing) &&
              audioTracks > 0) {
            AppLogger.i(
                '📞 Received media tracks - transitioning to connected (audio: $audioTracks, video: $videoTracks, state: $_state)',
                category: LogCategory.general);
            _setState(CallState.connected);
            _callConnectedAt = DateTime.now();
            _lastCallStatus = 'answered';
          } else if (_state == CallState.connected) {
            AppLogger.d(
                '📞 Received additional track while already connected (audio: $audioTracks, video: $videoTracks)',
                category: LogCategory.general);
          } else {
            AppLogger.d(
                '📞 Received tracks but not transitioning - state: $_state, audio: $audioTracks',
                category: LogCategory.general);
          }
        }
      };

      // Handle connection state - this is the primary state indicator
      _peerConnection!.onConnectionState = (state) {
        AppLogger.d('WebRTC connection state: $state (call state: $_state)',
            category: LogCategory.general);

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          // Connection established successfully (include answering - callee may still be in that state)
          if (_state == CallState.answering ||
              _state == CallState.connecting ||
              _state == CallState.ringing) {
            AppLogger.i('WebRTC connected - transitioning to connected state',
                category: LogCategory.general);
            _setState(CallState.connected);
            _callConnectedAt = DateTime.now();
            _lastCallStatus = 'answered';
          }
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          // Connection failed - end the call
          AppLogger.w('WebRTC connection failed - ending call',
              category: LogCategory.general);
          _handleCallEnded('webrtc_failed');
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          // Disconnected - might reconnect, but for now treat as ended for 1:1 calls
          AppLogger.w('WebRTC disconnected - ending call',
              category: LogCategory.general);
          _handleCallEnded('webrtc_disconnected');
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          // Connection closed - end the call
          AppLogger.d('WebRTC connection closed',
              category: LogCategory.general);
          // Only handle if we're not already cleaning up
          if (!_isCleaningUp &&
              _state != CallState.ended &&
              _state != CallState.idle) {
            _handleCallEnded('webrtc_closed');
          }
        }
      };

      // Handle ICE connection state - backup indicator
      _peerConnection!.onIceConnectionState = (state) {
        AppLogger.d('ICE connection state: $state (call state: $_state)',
            category: LogCategory.general);

        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          // ICE connected - use this as backup to set connected state (include answering for callee)
          if (_state == CallState.answering ||
              _state == CallState.connecting ||
              _state == CallState.ringing) {
            AppLogger.i('ICE connected - transitioning to connected state',
                category: LogCategory.general);
            _setState(CallState.connected);
            _callConnectedAt = DateTime.now();
            _lastCallStatus = 'answered';
          }
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          AppLogger.w('ICE connection failed', category: LogCategory.general);
          // Let the connection state handler deal with this
        }
      };

      AppLogger.i('WebRTC initialized successfully',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('WebRTC initialization failed',
          category: LogCategory.general, error: e);
      // Clean up partial initialization
      await _disposeWebRTC();
      rethrow;
    }
  }

  /// Create and send offer (caller)
  Future<void> _createOffer(String callId) async {
    final peerConnection = _peerConnection;
    if (peerConnection == null) {
      throw Exception('Peer connection not available for creating offer');
    }

    AppLogger.d('📞 Caller: Setting up ICE candidate handler',
        category: LogCategory.general);

    // Handle ICE candidates - must be set before createOffer
    peerConnection.onIceCandidate = (candidate) {
      if (candidate.candidate != null && _peerConnection != null) {
        AppLogger.d('📞 Caller: Sending ICE candidate',
            category: LogCategory.general);
        _sendIceCandidate(callId, 'callerCandidates', candidate);
      }
    };

    // Create offer
    AppLogger.d('📞 Caller: Creating offer...', category: LogCategory.general);
    final offer = await peerConnection.createOffer();

    AppLogger.d('📞 Caller: Setting local description...',
        category: LogCategory.general);
    await peerConnection.setLocalDescription(offer);

    // Save offer to Firestore
    AppLogger.d('📞 Caller: Saving offer to Firestore...',
        category: LogCategory.general);
    await _firestore.collection('calls').doc(callId).update({
      'offer': {
        'sdp': offer.sdp,
        'type': offer.type,
      },
    });

    AppLogger.d('📞 Caller: Offer saved successfully',
        category: LogCategory.general);
  }

  /// Send ICE candidate to Firestore with error handling
  Future<void> _sendIceCandidate(
      String callId, String collection, RTCIceCandidate candidate) async {
    try {
      await _firestore
          .collection('calls')
          .doc(callId)
          .collection(collection)
          .add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    } catch (e) {
      // Log but don't throw - ICE candidate failures shouldn't crash the call
      AppLogger.w('Failed to send ICE candidate: $e',
          category: LogCategory.general);
    }
  }

  // Subscription for answer listener
  StreamSubscription? _answerSubscription;

  // Track if we've already processed the answer
  bool _answerProcessed = false;

  /// Listen for answer (caller)
  void _listenForAnswer(String callId) {
    _answerSubscription?.cancel();
    _answerProcessed = false;

    AppLogger.d('📞 Caller: Listening for answer on call: $callId',
        category: LogCategory.general);

    _answerSubscription =
        _firestore.collection('calls').doc(callId).snapshots().listen(
      (snapshot) async {
        // Handle document not existing
        if (!snapshot.exists) {
          AppLogger.w(
              '📞 Caller: Call document deleted while waiting for answer',
              category: LogCategory.general);
          return;
        }

        final data = snapshot.data();
        if (data == null) return;

        final answerData = data['answer'];
        final peerConnection = _peerConnection;

        // Debug logging
        final signalingState = peerConnection?.signalingState;
        AppLogger.d(
            '📞 Caller: Snapshot update - hasAnswer: ${answerData != null}, '
            'peerConnection: ${peerConnection != null}, signalingState: $signalingState, '
            'answerProcessed: $_answerProcessed',
            category: LogCategory.general);

        // Skip if already processed the answer
        if (_answerProcessed) {
          return;
        }

        if (answerData != null && peerConnection != null) {
          // Check signaling state - accept both HaveLocalOffer and Stable (in case of race)
          // On web, the state might transition quickly
          final canProcess = signalingState ==
                  RTCSignalingState.RTCSignalingStateHaveLocalOffer ||
              signalingState == RTCSignalingState.RTCSignalingStateStable;

          if (!canProcess) {
            AppLogger.d(
                '📞 Caller: Cannot process answer yet - signalingState: $signalingState',
                category: LogCategory.general);
            return;
          }

          // Mark as processed to prevent duplicate processing
          _answerProcessed = true;

          AppLogger.i('📞 Caller: Answer received, setting remote description',
              category: LogCategory.general);

          try {
            // Only set remote description if we haven't already (check stable state)
            if (signalingState ==
                RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
              await peerConnection.setRemoteDescription(
                RTCSessionDescription(answerData['sdp'], answerData['type']),
              );
              AppLogger.d('📞 Caller: Remote description set successfully',
                  category: LogCategory.general);
            } else {
              AppLogger.d(
                  '📞 Caller: Skipping setRemoteDescription - already stable',
                  category: LogCategory.general);
            }

            // Start listening for ICE candidates from callee (this also sets up our sender)
            _listenForIceCandidates(callId, 'calleeCandidates');

            // Only set to connecting if we're not already connected
            // (tracks may have arrived first and already transitioned us to connected)
            if (_state != CallState.connected) {
              AppLogger.d(
                  '📞 Caller: Setting state to connecting after processing answer (current state: $_state)',
                  category: LogCategory.general);
              _setState(CallState.connecting);
            } else {
              AppLogger.d(
                  '📞 Caller: Already connected (tracks arrived first), keeping connected state',
                  category: LogCategory.general);
            }

            // Cancel the answer subscription since we got the answer
            _answerSubscription?.cancel();
            _answerSubscription = null;
          } catch (e) {
            AppLogger.e('📞 Caller: Error setting remote description',
                category: LogCategory.general, error: e);
            _answerProcessed = false; // Allow retry
            // If setting remote description fails, end the call
            await _cleanup('answer_processing_failed');
          }
        }
      },
      onError: (e) {
        AppLogger.e('📞 Caller: Error listening for answer',
            category: LogCategory.general, error: e);
        // On error, cleanup
        _cleanup('answer_listener_error');
      },
    );
  }

  /// Listen for ICE candidates and also set up sending our own
  void _listenForIceCandidates(String callId, String collection) {
    _listenForIceCandidatesOnly(callId, collection);

    // Also set up sending our candidates - use safe access
    final ourCollection = collection == 'callerCandidates'
        ? 'calleeCandidates'
        : 'callerCandidates';
    final peerConnection = _peerConnection;
    if (peerConnection != null) {
      AppLogger.d(
          '📞 Setting up ICE candidate sender for collection: $ourCollection',
          category: LogCategory.general);
      peerConnection.onIceCandidate = (candidate) {
        if (candidate.candidate != null && _peerConnection != null) {
          AppLogger.d('📞 Sending ICE candidate to $ourCollection',
              category: LogCategory.general);
          _sendIceCandidate(callId, ourCollection, candidate);
        }
      };
    } else {
      AppLogger.w(
          'Cannot set up ICE candidate sender - peer connection is null',
          category: LogCategory.general);
    }
  }

  /// Listen for ICE candidates only (without setting up sender - for when sender is already configured)
  void _listenForIceCandidatesOnly(String callId, String collection) {
    _iceCandidateSubscription?.cancel();
    AppLogger.d('📞 Listening for ICE candidates from: $collection',
        category: LogCategory.general);

    _iceCandidateSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .collection(collection)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );
          AppLogger.d('📞 Received ICE candidate from $collection',
              category: LogCategory.general);
          // Use safe access - peer connection could be disposed
          _peerConnection?.addCandidate(candidate).catchError((e) {
            AppLogger.w('Failed to add ICE candidate: $e',
                category: LogCategory.general);
          });
        }
      }
    });
  }

  /// Reject an incoming call
  Future<void> rejectCall() async {
    if (_currentCall == null) return;

    try {
      await _firestore.collection('calls').doc(_currentCall!.id).update({
        'status': 'rejected',
        'endedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.i('Rejected call from ${_currentCall!.callerName}',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Failed to reject call',
          category: LogCategory.general, error: e);
    } finally {
      await _cleanup('rejectCall');
    }
  }

  /// Miss an incoming call (timeout)
  Future<void> missCall() async {
    if (_currentCall == null) return;

    try {
      await _firestore.collection('calls').doc(_currentCall!.id).update({
        'status': 'missed',
        'endedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.i('Missed call from ${_currentCall!.callerName}',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Failed to mark call as missed',
          category: LogCategory.general, error: e);
    } finally {
      await _cleanup('missCall');
    }
  }

  /// End the current call
  /// If call was never connected (ringing/connecting), marks as 'cancelled'
  /// If call was connected, marks as 'ended'
  Future<void> endCall() async {
    if (_currentCall != null) {
      try {
        // Determine the appropriate status based on call state
        // 'cancelled' = caller hung up before call was answered
        // 'ended' = call was connected and then ended normally
        final wasConnected =
            _callConnectedAt != null || _state == CallState.connected;
        final newStatus = wasConnected ? 'ended' : 'cancelled';

        AppLogger.d(
            'Ending call with status: $newStatus (wasConnected: $wasConnected, state: $_state)',
            category: LogCategory.general);

        await _firestore.collection('calls').doc(_currentCall!.id).update({
          'status': newStatus,
          'endedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        AppLogger.e('Failed to update call status',
            category: LogCategory.general, error: e);
      }
    }

    await _cleanup('endCall');
  }

  /// Listen for call status changes with device awareness
  /// This is critical for 1:1 call synchronization - when one party ends, the other must also end
  void _listenForCallStatus(String callId) {
    _callStatusSubscription?.cancel();

    AppLogger.d('Setting up call status listener for call: $callId',
        category: LogCategory.general);

    _callStatusSubscription =
        _firestore.collection('calls').doc(callId).snapshots().listen(
      (snapshot) async {
        // Handle document deletion - other party might have deleted the call
        if (!snapshot.exists) {
          AppLogger.w('Call document deleted - ending call',
              category: LogCategory.general);
          _handleCallEnded('document_deleted');
          return;
        }

        final data = snapshot.data();
        if (data == null) {
          AppLogger.w('Call document has null data - ending call',
              category: LogCategory.general);
          _handleCallEnded('null_data');
          return;
        }

        final status = data['status'] as String?;
        final answeredByDeviceId = data['answeredByDeviceId'] as String?;
        final answeringDeviceId = data['answeringDeviceId'] as String?;
        final currentDeviceId = await _getDeviceId();
        // Only callee can have "another device" of the same user answer; caller always sees callee's device (different).
        final isCaller = _currentCall != null &&
            _currentUser != null &&
            _currentCall!.callerId == _currentUser!.uid;
        // Explicit callee check: we must be the callee to treat "another device answered" as ending our UI.
        // When _currentUser is null (e.g. auth not ready on web), isCallee is false so caller won't incorrectly end.
        final isCallee = _currentCall != null &&
            _currentUser != null &&
            _currentCall!.calleeId == _currentUser!.uid;

        AppLogger.d(
            'Call status update: $status (answeredBy: $answeredByDeviceId, answering: $answeringDeviceId, currentDevice: $currentDeviceId, isCaller: $isCaller, isCallee: $isCallee, currentState: $_state)',
            category: LogCategory.general);

        // Check for terminal states - call should end for BOTH parties
        if (status == 'ended' ||
            status == 'rejected' ||
            status == 'missed' ||
            status == 'cancelled' ||
            status == 'failed') {
          AppLogger.i('Call ended by remote party (status: $status)',
              category: LogCategory.general);
          _handleCallEnded('remote_$status');
          return;
        }

        // Handle answered state with device awareness
        if (status == 'answered') {
          // "Another device" only applies to CALLEE: we are the callee and a different device of ours answered.
          // Caller always sees answeredByDeviceId = callee's device (different from caller's) — that's normal.
          if (isCallee &&
              answeredByDeviceId != null &&
              answeredByDeviceId != currentDeviceId) {
            AppLogger.i('Call answered by another device: $answeredByDeviceId',
                category: LogCategory.general);
            _showMessageToUser?.call('Call answered on another device');
            _handleCallEnded('answered_by_other_device');
            return;
          }

          // If we answered (or we're caller and callee answered), transition to connecting when ready
          if (_state == CallState.connecting ||
              _state == CallState.ringing ||
              _state == CallState.answering) {
            AppLogger.i('Call was answered!', category: LogCategory.general);
            // State will transition to connected when WebRTC connects
            return;
          }
        }

        // Handle answering state (intermediate) — only relevant for callee (multiple devices)
        if (status == 'answering' && isCallee) {
          if (answeringDeviceId != null &&
              answeringDeviceId != currentDeviceId) {
            // Another device of the same user (callee) is answering
            AppLogger.i('Another device is answering: $answeringDeviceId',
                category: LogCategory.general);
            _showMessageToUser?.call('Another device is answering...');
            // Don't end call yet - wait for final status
          }
        }
      },
      onError: (error) {
        AppLogger.e('Call status listener error',
            category: LogCategory.general, error: error);
        // On error, end the call to prevent stuck state
        _handleCallEnded('listener_error');
      },
    );
  }

  /// Handle call ended - called when remote party ends or status changes to terminal state
  void _handleCallEnded([String? reason]) async {
    if (_isCleaningUp) {
      AppLogger.d(
          'Already cleaning up, skipping handleCallEnded (reason: $reason)',
          category: LogCategory.general);
      return;
    }

    AppLogger.i('Handling call ended (reason: $reason)',
        category: LogCategory.general);
    await _cleanup('callEnded${reason != null ? '_$reason' : ''}');
  }

  // Connection timeout timer
  Timer? _connectionTimeoutTimer;

  /// Start connection timeout - auto-end call if not connected within limit
  void _startConnectionTimeout() {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (_state == CallState.connecting || _state == CallState.ringing) {
        AppLogger.w('Call connection timed out after 45 seconds',
            category: LogCategory.general);
        endCall();
      }
    });
  }

  /// Cancel connection timeout
  void _cancelConnectionTimeout() {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;
  }

  /// Cleanup resources with proper sequencing to prevent memory leaks
  Future<void> _cleanup([String? reason]) async {
    if (_isCleaningUp) {
      AppLogger.d(
          'Cleanup already in progress (reason for new request: $reason)',
          category: LogCategory.general);
      return;
    }
    _isCleaningUp = true;

    AppLogger.i('Starting call cleanup (reason: $reason)',
        category: LogCategory.general);

    // CRITICAL: Set state to ended FIRST so UI can respond immediately
    // This ensures the UI gets notified even if subsequent cleanup steps fail
    _setState(CallState.ended);

    try {
      // Step 1: Cancel all timers first
      _incomingCallTimeoutTimer?.cancel();
      _incomingCallTimeoutTimer = null;
      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = null;

      // Step 2: Cancel all Firestore subscriptions EARLY
      // This prevents duplicate callbacks while we're cleaning up
      try {
        await _callStatusSubscription?.cancel();
      } catch (e) {
        AppLogger.w('Error cancelling call status subscription: $e',
            category: LogCategory.general);
      }
      _callStatusSubscription = null;

      try {
        await _iceCandidateSubscription?.cancel();
      } catch (e) {
        AppLogger.w('Error cancelling ICE candidate subscription: $e',
            category: LogCategory.general);
      }
      _iceCandidateSubscription = null;

      try {
        await _answerSubscription?.cancel();
      } catch (e) {
        AppLogger.w('Error cancelling answer subscription: $e',
            category: LogCategory.general);
      }
      _answerSubscription = null;

      // Step 3: Cancel notification
      if (_currentCall != null) {
        await _cancelCallNotification(_currentCall!.id);
      }

      // Step 3b: If we're the caller, mark call doc as ended/cancelled so it doesn't stay "answered"/"ringing" and block future calls
      if (_currentCall != null &&
          _currentUser != null &&
          _currentCall!.callerId == _currentUser!.uid) {
        try {
          final wasConnected =
              _callConnectedAt != null || _state == CallState.connected;
          await _firestore.collection('calls').doc(_currentCall!.id).update({
            'status': wasConnected ? 'ended' : 'cancelled',
            'endedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          AppLogger.w('Failed to update call status during cleanup: $e',
              category: LogCategory.general);
        }
      }

      // Step 4: Save call history before clearing state
      await _saveCallHistory(reason);

      // Step 5: Dispose WebRTC resources (this has its own proper sequencing)
      await _disposeWebRTC();

      // Step 6: Clear state variables
      _callConnectedAt = null;
      _lastCallStatus = null;
      _currentCall = null;
      _isMuted = false;
      _isCameraOff = false;
      _isSpeakerOn = true;
      _answerProcessed = false;

      AppLogger.i('Call cleanup completed successfully',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Error during cleanup (non-fatal)',
          category: LogCategory.general, error: e);
    }

    // Minimal delay for UI to process ended state before transitioning to idle
    await Future.delayed(const Duration(milliseconds: 100));
    _isCleaningUp = false;
    _setState(CallState.idle);
  }

  /// Save call history to the chat
  Future<void> _saveCallHistory(String? reason) async {
    if (_currentCall == null || _currentUser == null) return;

    final call = _currentCall!;
    final isOutgoing = call.callerId == _currentUser!.uid;

    final wasConnected = _callConnectedAt != null;
    final receiverEndedConnectedCall =
        !isOutgoing && wasConnected && reason == 'endCall';

    if (!isOutgoing && !receiverEndedConnectedCall) {
      return;
    }

    try {
      String callStatus;
      if (_lastCallStatus == 'answered' || wasConnected) {
        callStatus = 'answered';
      } else if (reason?.contains('rejected') == true ||
          reason == 'rejectCall') {
        callStatus = 'rejected';
      } else if (reason?.contains('missed') == true || reason == 'missCall') {
        callStatus = 'missed';
      } else {
        callStatus = wasConnected ? 'answered' : 'cancelled';
      }

      int duration = 0;
      if (wasConnected) {
        duration = DateTime.now().difference(_callConnectedAt!).inSeconds;
      }

      final participants = [call.callerId, call.calleeId]..sort();
      final spaceId = 'dm_${participants.join('_')}';

      final otherUserName = isOutgoing ? call.calleeName : call.callerName;

      AppLogger.i('Saving call history: $callStatus, duration: ${duration}s',
          category: LogCategory.general);

      await _chatService.sendCallMessage(
        spaceId: spaceId,
        callType: call.type == CallType.video ? 'video' : 'voice',
        callStatus: callStatus,
        callDuration: duration,
        isOutgoing: isOutgoing,
        otherUserName: otherUserName,
      );
    } catch (e) {
      AppLogger.e('Failed to save call history',
          category: LogCategory.general, error: e);
    }
  }

  /// Toggle microphone
  Future<bool> toggleMute() async {
    try {
      if (_localStream != null) {
        final audioTracks = _localStream!.getAudioTracks();
        if (audioTracks.isNotEmpty) {
          _isMuted = !_isMuted;
          audioTracks[0].enabled = !_isMuted;
          return true;
        }
      }
      return false;
    } catch (e) {
      AppLogger.e('Failed to toggle mute',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Toggle camera on/off
  /// Works for both voice calls (enabling camera) and video calls (disabling camera)
  Future<bool> toggleCamera() async {
    try {
      if (_localStream == null) {
        AppLogger.w('Cannot toggle camera: no local stream',
            category: LogCategory.general);
        return false;
      }

      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isEmpty) {
        AppLogger.w('Cannot toggle camera: no video tracks available',
            category: LogCategory.general);
        return false;
      }

      _isCameraOff = !_isCameraOff;
      videoTracks[0].enabled = !_isCameraOff;

      AppLogger.i('📹 Camera ${_isCameraOff ? "disabled" : "enabled"}',
          category: LogCategory.general);
      return true;
    } catch (e) {
      AppLogger.e('Failed to toggle camera',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Switch camera (front/back)
  /// On mobile: uses Helper.switchCamera
  /// On web: enumerates devices and switches to next camera
  Future<bool> switchCamera() async {
    try {
      if (_localStream == null) return false;

      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isEmpty) return false;

      if (kIsWeb) {
        // Web: enumerate devices and switch to next camera
        return await _switchCameraWeb();
      } else {
        // Mobile: use native camera switching
        await Helper.switchCamera(videoTracks[0]);
        return true;
      }
    } catch (e) {
      AppLogger.e('Failed to switch camera',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Web-specific camera switching
  /// Enumerates video devices and switches to the next available camera
  Future<bool> _switchCameraWeb() async {
    try {
      // Get all media devices
      final devices = await navigator.mediaDevices.enumerateDevices();

      // Filter to video input devices only
      _videoDevices = devices.where((d) => d.kind == 'videoinput').toList();

      AppLogger.d('📹 Web: Found ${_videoDevices.length} video devices',
          category: LogCategory.general);

      if (_videoDevices.length < 2) {
        AppLogger.w('📹 Web: Only one camera available, cannot switch',
            category: LogCategory.general);
        return false;
      }

      // Move to next device
      _currentVideoDeviceIndex =
          (_currentVideoDeviceIndex + 1) % _videoDevices.length;
      final nextDevice = _videoDevices[_currentVideoDeviceIndex];

      AppLogger.d(
          '📹 Web: Switching to camera: ${nextDevice.label} (${nextDevice.deviceId})',
          category: LogCategory.general);

      // Get new video stream with specific device
      final newStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'deviceId': {'exact': nextDevice.deviceId},
        },
      });

      final newVideoTrack = newStream.getVideoTracks().first;
      final oldVideoTrack = _localStream!.getVideoTracks().first;

      // Replace track in peer connection
      if (_peerConnection != null) {
        final senders = await _peerConnection!.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(newVideoTrack);
            break;
          }
        }
      }

      // Replace track in local stream
      await _localStream!.removeTrack(oldVideoTrack);
      await _localStream!.addTrack(newVideoTrack);

      // Stop old track
      await oldVideoTrack.stop();

      // Notify UI of updated local stream
      onLocalStream?.call(_localStream!);

      AppLogger.i('📹 Web: Camera switched successfully',
          category: LogCategory.general);
      return true;
    } catch (e) {
      AppLogger.e('📹 Web: Failed to switch camera',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Toggle speaker
  Future<bool> toggleSpeaker(bool enabled) async {
    try {
      _isSpeakerOn = enabled;
      await Helper.setSpeakerphoneOn(enabled);
      return true;
    } catch (e) {
      AppLogger.e('Failed to toggle speaker',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Update state and notify listeners
  void _setState(CallState newState) {
    final previousState = _state;
    _state = newState;

    AppLogger.i(
        '📞 Call state changing: $previousState -> $newState (callback set: ${onCallStateChanged != null})',
        category: LogCategory.general);

    // Start connection timeout when call starts connecting/ringing
    if (newState == CallState.ringing || newState == CallState.connecting) {
      _startConnectionTimeout();
    }

    // Cancel timeout and record connected time when connected
    if (newState == CallState.connected) {
      _cancelConnectionTimeout();

      if (_callConnectedAt == null) {
        _callConnectedAt = DateTime.now();
        _lastCallStatus = 'answered';

        // CallKit removed; no native call UI sync needed
      }
    }

    // Cancel timeout on end/idle states
    if (newState == CallState.ended || newState == CallState.idle) {
      _cancelConnectionTimeout();
    }

    // Fire callback - critical for UI updates
    final callback = onCallStateChanged;
    if (callback != null) {
      try {
        callback(newState);
        AppLogger.i('📞 Call state callback fired successfully for: $newState',
            category: LogCategory.general);
      } catch (e) {
        AppLogger.e('Error in onCallStateChanged callback',
            category: LogCategory.general, error: e);
      }
    } else {
      AppLogger.w(
          'onCallStateChanged callback is NULL - UI will not be notified of state: $newState',
          category: LogCategory.general);
    }
  }

  /// Cancel call notification
  Future<void> _cancelCallNotification(String callId) async {
    if (kIsWeb) return; // Local notifications not supported on web
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      final notificationId = _getNotificationIdForCall(callId);
      await localNotifications.cancel(notificationId);
    } catch (e) {
      AppLogger.w('Failed to cancel notification',
          category: LogCategory.general);
    }
  }

  static int _getNotificationIdForCall(String callId) {
    return callId.hashCode.abs() % 2147483647;
  }

  static Future<void> cancelNotificationForCall(String callId) async {
    if (kIsWeb) return; // Local notifications not supported on web
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      final notificationId = _getNotificationIdForCall(callId);
      await localNotifications.cancel(notificationId);
    } catch (e) {
      AppLogger.w('Failed to cancel notification',
          category: LogCategory.general);
    }
  }
}
