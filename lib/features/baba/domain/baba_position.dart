import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Offset;
import 'package:shared_preferences/shared_preferences.dart';

/// Where the user has parked Baba's floating blob.
///
/// `null` = the default anchored spot (bottom-right, above whatever bar the
/// screen shows — see [BabaInsets]). Once the user drags him, we remember the
/// exact top-left offset (logical px) and persist it so he stays put across
/// navigation AND app restarts. The overlay always re-clamps to the current
/// screen bounds on render, so a spot saved on a bigger screen can never strand
/// him off-screen.
///
/// App-scoped singleton (the overlay is mounted once), so it survives every
/// route change for free.
class BabaPosition extends ChangeNotifier {
  BabaPosition._() {
    _load();
  }
  static final BabaPosition instance = BabaPosition._();

  static const String _keyX = 'baba_pos_dx';
  static const String _keyY = 'baba_pos_dy';

  Offset? _offset;

  /// The user's parked top-left offset, or null for the default anchored spot.
  Offset? get offset => _offset;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_keyX);
    final y = prefs.getDouble(_keyY);
    if (x != null && y != null) {
      _offset = Offset(x, y);
      notifyListeners();
    }
  }

  /// Live update DURING a drag — cheap, frequent, not persisted.
  void update(Offset offset) {
    if (_offset == offset) return;
    _offset = offset;
    notifyListeners();
  }

  /// Commit + persist when the drag ends.
  Future<void> commit(Offset offset) async {
    update(offset);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyX, offset.dx);
    await prefs.setDouble(_keyY, offset.dy);
  }

  /// Send Baba back to his default anchored spot.
  Future<void> reset() async {
    _offset = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyX);
    await prefs.remove(_keyY);
  }
}
