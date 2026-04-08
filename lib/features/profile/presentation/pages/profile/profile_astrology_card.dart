import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';

/// Astrology "Stars" card showing sun/moon/rising signs or setup prompt.
class ProfileAstrologyCard extends StatelessWidget {
  final bool isDark;
  final bool isOwnProfile;
  final Future<AstrologyProfile?>? astrologyProfileFuture;
  final VoidCallback? onTapDetails;
  final VoidCallback? onTapRetry;
  final VoidCallback? onTapSetup;

  const ProfileAstrologyCard({
    super.key,
    required this.isDark,
    required this.isOwnProfile,
    required this.astrologyProfileFuture,
    this.onTapDetails,
    this.onTapRetry,
    this.onTapSetup,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;

    return FutureBuilder<AstrologyProfile?>(
      future: astrologyProfileFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final profile = snapshot.data;

        // Determine profile states
        final hasProfile = profile != null && profile.isEnabled;
        final hasCalculatedData =
            profile != null && profile.isEnabled && profile.hasCalculatedData;
        final isCalculating = hasProfile && !hasCalculatedData;

        // Don't show card if other user has no astrology profile
        if (!hasProfile && !isOwnProfile && !isLoading) {
          return const SizedBox.shrink();
        }

        // Only allow navigation for own profile (basic signs always visible to others)
        return TransparentToolbox.buildCard(
          context: context,
          onTap: isOwnProfile
              ? () {
                  if (hasCalculatedData) {
                    onTapDetails?.call();
                  } else if (isCalculating) {
                    onTapRetry?.call();
                  } else {
                    onTapSetup?.call();
                  }
                }
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'STARS',
                      style: AppTheme.cardLabelStyle,
                    ),
                    if (isLoading) ...[
                      // Loading state - show skeleton
                      const SizedBox(height: AppDimensions.spacingXs),
                      _buildAstroLoadingSkeleton(primaryColor, isDark),
                    ] else if (hasCalculatedData) ...[
                      const SizedBox(height: AppDimensions.spacingXs),
                      // Rising, Sun, Moon in a row
                      Row(
                        children: [
                          _buildSignItem(
                              'Rising', profile.ascendant ?? '—', primaryColor),
                          const SizedBox(width: AppDimensions.spacingXxl),
                          _buildSignItem(
                              'Sun', profile.sunSign ?? '—', primaryColor),
                          const SizedBox(width: AppDimensions.spacingXxl),
                          _buildSignItem(
                              'Moon', profile.moonSign ?? '—', primaryColor),
                        ],
                      ),
                    ] else if (isCalculating) ...[
                      // Calculating state - show animated indicator
                      const SizedBox(height: AppDimensions.spacingSm),
                      _buildCalculatingState(primaryColor, isDark),
                      const SizedBox(height: AppDimensions.spacingSmMd),
                      Text(
                        'Tap to retry',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: primaryColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        'Set up your birth chart',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Only show chevron for own profile when not calculating
              if (isOwnProfile && !isCalculating)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.primaryLow,
                ),
            ],
          ),
        );
      },
    );
  }

  /// Skeleton loading state for astrology card
  Widget _buildAstroLoadingSkeleton(Color primaryColor, bool isDark) {
    final skeletonBase = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : primaryColor.withValues(alpha: 0.1);

    return Row(
      children: [
        _buildSkeletonSignItem(skeletonBase),
        const SizedBox(width: AppDimensions.spacingXxl),
        _buildSkeletonSignItem(skeletonBase),
        const SizedBox(width: AppDimensions.spacingXxl),
        _buildSkeletonSignItem(skeletonBase),
      ],
    );
  }

  Widget _buildSkeletonSignItem(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Container(
          width: 50,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ],
    );
  }

  /// Calculating state with animated shimmer
  Widget _buildCalculatingState(Color primaryColor, bool isDark) {
    return Row(
      children: [
        // Animated moon/star icon
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1500),
          builder: (context, value, child) {
            return Transform.rotate(
              angle: value * 0.3,
              child: Icon(
                Icons.nights_stay_rounded,
                size: 18,
                color: AppTheme.cosmicPurple
                    .withValues(alpha: 0.7 + (value * 0.3)),
              ),
            );
          },
        ),
        const SizedBox(width: AppDimensions.spacingMdSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calculating your stars...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryColor.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXxs),
              Text(
                'Your birth chart is being prepared',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: primaryColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXxs),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
