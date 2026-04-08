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
import 'package:aurogram/models/call.dart';
import 'package:aurogram/services/call/call_signaling.dart';
import 'package:aurogram/services/call/call_webrtc.dart';

// Re-export so existing `import 'call_service.dart'` still exposes Call, etc.
export 'package:aurogram/models/call.dart';
export 'package:aurogram/services/call/call_signaling.dart';
export 'package:aurogram/services/call/call_webrtc.dart';

/// CallService handles voice/video calls using WebRTC.
///
/// Uses Google's FREE STUN servers for NAT traversal.
/// Firestore for signaling (offer/answer/ICE candidates).
///
/// WebRTC media logic lives in [CallWebRTC].
/// Firestore signaling logic lives in [CallSignaling].
class CallService with CallWebRTC, CallSignaling {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State
  CallState _state = CallState.idle;
  Call? _currentCall;
  StreamSubscription? _authStateSubscription;
  bool _isCleaningUp = false;

  // Call history tracking
  DateTime? _callConnectedAt;
  String? _lastCallStatus;
  final SpaceChatService _chatService = SpaceChatService();

  // Callbacks
  Function(CallState state)? onCallStateChanged;
  Function(Call call)? _onIncomingCall;
  Function(MediaStream stream)? _onLocalStream;
  Function(MediaStream stream)? _onRemoteStream;

  // Permission error callback
  Function(String error)? _onPermissionError;

  // Callback for showing messages to user (set by UI)
  Function(String message)? _showMessageToUser;

  // Getters
  User? get _currentUser => _auth.currentUser;
  CallState get state => _state;
  Call? get currentCall => _currentCall;
  bool get isInCall =>
      _state == CallState.connected || _state == CallState.connecting;
  MediaStream? get localStream => localStreamField;
  MediaStream? get remoteStream => remoteStreamField;

  // Mute state getters (delegated to CallWebRTC mixin)
  bool get isMuted => isMutedField;
  bool get isCameraOff => isCameraOffField;
  bool get isSpeakerOn => isSpeakerOnField;

  // Timer for connection timeout
  Timer? _connectionTimeoutTimer;

  // Lock to prevent concurrent call operations
  bool _isStartingCall = false;

  // Cached device ID
  String? _cachedDeviceId;

  // ── Callback setters (public API) ───────────────────────────────────

  set onIncomingCallCallback(Function(Call call)? cb) => _onIncomingCall = cb;
  set onLocalStreamCallback(Function(MediaStream stream)? cb) =>
      _onLocalStream = cb;
  set onRemoteStreamCallback(Function(MediaStream stream)? cb) =>
      _onRemoteStream = cb;
  set onPermissionErrorCallback(Function(String error)? cb) =>
      _onPermissionError = cb;

  // Preserve the old field-style API so existing code keeps working
  @override
  Function(Call call)? get onIncomingCall => _onIncomingCall;
  set onIncomingCall(Function(Call call)? cb) => _onIncomingCall = cb;

  @override
  Function(MediaStream stream)? get onLocalStream => _onLocalStream;
  set onLocalStream(Function(MediaStream stream)? cb) => _onLocalStream = cb;

  @override
  Function(MediaStream stream)? get onRemoteStream => _onRemoteStream;
  set onRemoteStream(Function(MediaStream stream)? cb) => _onRemoteStream = cb;

  @override
  Function(String error)? get onPermissionError => _onPermissionError;
  set onPermissionError(Function(String error)? cb) => _onPermissionError = cb;

  /// Set callback for showing user messages
  void setMessageCallback(Function(String message)? callback) {
    _showMessageToUser = callback;
  }

  // ── Mixin bridge: CallWebRTC ────────────────────────────────────────

  @override
  CallState get callState => _state;
  @override
  void setCallState(CallState s) => _setState(s);
  @override
  DateTime? get callConnectedAt => _callConnectedAt;
  @override
  set callConnectedAt(DateTime? v) => _callConnectedAt = v;
  @override
  String? get lastCallStatus => _lastCallStatus;
  @override
  set lastCallStatus(String? v) => _lastCallStatus = v;
  @override
  bool get isCleaningUp => _isCleaningUp;
  @override
  void handleCallEnded([String? reason]) => _handleCallEnded(reason);

  // ── Mixin bridge: CallSignaling ─────────────────────────────────────

