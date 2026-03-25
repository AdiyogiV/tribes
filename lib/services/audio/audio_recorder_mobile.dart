import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:aurogram/services/audio/audio_recorder_interface.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Mobile implementation of AudioRecorderInterface using `record` package
class AppAudioRecorder implements AudioRecorderInterface {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isInitialized = false;
  String? _currentPath;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        AppLogger.w('Microphone permission denied', category: LogCategory.media);
        return false;
      }

      _isInitialized = true;
      AppLogger.d('Mobile audio recorder initialized', category: LogCategory.media);
      return true;
    } catch (e) {
      AppLogger.e('Failed to initialize mobile audio recorder', 
          category: LogCategory.media, error: e);
      return false;
    }
  }

  @override
  Future<bool> startRecording() async {
    if (_isRecording) return false;
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      // Check if we can record
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        AppLogger.w('No recording permission', category: LogCategory.media);
        return false;
      }

      // Get temp directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPath = '${tempDir.path}/voice_recording_$timestamp.m4a';

      // Start recording with AAC codec
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentPath!,
      );

      _isRecording = true;
      AppLogger.d('Mobile audio recording started', category: LogCategory.media);
      return true;
    } catch (e) {
      AppLogger.e('Failed to start mobile audio recording', 
          category: LogCategory.media, error: e);
      return false;
    }
  }

  @override
  Future<Uint8List?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null || path.isEmpty) {
        AppLogger.w('No recording path returned', category: LogCategory.media);
        return null;
      }

      // Read the file as bytes
      final file = File(path);
      if (!await file.exists()) {
        AppLogger.w('Recording file does not exist', category: LogCategory.media);
        return null;
      }

      final bytes = await file.readAsBytes();
      
      // Clean up the temp file
      await file.delete().catchError((_) => file);

      AppLogger.d('Mobile audio recording stopped, bytes: ${bytes.length}', 
          category: LogCategory.media);
      return bytes;
    } catch (e) {
      AppLogger.e('Failed to stop mobile audio recording', 
          category: LogCategory.media, error: e);
      _isRecording = false;
      return null;
    }
  }

  @override
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder.cancel();
      _isRecording = false;
      _currentPath = null;

      AppLogger.d('Mobile audio recording cancelled', category: LogCategory.media);
    } catch (e) {
      AppLogger.e('Failed to cancel mobile audio recording', 
          category: LogCategory.media, error: e);
    }
  }

  @override
  bool get isRecording => _isRecording;

  @override
  bool get isInitialized => _isInitialized;

  @override
  String get mimeType => 'audio/m4a';

  @override
  String get fileExtension => '.m4a';

  @override
  void dispose() {
    cancelRecording();
    _recorder.dispose();
    _isInitialized = false;
    AppLogger.d('Mobile audio recorder disposed', category: LogCategory.media);
  }
}
