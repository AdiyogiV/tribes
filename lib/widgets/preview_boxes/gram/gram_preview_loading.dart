import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Loading and error state builders for GramPreviewBox.
/// These are static helpers so they can be called from the state class.
class GramPreviewLoading {
  GramPreviewLoading._();

  static Widget buildLoadingState(BuildContext context, {bool compact = false}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? AppTheme.cardDarkColor : Colors.white;
    // Warm beige colors matching feed skeleton
    final Color placeholder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppTheme.skeletonBaseLight;
    final Color placeholderDark = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : AppTheme.skeletonShimmerLight;

    if (compact) {
      // Compact skeleton - matches compact preview dimensions with shimmer
      return ShimmerBox(
        child: SizedBox(
          height: 42,
          child: Row(
            children: [
              // Avatar skeleton
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: placeholderDark,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMdSm),
              // Text placeholders
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: placeholderDark,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSmMd),
                    Container(
                      width: 60,
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
        ),
      );
    }

    // Full skeleton matching feed post card style
    return Padding(
      padding: EdgeInsets.fromLTRB(AppHeaderStyle.contentHorizontalPadding, 0, AppHeaderStyle.contentHorizontalPadding, AppHeaderStyle.cardVerticalGap),
      child: Material(
        color: cardColor,
        elevation: isDark ? 2 : 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        clipBehavior: Clip.antiAlias,
        child: ShimmerBox(
          child: Container(
            height: AppHeaderStyle.cardRegularHeight,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar skeleton - circular
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: placeholderDark,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingLg),
                // Content skeleton
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
                            width: 130,
                            height: 14,
                            decoration: BoxDecoration(
                              color: placeholderDark,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingSmMd),
                          Container(
                            width: 80,
                            height: 10,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                      // Mini previews skeleton row
                      Row(
                        children: List.generate(4, (i) => Transform.translate(
                          offset: Offset(-i * 8.0, 0),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                              border: Border.all(color: cardColor, width: 2),
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

  static Widget buildErrorState(BuildContext context, {bool compact = false}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (compact) {
      return Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Center(
          child: Icon(
            Icons.error_outline,
            color: isDark ? AppTheme.textSecondaryDarkColor : AppTheme.textSecondaryLightColor,
            size: 18,
          ),
        ),
      );
    }

    final Color barBase = isDark ? AppTheme.cardDarkColor : Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppHeaderStyle.contentHorizontalPadding, 0, AppHeaderStyle.contentHorizontalPadding, AppHeaderStyle.cardVerticalGap),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          elevation: 4,
          color: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            height: AppHeaderStyle.cardCompactHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  barBase.withValues(alpha: isDark ? 0.85 : 0.90),
                  barBase.withValues(alpha: isDark ? 0.80 : 0.85),
                ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : barBase.withValues(alpha: 0.32),
              ),
            ),
            child: Center(
              child: Text(
                "Gram unavailable",
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.textSecondaryDarkColor : AppTheme.textSecondaryLightColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
