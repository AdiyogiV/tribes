/// Stub implementation for static analysis
/// This file is never actually used at runtime
class PlatformVoiceRecorder {
  bool get isInitialized => false;
  String get fileExtension => '.m4a';
  String get mimeType => 'audio/mp4';
  
  Future<bool> initialize() async => false;
  Future<bool> startRecording() async => false;
  Future<dynamic> stopRecording() async => null;
  Future<void> cancelRecording() async {}
  void cleanup() {}
  void dispose() {}
}