  @override
  FirebaseFirestore get firestore => _firestore;
  @override
  String? get currentUserId => _currentUser?.uid;
  @override
  RTCPeerConnection? get peerConnectionForSignaling => peerConnection;
  @override
  Call? get currentCallField => _currentCall;
  @override
  set currentCallField(Call? v) => _currentCall = v;
  @override
  Function(String message)? get showMessageToUser => _showMessageToUser;
  @override
  Future<String> getDeviceId() async {
    _cachedDeviceId ??= await DeviceManager.getDeviceId();
    return _cachedDeviceId!;
  }

  @override
  Future<void> cleanupCall([String? reason]) => _cleanup(reason);

  // ── Lifecycle ───────────────────────────────────────────────────────

  /// Force reset state to idle (use when state gets stuck)
  Future<void> forceResetState() async {
    AppLogger.w('Force resetting call state from $_state to idle',
        category: LogCategory.general);

    incomingCallTimeoutTimer?.cancel();
    incomingCallTimeoutTimer = null;
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;

    await callStatusSubscription?.cancel();
    callStatusSubscription = null;

    await iceCandidateSubscription?.cancel();
    iceCandidateSubscription = null;

    await answerSubscription?.cancel();
    answerSubscription = null;

    await disposeWebRTC();

    _currentCall = null;
    _isCleaningUp = false;
    _isStartingCall = false;
    answerProcessed = false;
    _setState(CallState.idle);
  }

