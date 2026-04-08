import 'dart:typed_data';
import 'package:aurogram/services/audio/audio_recorder_web.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Web implementation using MediaRecorder API via AppAudioRecorder
class PlatformVoiceRecorder {
  final AppAudioRecorder _recorder = AppAudioRecorder();

  bool get isInitialized => _recorder.isInitialized;
  String get fileExtension => _recorder.fileExtension;
  String get mimeType => _recorder.mimeType;

  Future<bool> initialize() async {
    try {
      final result = await _recorder.initialize();
      AppLogger.d('Web voice recorder initialized: $result', category: LogCategory.voice);
      return result;
    } catch (e) {
      AppLogger.e('Failed to init web voice recorder: $e', category: LogCategory.voice);
      return false;
    }
  }

  Future<bool> startRecording() async {
    try {
      final result = await _recorder.startRecording();
      return result;
    } catch (e) {
      AppLogger.e('Failed to start web recording: $e', category: LogCategory.voice);
      return false;
    }
  }

  /// Returns Uint8List bytes on web
  Future<Uint8List?> stopRecording() async {
    try {
      final bytes = await _recorder.stopRecording();
      AppLogger.d('Web recording stopped, bytes: ${bytes?.length ?? 0}', 
          category: LogCategory.voice);
      return bytes;
    } catch (e) {
      AppLogger.e('Failed to stop web recording: $e', category: LogCategory.voice);
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _recorder.cancelRecording();
    } catch (e) {
      // Ignore errors during cancel
    }
  }

  void cleanup() {
    // No file cleanup needed on web - bytes are in memory
  }

  void dispose() {
    _recorder.dispose();
  }
}
