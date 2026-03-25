import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'platform_interface.dart';

/// Web implementation of PlatformServices
/// Provides stubs and web-specific alternatives for native features
class WebPlatformServices implements PlatformServices {
  WebPlatformServices._();
  
  static final WebPlatformServices _instance = WebPlatformServices._();
  
  /// Initialize and register the web platform services
  static void initialize() {
    PlatformServices.setInstance(_instance);
  }
  
  // ============ Platform Info ============
  
  @override
  bool get isWeb => true;
  
  @override
  bool get isMobile => false;
  
  @override
  bool get isIOS => false;
  
  @override
  bool get isAndroid => false;
  
  // ============ Contact Features ============
  // Contact sync is NOT supported on web
  
  @override
  bool get isContactSyncSupported => false;
  
  @override
  Future<bool> requestContactPermission() async {
    // Contact access not available on web
    return false;
  }
  
  @override
  Future<bool> hasContactPermission() async {
    return false;
  }
  
  // ============ Notifications ============
  // Use Web Notifications API
  
  @override
  bool get isLocalNotificationSupported => true;
  
  @override
  Future<bool> requestNotificationPermission() async {
    try {
      final permission = await html.Notification.requestPermission();
      return permission == 'granted';
    } catch (e) {
      debugPrint('Web notification permission error: $e');
      return false;
    }
  }
  
  @override
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (html.Notification.permission == 'granted') {
        html.Notification(title, body: body);
      }
    } catch (e) {
      debugPrint('Web notification error: $e');
    }
  }
  
  // ============ Audio Recording ============
  // Audio recording has limited support on web - disabled for now
  
  @override
  bool get isAudioRecordingSupported => false;
  
  @override
  Future<bool> initializeAudioRecording() async {
    // Audio recording disabled on web for Phase 1
    return false;
  }
  
  @override
  Future<bool> requestMicrophonePermission() async {
    return await _requestMediaPermission(audio: true, video: false);
  }
  
  /// Request camera permission using browser APIs
  Future<bool> requestCameraPermission() async {
    return await _requestMediaPermission(audio: false, video: true);
  }
  
  /// Request both camera and microphone permissions using browser APIs
  /// This is the proper way to request media permissions on web
  Future<bool> requestMediaPermissions({bool audio = true, bool video = true}) async {
    return await _requestMediaPermission(audio: audio, video: video);
  }
  
  /// Internal method to request media permissions via getUserMedia
  /// On web, permissions are requested by attempting to access the media
  Future<bool> _requestMediaPermission({required bool audio, required bool video}) async {
    try {
      // Use getUserMedia to trigger browser permission prompt
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        debugPrint('MediaDevices not available');
        return false;
      }
      
      final constraints = <String, dynamic>{};
      if (audio) constraints['audio'] = true;
      if (video) constraints['video'] = true;
      
      if (constraints.isEmpty) return true;
      
      // This will trigger the browser's permission prompt
      final stream = await mediaDevices.getUserMedia(constraints);
      
      // Permission granted - stop the stream immediately (we just needed to check)
      stream.getTracks().forEach((track) => track.stop());
      
      debugPrint('Web media permissions granted (audio: $audio, video: $video)');
      return true;
    } catch (e) {
      debugPrint('Web media permission denied or error: $e');
      return false;
    }
  }
  
  /// Check if media permissions are already granted (without prompting)
  Future<bool> hasMediaPermissions({bool audio = true, bool video = true}) async {
    try {
      // Check permission status using Permissions API if available
      final permissions = html.window.navigator.permissions;
      if (permissions != null) {
        bool audioGranted = !audio;
        bool videoGranted = !video;
        
        if (audio) {
          try {
            final micStatus = await permissions.query({'name': 'microphone'});
            audioGranted = micStatus.state == 'granted';
          } catch (_) {
            // Permissions API might not support this query
            audioGranted = false;
          }
        }
        
        if (video) {
          try {
            final camStatus = await permissions.query({'name': 'camera'});
            videoGranted = camStatus.state == 'granted';
          } catch (_) {
            videoGranted = false;
          }
        }
        
        return audioGranted && videoGranted;
      }
      
      // Fallback: we don't know, assume not granted
      return false;
    } catch (e) {
      debugPrint('Error checking media permissions: $e');
      return false;
    }
  }
  
  // ============ Video/Media Compression ============
  // Video compression is NOT supported on web
  
  @override
  bool get isVideoCompressionSupported => false;
  
  @override
  Future<String?> compressVideo(String path) async {
    // Video compression not available on web
    // Videos should be uploaded uncompressed or compression handled server-side
    return null;
  }
  
  // ============ Calling Features ============
  // 1:1 calling enabled on web using WebRTC
  // Group calling (Agora) enabled on web - Agora SDK 6.x supports web
  
  @override
  bool get isCallingSupported => true;  // WebRTC works on web
  
  @override
  bool get isGroupCallingSupported => true;  // Agora SDK 6.x supports web
  
  // ============ Location ============
  // Location works on web via Geolocation API
  
  @override
  bool get isLocationSupported => true;
  
  @override
  Future<bool> requestLocationPermission() async {
    try {
      // Web location permission is requested when you try to get position
      // We can't pre-request it, so we return true and let it fail gracefully
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // ============ Vibration ============
  // Vibration has limited support on web
  
  @override
  bool get isVibrationSupported => false;
  
  @override
  Future<void> vibrate({int duration = 500}) async {
    // Vibration not reliably supported on web
    // Could use navigator.vibrate in the future
  }
  
  // ============ File System ============
  // Web uses browser storage instead of file system
  
  @override
  Future<String> getTemporaryDirectoryPath() async {
    // Web doesn't have a traditional file system
    // Return a virtual path for compatibility
    return '/tmp';
  }
  
  @override
  Future<String> getApplicationDocumentsDirectoryPath() async {
    // Web doesn't have application documents directory
    // Return a virtual path for compatibility
    return '/documents';
  }
}
