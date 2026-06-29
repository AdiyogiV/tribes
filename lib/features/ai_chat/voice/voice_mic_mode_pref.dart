import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurogram/features/ai_chat/voice/voice_engine_pref.dart';

/// How the microphone behaves during a voice call.
///
/// * [waitTurn] — HALF-DUPLEX. The mic only streams while it's the user's turn
///   (the `listening` state). While Aryabhatt is thinking or speaking the mic
///   is muted, so his own voice / room noise can never leak in and trigger a
///   false "interrupt" or garble the next turn. Simplest and most robust.
/// * [openMic] — FULL-DUPLEX. The mic streams for the whole call, so the user
///   can talk over Aryabhatt to cut him off (barge-in). More natural, but only
///   the Live engine actually acts on barge-in, and CX (with no echo guard)
///   would transcribe Aryabhatt's own voice if it streamed during playback.
enum VoiceMicMode { waitTurn, openMic }

/// Persisted, app-wide microphone behaviour. Read at the start of each call, so
/// flipping it takes effect on the NEXT call — no rebuild, no redeploy. This is
/// a CLIENT-SIDE gate (the controller simply withholds mic frames when it isn't
/// the user's turn), so the gate logic is identical for both engines.
///
/// The default is **engine-aware** (see [defaultFor]) because the two engines
/// have opposite needs:
///   * Live's headline feature is native VAD barge-in, which only fires if the
///     mic streams DURING playback → it wants [openMic].
///   * CX has no interrupt handling and no echo guard, so streaming during
///     playback makes it transcribe Aryabhatt's own echo → it needs [waitTurn].
///
/// A user can still override the smart default via [set]; once they do, that
/// explicit choice sticks for both engines until cleared.
class VoiceMicModePref {
  VoiceMicModePref._();

  static const String _key = 'voice_mic_mode';

  /// The smart default mic mode for a given [engine], used when the user has
  /// not explicitly overridden it. Live → full-duplex (barge-in), CX →
  /// half-duplex (echo-proof).
  ///
  /// EXCEPTION: on web we always force [waitTurn], even for Live. The Live
  /// API does VAD but NO acoustic echo cancellation, and the browser can't
  /// cancel flutter_sound's Web Audio output from the mic either — so an open
  /// mic on web just feeds Aryabhatt's own voice back into the VAD and he
  /// talks to himself. [waitTurn] (mic muted while he speaks) is the only
  /// reliable guard there; barge-in never worked on web anyway.
  static VoiceMicMode defaultFor(VoiceEngine engine) {
    if (kIsWeb) return VoiceMicMode.waitTurn;
    return engine == VoiceEngine.live
        ? VoiceMicMode.openMic
        : VoiceMicMode.waitTurn;
  }

  /// The user's explicit override, or `null` if they've never touched the
  /// toggle (in which case the effective mode is derived from the engine).
  static Future<VoiceMicMode?> readOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == VoiceMicMode.openMic.name) return VoiceMicMode.openMic;
    if (raw == VoiceMicMode.waitTurn.name) return VoiceMicMode.waitTurn;
    return null;
  }

  /// The mic mode that actually applies for [engine]: the user's explicit
  /// choice if any, otherwise the engine-aware smart default.
  static Future<VoiceMicMode> effectiveFor(VoiceEngine engine) async {
    return await readOverride() ?? defaultFor(engine);
  }

  /// Persist an explicit mic-mode override. Takes effect on the next call.
  static Future<void> set(VoiceMicMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
