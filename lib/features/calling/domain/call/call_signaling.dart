import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/models/call.dart';

/// Mixin that handles Firestore signaling for WebRTC calls:
/// offer/answer exchange, ICE candidate relay, and call-status listeners.
///
/// The host class must provide:
///   - [firestore] Firestore instance
///   - [currentUserId] current user's UID (nullable)
///   - [peerConnectionForSignaling] the active RTCPeerConnection
///   - [callState], [setCallState] for state transitions
///   - [currentCallField] the current Call object
///   - [callConnectedAt], [lastCallStatus] for tracking
///   - [isCleaningUp] flag
///   - [onIncomingCall] callback
///   - [showMessageToUser] callback
///   - [getDeviceId] device id helper
///   - [cleanupCall] full cleanup path
///   - [handleCallEnded] lighter ended handler
///   - [missCall] miss-call handler
mixin CallSignaling {
  // ── Abstract hooks into the host class ──────────────────────────────

  FirebaseFirestore get firestore;
  String? get currentUserId;
  RTCPeerConnection? get peerConnectionForSignaling;
  CallState get callState;
  void setCallState(CallState s);
  Call? get currentCallField;
  set currentCallField(Call? v);
  DateTime? get callConnectedAt;
  set callConnectedAt(DateTime? v);
  String? get lastCallStatus;
  set lastCallStatus(String? v);
  bool get isCleaningUp;
  Function(Call call)? get onIncomingCall;
  Function(String message)? get showMessageToUser;
  Future<String> getDeviceId();
  Future<void> cleanupCall([String? reason]);
  void handleCallEnded([String? reason]);
  Future<void> missCall();

  // ── Subscriptions owned by this mixin ───────────────────────────────

  StreamSubscription? incomingCallSubscription;
  StreamSubscription? callStatusSubscription;
  StreamSubscription? iceCandidateSubscription;
  StreamSubscription? answerSubscription;

  // Track whether we already processed the answer (caller side)
  bool answerProcessed = false;

  // Timer for incoming call timeout
  Timer? incomingCallTimeoutTimer;

  // ── Incoming call listener ──────────────────────────────────────────

  /// Listen for incoming calls via Firestore query on callee's ID.
  void listenForIncomingCalls() {
    incomingCallSubscription?.cancel();
    incomingCallSubscription = null;

    if (currentUserId == null) {
      AppLogger.w(
          '📞 Cannot listen for incoming calls: user not logged in',
          category: LogCategory.general);
      return;
    }

    final userId = currentUserId!;
    AppLogger.i(
        '📞 Setting up incoming call Firestore listener for user: $userId',
        category: LogCategory.general,
        data: {'userId': userId});

    incomingCallSubscription = firestore
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
                  'currentState': callState.toString(),
                  'hasOnIncomingCallback': onIncomingCall != null,
                });

            if (callState == CallState.idle) {
              AppLogger.i(
                  '📞 Processing incoming call - state is idle, will trigger onIncomingCall callback',
                  category: LogCategory.general);
              handleIncomingCall(call);
            } else {
              AppLogger.w(
                  '📞 Ignoring incoming call - already in call state: $callState',
                  category: LogCategory.general,
                  data: {'currentState': callState.toString()});
            }
          }
        }
      },
      onError: (error) {
        AppLogger.e('📞 Error in incoming call listener',
            category: LogCategory.general, error: error);
        Future.delayed(const Duration(seconds: 5), () {
          if (currentUserId != null && incomingCallSubscription == null) {
            AppLogger.i('📞 Retrying incoming call listener setup',
                category: LogCategory.general);
            listenForIncomingCalls();
          }
        });
      },
    );

    AppLogger.i(
        '📞 Incoming call Firestore listener active for user: $userId',
        category: LogCategory.general,
        data: {
          'userId': userId,
          'subscriptionActive': incomingCallSubscription != null
        });
  }

  /// Handle an incoming call.
  void handleIncomingCall(Call call) async {
    AppLogger.i('📞 _handleIncomingCall starting',
        category: LogCategory.general,
        data: {
          'callId': call.id,
          'callerName': call.callerName,
          'callType': call.type.toString(),
          'hasOnIncomingCallback': onIncomingCall != null,
        });

    currentCallField = call;
    setCallState(CallState.incoming);

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

    listenForCallStatusAsReceiver(call.id);

    incomingCallTimeoutTimer?.cancel();
    incomingCallTimeoutTimer = Timer(const Duration(seconds: 60), () {
      if (callState == CallState.incoming) {
        AppLogger.w('📞 Incoming call timed out (60s without response)',
            category: LogCategory.general);
        missCall();
      }
    });

    AppLogger.i(
        '📞 Incoming ${call.type.name} call from ${call.callerName} - handler complete',
        category: LogCategory.general);
  }

  /// Public method to set up an incoming call from notification tap.
  void setupIncomingCall(Call call) {
    if (callState != CallState.idle || currentCallField != null) {
      AppLogger.d('CallService already has a call, skipping setup',
          category: LogCategory.general);
      return;
    }

    AppLogger.i(
        'Setting up incoming call from notification: ${call.callerName}',
        category: LogCategory.general);
    handleIncomingCall(call);
  }

  // ── Receiver-side status listener ───────────────────────────────────

  /// Listen for call status changes as the receiver (before answering).
  void listenForCallStatusAsReceiver(String callId) {
    callStatusSubscription?.cancel();

    AppLogger.d('Setting up receiver status listener for call: $callId',
        category: LogCategory.general);

    callStatusSubscription =
        firestore.collection('calls').doc(callId).snapshots().listen(
      (snapshot) {
        if (!snapshot.exists) {
          AppLogger.w('Call document deleted while ringing',
              category: LogCategory.general);
          cleanupCall('call_deleted');
          return;
        }

        final data = snapshot.data();
        if (data == null) {
          AppLogger.w('Call document has null data while ringing',
              category: LogCategory.general);
          cleanupCall('call_deleted');
          return;
        }

        final status = data['status'] as String?;
        AppLogger.d('Receiver status update: $status',
            category: LogCategory.general);

        if (status == 'ended' ||
            status == 'missed' ||
            status == 'cancelled' ||
            status == 'failed') {
          AppLogger.i('Caller ended call while ringing (status: $status)',
              category: LogCategory.general);
          cleanupCall('caller_ended_$status');
        }
      },
      onError: (error) {
        AppLogger.e('Receiver status listener error',
            category: LogCategory.general, error: error);
        cleanupCall('listener_error');
      },
    );
  }

  // ── Offer / Answer exchange ─────────────────────────────────────────

  /// Create and send offer (caller side).
  Future<void> createOffer(String callId) async {
    final pc = peerConnectionForSignaling;
    if (pc == null) {
      throw Exception('Peer connection not available for creating offer');
    }

    AppLogger.d('📞 Caller: Setting up ICE candidate handler',
        category: LogCategory.general);

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null &&
          peerConnectionForSignaling != null) {
        AppLogger.d('📞 Caller: Sending ICE candidate',
            category: LogCategory.general);
        sendIceCandidate(callId, 'callerCandidates', candidate);
      }
    };

    AppLogger.d('📞 Caller: Creating offer...',
        category: LogCategory.general);
    final offer = await pc.createOffer();

    AppLogger.d('📞 Caller: Setting local description...',
        category: LogCategory.general);
    await pc.setLocalDescription(offer);

    AppLogger.d('📞 Caller: Saving offer to Firestore...',
        category: LogCategory.general);
    await firestore.collection('calls').doc(callId).update({
      'offer': {
        'sdp': offer.sdp,
        'type': offer.type,
      },
    });

    AppLogger.d('📞 Caller: Offer saved successfully',
        category: LogCategory.general);
  }

  /// Send ICE candidate to Firestore with error handling.
  Future<void> sendIceCandidate(
      String callId, String collection, RTCIceCandidate candidate) async {
    try {
      await firestore
          .collection('calls')
          .doc(callId)
          .collection(collection)
          .add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    } catch (e) {
      AppLogger.w('Failed to send ICE candidate: $e',
          category: LogCategory.general);
    }
  }

  /// Wait for offer to be available in call document.
  Future<Map<String, dynamic>?> waitForOffer(String callId,
      {int maxWaitSeconds = 5}) async {
    final callRef = firestore.collection('calls').doc(callId);
    const maxAttempts = 10;

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

  /// Listen for answer (caller side).
  void listenForAnswer(String callId) {
    answerSubscription?.cancel();
    answerProcessed = false;

    AppLogger.d('📞 Caller: Listening for answer on call: $callId',
        category: LogCategory.general);

    answerSubscription =
        firestore.collection('calls').doc(callId).snapshots().listen(
      (snapshot) async {
        if (!snapshot.exists) {
          AppLogger.w(
              '📞 Caller: Call document deleted while waiting for answer',
              category: LogCategory.general);
          return;
        }

        final data = snapshot.data();
        if (data == null) return;

        final answerData = data['answer'];
        final pc = peerConnectionForSignaling;

        final signalingState = pc?.signalingState;
        AppLogger.d(
            '📞 Caller: Snapshot update - hasAnswer: ${answerData != null}, '
            'peerConnection: ${pc != null}, signalingState: $signalingState, '
            'answerProcessed: $answerProcessed',
            category: LogCategory.general);

        if (answerProcessed) return;

        if (answerData != null && pc != null) {
          final canProcess = signalingState ==
                  RTCSignalingState.RTCSignalingStateHaveLocalOffer ||
              signalingState == RTCSignalingState.RTCSignalingStateStable;

          if (!canProcess) {
            AppLogger.d(
                '📞 Caller: Cannot process answer yet - signalingState: $signalingState',
                category: LogCategory.general);
            return;
          }

          answerProcessed = true;

          AppLogger.i(
              '📞 Caller: Answer received, setting remote description',
              category: LogCategory.general);

          try {
            if (signalingState ==
                RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
              await pc.setRemoteDescription(
                RTCSessionDescription(answerData['sdp'], answerData['type']),
              );
              AppLogger.d(
                  '📞 Caller: Remote description set successfully',
                  category: LogCategory.general);
            } else {
              AppLogger.d(
                  '📞 Caller: Skipping setRemoteDescription - already stable',
                  category: LogCategory.general);
            }

            listenForIceCandidates(callId, 'calleeCandidates');

            if (callState != CallState.connected) {
              AppLogger.d(
                  '📞 Caller: Setting state to connecting after processing answer (current state: $callState)',
                  category: LogCategory.general);
              setCallState(CallState.connecting);
            } else {
              AppLogger.d(
                  '📞 Caller: Already connected (tracks arrived first), keeping connected state',
                  category: LogCategory.general);
            }

            answerSubscription?.cancel();
            answerSubscription = null;
          } catch (e) {
            AppLogger.e('📞 Caller: Error setting remote description',
                category: LogCategory.general, error: e);
            answerProcessed = false;
            await cleanupCall('answer_processing_failed');
          }
        }
      },
      onError: (e) {
        AppLogger.e('📞 Caller: Error listening for answer',
            category: LogCategory.general, error: e);
        cleanupCall('answer_listener_error');
      },
    );
  }

  // ── ICE candidate listeners ─────────────────────────────────────────

  /// Listen for ICE candidates and also set up sending our own.
  void listenForIceCandidates(String callId, String collection) {
    listenForIceCandidatesOnly(callId, collection);

    final ourCollection = collection == 'callerCandidates'
        ? 'calleeCandidates'
        : 'callerCandidates';
    final pc = peerConnectionForSignaling;
    if (pc != null) {
      AppLogger.d(
          '📞 Setting up ICE candidate sender for collection: $ourCollection',
          category: LogCategory.general);
      pc.onIceCandidate = (candidate) {
        if (candidate.candidate != null &&
            peerConnectionForSignaling != null) {
          AppLogger.d('📞 Sending ICE candidate to $ourCollection',
              category: LogCategory.general);
          sendIceCandidate(callId, ourCollection, candidate);
        }
      };
    } else {
      AppLogger.w(
          'Cannot set up ICE candidate sender - peer connection is null',
          category: LogCategory.general);
    }
  }

  /// Listen for ICE candidates only (without setting up sender).
  void listenForIceCandidatesOnly(String callId, String collection) {
    iceCandidateSubscription?.cancel();
    AppLogger.d('📞 Listening for ICE candidates from: $collection',
        category: LogCategory.general);

    iceCandidateSubscription = firestore
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
          peerConnectionForSignaling?.addCandidate(candidate).catchError((e) {
            AppLogger.w('Failed to add ICE candidate: $e',
                category: LogCategory.general);
          });
        }
      }
    });
  }

  // ── Call status listener (connected call) ───────────────────────────

  /// Listen for call status changes with device awareness.
  void listenForCallStatus(String callId) {
    callStatusSubscription?.cancel();

    AppLogger.d('Setting up call status listener for call: $callId',
        category: LogCategory.general);

    callStatusSubscription =
        firestore.collection('calls').doc(callId).snapshots().listen(
      (snapshot) async {
        if (!snapshot.exists) {
          AppLogger.w('Call document deleted - ending call',
              category: LogCategory.general);
          handleCallEnded('document_deleted');
          return;
        }

        final data = snapshot.data();
        if (data == null) {
          AppLogger.w('Call document has null data - ending call',
              category: LogCategory.general);
          handleCallEnded('null_data');
          return;
        }

        final status = data['status'] as String?;
        final answeredByDeviceId = data['answeredByDeviceId'] as String?;
        final answeringDeviceId = data['answeringDeviceId'] as String?;
        final currentDeviceId = await getDeviceId();
        final isCaller = currentCallField != null &&
            currentUserId != null &&
            currentCallField!.callerId == currentUserId;
        final isCallee = currentCallField != null &&
            currentUserId != null &&
            currentCallField!.calleeId == currentUserId;

        AppLogger.d(
            'Call status update: $status (answeredBy: $answeredByDeviceId, answering: $answeringDeviceId, currentDevice: $currentDeviceId, isCaller: $isCaller, isCallee: $isCallee, currentState: $callState)',
            category: LogCategory.general);

        // Terminal states
        if (status == 'ended' ||
            status == 'rejected' ||
            status == 'missed' ||
            status == 'cancelled' ||
            status == 'failed') {
          AppLogger.i('Call ended by remote party (status: $status)',
              category: LogCategory.general);
          handleCallEnded('remote_$status');
          return;
        }

        // Answered with device awareness
        if (status == 'answered') {
          if (isCallee &&
              answeredByDeviceId != null &&
              answeredByDeviceId != currentDeviceId) {
            AppLogger.i(
                'Call answered by another device: $answeredByDeviceId',
                category: LogCategory.general);
            showMessageToUser?.call('Call answered on another device');
            handleCallEnded('answered_by_other_device');
            return;
          }

          if (callState == CallState.connecting ||
              callState == CallState.ringing ||
              callState == CallState.answering) {
            AppLogger.i('Call was answered!',
                category: LogCategory.general);
            return;
          }
        }

        // Answering state (intermediate)
        if (status == 'answering' && isCallee) {
          if (answeringDeviceId != null &&
              answeringDeviceId != currentDeviceId) {
            AppLogger.i(
                'Another device is answering: $answeringDeviceId',
                category: LogCategory.general);
            showMessageToUser?.call('Another device is answering...');
          }
        }
      },
      onError: (error) {
        AppLogger.e('Call status listener error',
            category: LogCategory.general, error: error);
        handleCallEnded('listener_error');
      },
    );
  }

  // ── Subscription cleanup helper ─────────────────────────────────────

  /// Cancel all signaling subscriptions.
  Future<void> cancelSignalingSubscriptions() async {
    try {
      await callStatusSubscription?.cancel();
    } catch (e) {
      AppLogger.w('Error cancelling call status subscription: $e',
          category: LogCategory.general);
    }
    callStatusSubscription = null;

    try {
      await iceCandidateSubscription?.cancel();
    } catch (e) {
      AppLogger.w('Error cancelling ICE candidate subscription: $e',
          category: LogCategory.general);
    }
    iceCandidateSubscription = null;

    try {
      await answerSubscription?.cancel();
    } catch (e) {
      AppLogger.w('Error cancelling answer subscription: $e',
          category: LogCategory.general);
    }
    answerSubscription = null;
  }
}
