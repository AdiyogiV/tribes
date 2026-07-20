import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_colors.dart';
import 'package:aurogram/shared/presentation/web/web_style.dart';

/// The ambient cosmic backdrop that sits behind the entire web shell.
///
/// Renders a deep base wash plus a few soft radial "nebula" glows so the whole
/// app feels like one continuous surface — glass tiles float over it. Purely
/// decorative and non-interactive (ignores pointers). Web-only.
///
/// Both canvases are first-class:
///   • Dark  → near-black indigo with warm gold + cosmic-purple glows.
///   • Light → warm porcelain with a faint dawn/gold wash.
class AmbientBackground extends StatelessWidget {
  /// The content painted on top of the backdrop.
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Base wash
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF0B0B12),
                        Color(0xFF13111C),
                        Color(0xFF0A0E17),
                      ]
                    : const [
                        Color(0xFFF7F1EA),
                        Color(0xFFF2ECFA),
                        Color(0xFFEFF4FC),
                      ],
              ),
            ),
          ),
        ),

        // Warm glow, upper-left
        Positioned.fill(
          child: _Glow(
            alignment: const Alignment(-0.7, -0.9),
            radius: 1.2,
            color: WebStyle.accent(isDark)
                .withValues(alpha: isDark ? 0.22 : 0.14),
          ),
        ),

        // Cosmic-purple glow, lower-right
        Positioned.fill(
          child: _Glow(
            alignment: const Alignment(0.9, 0.8),
            radius: 1.3,
            color: AppColors.cosmicPurple
                .withValues(alpha: isDark ? 0.20 : 0.12),
          ),
        ),

        // Cool center-right glow for depth
        Positioned.fill(
          child: _Glow(
            alignment: const Alignment(0.4, -0.3),
            radius: 1.0,
            color: AppColors.skyBlue
                .withValues(alpha: isDark ? 0.09 : 0.12),
          ),
        ),

        // Foreground content
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final Alignment alignment;
  final double radius;
  final Color color;

  const _Glow({
    required this.alignment,
    required this.radius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: alignment,
            radius: radius,
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}
