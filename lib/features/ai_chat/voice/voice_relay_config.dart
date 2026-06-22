/// Configuration for the live voice relay (Cloud Run -> Dialogflow CX).
///
/// Override at build time with:
///   flutter run --dart-define=VOICE_RELAY_URL=wss://your-relay.run.app/voice
class VoiceRelayConfig {
  VoiceRelayConfig._();

  /// WebSocket endpoint of the deployed `voice-relay` Cloud Run service.
  /// Defaults to the deployed Cloud Run service so plain `flutter run` works
  /// on a real device. For local relay dev, override via --dart-define:
  ///   --dart-define=VOICE_RELAY_URL=ws://<your-mac-LAN-ip>:8080/voice
  static const String relayUrl = String.fromEnvironment(
    'VOICE_RELAY_URL',
    defaultValue:
        'wss://aryabhatt-voice-relay-7p5vte54jq-uc.a.run.app/voice',
  );

  /// Mic capture rate the relay (and Dialogflow CX) expects: PCM16, 16 kHz, mono.
  static const int micSampleRate = 16000;

  /// TTS playback rate the relay sends back: PCM16, 24 kHz, mono.
  static const int ttsSampleRate = 24000;
}
