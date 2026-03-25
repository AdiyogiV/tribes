/// Stub implementation of Agora web helper for non-web platforms
/// 
/// On mobile platforms, the Agora SDK is bundled natively and doesn't
/// need to be loaded via JavaScript.
library;

/// Always returns true on mobile - SDK is bundled natively
bool isAgoraLoaded() => true;

/// No-op on mobile - returns true immediately
Future<bool> loadAgoraSDK() async => true;
