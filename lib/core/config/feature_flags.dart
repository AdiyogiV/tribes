import 'package:flutter/foundation.dart';

/// Feature flags for conditionally enabling/disabling features based on platform
/// This class provides centralized feature management for web vs mobile
class FeatureFlags {
  FeatureFlags._();
  
  // ============ Calling Features ============
  
  /// Whether 1:1 voice/video calling is enabled
  /// Enabled on all platforms - flutter_webrtc supports web
  static bool get isCallingEnabled => true;
  
  /// Whether group calling is enabled
  /// Enabled on all platforms - agora_rtc_engine supports web
  static bool get isGroupCallingEnabled => true;
  
  // ============ Contact Features ============
  
  /// Whether contact sync is enabled
  /// Contact sync is not supported on web (browser cannot access device contacts)
  static bool get isContactSyncEnabled => !kIsWeb;
  
  /// Whether invite from contacts is enabled
  static bool get isInviteFromContactsEnabled => !kIsWeb;
  
  // ============ Media Features ============
  
  /// Whether voice message recording is enabled
  /// Enabled on all platforms - web uses MediaRecorder API
  static bool get isVoiceMessageEnabled => true;
  
  /// Whether video upload is enabled
  /// On web, videos are uploaded without compression (no video_compress)
  static bool get isVideoUploadEnabled => true;
  
  /// Whether video compression is available
  /// Not supported on web
  static bool get isVideoCompressionEnabled => !kIsWeb;
  
  /// Whether image compression is available
  /// Supported on all platforms
  static bool get isImageCompressionEnabled => true;
  
  // ============ Notification Features ============
  
  /// Whether local notifications are supported
  /// On web, we use Web Notifications API (with limitations)
  static bool get isLocalNotificationSupported => !kIsWeb;
  
  /// Whether push notifications are supported
  /// Supported on all platforms via FCM
  static bool get isPushNotificationSupported => true;
  
  /// Whether call notifications with actions are supported
  /// Only on mobile due to native notification actions
  static bool get isCallNotificationActionsSupported => !kIsWeb;
  
  // ============ Device Features ============
  
  /// Whether vibration is supported
  static bool get isVibrationSupported => !kIsWeb;
  
  /// Whether camera/photo capture is supported
  static bool get isCameraCaptureSupported => true;
  
  /// Whether location services are supported
  /// Supported on all platforms (web via Geolocation API)
  static bool get isLocationSupported => true;
  
  // ============ Aryabhatt / Voice Features ============

  /// Whether the experimental voice controls are shown in Settings:
  ///   * the voice-engine switch (Premium/Live vs Standard/CX), and
  ///   * the mic-mode switch (Wait-your-turn vs Always-listening).
  ///
  /// Hidden from production users so the app ships with the safe defaults
  /// (Standard Voice + Wait-your-turn). The code is kept intact for internal
  /// testing — these controls appear automatically in debug builds. Flip to
  /// `true` if you need them exposed in a release build for QA.
  static bool get showVoiceLabSettings => kDebugMode;

  // ============ Platform Info ============
  
  /// Whether running on web
  static bool get isWeb => kIsWeb;
  
  /// Whether running on mobile (iOS or Android)
  static bool get isMobile => !kIsWeb;
  
  // ============ Feature Availability Strings ============
  
  /// Get a user-friendly message for disabled features
  static String getFeatureDisabledMessage(String featureName) {
    return '$featureName is not available on web. Please use the mobile app for this feature.';
  }
  
  /// Check if a feature requires mobile and show appropriate message
  static bool checkFeatureAvailable({
    required bool isEnabled,
    required String featureName,
    void Function(String message)? onDisabled,
  }) {
    if (!isEnabled) {
      onDisabled?.call(getFeatureDisabledMessage(featureName));
      return false;
    }
    return true;
  }
}
