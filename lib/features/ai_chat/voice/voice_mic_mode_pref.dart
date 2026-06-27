import 'package:shared_preferences/shared_preferences.dart';

/// How the microphone behaves during a voice call.
///
/// * [waitTurn] — HALF-DUPLEX. The mic only streams while it's the user's turn
///   (the `listening` state). While Aryabhatt is thinking or speaking the mic
///   is muted, so his own voice / room noise can never leak in and trigger a
///   false "interrupt" or garble the next turn. Simplest and most robust.
/// * [openMic] — FULL-DUPLEX. The mic streams for the whole call, so the user
///   can talk over Aryabhatt to cut him off (barge-in). More natural, but only
///   the Live engine actually acts on barge-in, and it's more sensitive to
///   echo/noise.
enum VoiceMicMode { waitTurn, openMic }

/// Persisted, app-wide microphone behaviour. Read at the start of each call, so
/// flipping it takes effect on the NEXT call — no rebuild, no redeploy. This is
/// a CLIENT-SIDE gate (the controller simply withholds mic frames when it isn't
/// the user's turn), so it works identically for both the Live and CX engines.
///
/// Defaults to [VoiceMicMode.waitTurn]: the quiet, echo-proof behaviour. Flip
/// to [VoiceMicMode.openMic] to test talk-over-to-interrupt.
class VoiceMicModePref {
  VoiceMicModePref._();

  static const String _key = 'voice_mic_mode';
  static const VoiceMicMode _default = VoiceMicMode.waitTurn;

  /// Read the saved mic mode (defaults to [_default] if never set).
  static Future<VoiceMicMode> read() async {
    final prefs = await SharedPreferences.getInstance();
    return _fromName(prefs.getString(_key));
  }

  /// Persist the chosen mic mode. Takes effect on the next voice call.
  static Future<void> set(VoiceMicMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  static VoiceMicMode _fromName(String? raw) {
    return raw == VoiceMicMode.openMic.name ? VoiceMicMode.openMic : _default;
  }
}
