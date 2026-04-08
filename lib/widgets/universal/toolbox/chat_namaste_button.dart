import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Animated namaste button for chat input with press -> grow -> fade animation
class ChatNamasteButton extends StatefulWidget {
  final VoidCallback onTap;

  const ChatNamasteButton({super.key, required this.onTap});

  @override
  State<ChatNamasteButton> createState() => _ChatNamasteButtonState();
}

class _ChatNamasteButtonState extends State<ChatNamasteButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;
  Animation<double>? _opacityAnimation;
  bool _isAnimating = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    // Phase 1 (0-10%): Press down hard (shrink to 0.4x)
    // Phase 2 (10-40%): Grow to 1.8x
    // Phase 3 (40-100%): Stay at 1.8x while fading out
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.4)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 1.8)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.8, end: 1.8),
        weight: 60,
      ),
    ]).animate(_controller!);

    // Opacity: stays full until fade phase
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 65,
      ),
    ]).animate(_controller!);

    _isInitialized = true;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_isAnimating || !_isInitialized || _controller == null) return;

    setState(() => _isAnimating = true);
    HapticFeedback.lightImpact();

    // Call callback immediately so UI updates instantly
    widget.onTap();

    // Animation plays in parallel (purely visual)
    _controller!.forward(from: 0).then((_) {
      HapticFeedback.mediumImpact();
    });
  }

  Widget _buildNamasteIcon() {
    return Image.asset(
      'assets/icons/namaste.png',
      width: 36,
      height: 36,
      errorBuilder: (_, __, ___) => Text(
        '\u{1F64F}',
        style: TextStyle(fontSize: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show static tappable button if not initialized yet
    if (!_isInitialized || _controller == null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: _buildNamasteIcon(),
        ),
      );
    }

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _controller!,
          builder: (context, child) {
            final scale = _scaleAnimation?.value ?? 1.0;
            final opacity = _opacityAnimation?.value ?? 1.0;

            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
          child: _buildNamasteIcon(),
        ),
      ),
    );
  }
}
