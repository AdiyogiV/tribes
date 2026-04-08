import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Faded zodiac wheel background for FTUE page
class ZodiacWheelPainter extends CustomPainter {
  final double rotation;
  final Color primaryColor;
  final double opacity;
  final Map<String, double>?
      planetPositions; // planet name -> longitude (0-360)

  ZodiacWheelPainter({
    this.rotation = 0,
    required this.primaryColor,
    this.opacity = 0.08,
    this.planetPositions,
  });

  // Zodiac symbols
  static const List<String> zodiacSymbols = [
    '♈', // Aries
    '♉', // Taurus
    '♊', // Gemini
    '♋', // Cancer
    '♌', // Leo
    '♍', // Virgo
    '♎', // Libra
    '♏', // Scorpio
    '♐', // Sagittarius
    '♑', // Capricorn
    '♒', // Aquarius
    '♓', // Pisces
  ];

  // Planet symbols for current sky
  // Using non-emoji alternatives for Mars/Venus
  static const Map<String, String> planetSymbols = {
    'Sun': '☉',
    'Moon': '☽',
    'Mars': '✦', // Star symbol (Mars energy)
    'Mercury': '☿',
    'Jupiter': '♃',
    'Venus': '✧', // Open star (Venus energy)
    'Saturn': '♄',
    'Rahu': '☊',
    'Ketu': '☋',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;

    // Save canvas state for rotation
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    // Draw outer circle - main ring, most prominent
    final outerPaint = Paint()
      ..color = primaryColor.withValues(alpha: math.min(1.0, opacity * 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, outerPaint);

    // Draw inner circle (planet track)
    final innerRadius = radius * 0.65;
    final innerTrackPaint = Paint()
      ..color = primaryColor.withValues(alpha: math.min(1.0, opacity * 0.9))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, innerRadius, innerTrackPaint);

    // Draw innermost circle (center boundary)
    final centerRadius = radius * 0.35;
    final innerCirclePaint = Paint()
      ..color = primaryColor.withValues(alpha: math.min(1.0, opacity * 0.8))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, centerRadius, innerCirclePaint);

