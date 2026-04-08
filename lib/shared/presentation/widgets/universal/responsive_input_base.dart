import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// High-performance base widget for input areas.
/// 
/// Key optimizations:
/// - NO BackdropFilter (main performance killer for first-tap lag)
/// - Uses RepaintBoundary to isolate repaints
/// - Simple semi-transparent background instead of expensive blur
/// - Const constructors where possible
/// 
/// This widget provides a consistent styled container for text input
/// that is responsive on first tap.
class ResponsiveInputBase extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final EdgeInsets padding;
  final double height;

  const ResponsiveInputBase({
    super.key,
    required this.child,
    this.accentColor,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 10),
    this.height = 70,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = Theme.of(context).colorScheme.surface;
    final Color accent = accentColor ?? Theme.of(context).colorScheme.primary;

    // Use RepaintBoundary to isolate this widget from parent repaints
    return RepaintBoundary(
      child: Padding(
        padding: padding,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            // Simple semi-transparent background - NO blur filter
            color: isDark 
                ? surface.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            // Subtle shadow for depth
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            // Thin border for definition
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : accent.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Variant with subtle gradient background for premium feel
/// Still avoids BackdropFilter for performance
class ResponsiveInputGradient extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final EdgeInsets padding;
  final double height;

  const ResponsiveInputGradient({
    super.key,
    required this.child,
    this.accentColor,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 10),
    this.height = 70,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = Theme.of(context).colorScheme.surface;
    final Color accent = accentColor ?? Theme.of(context).colorScheme.primary;

    return RepaintBoundary(
      child: Padding(
        padding: padding,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            // Subtle gradient instead of blur
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      surface.withValues(alpha: 0.95),
                      surface.withValues(alpha: 0.90),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.98),
                      Colors.white.withValues(alpha: 0.94),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.08 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.15 : 0.10),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}








