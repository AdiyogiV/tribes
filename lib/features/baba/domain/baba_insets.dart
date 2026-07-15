import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Tracks bottom "bars" that would otherwise sit ON TOP of Baba (the tab bar,
/// a page's chat-input bar, etc.) so the app-wide [BabaOverlay] can float just
/// ABOVE them instead of overlapping.
///
/// Same spine idea as the screen-snapshot registry: whoever owns a bottom bar
/// reports its height by a stable id; the overlay lifts by the TALLEST reported
/// obstruction. Report only the bar's own height — the overlay already adds the
/// OS safe-area inset. Pass 0 / [clear] when the bar hides or unmounts.
class BabaInsets extends ChangeNotifier {
  BabaInsets._();
  static final BabaInsets instance = BabaInsets._();

  final Map<String, double> _bars = {};

  /// Report (or update) a bottom obstruction's height above the safe area.
  void set(String id, double height) {
    final h = height < 0 ? 0.0 : height;
    if (_bars[id] == h || (h == 0 && !_bars.containsKey(id))) return;
    if (h == 0) {
      _bars.remove(id);
    } else {
      _bars[id] = h;
    }
    _notify();
  }

  /// Stop reporting an obstruction (call on hide / dispose).
  void clear(String id) => set(id, 0);

  /// Notify safely. [clear] is often called from a widget's `dispose()`, which
  /// runs while the framework is finalizing the tree (locked) — notifying then
  /// throws "setState()/markNeedsBuild() called when widget tree was locked".
  /// During a frame we defer to the next one; otherwise we notify immediately.
  void _notify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final locked = phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (locked) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  /// How far the overlay must lift to clear every reported bar.
  double get bottomObstruction =>
      _bars.isEmpty ? 0 : _bars.values.reduce((a, b) => a > b ? a : b);
}
