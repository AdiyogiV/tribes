import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/models/call.dart';

/// Mixin that handles WebRTC peer connection setup, media streams,
/// and media controls (mute, camera, speaker).
///
/// The host class must provide:
///   - [onLocalStream], [onRemoteStream], [onPermissionError] callbacks
///   - [callState], [setCallState] for state transitions
///   - [callConnectedAt], [lastCallStatus] for tracking connection time
///   - [isCleaningUp] flag
mixin CallWebRTC {
  // ── Fields owned by this mixin ──────────────────────────────────────

  RTCPeerConnection? peerConnection;
  MediaStream? localStreamField;
  MediaStream? remoteStreamField;

  // ICE servers — Google's FREE STUN servers
  final Map<String, dynamic> iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ]
  };

  // Mute states
  bool isMutedField = false;
  bool isCameraOffField = false;
  bool isSpeakerOnField = true;

  // Web camera switching
  List<MediaDeviceInfo> videoDevices = [];
  int currentVideoDeviceIndex = 0;

  // ── Abstract hooks into the host class ──────────────────────────────

  Function(MediaStream stream)? get onLocalStream;
  Function(MediaStream stream)? get onRemoteStream;
  Function(String error)? get onPermissionError;
  CallState get callState;
  void setCallState(CallState s);
  DateTime? get callConnectedAt;
  set callConnectedAt(DateTime? v);
  String? get lastCallStatus;
  set lastCallStatus(String? v);
  bool get isCleaningUp;
  void handleCallEnded([String? reason]);

  // ── Public getters ──────────────────────────────────────────────────

  bool get hasVideoTrack {
    if (localStreamField == null) return false;
    return localStreamField!.getVideoTracks().isNotEmpty;
  }

  bool get canEnableCamera => hasVideoTrack && isCameraOffField;

  // ── Permissions ─────────────────────────────────────────────────────

  /// Request media permissions before starting a call.
  /// On web, this triggers the browser permission prompt.
  Future<bool> requestMediaPermissions({bool video = true}) async {
    try {
      AppLogger.i(
          '📹 Requesting media permissions (video: $video, isWeb: $kIsWeb)',
          category: LogCategory.general);

      final constraints = {
        'audio': true,
        'video': video
            ? {
                'facingMode': 'user',
              }
            : false,
      };

      final stream = await navigator.mediaDevices.getUserMedia(constraints);

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

  /// Check if we have media permissions without prompting.
  Future<bool> hasMediaPermissions({bool video = true}) async {
    if (kIsWeb) {
      return true; // Will be verified when actually starting the call
    }
    return true;
  }

  // ── WebRTC initialisation / disposal ────────────────────────────────

  /// Initialize WebRTC with comprehensive error handling.
  /// Always requests video capability, but can start with camera disabled
  /// for "voice" calls. This allows upgrading voice calls to video mid-call.
  Future<void> initializeWebRTC({bool startWithCameraOff = false}) async {
    try {
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

      bool fellBackToAudioOnly = false;

      try {
        localStreamField =
            await navigator.mediaDevices.getUserMedia(mediaConstraints);
        final videoTracks = localStreamField!.getVideoTracks();
        final audioTracks = localStreamField!.getAudioTracks();
        AppLogger.i(
            '📹 Got local stream: ${videoTracks.length} video, ${audioTracks.length} audio tracks',
            category: LogCategory.general);
      } catch (e) {
        AppLogger.e('Failed to get user media - permission may be denied',
            category: LogCategory.general, error: e);

        String errorMessage = 'Failed to access camera/microphone.';
        final errorStr = e.toString();

        if (errorStr.contains('NotAllowedError') ||
            errorStr.contains('Permission denied') ||
            errorStr.contains('PermissionDeniedError')) {
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

        // Try audio-only fallback
        AppLogger.i(
            '📹 Attempting audio-only fallback (will still receive remote video)',
            category: LogCategory.general);
        try {
          localStreamField = await navigator.mediaDevices.getUserMedia({
            'audio': true,
            'video': false,
          });
          fellBackToAudioOnly = true;
          AppLogger.i('📹 Audio-only fallback successful',
              category: LogCategory.general);

          onPermissionError?.call(
              'Video access denied. Continuing with audio only. $errorMessage');
        } catch (audioError) {
          AppLogger.e('📹 Audio-only fallback also failed',
              category: LogCategory.general, error: audioError);
          onPermissionError?.call(errorMessage);
          rethrow;
        }
      }

      if (localStreamField == null) {
        throw Exception('Failed to acquire local media stream');
      }

      onLocalStream?.call(localStreamField!);

      // Create peer connection
      try {
        peerConnection = await createPeerConnection(iceServers);
      } catch (e) {
        AppLogger.e('Failed to create peer connection',
            category: LogCategory.general, error: e);
        rethrow;
      }

      if (peerConnection == null) {
        throw Exception('Failed to create peer connection');
      }

      // Add local tracks
      final tracks = localStreamField!.getTracks();
      for (final track in tracks) {
        try {
          peerConnection!.addTrack(track, localStreamField!);
        } catch (e) {
          AppLogger.w('Failed to add track: ${track.kind} - $e',
              category: LogCategory.general);
        }
      }

      // If audio-only fallback, add receive-only video transceiver
      if (fellBackToAudioOnly) {
        try {
          AppLogger.i(
              '📹 Adding recvonly video transceiver to receive remote video',
              category: LogCategory.general);
          await peerConnection!.addTransceiver(
            kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init:
                RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
          );
        } catch (e) {
          AppLogger.w('Failed to add recvonly video transceiver: $e',
              category: LogCategory.general);
        }
      }

      // Disable camera for voice calls
      if (startWithCameraOff && !fellBackToAudioOnly) {
        final videoTracks = localStreamField!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          AppLogger.i(
              '📹 Disabling camera for voice call (can be enabled later)',
              category: LogCategory.general);
          videoTracks[0].enabled = false;
          isCameraOffField = true;
        }
      }

      // Handle remote stream
      peerConnection!.onTrack = (event) {
        final trackKind = event.track.kind;
        final streamCount = event.streams.length;
        final trackEnabled = event.track.enabled;

        AppLogger.i(
            '📞 onTrack: received $trackKind track (enabled: $trackEnabled, streams: $streamCount)',
            category: LogCategory.general);

        if (event.streams.isNotEmpty) {
          final newStream = event.streams[0];

          final streamChanged = remoteStreamField?.id != newStream.id;
          remoteStreamField = newStream;

          final videoTracks = remoteStreamField!.getVideoTracks().length;
          final audioTracks = remoteStreamField!.getAudioTracks().length;
          final enabledVideoTracks = remoteStreamField!
              .getVideoTracks()
              .where((track) => track.enabled)
              .length;

          AppLogger.i(
              '📞 Remote stream ${streamChanged ? "updated" : "track added"}: $videoTracks video tracks ($enabledVideoTracks enabled), $audioTracks audio tracks',
              category: LogCategory.general);

          if (videoTracks > 0 && enabledVideoTracks == 0) {
            AppLogger.w(
                '📞 WARNING: Remote video tracks exist but all are disabled!',
                category: LogCategory.general);
          }

          onRemoteStream?.call(remoteStreamField!);

          if ((callState == CallState.answering ||
                  callState == CallState.connecting ||
                  callState == CallState.ringing) &&
              audioTracks > 0) {
            AppLogger.i(
                '📞 Received media tracks - transitioning to connected (audio: $audioTracks, video: $videoTracks, state: $callState)',
                category: LogCategory.general);
            setCallState(CallState.connected);
            callConnectedAt = DateTime.now();
            lastCallStatus = 'answered';
          } else if (callState == CallState.connected) {
            AppLogger.d(
                '📞 Received additional track while already connected (audio: $audioTracks, video: $videoTracks)',
                category: LogCategory.general);
          } else {
            AppLogger.d(
                '📞 Received tracks but not transitioning - state: $callState, audio: $audioTracks',
                category: LogCategory.general);
          }
        }
      };

      // Handle connection state
      peerConnection!.onConnectionState = (state) {
        AppLogger.d(
            'WebRTC connection state: $state (call state: $callState)',
            category: LogCategory.general);

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          if (callState == CallState.answering ||
              callState == CallState.connecting ||
              callState == CallState.ringing) {
            AppLogger.i(
                'WebRTC connected - transitioning to connected state',
                category: LogCategory.general);
            setCallState(CallState.connected);
            callConnectedAt = DateTime.now();
            lastCallStatus = 'answered';
          }
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          AppLogger.w('WebRTC connection failed - ending call',
              category: LogCategory.general);
          handleCallEnded('webrtc_failed');
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          AppLogger.w('WebRTC disconnected - ending call',
              category: LogCategory.general);
          handleCallEnded('webrtc_disconnected');
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          AppLogger.d('WebRTC connection closed',
              category: LogCategory.general);
          if (!isCleaningUp &&
              callState != CallState.ended &&
              callState != CallState.idle) {
            handleCallEnded('webrtc_closed');
          }
        }
      };

      // Handle ICE connection state — backup indicator
      peerConnection!.onIceConnectionState = (state) {
        AppLogger.d(
            'ICE connection state: $state (call state: $callState)',
            category: LogCategory.general);

        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          if (callState == CallState.answering ||
              callState == CallState.connecting ||
              callState == CallState.ringing) {
            AppLogger.i(
                'ICE connected - transitioning to connected state',
                category: LogCategory.general);
            setCallState(CallState.connected);
            callConnectedAt = DateTime.now();
            lastCallStatus = 'answered';
          }
        } else if (state ==
            RTCIceConnectionState.RTCIceConnectionStateFailed) {
          AppLogger.w('ICE connection failed',
              category: LogCategory.general);
        }
      };

      AppLogger.i('WebRTC initialized successfully',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('WebRTC initialization failed',
          category: LogCategory.general, error: e);
      await disposeWebRTC();
      rethrow;
    }
  }

  /// Dispose WebRTC resources safely with proper sequencing.
  /// Order is critical to prevent GPU driver crashes and memory leaks.
  Future<void> disposeWebRTC() async {
    try {
      // Step 1: Clear peer connection handlers
      final pc = peerConnection;
      if (pc != null) {
        pc.onTrack = null;
        pc.onConnectionState = null;
        pc.onIceConnectionState = null;
        pc.onIceCandidate = null;
      }

      // Step 2: Stop all tracks before disposing stream
      final ls = localStreamField;
      if (ls != null) {
        final tracks = ls.getTracks();
        for (final track in tracks) {
          try {
            await track.stop();
          } catch (e) {
            AppLogger.w('Error stopping track ${track.kind}: $e',
                category: LogCategory.general);
          }
        }

        await Future.delayed(const Duration(milliseconds: 50));

        try {
          await ls.dispose();
        } catch (e) {
          AppLogger.w('Error disposing local stream: $e',
              category: LogCategory.general);
        }
      }
      localStreamField = null;

      // Step 3: Clear remote stream reference
      remoteStreamField = null;

      // Step 4: Close peer connection after streams are disposed
      if (pc != null) {
        try {
          await Future.delayed(const Duration(milliseconds: 50));
          await pc.close();
        } catch (e) {
          AppLogger.w('Error closing peer connection: $e',
              category: LogCategory.general);
        }
      }
      peerConnection = null;

      // Step 5: Final delay for GPU/EGL cleanup
      await Future.delayed(const Duration(milliseconds: 100));

      AppLogger.d('WebRTC resources disposed successfully',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Error disposing WebRTC',
          category: LogCategory.general, error: e);
    }
  }

  // ── Media controls ──────────────────────────────────────────────────

  /// Toggle microphone
  Future<bool> toggleMute() async {
    try {
      if (localStreamField != null) {
        final audioTracks = localStreamField!.getAudioTracks();
        if (audioTracks.isNotEmpty) {
          isMutedField = !isMutedField;
          audioTracks[0].enabled = !isMutedField;
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

  /// Toggle camera on/off.
  /// Works for both voice calls (enabling camera) and video calls (disabling camera).
  Future<bool> toggleCamera() async {
    try {
      if (localStreamField == null) {
        AppLogger.w('Cannot toggle camera: no local stream',
            category: LogCategory.general);
        return false;
      }

      final videoTracks = localStreamField!.getVideoTracks();
      if (videoTracks.isEmpty) {
        AppLogger.w('Cannot toggle camera: no video tracks available',
            category: LogCategory.general);
        return false;
      }

      isCameraOffField = !isCameraOffField;
      videoTracks[0].enabled = !isCameraOffField;

      AppLogger.i('📹 Camera ${isCameraOffField ? "disabled" : "enabled"}',
          category: LogCategory.general);
      return true;
    } catch (e) {
      AppLogger.e('Failed to toggle camera',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Switch camera (front/back).
  /// On mobile: uses Helper.switchCamera.
  /// On web: enumerates devices and switches to next camera.
  Future<bool> switchCamera() async {
    try {
      if (localStreamField == null) return false;

      final videoTracks = localStreamField!.getVideoTracks();
      if (videoTracks.isEmpty) return false;

      if (kIsWeb) {
        return await _switchCameraWeb();
      } else {
        await Helper.switchCamera(videoTracks[0]);
        return true;
      }
    } catch (e) {
      AppLogger.e('Failed to switch camera',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Web-specific camera switching.
  Future<bool> _switchCameraWeb() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();

      videoDevices = devices.where((d) => d.kind == 'videoinput').toList();

      AppLogger.d('📹 Web: Found ${videoDevices.length} video devices',
          category: LogCategory.general);

      if (videoDevices.length < 2) {
        AppLogger.w('📹 Web: Only one camera available, cannot switch',
            category: LogCategory.general);
        return false;
      }

      currentVideoDeviceIndex =
          (currentVideoDeviceIndex + 1) % videoDevices.length;
      final nextDevice = videoDevices[currentVideoDeviceIndex];

      AppLogger.d(
          '📹 Web: Switching to camera: ${nextDevice.label} (${nextDevice.deviceId})',
          category: LogCategory.general);

      final newStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'deviceId': {'exact': nextDevice.deviceId},
        },
      });

      final newVideoTrack = newStream.getVideoTracks().first;
      final oldVideoTrack = localStreamField!.getVideoTracks().first;

      if (peerConnection != null) {
        final senders = await peerConnection!.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(newVideoTrack);
            break;
          }
        }
      }

      await localStreamField!.removeTrack(oldVideoTrack);
      await localStreamField!.addTrack(newVideoTrack);

      await oldVideoTrack.stop();

      onLocalStream?.call(localStreamField!);

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
      isSpeakerOnField = enabled;
      await Helper.setSpeakerphoneOn(enabled);
      return true;
    } catch (e) {
      AppLogger.e('Failed to toggle speaker',
          category: LogCategory.general, error: e);
      return false;
    }
  }
}
