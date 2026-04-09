/// Agora Configuration for Group Calls
///
/// To get your credentials:
/// 1. Go to https://console.agora.io/
/// 2. Create a new project (or select existing)
/// 3. Copy the App ID
/// 4. Enable App Certificate for token authentication (required for production)
///
/// Free Tier: 10,000 minutes/month for both audio and video
class AgoraConfig {
  AgoraConfig._(); // Private constructor

  /// Agora App ID — loaded from environment at build time.
  /// Pass via: --dart-define=AGORA_APP_ID=your_id
  /// Falls back to empty string if not provided (will fail gracefully).
  static const String appId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: '',
  );
  
  /// Whether to use token authentication (recommended for production)
  /// Token is generated server-side via Firebase Cloud Function
  static const bool useTokenAuth = true;
  
  /// Default channel profile for group calls
  /// Communication profile is for real-time voice/video communication
  static const int channelProfile = 0; // 0 = Communication, 1 = Live Broadcasting
  
  /// Video configuration - optimized for mobile
  static const int videoWidth = 640;
  static const int videoHeight = 360;
  static const int videoFrameRate = 15;
  static const int videoBitrate = 400;
  
  /// Audio configuration
  static const int audioSampleRate = 48000;
  static const int audioChannels = 1;
  
  /// Maximum participants in a group call
  static const int maxParticipants = 8;
}

