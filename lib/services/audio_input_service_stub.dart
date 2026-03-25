import 'package:flutter/foundation.dart';

/// Stub for AudioInputService on web
/// Audio recording is not supported on web in Phase 1

enum AudioInputState {
  idle,
  recording,
  processing,
  error,
}

class AudioInputResult {
  final String transcript;
  final String? audioUrl;
  final int durationInSeconds;
  final String? localAudioPath;

  const AudioInputResult({
    required this.transcript,
    this.audioUrl,
    required this.durationInSeconds,
    this.localAudioPath,
  });
}

/// Stub AudioInputService for web - audio recording disabled
class AudioInputService extends ChangeNotifier {
  static final AudioInputService _instance = AudioInputService._internal();
  factory AudioInputService() => _instance;
  AudioInputService._internal();

  // State
  AudioInputState _state = AudioInputState.idle;
  String _currentTranscript = '';
  String _errorMessage = '';

  // Getters
  AudioInputState get state => _state;
  String get currentTranscript => _currentTranscript;
  String get errorMessage => _errorMessage;
  bool get isRecording => false;
  bool get isProcessing => false;
  bool get hasError => _state == AudioInputState.error;
  bool get hasSpeechRecognitionError => false;
  String get speechErrorType => '';
  DateTime? get recordingStartTime => null;
  bool get canStartRecording => false;

  /// Initialize - always returns false on web
  Future<bool> initialize() async {
    _setError('Audio recording is not available on web');
    return false;
  }

  /// Start recording - not supported on web
  Future<void> startRecording({
    Function(AudioInputResult)? onResult,
    Function(String)? onTranscriptUpdate,
    bool skipSpeechRecognition = true,
  }) async {
    _setError('Audio recording is not available on web');
  }

  /// Stop recording - no-op on web
  Future<void> stopRecording() async {}

  /// Cancel recording - no-op on web
  Future<void> cancelRecording() async {}

  /// Reset service - no-op on web
  Future<void> resetService() async {
    clearState();
  }

  /// Clear state
  void clearState() {
    _currentTranscript = '';
    _errorMessage = '';
    _state = AudioInputState.idle;
    notifyListeners();
  }

  /// Set callback for audio URL - no-op on web
  void setOnAudioUrlUploaded(Function(String audioUrl)? callback) {}

  /// Set callback for upload skipped - no-op on web
  void setOnAudioUploadSkipped(Function()? callback) {}

  void _setError(String message) {
    _state = AudioInputState.error;
    _errorMessage = message;
    notifyListeners();
  }
}