    // Draw 12 main segment lines (30° each)
    final segmentPaint = Paint()
      ..color = primaryColor.withValues(alpha: math.min(1.0, opacity * 0.85))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180 - math.pi / 2;
      final startX = center.dx + centerRadius * math.cos(angle);
      final startY = center.dy + centerRadius * math.sin(angle);
      final endX = center.dx + radius * math.cos(angle);
      final endY = center.dy + radius * math.sin(angle);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), segmentPaint);
    }

    // Draw minor tick marks (every 10°) - keep subtle
    final tickPaint = Paint()
      ..color = primaryColor.withValues(alpha: math.min(1.0, opacity * 0.5))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < 36; i++) {
      if (i % 3 == 0) continue; // Skip main segment lines
      final angle = (i * 10) * math.pi / 180 - math.pi / 2;
      final startX = center.dx + (radius * 0.92) * math.cos(angle);
      final startY = center.dy + (radius * 0.92) * math.sin(angle);
      final endX = center.dx + radius * math.cos(angle);
      final endY = center.dy + radius * math.sin(angle);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);
    }

    // Draw zodiac symbols
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < 12; i++) {
      // Position in middle of each segment
      final angle = ((i * 30) + 15) * math.pi / 180 - math.pi / 2;
      final symbolRadius = radius * 0.82;
      final x = center.dx + symbolRadius * math.cos(angle);
      final y = center.dy + symbolRadius * math.sin(angle);

      textPainter.text = TextSpan(
        text: zodiacSymbols[i],
        style: TextStyle(
          fontSize: radius * 0.12,
          color: primaryColor.withValues(alpha: math.min(1.0, opacity * 0.9)),
          fontWeight: FontWeight.w400,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }

    // Draw planets if available
    if (planetPositions != null && planetPositions!.isNotEmpty) {
      _drawPlanets(
          canvas, center, innerRadius, centerRadius, radius, textPainter);
    }

    canvas.restore();
  }

  void _drawPlanets(
    Canvas canvas,
    Offset center,
    double outerRadius,
    double innerRadius,
    double wheelRadius,
    TextPainter textPainter,
  ) {
    // Sort planets by longitude
    final sortedPlanets = planetPositions!.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Spread out planets that are too close (within 8°)
    // Adjust their display angle while keeping them on same radius
    final adjustedAngles = <String, double>{};
    const minSeparation = 12.0; // Minimum degrees between planets

    for (int i = 0; i < sortedPlanets.length; i++) {
      final planet = sortedPlanets[i].key;
      var longitude = sortedPlanets[i].value;

      // Check previous planet and push apart if too close
      if (i > 0) {
        final prevPlanet = sortedPlanets[i - 1].key;
        final prevAngle = adjustedAngles[prevPlanet]!;
        var diff = longitude - prevAngle;

        // Handle wrap-around
        if (diff < 0) diff += 360;
        if (diff > 180) diff = 360 - diff;

        if (diff < minSeparation) {
          // Push this planet forward
          longitude = prevAngle + minSeparation;
          if (longitude >= 360) longitude -= 360;
        }
      }

      adjustedAngles[planet] = longitude;
    }

    final planetRadius = innerRadius + (outerRadius - innerRadius) * 0.5;

    // Scale sizes based on wheel radius (base reference: 150px radius ~ 360px widget)
    // Using wheelRadius directly since it's already the actual radius
    final scaleFactor = wheelRadius / 150.0;
    final dotRadius = (2.0 * scaleFactor).clamp(1.0, 3.5);
    final fontSize = (14.0 * scaleFactor).clamp(8.0, 18.0);
    final symbolDist = (8.0 * scaleFactor).clamp(5.0, 14.0);

    // Draw planets with tiny dots and symbols
    adjustedAngles.forEach((planet, displayLongitude) {
      final symbol = planetSymbols[planet];
      if (symbol == null) return;

      // Convert longitude to angle (0° Aries at top, clockwise)
      final angle = (displayLongitude - 90) * math.pi / 180;
      final x = center.dx + planetRadius * math.cos(angle);
      final y = center.dy + planetRadius * math.sin(angle);

      // Draw tiny dot at planet position (skip on web)
      if (!kIsWeb) {
        final dotPaint = Paint()
          ..color = primaryColor.withValues(alpha: math.min(1.0, opacity * 6))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }

      // Draw planet symbol slightly outward
      textPainter.text = TextSpan(
        text: symbol,
        style: TextStyle(
          fontSize: fontSize,
          color: primaryColor.withValues(alpha: math.min(1.0, opacity * 8)),
          fontWeight: FontWeight.w300,
        ),
      );
      textPainter.layout();

      // Position symbol outward from center
      final sx = x + math.cos(angle) * symbolDist - textPainter.width / 2;
      final sy = y + math.sin(angle) * symbolDist - textPainter.height / 2;
      textPainter.paint(canvas, Offset(sx, sy));
    });
  }

  @override
  bool shouldRepaint(ZodiacWheelPainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.opacity != opacity ||
      oldDelegate.planetPositions != planetPositions;
}

/// Animated zodiac wheel background widget
class AnimatedZodiacWheel extends StatefulWidget {
  final Color primaryColor;
  final double opacity;
  final Map<String, double>? planetPositions;
  final bool animate;

  const AnimatedZodiacWheel({
    super.key,
    required this.primaryColor,
    this.opacity = 0.08,
    this.planetPositions,
    this.animate = true,
  });

  @override
  State<AnimatedZodiacWheel> createState() => _AnimatedZodiacWheelState();
}

class _AnimatedZodiacWheelState extends State<AnimatedZodiacWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 120), // Very slow rotation
      vsync: this,
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ZodiacWheelPainter(
            rotation: widget.animate ? _controller.value * 2 * math.pi : 0,
            primaryColor: widget.primaryColor,
            opacity: widget.opacity,
            planetPositions: widget.planetPositions,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// Reusable widget that combines AnimatedZodiacWheel with app icon in center
/// Used in FTUE page and onboarding loading phase
class ZodiacWheelWithIcon extends StatelessWidget {
  final double wheelSize;
  final Map<String, double>? planetPositions;
  final Color primaryColor;
  final double opacity;
  final bool animate;

  const ZodiacWheelWithIcon({
    super.key,
    required this.wheelSize,
    this.planetPositions,
    required this.primaryColor,
    this.opacity = 1.0,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    // Scale the center icon based on wheel size
    final iconSize = (wheelSize * 0.15).clamp(40.0, 96.0);
    final iconRadius = (wheelSize * 0.05).clamp(12.0, 28.0);

    return SizedBox(
      width: wheelSize,
      height: wheelSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating wheel
          AnimatedZodiacWheel(
            primaryColor: primaryColor,
            opacity: opacity,
            planetPositions: planetPositions,
            animate: animate,
          ),
          // Static app icon in center
          ClipRRect(
            borderRadius: BorderRadius.circular(iconRadius),
            child: Image.asset(
              'assets/images/icon_transparent.png',
              height: iconSize,
              width: iconSize,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
