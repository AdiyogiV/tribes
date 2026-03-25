import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:video_compress/video_compress.dart';
import 'platform_interface.dart';

/// Mobile (iOS/Android) implementation of PlatformServices
class MobilePlatformServices implements PlatformServices {
  MobilePlatformServices._();
  
  static final MobilePlatformServices _instance = MobilePlatformServices._();
  
  /// Initialize and register the mobile platform services
  static void initialize() {
    PlatformServices.setInstance(_instance);
  }
  
  // ============ Platform Info ============
  
  @override
  bool get isWeb => kIsWeb;
  
  @override
  bool get isMobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  
  @override
  bool get isIOS => !kIsWeb && Platform.isIOS;
  
  @override
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  
  // ============ Contact Features ============
  
  @override
  bool get isContactSyncSupported => true;
  
  @override
  Future<bool> requestContactPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }
  
  @override
  Future<bool> hasContactPermission() async {
    return await Permission.contacts.isGranted;
  }
  
  // ============ Notifications ============
  
  @override
  bool get isLocalNotificationSupported => true;
  
  @override
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
  
  @override
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // This is handled by NotificationService directly on mobile
    // This method exists for interface compatibility
  }
  
  // ============ Audio Recording ============
  
  @override
  bool get isAudioRecordingSupported => true;
  
  @override
  Future<bool> initializeAudioRecording() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
  
  @override
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
  
  // ============ Video/Media Compression ============
  
  @override
  bool get isVideoCompressionSupported => true;
  
  @override
  Future<String?> compressVideo(String path) async {
    try {
      final info = await VideoCompress.compressVideo(
        path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      return info?.file?.path;
    } catch (e) {
      debugPrint('Video compression failed: $e');
      return null;
    }
  }
  
  // ============ Calling Features ============
  
  @override
  bool get isCallingSupported => true;
  
  @override
  bool get isGroupCallingSupported => true;
  
  // ============ Location ============
  
  @override
  bool get isLocationSupported => true;
  
  @override
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }
  
  // ============ Vibration ============
  
  @override
  bool get isVibrationSupported => true;
  
  @override
  Future<void> vibrate({int duration = 500}) async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      await Vibration.vibrate(duration: duration);
    }
  }
  
  // ============ File System ============
  
  @override
  Future<String> getTemporaryDirectoryPath() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }
  
  @override
  Future<String> getApplicationDocumentsDirectoryPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }
}
