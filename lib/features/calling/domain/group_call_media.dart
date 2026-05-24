import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

/// Manages Agora RTC engine lifecycle, media permissions, and audio/video controls.
class GroupCallMediaManager {
  RtcEngine? engine;
  bool isInitialized = false;
  bool hasMediaPermissions = false;

  /// Initialize the Agora engine and register event handlers.
  ///
  /// [onJoinChannelSuccess], [onUserJoined], etc. are callbacks wired by the
  /// owning [GroupCallService] so that high-level state stays in one place.
  Future<bool> initializeEngine({
    required void Function(int localUid) onJoinChannelSuccess,
    required void Function(int remoteUid) onUserJoined,
    required void Function(int remoteUid, UserOfflineReasonType reason) onUserOffline,
    required void Function(int remoteUid, bool muted) onUserMuteAudio,
    required void Function(int remoteUid, bool muted) onUserMuteVideo,
    required void Function(String msg) onEngineError,
    required void Function(ConnectionStateType state, ConnectionChangedReasonType reason) onConnectionStateChanged,
    required void Function(int quality) onNetworkQuality,
  }) async {
    if (isInitialized && engine != null) return true;

    try {
      AppLogger.i('Initializing Agora engine... (isWeb: $kIsWeb)', category: LogCategory.general);

      // On web, lazy-load the Agora SDK via JavaScript
      if (kIsWeb) {
        AppLogger.i('Loading Agora SDK for web...', category: LogCategory.general);
        final sdkLoaded = await agora_web.loadAgoraSDK();
        if (!sdkLoaded) {
          AppLogger.e('Failed to load Agora SDK for web', category: LogCategory.general);
          onEngineError('Failed to load video call SDK. Please refresh the page and try again.');
          return false;
        }
        AppLogger.i('Agora SDK loaded successfully for web', category: LogCategory.general);
      }

      // Request camera/microphone permissions
      hasMediaPermissions = await requestMediaPermissions();
      if (!hasMediaPermissions) {
        AppLogger.w('Camera or microphone permission denied - will join with media disabled',
            category: LogCategory.general);
      }

      AppLogger.i('Creating Agora RTC engine...', category: LogCategory.general);
      final rtcEngine = createAgoraRtcEngine();
      engine = rtcEngine;

      AppLogger.i('Initializing Agora engine with appId...', category: LogCategory.general);
      await rtcEngine.initialize(RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      rtcEngine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          AppLogger.i('Joined channel: ${connection.channelId}, uid: ${connection.localUid}',
              category: LogCategory.general);
          onJoinChannelSuccess(connection.localUid ?? 0);
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          AppLogger.i('User joined: $remoteUid', category: LogCategory.general);
          onUserJoined(remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          AppLogger.i('User left: $remoteUid, reason: $reason', category: LogCategory.general);
          onUserOffline(remoteUid, reason);
        },
        onUserMuteAudio: (connection, remoteUid, muted) {
          onUserMuteAudio(remoteUid, muted);
        },
        onUserMuteVideo: (connection, remoteUid, muted) {
          onUserMuteVideo(remoteUid, muted);
        },
        onError: (err, msg) {
          AppLogger.e('Agora error: $err - $msg', category: LogCategory.general);
          onEngineError('Call error: $msg');
        },
        onConnectionLost: (connection) {
          AppLogger.w('Connection lost - Agora will attempt automatic reconnection',
              category: LogCategory.general);
        },
        onConnectionStateChanged: (connection, state, reason) {
          AppLogger.i('Connection state: $state, reason: $reason', category: LogCategory.general);
          onConnectionStateChanged(state, reason);
        },
        onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
          if (remoteUid == 0) {
            final quality = 5 - (((txQuality.index + rxQuality.index) / 2).round().clamp(0, 5));
            onNetworkQuality(quality);
          }
        },
      ));

      await rtcEngine.enableVideo();
      await rtcEngine.enableAudio();