  /// Initialize the call service
  Future<void> initialize() async {
    try {
      AppLogger.i('📞 CallService.initialize() starting (isWeb: $kIsWeb)',
          category: LogCategory.general,
          data: {'isWeb': kIsWeb, 'currentUser': _currentUser?.uid});

      // Listen for incoming calls (delegated to CallSignaling mixin)
      listenForIncomingCalls();

      // Listen for auth state changes with proper cleanup on account switch
      _authStateSubscription?.cancel();
      User? previousUser = _currentUser;

      _authStateSubscription = _auth.authStateChanges().listen((user) async {
        final prev = previousUser;
        previousUser = user;

        AppLogger.i('📞 Auth state changed in CallService (isWeb: $kIsWeb)',
            category: LogCategory.general,
            data: {
              'hasUser': user != null,
              'userId': user?.uid,
              'previousUserId': prev?.uid,
              'hasSubscription': incomingCallSubscription != null
            });

        if (prev != null && (user == null || user.uid != prev.uid)) {
          AppLogger.i(
              '📞 User changed or logged out - cleaning up active call',
              category: LogCategory.general);

          if (_state != CallState.idle && _currentCall != null) {
            try {
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

          await forceResetState();

          await incomingCallSubscription?.cancel();
          incomingCallSubscription = null;

          if (user == null) {
            await DeviceManager.cleanupOnSignOut();
          }
        }

        if (user != null && (prev == null || user.uid != prev.uid)) {
          AppLogger.i('📞 New user logged in - reinitializing call service',
              category: LogCategory.general);
          _cachedDeviceId = null;
          await initialize();
        } else if (user != null && incomingCallSubscription == null) {
          AppLogger.i(
              '📞 Auth state changed - setting up incoming call listener (isWeb: $kIsWeb)',
              category: LogCategory.general);
          listenForIncomingCalls();
        } else if (user == null) {
          AppLogger.i(
              '📞 User logged out - cancelling incoming call listener',
              category: LogCategory.general);
          incomingCallSubscription?.cancel();
          incomingCallSubscription = null;
        }
      });

      AppLogger.i(
          '📞 CallService initialized successfully (WebRTC, isWeb: $kIsWeb)',
          category: LogCategory.general,
          data: {
            'isWeb': kIsWeb,
            'hasIncomingSubscription': incomingCallSubscription != null
          });
    } catch (e) {
      AppLogger.e('📞 Failed to initialize CallService (isWeb: $kIsWeb)',
          category: LogCategory.general, error: e, data: {'isWeb': kIsWeb});
    }
  }

  /// Re-initialize the incoming call listener (call after login)
  void reinitializeListener() {
    AppLogger.i(
        '📞 Reinitializing incoming call listener (isWeb: $kIsWeb)',
        category: LogCategory.general,
        data: {
          'isWeb': kIsWeb,
          'currentUser': _currentUser?.uid,
          'hasExistingSubscription': incomingCallSubscription != null,
          'hasOnIncomingCallback': _onIncomingCall != null,
        });
    listenForIncomingCalls();
  }

  /// Dispose resources
  Future<void> dispose() async {
    AppLogger.d('Disposing CallService', category: LogCategory.general);

    incomingCallTimeoutTimer?.cancel();
    _connectionTimeoutTimer?.cancel();

    await incomingCallSubscription?.cancel();
    incomingCallSubscription = null;
    await _authStateSubscription?.cancel();
    _authStateSubscription = null;

    await cancelSignalingSubscriptions();

    await disposeWebRTC();

    onCallStateChanged = null;
    _onIncomingCall = null;
    _onLocalStream = null;
    _onRemoteStream = null;
  }

  // ── Call operations ─────────────────────────────────────────────────

  /// Start an outgoing call with deduplication
  Future<bool> startCall({
    required String calleeId,
    required String calleeName,
    String? calleeAvatar,
    required CallType type,
  }) async {
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

      // Check for existing in-progress calls
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

          listenForAnswer(existingCall.id);
          listenForCallStatus(existingCall.id);

          return true;
        }
      }

      _setState(CallState.ringing);

      final callerDoc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();
      final callerData = callerDoc.data() ?? {};
      final callerName =
          callerData['name'] ?? callerData['nickname'] ?? 'Unknown';
      final callerAvatar = callerData['displayPicture'];

      final callRef = _firestore.collection('calls').doc();
      final deviceId = await getDeviceId();

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

      await _firestore.runTransaction((transaction) async {
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

      // Initialize WebRTC
      try {
        await initializeWebRTC(startWithCameraOff: type == CallType.voice);
      } catch (webrtcError) {
        AppLogger.e('WebRTC initialization failed during call start',
            category: LogCategory.general, error: webrtcError);
        await callRef.update({'status': 'failed'});
        rethrow;
      }

      // Create and send offer
      await createOffer(callRef.id);

      // Listen for answer & status
      listenForAnswer(callRef.id);
      listenForCallStatus(callRef.id);

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
      incomingCallTimeoutTimer?.cancel();
      incomingCallTimeoutTimer = null;

      _isCleaningUp = false;
      _setState(CallState.answering);

      AppLogger.d('📞 Answering call: ${call.id}',
          category: LogCategory.general);

      final callRef = _firestore.collection('calls').doc(call.id);
      final deviceId = await getDeviceId();

      Map<String, dynamic>? offerData;

      try {
        final result = await _firestore.runTransaction((transaction) async {
          final callDoc = await transaction.get(callRef);

          if (!callDoc.exists) {
            throw Exception('Call no longer exists');
          }

          final data = callDoc.data()!;
          final currentStatus = data['status'] as String?;

          if (currentStatus != 'ringing' && currentStatus != 'answering') {
            throw Exception(
                'Call already answered or ended (status: $currentStatus)');
          }

          final answeringDeviceId = data['answeringDeviceId'] as String?;
          if (answeringDeviceId != null && answeringDeviceId != deviceId) {
            final answeringTimestamp = data['answeringTimestamp'] as Timestamp?;
            if (answeringTimestamp != null) {
              final timeSinceAnswering =
                  DateTime.now().difference(answeringTimestamp.toDate());
              if (timeSinceAnswering.inSeconds < 3) {
                throw Exception('Another device is answering this call');
              }
            }
          }

          transaction.update(callRef, {
            'answeringDeviceId': deviceId,
            'answeringTimestamp': FieldValue.serverTimestamp(),
            'status': 'answering',
          });

          return data['offer'] as Map<String, dynamic>?;
        });

        offerData = result;
      } catch (e) {
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

      if (offerData == null) {
        offerData = await waitForOffer(call.id, maxWaitSeconds: 5);
        if (offerData == null) {
          try {
            await callRef.update({
              'answeringDeviceId': FieldValue.delete(),
              'answeringTimestamp': FieldValue.delete(),
              'status': 'ringing',
            });
          } catch (_) {
            AppLogger.w('CallService: failed to reset answering state',
                category: LogCategory.general);
          }
          throw Exception('Offer not available');
        }
      }

      // Initialize WebRTC
      AppLogger.d('📞 Initializing WebRTC...', category: LogCategory.general);
      await initializeWebRTC(startWithCameraOff: call.isVoice);

      final pc = peerConnection;
      if (pc == null) {
        throw Exception('Peer connection not initialized');
      }

      // Set up ICE candidate handler BEFORE creating answer
      AppLogger.d('📞 Setting up ICE candidate handler for callee...',
          category: LogCategory.general);
      pc.onIceCandidate = (candidate) {
        if (candidate.candidate != null && peerConnection != null) {
          AppLogger.d('📞 Callee: Sending ICE candidate',
              category: LogCategory.general);
          sendIceCandidate(call.id, 'calleeCandidates', candidate);
        }
      };

      // Set remote description (the offer)
      AppLogger.d('📞 Setting remote description (offer)...',
          category: LogCategory.general);
      await pc.setRemoteDescription(
        RTCSessionDescription(offerData['sdp'], offerData['type']),
      );

      // Create and send answer
      AppLogger.d('📞 Creating answer...', category: LogCategory.general);
      final answer = await pc.createAnswer();

      AppLogger.d('📞 Setting local description (answer)...',
          category: LogCategory.general);
      await pc.setLocalDescription(answer);

      // Finalize answer with another transaction
      await _firestore.runTransaction((transaction) async {
        final callDoc = await transaction.get(callRef);
        if (!callDoc.exists) {
          throw Exception('Call no longer exists');
        }

        final data = callDoc.data()!;
        final answeringDeviceId = data['answeringDeviceId'] as String?;

        if (answeringDeviceId != null && answeringDeviceId != deviceId) {
          throw Exception('Call answered by another device');
        }

        transaction.update(callRef, {
          'status': 'answered',
          'answeredAt': FieldValue.serverTimestamp(),
          'answeredByDeviceId': deviceId,
          'answer': {
            'sdp': answer.sdp,
            'type': answer.type,
          },
          'answeringDeviceId': FieldValue.delete(),
          'answeringTimestamp': FieldValue.delete(),
        });
      });

      if (_state != CallState.connected) {
        _setState(CallState.connecting);
      }

      // Listen for ICE candidates from caller
      listenForIceCandidatesOnly(call.id, 'callerCandidates');

      // Listen for call status changes
      listenForCallStatus(call.id);

      AppLogger.i('📞 Successfully answered call from ${call.callerName}',
          category: LogCategory.general);

      return true;
    } catch (e) {
      AppLogger.e('Failed to answer call',
          category: LogCategory.general, error: e);
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
  @override
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

  /// End the current call.
  /// If call was never connected, marks as 'cancelled'.
  /// If call was connected, marks as 'ended'.
  Future<void> endCall() async {
    if (_currentCall != null) {
      try {
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

  // ── Internal helpers ────────────────────────────────────────────────

  /// Handle call ended
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

  /// Start connection timeout
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

  /// Cleanup resources with proper sequencing
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

    // Set state to ended FIRST so UI can respond immediately
    _setState(CallState.ended);

    try {
      // Step 1: Cancel all timers
      incomingCallTimeoutTimer?.cancel();
      incomingCallTimeoutTimer = null;
      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = null;

      // Step 2: Cancel all Firestore subscriptions
      await cancelSignalingSubscriptions();

      // Step 3: Cancel notification
      if (_currentCall != null) {
        await _cancelCallNotification(_currentCall!.id);
      }

      // Step 3b: Mark call doc as ended/cancelled if we're the caller
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

      // Step 4: Save call history
      await _saveCallHistory(reason);

      // Step 5: Dispose WebRTC resources
      await disposeWebRTC();

      // Step 6: Clear state variables
      _callConnectedAt = null;
      _lastCallStatus = null;
      _currentCall = null;
      isMutedField = false;
      isCameraOffField = false;
      isSpeakerOnField = true;
      answerProcessed = false;

      AppLogger.i('Call cleanup completed successfully',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Error during cleanup (non-fatal)',
          category: LogCategory.general, error: e);
    }

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

  /// Update state and notify listeners
  void _setState(CallState newState) {
    final previousState = _state;
    _state = newState;

    AppLogger.i(
        '📞 Call state changing: $previousState -> $newState (callback set: ${onCallStateChanged != null})',
        category: LogCategory.general);

    if (newState == CallState.ringing || newState == CallState.connecting) {
      _startConnectionTimeout();
    }

    if (newState == CallState.connected) {
      _cancelConnectionTimeout();

      if (_callConnectedAt == null) {
        _callConnectedAt = DateTime.now();
        _lastCallStatus = 'answered';
      }
    }

    if (newState == CallState.ended || newState == CallState.idle) {
      _cancelConnectionTimeout();
    }

    final callback = onCallStateChanged;
    if (callback != null) {
      try {
        callback(newState);
        AppLogger.i(
            '📞 Call state callback fired successfully for: $newState',
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

  // ── Notifications ───────────────────────────────────────────────────

  /// Cancel call notification
  Future<void> _cancelCallNotification(String callId) async {
    if (kIsWeb) return;
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
    if (kIsWeb) return;
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
