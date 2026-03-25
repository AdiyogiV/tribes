import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

// Conditional imports for platform-specific implementations
import 'voice_recorder_controller_stub.dart'
    if (dart.library.io) 'voice_recorder_controller_mobile.dart'
    if (dart.library.html) 'voice_recorder_controller_web.dart'
    as platform_impl;

/// Singleton controller for voice recording.
/// Lives outside the widget tree to survive widget rebuilds.
/// Supports both mobile (flutter_sound) and web (MediaRecorder API).
class VoiceRecorderController {
  static final VoiceRecorderController _instance =
      VoiceRecorderController._internal();
  factory VoiceRecorderController() => _instance;
  VoiceRecorderController._internal();

  final platform_impl.PlatformVoiceRecorder _platformRecorder =
      platform_impl.PlatformVoiceRecorder();

  bool _isRecording = false;
  Duration _duration = Duration.zero;
  Timer? _timer;
  String? _recordingPath;
  Uint8List? _recordingBytes;

  // Stream controller for UI updates
  final _stateController = StreamController<VoiceRecorderState>.broadcast();
  Stream<VoiceRecorderState> get stateStream => _stateController.stream;

  VoiceRecorderState get currentState => VoiceRecorderState(
        isRecording: _isRecording,
        duration: _duration,
        recordingPath: _recordingPath,
        recordingBytes: _recordingBytes,
      );

  bool get isRecording => _isRecording;
  Duration get duration => _duration;
  String? get recordingPath => _recordingPath;
  Uint8List? get recordingBytes => _recordingBytes;

  /// Get the file extension for the current platform
  String get fileExtension => _platformRecorder.fileExtension;

  /// Get the mime type for the current platform
  String get mimeType => _platformRecorder.mimeType;

  /// Initialize the recorder (call once on app start or first use)
  /// NOTE: This will request microphone permission. Only call when user actually wants to record.
  Future<void> init() async {
    if (_platformRecorder.isInitialized) return;

    try {
      await _platformRecorder.initialize();
      AppLogger.i('VoiceRecorderController initialized',
          category: LogCategory.voice);
    } catch (e) {
      AppLogger.e('Failed to init voice recorder: $e',
          category: LogCategory.voice);
    }
  }

  /// Start recording
  Future<bool> startRecording() async {
    // Initialize if needed
    if (!_platformRecorder.isInitialized) {
      await init();
    }

    if (!_platformRecorder.isInitialized) {
      AppLogger.e('Recorder not available', category: LogCategory.voice);
      return false;
    }

    try {
      final started = await _platformRecorder.startRecording();
      if (!started) {
        AppLogger.w('Failed to start platform recorder',
            category: LogCategory.voice);
        return false;
      }

      _isRecording = true;
      _duration = Duration.zero;
      _recordingPath = null;
      _recordingBytes = null;

      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _duration = Duration(seconds: timer.tick);
        _emitState();
      });

      _emitState();
      AppLogger.i('Voice recording started', category: LogCategory.voice);
      return true;
    } catch (e) {
      AppLogger.e('Failed to start recording: $e', category: LogCategory.voice);
      return false;
    }
  }

  /// Stop recording and return the file path (mobile) or marker string (web)
  /// On web, use recordingBytes to get the actual audio data
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    _timer?.cancel();
    _timer = null;

    try {
      final result = await _platformRecorder.stopRecording();
      _isRecording = false;

      final recordedDuration = _duration;

      // Validate recording
      if (recordedDuration.inSeconds < 1) {
        AppLogger.w('Recording too short', category: LogCategory.voice);
        _cleanup();
        return null;
      }

      if (result == null) {
        AppLogger.e('Recording result is null', category: LogCategory.voice);
        _cleanup();
        return null;
      }

      // Store result based on platform
      if (kIsWeb) {
        // Web returns bytes
        _recordingBytes = result as Uint8List;
        _recordingPath = 'web_recording'; // Marker for web
      } else {
        // Mobile returns path
        _recordingPath = result as String;
      }

      _emitState();

      AppLogger.i('Voice recording stopped',
          category: LogCategory.voice,
          data: {
            'duration': recordedDuration.inSeconds,
            'isWeb': kIsWeb,
            'hasBytes': _recordingBytes != null,
            'path': _recordingPath,
          });

      return _recordingPath;
    } catch (e) {
      AppLogger.e('Failed to stop recording: $e', category: LogCategory.voice);
      _cleanup();
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    _timer?.cancel();
    _timer = null;

    try {
      await _platformRecorder.cancelRecording();
    } catch (e) {
      // Ignore errors during cancel
    }

    _cleanup();
    _emitState();
    AppLogger.i('Voice recording cancelled', category: LogCategory.voice);
  }

  void _cleanup() {
    _isRecording = false;
    _duration = Duration.zero;
    _recordingPath = null;
    _recordingBytes = null;

    // Platform-specific cleanup
    _platformRecorder.cleanup();
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(currentState);
    }
  }

  /// Dispose the recorder (call on app close)
  Future<void> dispose() async {
    _timer?.cancel();
    _platformRecorder.dispose();
    await _stateController.close();
  }
}

/// Immutable state for voice recorder
class VoiceRecorderState {
  final bool isRecording;
  final Duration duration;
  final String? recordingPath;
  final Uint8List? recordingBytes;

  const VoiceRecorderState({
    required this.isRecording,
    required this.duration,
    this.recordingPath,
    this.recordingBytes,
  });
}
