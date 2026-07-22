import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/baba/voice/voice_session_controller.dart';

/// Organic, liquid clip for Baba's blob — a circle that gently wobbles while a
/// call is live. Kept purely visual so the blob can be reused anywhere.
class WavyCircleClipper extends CustomClipper<Path> {
  WavyCircleClipper(this.pulse);

  final double pulse;

  @override
  Path getClip(Size size) {
    final Path path = Path();
    final double center = size.width / 2;

    // Shrink the base radius ~15% so an outward wobble never clips the box.
    const double maxWobbleFactor = 0.15;
    final double radius = center / (1.0 + maxWobbleFactor);

    // Active state amplifies the wobble based on the pulse.
    final double waveIntensity = 0.03 + (pulse * 0.05);

    const int samples = 120;
    for (int i = 0; i <= samples; i++) {
      final double t = (i / samples) * 2 * math.pi;
      final double wobble =
          math.sin(t * 3 + (pulse * math.pi)) * (radius * waveIntensity) +
              math.cos(t * 4 - (pulse * math.pi * 0.5)) *
                  (radius * waveIntensity * 0.6);
      final double r = radius + wobble;
      final double x = center + r * math.cos(t);
      final double y = center + r * math.sin(t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WavyCircleClipper oldClipper) =>
      oldClipper.pulse != pulse;
}

/// The Baba blob itself — a translucent glass wave with Aurobhatt inside.
///
/// Pure presentation: it takes a size, whether a call is [active], and the
/// current [pulse], and renders the wavy glass. Placement, taps and lifecycle
/// live in the owning overlay so this stays reusable + testable.
class BabaBlob extends StatelessWidget {
  const BabaBlob({
    super.key,
    required this.size,
    required this.active,
    required this.pulse,
    required this.isDark,
  });

  final double size;
  final bool active;
  final double pulse;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Scale the icon up prominently when active.
    final double iconSize = active ? size * 0.75 : size * 0.83;

    return ClipPath(
      clipper: WavyCircleClipper(active ? pulse : 0.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: -4.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  width: iconSize,
                  height: iconSize,
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    'assets/images/aurobhatt.webp',
                    fit: BoxFit.fitWidth,
                    cacheWidth:
                        (iconSize * MediaQuery.devicePixelRatioOf(context))
                            .ceil()
                            .clamp(64, 256)
                            .toInt(),
                    alignment: Alignment.bottomCenter,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.auto_awesome,
                      color: AppTheme.primaryColor,
                      size: 30.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ultra-minimal glass status pill shown beneath the blob during a call:
/// a morphing state dot + tiny state label (CONNECTING / LISTENING / …).
class BabaStatusPill extends StatelessWidget {
  const BabaStatusPill({
    super.key,
    required this.state,
    required this.pulse,
    required this.isDark,
  });

  final VoiceCallState state;
  final double pulse;
  final bool isDark;

  static String labelFor(VoiceCallState s) {
    switch (s) {
      case VoiceCallState.connecting:
        return 'CONNECTING';
      case VoiceCallState.listening:
        return 'LISTENING';
      case VoiceCallState.thinking:
        return 'THINKING';
      case VoiceCallState.speaking:
        return 'SPEAKING';
      case VoiceCallState.error:
        return 'ERROR';
      case VoiceCallState.idle:
      case VoiceCallState.ended:
        return '';
    }
  }

  static Color colorFor(VoiceCallState state) {
    switch (state) {
      case VoiceCallState.listening:
        return const Color(0xFFFF5722);
      case VoiceCallState.thinking:
        return const Color(0xFF5C6BC0);
      case VoiceCallState.speaking:
        return AppTheme.primaryColor;
      case VoiceCallState.connecting:
        return const Color(0xFFFFB300);
      case VoiceCallState.error:
        return const Color(0xFFE53935);
      case VoiceCallState.idle:
      case VoiceCallState.ended:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MicroMorphIndicator(state: state, pulse: pulse),
              const SizedBox(width: 8),
              Text(
                labelFor(state),
                style: TextStyle(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tiny morphing state dot: breathes while listening, scans while thinking,
/// vibrates while speaking. Fixed bounds so the label never jitters.
class _MicroMorphIndicator extends StatelessWidget {
  const _MicroMorphIndicator({required this.state, required this.pulse});

  final VoiceCallState state;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    double w = 5.0;
    double h = 5.0;
    Color c = BabaStatusPill.colorFor(state);
    BorderRadius r = BorderRadius.circular(5);
    Offset offset = Offset.zero;

    if (state == VoiceCallState.listening ||
        state == VoiceCallState.connecting) {
      final breath = math.sin(pulse * math.pi) * 1.5;
      w = 5.0 + breath;
      h = 5.0 + breath;
    } else if (state == VoiceCallState.thinking) {
      w = 4.0;
      h = 4.0;
      offset = Offset(math.sin(pulse * math.pi * 2) * 4.5, 0);
    } else if (state == VoiceCallState.speaking) {
      w = 2.5;
      h = 5.0 + (math.sin(pulse * math.pi * 5).abs() * 7.0);
      r = BorderRadius.circular(1.5);
    }

    return SizedBox(
      width: 14,
      height: 14,
      child: Center(
        child: Transform.translate(
          offset: offset,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: w,
            height: h,
            decoration: BoxDecoration(color: c, borderRadius: r),
          ),
        ),
      ),
    );
  }
}
