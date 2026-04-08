import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Mobile implementation using flutter_sound
class PlatformVoiceRecorder {
  FlutterSoundRecorder? _recorder;
  bool _isInitialized = false;
  String? _recordingPath;

  bool get isInitialized => _isInitialized;
  String get fileExtension => '.m4a';
  String get mimeType => 'audio/mp4';

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _recorder = FlutterSoundRecorder(logLevel: Level.off);
      await _recorder!.openRecorder();
      _isInitialized = true;
      AppLogger.d('Mobile voice recorder initialized',
          category: LogCategory.voice);
      return true;
    } catch (e) {
      AppLogger.e('Failed to init mobile voice recorder: $e',
          category: LogCategory.voice);
      return false;
    }
  }

  Future<bool> startRecording() async {
    // Initialize if needed (lazy initialization - only when user wants to record)
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_recorder == null || !_isInitialized) {
      return false;
    }

    // Request permission (in case it was revoked or not yet granted)
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      AppLogger.w('Microphone permission denied', category: LogCategory.voice);
      return false;
    }

    try {
      // Get temp directory and create path
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${tempDir.path}/voice_$timestamp.m4a';

      await _recorder!.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacMP4,
      );

      return true;
    } catch (e) {
      AppLogger.e('Failed to start mobile recording: $e',
          category: LogCategory.voice);
      return false;
    }
  }

  /// Returns the file path as String
  Future<String?> stopRecording() async {
    if (_recorder == null) return null;

    try {
      await _recorder!.stopRecorder();

      final path = _recordingPath;

      // Validate file exists
      if (path == null || !File(path).existsSync()) {
        AppLogger.e('Recording file not found', category: LogCategory.voice);
        return null;
      }

      return path;
    } catch (e) {
      AppLogger.e('Failed to stop mobile recording: $e',
          category: LogCategory.voice);
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _recorder?.stopRecorder();
    } catch (e) {
      // Ignore errors during cancel
    }
  }

  void cleanup() {
    // Delete temp file if exists
    if (_recordingPath != null) {
      try {
        final file = File(_recordingPath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {
        AppLogger.w('VoiceRecorderMobile: failed to delete recording file', category: LogCategory.general);
      }
    }
    _recordingPath = null;
  }

  void dispose() {
    _recorder?.closeRecorder();
    _isInitialized = false;
  }
}
