/// Platform abstraction layer for handling platform-specific features
/// This allows the app to compile and run on web while maintaining mobile functionality
library;

abstract class PlatformServices {
  /// Singleton instance - set by platform-specific implementation
  static PlatformServices? _instance;
  
  static PlatformServices get instance {
    if (_instance == null) {
      throw StateError('PlatformServices not initialized. Call PlatformServices.initialize() first.');
    }
    return _instance!;
  }
  
  static void setInstance(PlatformServices services) {
    _instance = services;
  }
  
  // ============ Platform Info ============
  
  /// Whether the current platform is web
  bool get isWeb;
  
  /// Whether the current platform is mobile (iOS or Android)
  bool get isMobile;
  
  /// Whether the current platform is iOS
  bool get isIOS;
  
  /// Whether the current platform is Android
  bool get isAndroid;
  
  // ============ Contact Features ============
  
  /// Whether contact sync is supported on this platform
  bool get isContactSyncSupported;
  
  /// Request contact permission
  Future<bool> requestContactPermission();
  
  /// Check if we have contact permission
  Future<bool> hasContactPermission();
  
  // ============ Notifications ============
  
  /// Whether local notifications are supported
  bool get isLocalNotificationSupported;
  
  /// Request notification permission
  Future<bool> requestNotificationPermission();
  
  /// Show a local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  });
  
  // ============ Audio Recording ============
  
  /// Whether audio recording is supported
  bool get isAudioRecordingSupported;
  
  /// Initialize audio recording
  Future<bool> initializeAudioRecording();
  
  /// Request microphone permission
  Future<bool> requestMicrophonePermission();
  
  // ============ Video/Media Compression ============
  
  /// Whether video compression is supported
  bool get isVideoCompressionSupported;
  
  /// Compress video at the given path
  Future<String?> compressVideo(String path);
  
  // ============ Calling Features ============
  
  /// Whether voice/video calling is supported
  bool get isCallingSupported;
  
  /// Whether group calling is supported
  bool get isGroupCallingSupported;
  
  // ============ Location ============
  
  /// Whether location services are supported
  bool get isLocationSupported;
  
  /// Request location permission
  Future<bool> requestLocationPermission();
  
  // ============ Vibration ============
  
  /// Whether vibration is supported
  bool get isVibrationSupported;
  
  /// Vibrate the device
  Future<void> vibrate({int duration = 500});
  
  // ============ File System ============
  
  /// Get the temporary directory path
  Future<String> getTemporaryDirectoryPath();
  
  /// Get the application documents directory path
  Future<String> getApplicationDocumentsDirectoryPath();
}
