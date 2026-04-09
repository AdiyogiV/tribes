/// Data models for the audio input subsystem.
library;

enum AudioInputState {
  idle,
  recording, // Both recording audio and transcribing
  processing, // Processing the recording
  error,
}

class AudioInputResult {
  final String transcript;
  final String? audioUrl; // Firebase Storage URL
  final int durationInSeconds;
  final String? localAudioPath; // Temp local path before upload

  const AudioInputResult({
    required this.transcript,
    this.audioUrl,
    required this.durationInSeconds,
    this.localAudioPath,
  });
}
