import 'platform_interface.dart';

/// Stub implementation used during conditional imports
/// This should never actually be used at runtime
class StubPlatformServices implements PlatformServices {
  @override
  bool get isWeb => throw UnimplementedError();
  
  @override
  bool get isMobile => throw UnimplementedError();
  
  @override
  bool get isIOS => throw UnimplementedError();
  
  @override
  bool get isAndroid => throw UnimplementedError();
  
  @override
  bool get isContactSyncSupported => throw UnimplementedError();
  
  @override
  Future<bool> requestContactPermission() => throw UnimplementedError();
  
  @override
  Future<bool> hasContactPermission() => throw UnimplementedError();
  
  @override
  bool get isLocalNotificationSupported => throw UnimplementedError();
  
  @override
  Future<bool> requestNotificationPermission() => throw UnimplementedError();
  
  @override
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) => throw UnimplementedError();
  
  @override
  bool get isAudioRecordingSupported => throw UnimplementedError();
  
  @override
  Future<bool> initializeAudioRecording() => throw UnimplementedError();
  
  @override
  Future<bool> requestMicrophonePermission() => throw UnimplementedError();
  
  @override
  bool get isVideoCompressionSupported => throw UnimplementedError();
  
  @override
  Future<String?> compressVideo(String path) => throw UnimplementedError();
  
  @override
  bool get isCallingSupported => throw UnimplementedError();
  
  @override
  bool get isGroupCallingSupported => throw UnimplementedError();
  
  @override
  bool get isLocationSupported => throw UnimplementedError();
  
  @override
  Future<bool> requestLocationPermission() => throw UnimplementedError();
  
  @override
  bool get isVibrationSupported => throw UnimplementedError();
  
  @override
  Future<void> vibrate({int duration = 500}) => throw UnimplementedError();
  
  @override
  Future<String> getTemporaryDirectoryPath() => throw UnimplementedError();
  
  @override
  Future<String> getApplicationDocumentsDirectoryPath() => throw UnimplementedError();
}

/// Initialize stub - should be replaced by actual implementation
void initializePlatform() {
  throw UnimplementedError('Platform initialization not implemented for this target');
}
