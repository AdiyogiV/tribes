/// Configuration for the live voice relay (Cloud Run -> Dialogflow CX).
///
/// Override at build time with:
///   flutter run --dart-define=VOICE_RELAY_URL=wss://your-relay.run.app/voice
class VoiceRelayConfig {
  VoiceRelayConfig._();

  /// WebSocket endpoint of the deployed `voice-relay` Cloud Run service.
  /// Defaults to the deployed Cloud Run service so plain `flutter run` works
  /// on a real device. For local relay dev, override via --dart-define:
  ///   --dart-define=VOICE_RELAY_URL=ws://YOUR-MAC-LAN-IP:8080/voice
  static const String relayUrl = String.fromEnvironment(
    'VOICE_RELAY_URL',
    defaultValue:
        'wss://aryabhatt-voice-relay-7p5vte54jq-uc.a.run.app/voice',
  );

  /// Mic capture rate the relay (and Dialogflow CX) expects: PCM16, 16 kHz, mono.
  static const int micSampleRate = 16000;

  /// TTS playback rate the relay sends back: PCM16, 24 kHz, mono.
  static const int ttsSampleRate = 24000;

  /// Playback speed multiplier for Aryabhatt's replies. The Live API gives no
  /// server-side speaking-rate knob on native audio, so we speed playback up by
  /// handing the player a slightly higher sample rate. 1.0 = original pace,
  /// 1.12 = ~12% snappier. Side effect: pitch rises by the same factor, barely
  /// noticeable up to ~1.15 on the deep Charon voice. Bump if still too slow.
  static const double playbackSpeed = 1.12;

  /// Sample rate actually handed to the player = base rate x speed. Same PCM
  /// frames played at a higher rate => the speech finishes sooner => faster.
  static int get ttsPlaybackSampleRate =>
      (ttsSampleRate * playbackSpeed).round();
}
