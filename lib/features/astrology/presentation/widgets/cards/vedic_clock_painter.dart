import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';

/// Vedic analog clock showing Gati/Pala hands with Prahar background.
///
/// Layout (center → edge):
///   0.00 → 0.68  Prahar background segments + labels
///   0.72 → 0.92  Gati tick marks (60 marks) + ☀ at 12 o'clock
///   Hands reach into Gati ring area
///   Sunrise (6 AM) at 12 o'clock = 0 Gati
class VedicClockPainter extends CustomPainter {
  final DateTime time;
  final Color primaryColor;
  final bool isDark;

  VedicClockPainter({
    required this.time,
    required this.primaryColor,
    required this.isDark,
  });

  static const _sunriseHour = 6;

  // Prahar names
  static const _praharNames = [
    'pratham', 'dwitiya', 'tritiya', 'chaturth',
    'pancham', 'shashth', 'saptam', 'ashtam',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Vedic time from sunrise
    final hour = time.hour;
    final minute = time.minute;
    final second = time.second;
    var secondsFromSunrise = (hour - _sunriseHour) * 3600 + minute * 60 + second;
    if (secondsFromSunrise < 0) secondsFromSunrise += 86400;

    final gati = secondsFromSunrise / 1440.0; // 0–60
    final pala = (secondsFromSunrise % 1440) / 24.0; // 0–60

    canvas.save();
    canvas.translate(center.dx, center.dy);

    _drawPraharSegments(canvas, radius);
    _drawGatiRing(canvas, radius);
    _drawHands(canvas, radius, gati, pala);
    _drawCenterDot(canvas, radius);

    canvas.restore();
  }

  // ── Prahar segments (inner area) ──────────────────────────

  void _drawPraharSegments(Canvas canvas, double radius) {
    final segR = radius * 0.76;
    const sweep = math.pi / 4; // 45°

    for (int i = 0; i < 8; i++) {
      final start = -math.pi / 2 + i * sweep;

      final isDay = i < 4;
      final alpha = isDark ? 0.12 : 0.08;
      final color = isDay
          ? Color.lerp(
              const Color(0xFFFFA726),
              const Color(0xFFFF7043),
              i / 4.0,
            )!.withValues(alpha: alpha + (i == 0 ? 0.04 : 0))
          : Color.lerp(
              const Color(0xFF5C6BC0),
              const Color(0xFF283593),
              (i - 4) / 4.0,
            )!.withValues(alpha: alpha + (i == 4 ? 0.02 : 0));

      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: segR),
        start,
        sweep,
        true,
        Paint()..color = color,
      );

