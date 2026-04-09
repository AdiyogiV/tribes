import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/features/profile/domain/follow_service.dart';
import 'package:aurogram/shared/models/call.dart';

/// Mixin that handles the call lifecycle operations:
/// start, answer, reject, miss, end, call history, and notifications.
///
/// The host class must provide:
///   - [firestore] Firestore instance
///   - [currentUserId] current user's UID (nullable)
///   - [callState], [setCallState] for state transitions
///   - [currentCallField] the current Call object
///   - [callConnectedAt], [lastCallStatus] for tracking
///   - [isCleaningUp], [isStartingCall] flags
///   - [onIncomingCall] callback
///   - [getDeviceId] device id helper
///   - [cleanupCall] full cleanup path
///   - WebRTC: [initializeWebRTC], [peerConnectionForSignaling]
///   - Signaling: [createOffer], [listenForAnswer], [listenForCallStatus],
///     [listenForIceCandidatesOnly], [sendIceCandidate], [waitForOffer],
///     [incomingCallTimeoutTimer], [cancelSignalingSubscriptions]
mixin CallOperations {
  // ── Abstract hooks into the host class ──────────────────────────────

  FirebaseFirestore get firestore;
  String? get currentUserId;
  CallState get callState;
  void setCallState(CallState s);
  Call? get currentCallField;
  set currentCallField(Call? v);
  DateTime? get callConnectedAt;
  set callConnectedAt(DateTime? v);
  String? get lastCallStatus;
  set lastCallStatus(String? v);
  bool get isCleaningUp;
  bool get isStartingCall;
  set isStartingCall(bool v);
  bool get isInCall;
  Future<String> getDeviceId();
  Future<void> cleanupCall([String? reason]);
  Function(String message)? get showMessageToUser;

  // WebRTC hooks
  Future<void> initializeWebRTC({bool startWithCameraOff = false});
  RTCPeerConnection? get peerConnectionForSignaling;

  // Signaling hooks
  Future<void> createOffer(String callId);
  void listenForAnswer(String callId);
  void listenForCallStatus(String callId);
  void listenForIceCandidatesOnly(String callId, String collection);
  Future<void> sendIceCandidate(
      String callId, String collection, RTCIceCandidate candidate);
  Future<Map<String, dynamic>?> waitForOffer(String callId,
      {int maxWaitSeconds = 5});
  Timer? get incomingCallTimeoutTimer;
  set incomingCallTimeoutTimer(Timer? v);

  // ── Fields owned by this mixin ─────────────────────────────────────

  final SpaceChatService _chatService = SpaceChatService();

  // ── Call operations ─────────────────────────────────────────────────

  /// Start an outgoing call with deduplication
  Future<bool> startCall({
    required String calleeId,
    required String calleeName,
    String? calleeAvatar,
    required CallType type,
  }) async {
    if (isStartingCall) {
      AppLogger.w('Cannot start call: another call is being started',
          category: LogCategory.general);
      return false;
    }

    if (currentUserId == null) {
      AppLogger.w('Cannot start call: user is null',
          category: LogCategory.general);
      return false;
    }

    if (calleeId == currentUserId) {
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

    if (isInCall || callState != CallState.idle) {
      AppLogger.w(
          'Cannot start call: already in call (state: $callState)',
          category: LogCategory.general);
      return false;
    }

    isStartingCall = true;

    try {
      // Check for existing in-progress calls
      final existingCalls = await firestore
          .collection('calls')
          .where('callerId', isEqualTo: currentUserId)
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
          currentCallField = existingCall;
          setCallState(CallState.ringing);
          isStartingCall = false;

          listenForAnswer(existingCall.id);
          listenForCallStatus(existingCall.id);

          return true;
        }
      }

      setCallState(CallState.ringing);

      final callerDoc =
          await firestore.collection('users').doc(currentUserId).get();
      final callerData = callerDoc.data() ?? {};
      final callerName =
          callerData['name'] ?? callerData['nickname'] ?? 'Unknown';
      final callerAvatar = callerData['displayPicture'];

      final callRef = firestore.collection('calls').doc();
      final deviceId = await getDeviceId();

      final call = Call(
        id: callRef.id,
        callerId: currentUserId!,
        callerName: callerName,
        callerAvatar: callerAvatar,
        calleeId: calleeId,
        calleeName: calleeName,
        calleeAvatar: calleeAvatar,
        type: type,
        createdAt: DateTime.now(),
        status: 'ringing',
      );

      currentCallField = call;

      await firestore.runTransaction((transaction) async {
        final recentCalls = await firestore
            .collection('calls')
            .where('callerId', isEqualTo: currentUserId)
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

      isStartingCall = false;
      return true;
    } catch (e) {
      AppLogger.e('Failed to start call',
          category: LogCategory.general, error: e);
      isStartingCall = false;
      await cleanupCall('start_failed');
      return false;
    }
  }

  /// Answer an incoming call with atomic transaction to prevent race conditions
  Future<bool> answerCall() async {
    final call = currentCallField;
    if (call == null || callState != CallState.incoming) {
      AppLogger.w(
          'Cannot answer call: no current call or wrong state (state: $callState)',
          category: LogCategory.general);
      return false;
    }

    try {
      incomingCallTimeoutTimer?.cancel();
      incomingCallTimeoutTimer = null;

      setCallState(CallState.answering);

      AppLogger.d('📞 Answering call: ${call.id}',
          category: LogCategory.general);

      final callRef = firestore.collection('calls').doc(call.id);
      final deviceId = await getDeviceId();

      Map<String, dynamic>? offerData;

      try {
        final result = await firestore.runTransaction((transaction) async {
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
          await cleanupCall('answered_by_other_device');
          showMessageToUser?.call('Call was answered on another device');
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

      final pc = peerConnectionForSignaling;
      if (pc == null) {
        throw Exception('Peer connection not initialized');
      }

      // Set up ICE candidate handler BEFORE creating answer
      AppLogger.d('📞 Setting up ICE candidate handler for callee...',
          category: LogCategory.general);
      pc.onIceCandidate = (candidate) {
        if (candidate.candidate != null &&
            peerConnectionForSignaling != null) {
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
      await firestore.runTransaction((transaction) async {
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

      if (callState != CallState.connected) {
        setCallState(CallState.connecting);
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
        await cleanupCall('call_unavailable');
      } else {
        await rejectCall();
      }
      return false;
    }
  }

  /// Reject an incoming call
  Future<void> rejectCall() async {
    if (currentCallField == null) return;

    try {
      await firestore.collection('calls').doc(currentCallField!.id).update({
        'status': 'rejected',
        'endedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.i('Rejected call from ${currentCallField!.callerName}',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Failed to reject call',
          category: LogCategory.general, error: e);
    } finally {
      await cleanupCall('rejectCall');
    }
  }

  /// Miss an incoming call (timeout)
  Future<void> missCall() async {
    if (currentCallField == null) return;

    try {
      await firestore.collection('calls').doc(currentCallField!.id).update({
        'status': 'missed',
        'endedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.i('Missed call from ${currentCallField!.callerName}',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Failed to mark call as missed',
          category: LogCategory.general, error: e);
    } finally {
      await cleanupCall('missCall');
    }
  }

  /// End the current call.
  /// If call was never connected, marks as 'cancelled'.
  /// If call was connected, marks as 'ended'.
  Future<void> endCall() async {
    if (currentCallField != null) {
      try {
        final wasConnected =
            callConnectedAt != null || callState == CallState.connected;
        final newStatus = wasConnected ? 'ended' : 'cancelled';

        AppLogger.d(
            'Ending call with status: $newStatus (wasConnected: $wasConnected, state: $callState)',
            category: LogCategory.general);

        await firestore.collection('calls').doc(currentCallField!.id).update({
          'status': newStatus,
          'endedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        AppLogger.e('Failed to update call status',
            category: LogCategory.general, error: e);
      }
    }

    await cleanupCall('endCall');
  }

  // ── Call history ────────────────────────────────────────────────────

  /// Save call history to the chat
  Future<void> saveCallHistory(String? reason) async {
    if (currentCallField == null || currentUserId == null) return;

    final call = currentCallField!;
    final isOutgoing = call.callerId == currentUserId;

    final wasConnected = callConnectedAt != null;
    final receiverEndedConnectedCall =
        !isOutgoing && wasConnected && reason == 'endCall';

    if (!isOutgoing && !receiverEndedConnectedCall) {
      return;
    }

    try {
      String callStatus;
      if (lastCallStatus == 'answered' || wasConnected) {
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
        duration = DateTime.now().difference(callConnectedAt!).inSeconds;
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

  // ── Notifications ───────────────────────────────────────────────────

  /// Cancel call notification
  Future<void> cancelCallNotification(String callId) async {
    if (kIsWeb) return;
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      final notificationId = getNotificationIdForCall(callId);
      await localNotifications.cancel(notificationId);
    } catch (e) {
      AppLogger.w('Failed to cancel notification',
          category: LogCategory.general);
    }
  }

  static int getNotificationIdForCall(String callId) {
    return callId.hashCode.abs() % 2147483647;
  }

  static Future<void> cancelNotificationForCall(String callId) async {
    if (kIsWeb) return;
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      final notificationId = getNotificationIdForCall(callId);
      await localNotifications.cancel(notificationId);
    } catch (e) {
      AppLogger.w('Failed to cancel notification',
          category: LogCategory.general);
    }
  }
}
