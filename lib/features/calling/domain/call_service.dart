import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/services/device_manager.dart';
import 'package:aurogram/shared/models/call.dart';
import 'package:aurogram/features/calling/domain/call/call_signaling.dart';
import 'package:aurogram/features/calling/domain/call/call_webrtc.dart';
import 'package:aurogram/features/calling/domain/call/call_operations.dart';

// Re-export so existing `import 'call_service.dart'` still exposes Call, etc.
export 'package:aurogram/shared/models/call.dart';
export 'package:aurogram/features/calling/domain/call/call_signaling.dart';
export 'package:aurogram/features/calling/domain/call/call_webrtc.dart';
export 'package:aurogram/features/calling/domain/call/call_operations.dart';

/// CallService handles voice/video calls using WebRTC.
///
/// Uses Google's FREE STUN servers for NAT traversal.
/// Firestore for signaling (offer/answer/ICE candidates).
///
/// WebRTC media logic lives in [CallWebRTC].
/// Firestore signaling logic lives in [CallSignaling].
/// Call lifecycle operations live in [CallOperations].
class CallService with CallWebRTC, CallSignaling, CallOperations {
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
  @override
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
  bool _isStartingCallField = false;

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

  // ── Mixin bridge: CallOperations ────────────────────────────────────

  @override
  bool get isStartingCall => _isStartingCallField;
  @override
  set isStartingCall(bool v) => _isStartingCallField = v;

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
    _isStartingCallField = false;
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
        await cancelCallNotification(_currentCall!.id);
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
      await saveCallHistory(reason);

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
}
