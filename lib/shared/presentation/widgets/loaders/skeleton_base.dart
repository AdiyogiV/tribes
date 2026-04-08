import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

// =============================================================================
// SKELETON SYSTEM - Clean & Simple
// =============================================================================
//
// USAGE:
// 1. Wrap your custom skeleton with ShimmerBox for shimmer effect
// 2. Use SkeletonColors.fromContext(context) for consistent colors
// 3. Each page should have its own detailed skeleton matching actual content
//
// =============================================================================

// =============================================================================
// CORE: ShimmerBox - Wrap any widget for shimmer animation
// =============================================================================

class ShimmerBox extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Duration duration;

  const ShimmerBox({
    super.key,
    required this.child,
    this.enabled = true,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    if (widget.enabled) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final colors = SkeletonColors.fromContext(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [colors.base, colors.shimmer, colors.base],
              stops: [
                (_animation.value - 0.4).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.4).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

// =============================================================================
// CORE: SkeletonColors - Consistent theming
// =============================================================================

class SkeletonColors {
  final Color base;
  final Color highlight;
  final Color shimmer;
  final Color accent;

  const SkeletonColors({
    required this.base,
    required this.highlight,
    required this.shimmer,
    required this.accent,
  });

  factory SkeletonColors.fromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SkeletonColors(
      // Dark mode: brighter so ShimmerBox gradient is visible on dark background
      base: isDark ? const Color(0xFF404040) : const Color(0xFFF0EBE5),
      highlight: isDark ? const Color(0xFF505050) : const Color(0xFFE5E0DA),
      shimmer: isDark ? const Color(0xFF686868) : const Color(0xFFFAF8F5),
      accent: isDark
          ? AppTheme.sunGold.withValues(alpha: 0.12)
          : AppTheme.primaryColor.withValues(alpha: 0.08),
    );
  }
}

// =============================================================================
// PRIMITIVES: Basic building blocks
// =============================================================================

/// Line placeholder for text
class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final bool highlight;

  const SkeletonLine({
    super.key,
    this.width,
    this.height = 12,
    this.borderRadius = 6,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: highlight ? colors.highlight : colors.base,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Circle placeholder for avatars
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.base,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Box placeholder for content areas
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final bool highlight;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: highlight ? colors.highlight : colors.base,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// =============================================================================
// COMMON WIDGETS: Frequently used patterns
// =============================================================================

/// List item skeleton - avatar + text lines + time/badge
class SkeletonListItem extends StatelessWidget {
  final double height;
  final bool showAvatar;

  const SkeletonListItem({
    super.key,
    this.height = 72,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color placeholder =
        AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.08);
    final Color placeholderDark =
        AppTheme.primaryColor.withValues(alpha: isDark ? 0.18 : 0.12);

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
      child: Row(
        children: [
          if (showAvatar) ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: placeholder,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: placeholderDark,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSmMd),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: placeholder,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 36,
                height: 10,
                decoration: BoxDecoration(
                  color: placeholder,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: placeholder,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact user row skeleton
class SkeletonCompactUser extends StatelessWidget {
  const SkeletonCompactUser({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color placeholder =
        AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.08);
    final Color placeholderDark =
        AppTheme.primaryColor.withValues(alpha: isDark ? 0.18 : 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: placeholder,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 13,
                  decoration: BoxDecoration(
                    color: placeholderDark,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 70,
                  height: 10,
                  decoration: BoxDecoration(
                    color: placeholder,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LOADERS: For buttons and inline loading
// =============================================================================

/// Pulsing dots for buttons
class PulsingDots extends StatefulWidget {
  final Color? color;
  final double size;
  final int dotCount;

  const PulsingDots({
    super.key,
    this.color,
    this.size = 8,
    this.dotCount = 3,
  });

  @override
  State<PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<PulsingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = widget.color ??
        (isDark ? AppTheme.primaryLightColor : AppTheme.primaryColor);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.dotCount, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final value = ((_controller.value + delay) % 1.0);
            final scale = 0.5 + (0.5 * (1 - (2 * (value - 0.5)).abs()));
            final opacity = 0.3 + (0.7 * scale);

            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.size * 0.25),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor.withValues(alpha: opacity),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Inline shimmer loader for icons
class InlineShimmerLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const InlineShimmerLoader({super.key, this.size = 16, this.color});

  @override
  State<InlineShimmerLoader> createState() => _InlineShimmerLoaderState();
}

class _InlineShimmerLoaderState extends State<InlineShimmerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.color ??
        (isDark ? AppTheme.primaryLightColor : AppTheme.primaryColor);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.3 +
            (0.7 * (0.5 + 0.5 * (1 - (2 * (_controller.value - 0.5)).abs())));
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: baseColor.withValues(alpha: opacity),
          ),
        );
      },
    );
  }
}

/// Pagination loader for list bottoms
class PaginationLoader extends StatelessWidget {
  const PaginationLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      alignment: Alignment.center,
      child: const PulsingDots(size: 8),
    );
  }
}

/// Message sending indicator
class MessageSendingIndicator extends StatelessWidget {
  final Color? color;

  const MessageSendingIndicator({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return PulsingDots(
      color: color ?? AppTheme.primaryColor.withValues(alpha: 0.5),
      size: 4,
      dotCount: 3,
    );
  }
}

/// Button loading state
class ShimmerButtonLoader extends StatelessWidget {
  final String? text;
  final Color? color;

  const ShimmerButtonLoader({super.key, this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PulsingDots(color: color, size: 6),
        if (text != null) ...[
          const SizedBox(width: AppDimensions.spacingSm),
          Text(text!, style: TextStyle(color: color)),
        ],
      ],
    );
  }
}

/// Loading overlay
class ShimmerLoadingOverlay extends StatelessWidget {
  final String text;
  final Color? backgroundColor;

  const ShimmerLoadingOverlay({
    super.key,
    this.text = 'Loading...',
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: backgroundColor ?? Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulsingDots(
              color: isDark ? AppTheme.sunGold : AppTheme.primaryColor,
              size: 12,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
