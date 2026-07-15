import 'package:flutter/foundation.dart';

/// App-scoped switch for Baba's in-place floating chat panel.
///
/// Baba is one app-wrapping presence: a voice-first blob that floats over every
/// route (see `BabaOverlay`). When the user wants to *type* instead of talk —
/// or when Baba himself decides to open chat via a tool — we don't navigate to a
/// separate page (that would break the "I wrap your whole app" illusion). We
/// slide a glass chat sheet up over whatever screen they're on.
///
/// This tiny singleton is the one source of truth for "is the chat sheet open?"
/// so both the overlay UI and Baba's `navigateTo: chat` tool drive the same
/// state without either depending on the other.
class BabaChatController extends ChangeNotifier {
  BabaChatController._();
  static final BabaChatController instance = BabaChatController._();

  bool _open = false;
  bool get isOpen => _open;

  void open() {
    if (_open) return;
    _open = true;
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    notifyListeners();
  }

  void toggle() => _open ? close() : open();
}