      // Segment border
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: segR),
        start,
        sweep,
        true,
        Paint()
          ..color = primaryColor.withValues(alpha: isDark ? 0.06 : 0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );

      // Prahar label
      final mid = start + sweep / 2;
      final lr = segR * 0.72;
      _drawLabel(
        canvas,
        _praharNames[i],
        lr * math.cos(mid),
        lr * math.sin(mid),
        radius * 0.055,
        primaryColor.withValues(alpha: isDark ? 0.55 : 0.45),
        FontWeight.w300,
      );
    }

    // Ring around prahar area
    canvas.drawCircle(
      Offset.zero,
      segR,
      Paint()
        ..color = primaryColor.withValues(alpha: isDark ? 0.10 : 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  // ── Gati marks (outer ring, fills to edge) ────────────────

  void _drawGatiRing(Canvas canvas, double radius) {
    final outerR = radius * 0.92;
    final innerR = radius * 0.80;
    final labelR = radius * 0.84; // visually centered in ring gap (0.80–0.92)

    // Outer ring line
    canvas.drawCircle(
      Offset.zero,
      outerR,
      Paint()
        ..color = primaryColor.withValues(alpha: isDark ? 0.12 : 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    for (int g = 0; g < 60; g++) {
      final angle = -math.pi / 2 + (g / 60.0) * 2 * math.pi;
      final isMajor = g % 5 == 0;
      final hasNumberLabel = g % 15 == 0 && g > 0;
      final isSunrise = g == 0;

      // Skip tick where label or sunrise symbol sits
      if (!hasNumberLabel && !isSunrise) {
        final tickLen = isMajor
            ? (outerR - innerR) * 0.6
            : (outerR - innerR) * 0.25;
        final tickStart = outerR - tickLen;

        canvas.drawLine(
          Offset(tickStart * math.cos(angle), tickStart * math.sin(angle)),
          Offset(outerR * math.cos(angle), outerR * math.sin(angle)),
          Paint()
            ..color = primaryColor.withValues(alpha: isMajor ? 0.50 : 0.18)
            ..strokeWidth = isMajor ? 1.2 : 0.5
            ..strokeCap = StrokeCap.round,
        );
      }

      // Sun at 0 Gati (sunrise / 12 o'clock) — drawn as golden circle + rays
      if (isSunrise) {
        _drawSunIcon(canvas, labelR * math.cos(angle), labelR * math.sin(angle), radius * 0.038);
      }

      // Number label every 10 Gati
      if (hasNumberLabel) {
        _drawLabel(
          canvas,
          '$g',
          labelR * math.cos(angle),
          labelR * math.sin(angle),
          radius * 0.058,
          primaryColor.withValues(alpha: 0.70),
          FontWeight.w600,
        );
      }
    }
  }

  // ── Hands ─────────────────────────────────────────────────

  void _drawHands(Canvas canvas, double radius, double gati, double pala) {
    // Pala hand — long, thin
    final palaAngle = -math.pi / 2 + (pala / 60.0) * 2 * math.pi;
    _drawHand(canvas,
      angle: palaAngle,
      length: radius * 0.68,
      tail: radius * 0.10,
      width: 1.5,
      color: primaryColor.withValues(alpha: 0.6),
    );

    // Gati hand — short, thick
    final gatiAngle = -math.pi / 2 + (gati / 60.0) * 2 * math.pi;
    _drawHand(canvas,
      angle: gatiAngle,
      length: radius * 0.52,
      tail: radius * 0.08,
      width: 2.8,
      color: primaryColor.withValues(alpha: 0.85),
    );
  }

  void _drawHand(Canvas canvas, {
    required double angle,
    required double length,
    required double tail,
    required double width,
    required Color color,
  }) {
    canvas.drawLine(
      Offset(-tail * math.cos(angle), -tail * math.sin(angle)),
      Offset(length * math.cos(angle), length * math.sin(angle)),
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── Sun icon (golden circle + rays) ────────────────────────

  void _drawSunIcon(Canvas canvas, double cx, double cy, double r) {
    const sunColor = Color(0xFFFFC107); // warm golden yellow
    final corePaint = Paint()..color = sunColor;
    final rayPaint = Paint()
      ..color = sunColor.withValues(alpha: 0.8)
      ..strokeWidth = r * 0.22
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(cx, cy);

    // Core circle
    canvas.drawCircle(Offset.zero, r * 0.55, corePaint);

    // 8 rays
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8.0) * 2 * math.pi;
      final innerR = r * 0.7;
      final outerR = r;
      canvas.drawLine(
        Offset(innerR * math.cos(angle), innerR * math.sin(angle)),
        Offset(outerR * math.cos(angle), outerR * math.sin(angle)),
        rayPaint,
      );
    }

    canvas.restore();
  }

  // ── Center dot ────────────────────────────────────────────

  void _drawCenterDot(Canvas canvas, double radius) {
    canvas.drawCircle(Offset.zero, radius * 0.03,
        Paint()..color = primaryColor.withValues(alpha: 0.5));
    canvas.drawCircle(Offset.zero, radius * 0.015,
        Paint()..color = primaryColor);
  }

  // ── Label helper ──────────────────────────────────────────

  void _drawLabel(Canvas canvas, String text, double x, double y,
      double fontSize, Color color, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(x, y);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant VedicClockPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.isDark != isDark ||
      oldDelegate.primaryColor != primaryColor;
}

/// Widget wrapper for VedicClockPainter
class VedicClockWidget extends StatelessWidget {
  final DateTime time;
  final bool isDark;
  final double size;

  const VedicClockWidget({
    super.key,
    required this.time,
    required this.isDark,
    this.size = 300,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: VedicClockPainter(
          time: time,
          primaryColor: AppTheme.primaryColor,
          isDark: isDark,
        ),
      ),
    );
  }
}
