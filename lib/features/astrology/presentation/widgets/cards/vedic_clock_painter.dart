import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';

/// Minimal Vedic clock — transparent background, bold white lines only.
/// Matches watchOS VedicClockView exactly.
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

  static const _praharNames = [
    'purvanha', 'madhyanha', 'aparanha', 'sayanha',
    'pradosha', 'nishitha', 'triyama', 'usha',
  ];

  /// Base clock color — white on dark backgrounds, warm brown on light.
  Color get _clockColor => isDark ? Colors.white : const Color(0xFF5A3D34);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final hour = time.hour;
    final minute = time.minute;
    final second = time.second;
    var secondsFromSunrise = (hour - _sunriseHour) * 3600 + minute * 60 + second;
    if (secondsFromSunrise < 0) secondsFromSunrise += 86400;

    final ghati = secondsFromSunrise / 1440.0;
    final pala = (secondsFromSunrise % 1440) / 24.0;
    final praharIndex = _currentPraharIndex();

    canvas.save();
    canvas.translate(center.dx, center.dy);

    _drawPraharRing(canvas, radius, praharIndex);
    _drawGhatiRing(canvas, radius, ghati, pala);
    _drawHands(canvas, radius, ghati, pala);
    _drawCenterDot(canvas, radius);

    canvas.restore();
  }

  // ── Prahar ring — spokes from center to 70% + labels ──

  void _drawPraharRing(Canvas canvas, double radius, int currentIdx) {
    final ringR = radius * 0.76;
    final spokeEnd = ringR * 0.70;

    // 8 divider spokes from center + labels
    const sweep = math.pi / 4;
    for (int i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * sweep;

      // Spoke from center to 70% of ring
      canvas.drawLine(
        Offset.zero,
        Offset(spokeEnd * math.cos(angle), spokeEnd * math.sin(angle)),
        Paint()
          ..color = _clockColor.withValues(alpha: 0.30)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );

      // Large number at midpoint of segment
      final mid = angle + sweep / 2;
      final lr = ringR * 0.58;
      final isCurrent = i == currentIdx;

      _drawLabel(
        canvas, '${i + 1}',
        lr * math.cos(mid), lr * math.sin(mid),
        radius * 0.08,
        _clockColor.withValues(alpha: isCurrent ? 0.50 : 0.25),
        FontWeight.w600,
      );
    }
  }

  int _currentPraharIndex() {
    var h = time.hour - _sunriseHour;
    if (h < 0) h += 24;
    return (h ~/ 3).clamp(0, 7);
  }

  // ── Ghati ring — outer circle, sun, tracker, time + ghati labels ──

  void _drawGhatiRing(Canvas canvas, double radius, double ghati, double pala) {
    final outerR = radius * 0.92;
    final labelR = radius * 0.75;

    // Sun icon disabled — kept for reuse
    // _drawSunIcon(canvas, 0, -labelR, radius * 0.065);

    // Ghati tracker — sun color, tracks around dial
    final trackerAngle = -math.pi / 2 + (ghati / 60.0) * 2 * math.pi;
    final trackerDist = math.min(ghati, 60 - ghati);
    if (trackerDist >= 3) {
      _drawLabel(
        canvas, '${ghati.toInt()}',
        labelR * math.cos(trackerAngle), labelR * math.sin(trackerAngle),
        radius * 0.15,
        const Color(0xFFFFD64F),
        FontWeight.w800,
      );
    }

    // Pala tracker — same ring as ghati, same size, white; hides when near ghati
    final palaAngle = -math.pi / 2 + (pala / 60.0) * 2 * math.pi;
    final palaDist = (pala - ghati).abs();
    final palaNearGhati = math.min(palaDist, 60 - palaDist) < 4;
    if (!palaNearGhati) {
      _drawLabel(
        canvas, '${pala.toInt()}',
        labelR * math.cos(palaAngle), labelR * math.sin(palaAngle),
        radius * 0.15,
        _clockColor,
        FontWeight.w800,
      );
    }

    // Time-of-day labels
    final timeLabels = <List<dynamic>>[];
    for (final pair in timeLabels) {
      final gPos = pair[0] as double;
      final label = pair[1] as String;
      final angle = -math.pi / 2 + (gPos / 60.0) * 2 * math.pi;

      final dist = (gPos - ghati).abs() % 60;
      final nearTracker = math.min(dist, 60 - dist) < 3;
      if (nearTracker) continue;

      _drawLabel(
        canvas, label,
        labelR * math.cos(angle), labelR * math.sin(angle),
        radius * 0.08,
        _clockColor.withValues(alpha: 0.25),
        FontWeight.w600,
      );
    }

    // Ghati number labels every 5
    const ghatiLabels = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
    for (final g in ghatiLabels) {
      final angle = -math.pi / 2 + (g / 60.0) * 2 * math.pi;

      final dist = ((g - ghati) % 60).abs();
      final nearTracker = math.min(dist, 60 - dist) < 3;
      if (nearTracker) continue;

      _drawLabel(
        canvas, '$g',
        labelR * math.cos(angle), labelR * math.sin(angle),
        radius * 0.08,
        _clockColor.withValues(alpha: 0.25),
        FontWeight.w600,
      );
    }
  }

  // ── Hands ─────────────────────────────────────────────────

  void _drawHands(Canvas canvas, double radius, double ghati, double pala) {
    // Pala — long
    final palaAngle = -math.pi / 2 + (pala / 60.0) * 2 * math.pi;
    _drawHand(canvas, angle: palaAngle, length: radius * 0.55, tail: radius * 0.30,
              width: 2.0, color: _clockColor.withValues(alpha: 0.85));

    // Ghati — short, bold
    final ghatiAngle = -math.pi / 2 + (ghati / 60.0) * 2 * math.pi;
    _drawHand(canvas, angle: ghatiAngle, length: radius * 0.52, tail: radius * 0.08,
              width: 6.5, color: _clockColor);
  }

  void _drawHand(Canvas canvas, {
    required double angle, required double length, required double tail,
    required double width, required Color color,
  }) {
    canvas.drawLine(
      Offset(-tail * math.cos(angle), -tail * math.sin(angle)),
      Offset(length * math.cos(angle), length * math.sin(angle)),
      Paint()..color = color..strokeWidth = width..strokeCap = StrokeCap.round,
    );
  }

  // ── Sun icon ──────────────────────────────────────────────

  void _drawSunIcon(Canvas canvas, double cx, double cy, double r) {
    const sunColor = Color(0xFFFFD64F);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.drawCircle(Offset.zero, r * 0.55, Paint()..color = sunColor);
    for (int i = 0; i < 8; i++) {
      final a = (i / 8.0) * 2 * math.pi;
      canvas.drawLine(
        Offset(r * 0.7 * math.cos(a), r * 0.7 * math.sin(a)),
        Offset(r * math.cos(a), r * math.sin(a)),
        Paint()..color = sunColor.withValues(alpha: 0.85)..strokeWidth = r * 0.24..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  // ── Center dot ────────────────────────────────────────────

  void _drawCenterDot(Canvas canvas, double radius) {
    canvas.drawCircle(Offset.zero, radius * 0.040, Paint()..color = _clockColor.withValues(alpha: 0.80));
    canvas.drawCircle(Offset.zero, radius * 0.020, Paint()..color = _clockColor);
  }

  // ── Label ─────────────────────────────────────────────────

  void _drawLabel(Canvas canvas, String text, double x, double y,
      double fontSize, Color color, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, fontWeight: weight, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(x, y);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant VedicClockPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.isDark != isDark || oldDelegate.primaryColor != primaryColor;
}

/// Widget wrapper
class VedicClockWidget extends StatelessWidget {
  final DateTime time;
  final bool isDark;
  final double size;

  const VedicClockWidget({super.key, required this.time, required this.isDark, this.size = 300});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(
        painter: VedicClockPainter(time: time, primaryColor: AppTheme.primaryColor, isDark: isDark),
      ),
    );
  }
}
