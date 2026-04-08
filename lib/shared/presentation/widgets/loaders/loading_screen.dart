import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// A loading screen widget that displays a pulsing animation.
class LoadingScreen extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const LoadingScreen({
    super.key,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) {
          return Center(
            child: CustomPaint(
              painter: _LoadingPulsePainter(
                pulseValue: pulseAnimation.value,
              ),
              child: const SizedBox(
                width: 100,
                height: 100,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A simple pulse painter for loading animations.
class _LoadingPulsePainter extends CustomPainter {
  final double pulseValue;

  _LoadingPulsePainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pulseColor = AppTheme.primaryColor;

    // Outer glow
    final outerGlowPaint = Paint()
      ..color = pulseColor.withValues(alpha: 0.15 * pulseValue)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 40 * pulseValue, outerGlowPaint);

    // Middle glow
    final middleGlowPaint = Paint()
      ..color = pulseColor.withValues(alpha: 0.3 * pulseValue)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 25 * pulseValue, middleGlowPaint);

    // Inner glow
    final innerGlowPaint = Paint()
      ..color = pulseColor.withValues(alpha: 0.6 * pulseValue)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 15 * pulseValue, innerGlowPaint);

    // Core dot
    final dotPaint = Paint()
      ..color = pulseColor.withValues(alpha: pulseValue)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, dotPaint);

    // Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6 * pulseValue)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - 2, center.dy - 2), 3, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _LoadingPulsePainter oldDelegate) {
    return pulseValue != oldDelegate.pulseValue;
  }
}
