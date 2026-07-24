import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Shared building blocks + palette for the signed-out (guest) dashboard.
///
/// ── Palette note ──────────────────────────────────────────────────────────
/// The app's `AppTheme.primaryColor` is a leftover "farm" brown (light) / white
/// (dark) from a previous brand. The guest landing deliberately does NOT use
/// it. It leans on this small, self-contained Indic palette (saffron brand +
/// haldi gold / cosmic purple / emerald for the three sciences) so it reads
/// on-brand regardless of the lingering theme color.

/// Saffron — the brand accent for the guest page (CTAs, brand mark).
const Color kGuestSaffron = Color(0xFFE2571E);

/// Haldi gold — Panchang (the sacred calendar / timing).
const Color kGuestHaldi = Color(0xFFD99A00);

/// Cosmic purple — Jyotish (Vedic astrology).
Color get kGuestJyotish => AppTheme.cosmicPurple;

/// Emerald — Ayurveda (balance / wellbeing).
Color get kGuestAyurveda => AppTheme.emeraldGreen;

/// Sky blue — Circles (community).
Color get kGuestCircles => AppTheme.skyBlue;

// ─────────────────────────────────────────────────────────────────────────────
// Small atoms
// ─────────────────────────────────────────────────────────────────────────────

/// Spaced-caps eyebrow label.
class GuestEyebrow extends StatelessWidget {
  const GuestEyebrow({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
      ),
    );
  }
}

/// The full-width primary call to action.
class GuestPrimaryCta extends StatelessWidget {
  const GuestPrimaryCta({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mandala mark
// ─────────────────────────────────────────────────────────────────────────────

/// A decorative Surya/mandala mark — concentric rings, radiating sun rays and a
/// dotted nakshatra ring. Purely ornamental (no data); it stands in for the
/// real wheel a signed-out visitor can't see yet.
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
        painter: _MandalaPainter(isDark: isDark),
        child: const SizedBox.shrink(),
      ),
    );
  }
}

class _MandalaPainter extends CustomPainter {
  _MandalaPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    final line = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: isDark ? 0.12 : 0.09);

    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = line;
    for (final f in const [0.34, 0.62, 0.92]) {
      canvas.drawCircle(center, maxR * f, orbit);
    }

    // Radiating sun rays (Surya).
    final ray = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = kGuestHaldi.withValues(alpha: 0.55);
    const rays = 24;
    for (var i = 0; i < rays; i++) {
      final a = (i / rays) * 2 * math.pi;
      final inner = center + Offset(math.cos(a), math.sin(a)) * (maxR * 0.62);
      final outer = center + Offset(math.cos(a), math.sin(a)) * (maxR * 0.78);
      canvas.drawLine(inner, outer, ray);
    }

    // Dotted nakshatra ring (27) on the outermost orbit.
    final dot = Paint()..color = kGuestJyotish.withValues(alpha: 0.55);
    const ticks = 27;
    for (var i = 0; i < ticks; i++) {
      final a = (i / ticks) * 2 * math.pi - math.pi / 2;
      final p = center + Offset(math.cos(a), math.sin(a)) * (maxR * 0.92);
      canvas.drawCircle(p, 1.5, dot);
    }

    // Warm saffron core with a soft glow.
    canvas.drawCircle(
      center,
      maxR * 0.30,
      Paint()
        ..color = kGuestSaffron.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      center,
      maxR * 0.16,
      Paint()..color = kGuestSaffron.withValues(alpha: 0.9),
    );
    canvas.drawCircle(center, maxR * 0.08, Paint()..color = kGuestHaldi);
  }

  @override
  bool shouldRepaint(covariant _MandalaPainter old) => old.isDark != isDark;
}
