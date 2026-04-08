import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_base.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

// =============================================================================
// CHAT & NOTIFICATION SKELETONS
// =============================================================================

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
        isDark ? Colors.white.withValues(alpha: 0.12) : AppTheme.skeletonBaseLight;
    final Color textPlaceholderDark =
        isDark ? Colors.white.withValues(alpha: 0.18) : AppTheme.skeletonShimmerLight;

    // Avatar placeholder
    final Color avatarColor =
        isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.borderLightColor;

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
                padding: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
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
                    const SizedBox(width: AppDimensions.spacingSm),
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
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
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
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
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
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
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
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
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
          const SizedBox(width: AppDimensions.spacingMd),
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
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSmMd),
                    Expanded(
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: placeholder,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingSmMd),
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
          const SizedBox(width: AppDimensions.spacingSm),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: placeholder,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
          ),
        ],
      ),
    );
  }
}
