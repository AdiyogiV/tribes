import 'package:flutter/foundation.dart';

/// App-scoped coordinator for Baba's ambient presence.
///
/// Baba lives in ONE place at a time even though two widgets can render him:
///   * the dashboard cow (rich, docked above the profile tab), and
///   * the [BabaShell] orb (global, floats over every other screen).
///
/// This flag decides who's on stage so we never show two Babas:
///   * [dashboardActive] — the dashboard cow is on-screen → the shell hides.
///   * [dismissed]       — the user crossed Baba off → the shell shows only a
///     small summon dot until they bring him back.
///
/// Both presences share the one [VoiceSessionController] singleton, so a call
/// started on the dashboard keeps going as the orb takes over elsewhere.
class BabaPresence extends ChangeNotifier {
  BabaPresence._();
  static final BabaPresence instance = BabaPresence._();

  bool _dashboardActive = false;
  bool _dismissed = false;

  bool get dashboardActive => _dashboardActive;
  bool get dismissed => _dismissed;

  /// The global shell orb should render its full presence right now.
  bool get shellVisible => !_dashboardActive && !_dismissed;

  set dashboardActive(bool value) {
    if (_dashboardActive == value) return;
    _dashboardActive = value;
    notifyListeners();
  }

  /// User crossed Baba off — collapse to a summon dot.
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    notifyListeners();
  }

  /// Bring Baba back from the summon dot.
  void summon() {
    if (!_dismissed) return;
    _dismissed = false;
    notifyListeners();
  }
}
