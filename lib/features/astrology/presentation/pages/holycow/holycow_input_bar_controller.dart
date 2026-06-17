import 'package:flutter/widgets.dart';

/// Owns the state of the HolyCow dashboard's collapsible AI input bar.
///
/// This consolidates what used to be four scattered `setState` mutations on the
/// page into one place, with a single intent per gesture:
///   * scroll down              → [collapseIfUnfocused]
///   * tap anywhere on the page → [collapseIfUnfocused]
///   * cow icon tap             → [toggle]
///   * text field gains focus   → auto-expand (internal focus listener)
///
/// Crucially it is a [ChangeNotifier]: only the input bar and its layout spacer
/// listen to it. Collapsing the bar mid-scroll therefore rebuilds just those
/// two small subtrees instead of the entire 1000+ line dashboard — which is
/// what used to stall the very first frame of a downward scroll.
class HolyCowInputBarController extends ChangeNotifier {
  HolyCowInputBarController({bool expanded = true}) : _expanded = expanded {
    focusNode.addListener(_onFocusChanged);
  }

  /// Text being composed in the AI input. The page reads/clears this on send.
  final TextEditingController text = TextEditingController();

  /// Focus for the input's [TextField].
  final FocusNode focusNode = FocusNode();

  bool _expanded;

  /// Whether the bar is showing its full input (true) or the collapsed cow.
  bool get expanded => _expanded;

  bool _hidden = false;

  /// Whether the whole bar (cow included) has slid off-screen because the user
  /// is scrolling down — mirrors the tab bar's hide-on-scroll. Separate from
  /// [expanded]: scrolling back up reveals the (still-collapsed) cow.
  bool get hidden => _hidden;

  /// Slide the bar off-screen (true) or back into view (false) on scroll.
  void setHidden(bool value) {
    if (_hidden == value) return;
    _hidden = value;
    notifyListeners();
  }

  /// Whether the text field currently holds focus (keyboard up). The spacer
  /// reserves extra height in this case, so it's part of the listenable state.
  bool get hasFocus => focusNode.hasFocus;

  /// Cow icon tap: flip the state. Collapsing also drops the keyboard.
  void toggle() {
    _expanded = !_expanded;
    if (!_expanded) focusNode.unfocus();
    notifyListeners();
  }

  /// Collapse only when the user isn't actively typing — used by scroll and
  /// tap-elsewhere gestures so we never yank the keyboard away mid-message.
  void collapseIfUnfocused() {
    if (_expanded && !focusNode.hasFocus) {
      _expanded = false;
      notifyListeners();
    }
  }

  void _onFocusChanged() {
    // Gaining focus always expands; we notify regardless because the spacer
    // sizes itself off [hasFocus] even when [expanded] is unchanged.
    if (focusNode.hasFocus) _expanded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    focusNode.removeListener(_onFocusChanged);
    text.dispose();
    focusNode.dispose();
    super.dispose();
  }
}
