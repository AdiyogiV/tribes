import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

/// Animated dark-mode toggle button using a Lottie sun↔moon animation.
///
/// The animation has two halves:
///  • 0 → 0.5  =  sun (light mode) → moon (dark mode)
///  • 0.5 → 1  =  moon (dark mode) → sun (light mode)
///
/// The theme change fires 200 ms into the animation — early enough that
/// the switch feels instant, but late enough that the morph is already
/// visibly underway so both happen together.  The `_animating` guard in
/// `didUpdateWidget` prevents the full-tree rebuild from resetting the
/// controller, so the Lottie playback continues uninterrupted.
class DarkModeToggle extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool>? onChanged;
  final double size;

  const DarkModeToggle({
    super.key,
    required this.isDark,
    this.onChanged,
    this.size = 28,
  });

  @override
  State<DarkModeToggle> createState() => _DarkModeToggleState();
}

class _DarkModeToggleState extends State<DarkModeToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _localDark = false;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _localDark = widget.isDark;
    _controller = AnimationController(vsync: this);
    _controller.value = widget.isDark ? 0.5 : 0.0;
  }

  @override
  void didUpdateWidget(DarkModeToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) {
      _localDark = widget.isDark;
      if (!_animating) {
        _controller.value = widget.isDark ? 0.5 : 0.0;
      }
    }
  }

  void _onTap() {
    if (_animating) return;
    HapticFeedback.lightImpact();
    final newValue = !_localDark;
    setState(() => _localDark = newValue);

    _animating = true;
    final target = newValue ? 0.5 : 1.0;

    // Play a quick 500 ms morph, then fire the theme change.
    _controller
        .animateTo(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    )
        .then((_) {
      if (!mounted) return;
      _animating = false;
      if (!newValue) _controller.value = 0.0;
      widget.onChanged?.call(newValue);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Lottie.asset(
          'assets/animations/dark_mode_button.json',
          controller: _controller,
          fit: BoxFit.contain,
          onLoaded: (composition) {
            _controller.duration = composition.duration;
          },
        ),
      ),
    );
  }
}