      await rtcEngine.setVideoEncoderConfiguration(VideoEncoderConfiguration(
        dimensions: VideoDimensions(
          width: AgoraConfig.videoWidth,
          height: AgoraConfig.videoHeight,
        ),
        frameRate: AgoraConfig.videoFrameRate,
        bitrate: AgoraConfig.videoBitrate,
      ));

      isInitialized = true;
      AppLogger.i('Agora engine initialized successfully', category: LogCategory.general);
      return true;
    } catch (e) {
      AppLogger.e('Failed to initialize Agora engine', category: LogCategory.general, error: e);
      onEngineError('Failed to initialize call: $e');
      engine = null;
      isInitialized = false;
      return false;
    }
  }

  /// Request media permissions for camera and microphone.
  /// Uses browser APIs on web, permission_handler on mobile.
  Future<bool> requestMediaPermissions() async {
    if (kIsWeb) {
      try {
        AppLogger.i('Requesting media permissions via browser API...', category: LogCategory.general);

        final stream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {
            'facingMode': 'user',
          },
        });

        // Permission granted - stop the stream immediately
        for (final track in stream.getTracks()) {
          await track.stop();
        }
        await stream.dispose();

        AppLogger.i('Browser media permissions granted', category: LogCategory.general);
        return true;
      } catch (e) {
        AppLogger.e('Browser media permission denied or error',
            category: LogCategory.general, error: e);
        return false;
      }
    } else {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (cameraStatus.isDenied || micStatus.isDenied) {
        return false;
      }
      return true;
    }
  }

  /// Fetch an Agora token from the Cloud Function.
  Future<String?> getToken(String channelName, int uid) async {
    if (!AgoraConfig.useTokenAuth) {
      AppLogger.i('Token auth disabled, skipping token fetch', category: LogCategory.general);
      return null;
    }

    try {
      AppLogger.i('Fetching Agora token for channel: $channelName, uid: $uid',
          category: LogCategory.general);

      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('commsGateway',
              options: HttpsCallableOptions(timeout: const Duration(seconds: 10)));

      AppLogger.i('Calling generateAgoraToken function...', category: LogCategory.general);
      final result = await callable.call({
        'method': 'generateAgoraToken',
        'channelName': channelName,
        'uid': uid,
      });
      AppLogger.i('Token function call completed', category: LogCategory.general);

      final data = result.data;

      if (data == null) {
        AppLogger.w('Token function returned null data', category: LogCategory.general);
        return null;
      }

      if (data is Map) {
        final tokenValue = data['token'];
        if (tokenValue is String && tokenValue.isNotEmpty) {
          AppLogger.i('Token received successfully',
              category: LogCategory.general, data: {'tokenLength': tokenValue.length});
          return tokenValue;
        }
      }

      AppLogger.w('Token function returned invalid response',
          category: LogCategory.general, data: {'dataType': data.runtimeType.toString()});
      return null;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to get Agora token', category: LogCategory.general, error: e);
      AppLogger.d('Token error stacktrace: $stackTrace', category: LogCategory.general);
      final errorStr = e.toString();
      if (errorStr.contains('NOT_FOUND') || errorStr.contains('not-found')) {
        AppLogger.w('Token function not deployed, joining without token',
            category: LogCategory.general);
        return null;
      }
      AppLogger.w('Proceeding without token due to error: $errorStr',
          category: LogCategory.general);
      return null;
    }
  }

  /// Toggle local audio mute state. Returns the new muted state.
  Future<bool> toggleAudio({
    required bool isCurrentlyMuted,
    required Function(String error) onError,
  }) async {
    if (engine == null) return isCurrentlyMuted;

    // If trying to unmute but don't have permissions, request them first
    if (isCurrentlyMuted && !hasMediaPermissions) {
      AppLogger.i('Requesting media permissions to enable audio...', category: LogCategory.general);
      hasMediaPermissions = await requestMediaPermissions();
      if (!hasMediaPermissions) {
        onError('Microphone permission required. Please grant permission in browser/system settings.');
        return isCurrentlyMuted;
      }
      await engine!.enableLocalAudio(true);
    }

    final newMuted = !isCurrentlyMuted;
    await engine!.muteLocalAudioStream(newMuted);
    AppLogger.i('Audio ${newMuted ? "muted" : "unmuted"}', category: LogCategory.general);
    return newMuted;
  }

  /// Toggle local video mute state. Returns the new muted state.
  Future<bool> toggleVideo({
    required bool isCurrentlyMuted,
    required Function(String error) onError,
  }) async {
    if (engine == null) return isCurrentlyMuted;

    // If trying to enable video but don't have permissions, request them first
    if (isCurrentlyMuted && !hasMediaPermissions) {
      AppLogger.i('Requesting media permissions to enable video...', category: LogCategory.general);
      hasMediaPermissions = await requestMediaPermissions();
      if (!hasMediaPermissions) {
        onError('Camera permission required. Please grant permission in browser/system settings.');
        return isCurrentlyMuted;
      }
      await engine!.enableLocalVideo(true);
    }

    final newMuted = !isCurrentlyMuted;
    await engine!.muteLocalVideoStream(newMuted);
    if (newMuted) {
      await engine!.stopPreview();
    } else {
      await engine!.startPreview();
    }
    AppLogger.i('Video ${newMuted ? "off" : "on"}', category: LogCategory.general);
    return newMuted;
  }

  /// Switch between front and back cameras.
  Future<void> switchCamera() async {
    if (engine == null) return;
    try {
      await engine!.switchCamera();
      AppLogger.i('Camera switched', category: LogCategory.general);
    } catch (e) {
      AppLogger.w('Failed to switch camera (device may have single camera): $e',
          category: LogCategory.general);
    }
  }

  /// Toggle speaker / earpiece output (mobile only).
  Future<void> toggleSpeaker(bool enabled) async {
    if (engine == null) return;
    if (kIsWeb) {
      AppLogger.w('toggleSpeaker not supported on web', category: LogCategory.general);
      return;
    }
    try {
      await engine!.setEnableSpeakerphone(enabled);
      AppLogger.i('Speaker ${enabled ? "enabled" : "disabled"}', category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Failed to toggle speaker', category: LogCategory.general, error: e);
    }
  }

  /// Prepare engine for joining a channel — enable video/audio based on permissions.
  /// Returns ({bool isAudioMuted, bool isVideoMuted}).
  Future<({bool isAudioMuted, bool isVideoMuted})> prepareForJoin() async {
    final rtcEngine = engine;
    if (rtcEngine == null) return (isAudioMuted: true, isVideoMuted: true);

    await rtcEngine.enableVideo();
    await rtcEngine.enableAudio();

    if (hasMediaPermissions) {
      await rtcEngine.enableLocalVideo(true);
      await rtcEngine.startPreview();
      await rtcEngine.enableLocalAudio(true);
      return (isAudioMuted: false, isVideoMuted: false);
    } else {
      AppLogger.i('Joining call with video/audio disabled (no permissions)',
          category: LogCategory.general);
      await rtcEngine.enableLocalVideo(false);
      await rtcEngine.enableLocalAudio(false);
      return (isAudioMuted: true, isVideoMuted: true);
    }
  }

  /// Join an Agora channel.
  Future<void> joinChannel({
    required String channelName,
    required String token,
    required int uid,
    required bool publishMedia,
  }) async {
    final rtcEngine = engine;
    if (rtcEngine == null) return;

    AppLogger.i('Joining channel: $channelName with uid: $uid', category: LogCategory.general);

    await rtcEngine.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        publishMicrophoneTrack: publishMedia,
        publishCameraTrack: publishMedia,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  /// Leave channel and stop preview.
  Future<void> leaveChannel() async {
    await engine?.leaveChannel();
    await engine?.stopPreview();
  }

  /// Release the Agora engine entirely.
  Future<void> release() async {
    await engine?.release();
    engine = null;
    isInitialized = false;
  }
}
