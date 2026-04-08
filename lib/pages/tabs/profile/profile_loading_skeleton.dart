import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Shimmer/skeleton loading state for the profile page
class ProfileLoadingSkeleton extends StatelessWidget {
  final bool isDark;

  const ProfileLoadingSkeleton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Color placeholder =
        AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.08);
    final Color placeholderDark =
        AppTheme.primaryColor.withValues(alpha: isDark ? 0.18 : 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.spacingXxl),
          // Avatar skeleton
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: placeholder,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          // Name skeleton
          Container(
            width: 150,
            height: 22,
            decoration: BoxDecoration(
              color: placeholderDark,
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMdSm),
          // Username skeleton
          Container(
            width: 100,
            height: 14,
            decoration: BoxDecoration(
              color: placeholder,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(height: 28),
          // Stats row skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                3,
                (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 20,
                            decoration: BoxDecoration(
                              color: placeholderDark,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingSmMd),
                          Container(
                            width: 56,
                            height: 12,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                            ),
                          ),
                        ],
                      ),
                    )),
          ),
          const SizedBox(height: 28),
          // Bio skeleton lines
          ...List.generate(
              2,
              (i) => Padding(
                    padding: EdgeInsets.only(
                        bottom: 10,
                        left: i == 1 ? 30 : 0,
                        right: i == 1 ? 30 : 0),
                    child: Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: i == 0 ? placeholderDark : placeholder,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  )),
          const SizedBox(height: AppDimensions.spacingLg),
          // Action buttons skeleton
          Container(
            width: 200,
            height: 44,
            decoration: BoxDecoration(
              color: placeholder,
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ],
      ),
    );
  }
}
