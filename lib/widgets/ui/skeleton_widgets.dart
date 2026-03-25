import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:aurogram/utils/theme/app_theme.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            const SizedBox(width: 12),
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
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: placeholder,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
              const SizedBox(height: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: placeholder,
                  borderRadius: BorderRadius.circular(10),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 13,
                  decoration: BoxDecoration(
                    color: placeholderDark,
                    borderRadius: BorderRadius.circular(6),
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

/// Chat message skeleton - matches actual message bubble styling
class SkeletonChatMessage extends StatelessWidget {
  final bool isUser;
  final int lineCount;

  const SkeletonChatMessage({
    super.key,
    this.isUser = false,
    this.lineCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxWidth = MediaQuery.of(context).size.width * 0.7;

    // User messages: tinted primary color, Other messages: warm white/beige
    final Color bubbleColor = isUser
        ? (isDark
            ? AppTheme.primaryColor.withValues(alpha: 0.3)
            : AppTheme.primaryColor.withValues(alpha: 0.15))
        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white);

    // Text placeholder colors - warm beige for light, subtle for dark
    final Color textPlaceholder =
        isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE8E0D5);
    final Color textPlaceholderDark =
        isDark ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFD8CFC2);

    // Avatar placeholder
    final Color avatarColor =
        isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE0D8CC);

    // Vary widths for organic look
    final lineWidths = [0.85, 0.6, 0.75, 0.5];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ShimmerBox(
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Avatar and name row (only for non-user, simulating first in group)
            if (!isUser) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: avatarColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 60,
                      height: 10,
                      decoration: BoxDecoration(
                        color: textPlaceholder,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Message bubble
            Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(lineCount, (index) {
                  final widthFactor = lineWidths[index % lineWidths.length];
                  return Padding(
                    padding:
                        EdgeInsets.only(bottom: index < lineCount - 1 ? 6 : 0),
                    child: Container(
                      width: math.min(maxWidth * widthFactor, 180.0),
                      height: 12,
                      decoration: BoxDecoration(
                        color: isUser
                            ? (isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.5))
                            : (index == 0
                                ? textPlaceholderDark
                                : textPlaceholder),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Timestamp placeholder
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 36,
                height: 8,
                decoration: BoxDecoration(
                  color: textPlaceholder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Notification skeleton
class SkeletonNotification extends StatelessWidget {
  const SkeletonNotification({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color placeholder =
        AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.08);
    final Color placeholderDark =
        AppTheme.primaryColor.withValues(alpha: isDark ? 0.18 : 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: placeholder,
                  shape: BoxShape.circle,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: placeholderDark,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 13,
                      decoration: BoxDecoration(
                        color: placeholderDark,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: placeholder,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: 50,
                  height: 10,
                  decoration: BoxDecoration(
                    color: placeholder,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: placeholder,
              borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.all(16),
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
          const SizedBox(width: 8),
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
            const SizedBox(height: 16),
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

// =============================================================================
// CARD SKELETONS: For content cards
// =============================================================================

/// Card skeleton for posts/content
class SkeletonCard extends StatelessWidget {
  final double? height;

  const SkeletonCard({super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);

    return ShimmerBox(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.base,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.highlight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors.highlight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 60,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors.shimmer,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: colors.highlight,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid item skeleton for image grids
class SkeletonGridItem extends StatelessWidget {
  final double aspectRatio;

  const SkeletonGridItem({super.key, this.aspectRatio = 1.0});

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);

    return ShimmerBox(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: colors.base,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colors.shimmer,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Image placeholder with shimmer - simple box for image loading
class ShimmerImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const ShimmerImagePlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);
    return ShimmerBox(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.base,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

// =============================================================================
// POST BOX SKELETON: One post-shaped box with separate skeleton areas
// =============================================================================

/// Single post box with fixed-height skeleton sections: header, content, toolbar.
/// Used in feed (placeholder items) and inside Post when loading. Same layout
/// everywhere so content "fills in" the same box – no list swap, no overflow.
class PostBoxSkeleton extends StatelessWidget {
  const PostBoxSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: avatar + 2 lines (fixed height)
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ShimmerBox(
                child: SkeletonCircle(size: 40),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(
                    child: SkeletonLine(width: 120, height: 12),
                  ),
                  const SizedBox(height: 6),
                  ShimmerBox(
                    child: SkeletonLine(width: 80, height: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Content area (fixed height)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: ShimmerBox(
            child: SkeletonBox(height: 180, width: double.infinity),
          ),
        ),
        // Toolbar: icon placeholders (fixed height)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: 16),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: 16),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Video post skeleton - tall media box to match typical video posts.
class PostVideoSkeleton extends StatelessWidget {
  const PostVideoSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonCircle(size: 40)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(child: SkeletonLine(width: 120, height: 12)),
                  const SizedBox(height: 6),
                  ShimmerBox(child: SkeletonLine(width: 80, height: 10)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: ShimmerBox(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: const SkeletonBox(width: double.infinity),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: 16),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: 16),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Audio post skeleton - medium height media box.
class PostAudioSkeleton extends StatelessWidget {
  const PostAudioSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonCircle(size: 40)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(child: SkeletonLine(width: 120, height: 12)),
                  const SizedBox(height: 6),
                  ShimmerBox(child: SkeletonLine(width: 80, height: 10)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: ShimmerBox(
            child: SkeletonBox(height: 220, width: double.infinity),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: 16),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: 16),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Text post skeleton - smaller media area and text lines.
class PostTextSkeleton extends StatelessWidget {
  const PostTextSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonCircle(size: 40)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(child: SkeletonLine(width: 120, height: 12)),
                  const SizedBox(height: 6),
                  ShimmerBox(child: SkeletonLine(width: 80, height: 10)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(
                  child: SkeletonLine(width: double.infinity, height: 12)),
              const SizedBox(height: 8),
              ShimmerBox(
                  child: SkeletonLine(width: double.infinity, height: 12)),
              const SizedBox(height: 8),
              ShimmerBox(child: SkeletonLine(width: 200, height: 12)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: 16),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: 16),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Image post skeleton - square media box for images.
class PostImageSkeleton extends StatelessWidget {
  const PostImageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonCircle(size: 40)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(child: SkeletonLine(width: 120, height: 12)),
                  const SizedBox(height: 6),
                  ShimmerBox(child: SkeletonLine(width: 80, height: 10)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: ShimmerBox(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: const SkeletonBox(width: double.infinity),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: 16),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: 16),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact card for posts still processing/uploading.
class PostProcessingCard extends StatelessWidget {
  const PostProcessingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.base,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.highlight),
      ),
      child: Row(
        children: [
          ShimmerBox(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.shimmer,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Processing post...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This post will appear shortly.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
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

/// Compact card for missing/unavailable posts.
class PostUnavailableCard extends StatelessWidget {
  const PostUnavailableCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.base,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.highlight),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.shimmer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              size: 20,
              color: Colors.black38,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Post unavailable',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This post could not be loaded.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
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
// STORY RING SKELETON: Horizontal list of story avatars
// =============================================================================

/// Skeleton loader for story ring - shows horizontal list of circular avatars
/// with text labels below, matching the actual StoryRing layout.
class StoryRingSkeleton extends StatelessWidget {
  final int itemCount;
  static const double _avatarSize = 84.0; // Increased size (matches StoryRing)
  static const double _ringWidth = 102.0; // Increased size (matches StoryRing)

  const StoryRingSkeleton({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    // Height: ring (102px) + spacing (4px) + text (16px) = 122px, no extra padding
    return SizedBox(
      height: _ringWidth + 20,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _ringWidth + 4 + 6, // Avatar + spacing + text
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circular avatar skeleton with ring (Instagram size)
                  ShimmerBox(
                    child: Container(
                      width: _ringWidth,
                      height: _ringWidth,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SkeletonColors.fromContext(context).base,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: SkeletonCircle(size: _avatarSize),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Text label skeleton
                  SizedBox(
                    width: _ringWidth,
                    height: 16,
                    child: Center(
                      child: ShimmerBox(
                        child: SkeletonLine(
                          width: _ringWidth * 0.6,
                          height: 12,
                          borderRadius: 4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
