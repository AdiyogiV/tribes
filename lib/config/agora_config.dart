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
  
  /// Your Agora App ID from the Agora Console
  static const String appId = '89a0a2f0e6c9488fbc657ec4c1dac6eb';
  
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

