import 'dart:typed_data';
import 'package:aurogram/services/audio/audio_recorder_interface.dart';

/// Stub implementation of AudioRecorderInterface
/// Used as fallback when no platform-specific implementation is available
class AppAudioRecorder implements AudioRecorderInterface {
  @override
  Future<bool> initialize() async {
    return false;
  }

  @override
  Future<bool> startRecording() async {
    throw UnsupportedError('Audio recording is not supported on this platform');
  }

  @override
  Future<Uint8List?> stopRecording() async {
    return null;
  }

  @override
  Future<void> cancelRecording() async {}

  @override
  bool get isRecording => false;

  @override
  bool get isInitialized => false;

  @override
  String get mimeType => 'audio/webm';

  @override
  String get fileExtension => '.webm';

  @override
  void dispose() {}
}
