import 'package:flutter/material.dart';

/// A pulsating dot with glow — used as a "now" / live-time indicator
/// on the muhurat timeline and the nakshatra ring.
class PulsingDot extends StatefulWidget {
  final double size;
  final Color color;
  final double borderWidth;
  final Color borderColor;
  final bool showShadow;

  const PulsingDot({
    super.key,
    this.size = 10,
    this.color = const Color(0xFF1E88E5), // blue.shade600
    this.borderColor = Colors.white,
    this.borderWidth = 1.5,
    this.showShadow = false,
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(_controller),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.borderColor,
            width: widget.borderWidth,
          ),
          boxShadow: widget.showShadow
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.6),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
