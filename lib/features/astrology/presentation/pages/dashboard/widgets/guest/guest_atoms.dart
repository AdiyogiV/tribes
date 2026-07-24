import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette
// ─────────────────────────────────────────────────────────────────────────────

const Color kGuestSaffron = Color(0xFFE2571E);
const Color kGuestHaldi = Color(0xFFD99A00);
Color get kGuestJyotish => AppTheme.cosmicPurple;
Color get kGuestAyurveda => AppTheme.emeraldGreen;
Color get kGuestCircles => AppTheme.skyBlue;

// ─────────────────────────────────────────────────────────────────────────────
// Small atoms
// ─────────────────────────────────────────────────────────────────────────────

class GuestEyebrow extends StatelessWidget {
  const GuestEyebrow({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 3.0,
      ),
    );
  }
}

class GuestPrimaryCta extends StatelessWidget {
  const GuestPrimaryCta({
    super.key,
    required this.label,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fgMain = isDark ? Colors.white : Colors.black;
    final bgMain = isDark ? Colors.black : Colors.white;
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
        decoration: BoxDecoration(
          color: fgMain,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: bgMain,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 16, color: bgMain),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Celestial Astrolabe (Abstract mark)
// ─────────────────────────────────────────────────────────────────────────────

/// The deeply abstract, elegant orbital model (restored).
class GuestMandalaMark extends StatelessWidget {
  const GuestMandalaMark({super.key, required this.size, required this.isDark});

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AstrolabePainter(isDark: isDark),
        child: const SizedBox.shrink(),
      ),
    );
  }
}

class _AstrolabePainter extends CustomPainter {
  _AstrolabePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    
    final lineBase = isDark ? Colors.white : Colors.black;
    final thinLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = lineBase.withValues(alpha: 0.08);
      
    final thickLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = lineBase.withValues(alpha: 0.15);

    // Outer boundary
    canvas.drawCircle(center, maxR * 0.9, thinLine);
    canvas.drawCircle(center, maxR * 0.88, thinLine);

    // Intersecting orbital planes
    canvas.save();
    canvas.translate(center.dx, center.dy);
    
    // Plane 1
    canvas.rotate(math.pi / 6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: maxR * 1.7, height: maxR * 0.4), 
      thickLine
    );
    
    // Plane 2
    canvas.rotate(math.pi / 3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: maxR * 1.6, height: maxR * 0.2), 
      thinLine
    );
    
    // Plane 3
    canvas.rotate(math.pi / 3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: maxR * 1.8, height: maxR * 0.6), 
      thickLine
    );
    
    canvas.restore();

    // Celestial nodes (Planets/Intersections)
    final nodeGlow = Paint()
      ..color = kGuestSaffron.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      
    final nodeSolid = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.8);

    void drawNode(double angle, double distance, double r) {
      final p = center + Offset(math.cos(angle), math.sin(angle)) * (maxR * distance);
      canvas.drawCircle(p, r * 4, nodeGlow);
      canvas.drawCircle(p, r, nodeSolid);
    }

    drawNode(math.pi / 4, 0.6, 2.5);
    drawNode(-math.pi / 6, 0.8, 1.5);
    drawNode(math.pi * 0.8, 0.4, 3.0);
    drawNode(math.pi * 1.2, 0.85, 2.0);

    // Central anchor
    canvas.drawCircle(center, 4.0, nodeSolid);
    canvas.drawCircle(center, maxR * 0.15, thinLine);
  }

  @override
  bool shouldRepaint(covariant _AstrolabePainter old) => old.isDark != isDark;
}
