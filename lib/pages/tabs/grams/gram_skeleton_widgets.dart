import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Skeleton grid for initial loading - instant display with shimmer.
/// Matches the actual GramPreviewBox card dimensions (full width, ~88px height).
class GramSkeletonGrid extends StatelessWidget {
  const GramSkeletonGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: AppHeaderStyle.contentTopPadding),
          // Generate 5 skeleton items - no delay, instant display
          ...List.generate(
              5, (index) => GramSkeletonItem(index: index)),
          SizedBox(height: AppHeaderStyle.contentBottomPadding + 50),
        ],
      ),
    );
  }
}

/// Single skeleton item - matches GramPreviewBox layout with shimmer animation.
/// Uses warm beige colors consistent with feed and chat skeletons.
class GramSkeletonItem extends StatelessWidget {
  final int index;

  const GramSkeletonItem({super.key, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? AppTheme.cardDarkColor : Colors.white;
    // Warm beige colors matching feed skeleton
    final Color placeholder =
        isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.skeletonBaseLight;
    final Color placeholderDark =
        isDark ? Colors.white.withValues(alpha: 0.14) : AppTheme.skeletonShimmerLight;

    // Vary widths for organic look
    final titleWidths = [130.0, 110.0, 145.0, 120.0, 135.0];
    final subtitleWidths = [80.0, 65.0, 90.0, 75.0, 85.0];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppHeaderStyle.contentHorizontalPadding,
          0,
          AppHeaderStyle.contentHorizontalPadding,
          AppHeaderStyle.cardVerticalGap),
      child: Material(
        color: cardColor,
        elevation: isDark ? 2 : 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: ShimmerBox(
          child: Container(
            height: AppHeaderStyle.cardRegularHeight,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar placeholder
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: placeholderDark,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingLg),
                // Content area
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and subtitle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: titleWidths[index % titleWidths.length],
                            height: 14,
                            decoration: BoxDecoration(
                              color: placeholderDark,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingSmMd),
                          Container(
                            width:
                                subtitleWidths[index % subtitleWidths.length],
                            height: 10,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                      // Mini previews placeholder row
                      Row(
                        children: List.generate(
                            4,
                            (i) => Transform.translate(
                                  offset: Offset(-i * 8.0, 0),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: placeholder,
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                      border: Border.all(
                                          color: cardColor, width: 2),
                                    ),
                                  ),
                                )),
                      ),
                    ],
                  ),
                ),
                // Right side
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 35,
                      height: 10,
                      decoration: BoxDecoration(
                        color: placeholder,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
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
