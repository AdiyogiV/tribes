import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';

/// Build skeleton loaders for message cards during refresh
class MessageSkeletons extends StatelessWidget {
  const MessageSkeletons({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(top: AppHeaderStyle.contentTopPadding),
      child: Column(
        children: [
          _MessageSectionLabelSkeleton(isDark: isDark),
          ...List.generate(
              5, (index) => _MessageCardSkeleton(index: index, isDark: isDark)),
          SizedBox(height: AppDimensions.spacingLg),
          _MessageSectionLabelSkeleton(isDark: isDark),
          ...List.generate(
              3,
              (index) =>
                  _MessageCardSkeleton(index: index + 5, isDark: isDark)),
        ],
      ),
    );
  }
}

/// Section label skeleton for messages
class _MessageSectionLabelSkeleton extends StatelessWidget {
  final bool isDark;

  const _MessageSectionLabelSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    // Warm beige colors matching feed skeleton
    final Color placeholder =
        isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.skeletonBaseLight;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        8,
        AppHeaderStyle.contentHorizontalPadding,
        AppHeaderStyle.cardVerticalGap,
      ),
      child: Material(
        color: cardColor,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: ShimmerBox(
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 12,
                  decoration: BoxDecoration(
                    color: placeholder,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                  ),
                ),
                SizedBox(width: AppDimensions.spacingMdSm),
                Container(
                  width: 32,
                  height: 18,
                  decoration: BoxDecoration(
                    color: placeholder,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Message card skeleton with shimmer animation
class _MessageCardSkeleton extends StatelessWidget {
  final int index;
  final bool isDark;

  const _MessageCardSkeleton({required this.index, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    // Warm beige colors matching feed skeleton
    final Color placeholder =
        isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.skeletonBaseLight;
    final Color placeholderDark =
        isDark ? Colors.white.withValues(alpha: 0.14) : AppTheme.skeletonShimmerLight;

    // Vary widths naturally for organic look
    final nameWidths = [100.0, 85.0, 115.0, 90.0, 105.0, 80.0, 95.0, 110.0];
    final msgWidths = [160.0, 130.0, 175.0, 145.0, 155.0, 140.0, 125.0, 165.0];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        0,
        AppHeaderStyle.contentHorizontalPadding,
        AppHeaderStyle.cardVerticalGap,
      ),
      child: Material(
        color: cardColor,
        elevation: isDark ? 2 : 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: ShimmerBox(
          child: Container(
            height: AppHeaderStyle.cardCompactHeight,
            padding: EdgeInsets.only(left: 20, right: 12),
            child: Row(
              children: [
                // Avatar placeholder - 44x44 circle matching actual card
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: placeholderDark,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: AppDimensions.spacingMdLg),
                // Content
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Container(
                        width: nameWidths[index % nameWidths.length],
                        height: 14,
                        decoration: BoxDecoration(
                          color: placeholderDark,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      SizedBox(height: AppDimensions.spacingSmMd),
                      // Message preview
                      Container(
                        width: msgWidths[index % msgWidths.length],
                        height: 11,
                        decoration: BoxDecoration(
                          color: placeholder,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right side - time + namaste area
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Time
                    Container(
                      width: 22,
                      height: 10,
                      decoration: BoxDecoration(
                        color: placeholder,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    SizedBox(width: AppDimensions.spacingSm),
                    // Namaste button area
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: placeholder,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
