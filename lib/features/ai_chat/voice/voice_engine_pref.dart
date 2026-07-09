import 'package:shared_preferences/shared_preferences.dart';

/// Which voice backend the relay should use for a session.
///
/// * [live] — Gemini Live API (Charon native / half-cascade). Best, most
///   natural voice + native barge-in, but bills to Vertex AI (NOT covered by
///   our trial credits). Reserve for the premium experience.
/// * [cx] — Dialogflow CX generative agent. Slightly less buttery, but its
///   audio sessions are paid by the Dialogflow CX trial credit, so it's
///   effectively free to us until the credit runs out.
enum VoiceEngine { live, cx }

/// Persisted, app-wide choice of voice engine. The relay reads whatever the
/// client sends in its `start` frame, so flipping this changes the NEXT call
/// (no rebuild, no redeploy). Defaults to [VoiceEngine.cx].
///
/// Why cx (not live) by default: the Live engine runs on Vertex AI's preview
/// native-audio model, which needs provisioned quota + billing that isn't set
/// up on this project (trial credits fund the Dialogflow CX path instead). An
/// unprovisioned Live session fails its upstream Vertex WebSocket, which the
/// relay forwards to the client as an opaque "unexpected websocket" error and
/// the call never starts. cx is the funded, working path. Flip back to live
/// (here or via Settings) once Vertex Live quota is granted.
class VoiceEnginePref {
  VoiceEnginePref._();

  static const String _key = 'voice_engine';
  static const VoiceEngine _default = VoiceEngine.cx;

  /// Read the saved engine (defaults to [_default] if never set).
  static Future<VoiceEngine> read() async {
    final prefs = await SharedPreferences.getInstance();
    return _fromWire(prefs.getString(_key));
  }

  /// Persist the chosen engine. Takes effect on the next voice call.
  static Future<void> set(VoiceEngine engine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, engine.name);
  }

  /// The string the relay expects in the `start` frame: 'live' | 'cx'.
  static String wireValue(VoiceEngine engine) => engine.name;

  static VoiceEngine _fromWire(String? raw) {
    // Honour an explicit saved choice for BOTH engines; fall back to _default
    // only when nothing (or something unrecognised) is stored.
    if (raw == VoiceEngine.live.name) return VoiceEngine.live;
    if (raw == VoiceEngine.cx.name) return VoiceEngine.cx;
    return _default;
  }
}
