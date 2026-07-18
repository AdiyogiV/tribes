import 'package:shared_preferences/shared_preferences.dart';

/// Whether Aurobhatt should AUTO-ACTIVATE (go live and greet) when the app or
/// website opens onto the home screen.
///
/// Default **OFF** — a live-mic call that starts talking the instant you open
/// the app is intrusive (it grabs audio focus, holds the mic, and spends a CX
/// turn every launch), so it is strictly opt-in.
///
/// Scope + platform behaviour live in [BabaOverlay], the single owner of the
/// auto-start decision:
///   * he only auto-starts on the HOME screen, at most once per app launch;
///   * on native he starts immediately (after mic permission is granted);
///   * on web — where browsers forbid audio/mic without a user gesture — the
///     overlay ARMS the auto-start to fire on the user's FIRST tap/click
///     anywhere, since a true zero-gesture autoplay is impossible there.
class BabaGreetOnOpenPref {
  BabaGreetOnOpenPref._();

  static const String _key = 'baba_greet_on_open';

  /// The saved preference; defaults to `false` (opt-in).
  static Future<bool> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// Persist the preference. Takes effect on the next app open.
  static Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
