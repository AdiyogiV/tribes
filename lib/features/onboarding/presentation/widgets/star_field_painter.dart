import 'dart:math' as math;
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Custom painter for animated star field background in onboarding
class StarFieldPainter extends CustomPainter {
  final double rotation;
  final Color color;

  StarFieldPainter({required this.rotation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random(42);

    for (int i = 0; i < 60; i++) {
      final angle = (i / 60) * 2 * math.pi + rotation;
      final distance = 50 + random.nextDouble() * (size.width / 2 - 30);
      final starSize = 1.0 + random.nextDouble() * 2.5;

      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      final edgeFade = 1.0 -
          (math.max(
                (x - size.width / 2).abs() / (size.width / 2),
                (y - size.height / 2).abs() / (size.height / 2),
              ) *
              0.7);

      if (x > 0 && x < size.width && y > 0 && y < size.height && edgeFade > 0) {
        canvas.drawCircle(
          Offset(x, y),
          starSize * edgeFade,
          paint..color = color.withValues(alpha: color.a * edgeFade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(StarFieldPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

/// Animated star field background widget
class AnimatedStarField extends StatelessWidget {
  final Animation<double> rotationAnimation;
  final double alphaMultiplier;

  const AnimatedStarField({
    super.key,
    required this.rotationAnimation,
    this.alphaMultiplier = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: rotationAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: StarFieldPainter(
            rotation: rotationAnimation.value * 2 * math.pi,
            color: AppTheme.cosmicPurple.withValues(alpha: alphaMultiplier),
          ),
        );
      },
    );
  }
}
