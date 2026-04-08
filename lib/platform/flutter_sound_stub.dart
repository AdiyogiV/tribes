/// Stub for flutter_sound on web platform
/// These classes provide the same interface but do nothing on web
library;

class FlutterSoundRecorder {
  Future<void> openRecorder() async {}
  Future<void> closeRecorder() async {}
  Future<void> startRecorder({String? toFile, Codec? codec}) async {}
  Future<String?> stopRecorder() async => null;
  bool get isRecording => false;
}

enum Codec {
  aacMP4,
  aacADTS,
  opus,
  vorbisOGG,
  pcm16,
  pcm16WAV,
}
