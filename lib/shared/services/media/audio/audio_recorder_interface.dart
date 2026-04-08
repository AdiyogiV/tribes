import 'dart:typed_data';

/// Abstract interface for audio recording across platforms
/// Web uses MediaRecorder API, mobile uses `record` package
abstract class AudioRecorderInterface {
  /// Initialize the recorder and request permissions
  Future<bool> initialize();

  /// Start recording audio
  /// Returns true if recording started successfully
  Future<bool> startRecording();

  /// Stop recording and return the audio data as bytes
  /// Returns null if recording was not active
  Future<Uint8List?> stopRecording();

  /// Cancel the current recording without saving
  Future<void> cancelRecording();

  /// Whether the recorder is currently recording
  bool get isRecording;

  /// Whether the recorder has been initialized
  bool get isInitialized;

  /// Get the MIME type of the recorded audio
  /// - Mobile: audio/m4a or audio/aac
  /// - Web: audio/webm
  String get mimeType;

  /// Get the file extension for the recorded audio
  /// - Mobile: .m4a
  /// - Web: .webm
  String get fileExtension;

  /// Dispose the recorder and release resources
  void dispose();
}

/// Result of an audio recording
class AudioRecordingResult {
  /// The recorded audio data
  final Uint8List bytes;

  /// Duration of the recording in seconds
  final int durationSeconds;

  /// MIME type of the audio
  final String mimeType;

  /// File extension (including dot)
  final String fileExtension;

  const AudioRecordingResult({
    required this.bytes,
    required this.durationSeconds,
    required this.mimeType,
    required this.fileExtension,
  });
}
