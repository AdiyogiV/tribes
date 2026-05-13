import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/app/tabs/widgets/profile_stats.dart';
import 'package:aurogram/features/profile/domain/follow_service.dart';

/// Stats card: posts, followers, following.
class ProfileStatsCardWidget extends StatelessWidget {
  final bool isDark;
  final bool isOwnProfile;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final String? followStatus;
  final bool theyFollowMe;
  final FollowService followService;
  final VoidCallback? onOpenStats;
  final void Function({int initialTabIndex})? onOpenStatsWithTab;

  const ProfileStatsCardWidget({
    super.key,
    required this.isDark,
    required this.isOwnProfile,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    required this.followStatus,
    required this.theyFollowMe,
    required this.followService,
    this.onOpenStats,
    this.onOpenStatsWithTab,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;
    final isMutual =
        followStatus == FollowService.statusFollowing && theyFollowMe;
    final canOpenStats = isOwnProfile || isMutual;

    return TransparentToolbox.buildCard(
      context: context,
      onTap: canOpenStats ? onOpenStats : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'STATS',
            style: AppTheme.cardLabelStyle,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Row(
            children: [
              ProfileStatItem(
                label: 'Posts',
                value: postCount.toString(),
                color: primaryColor,
              ),
              const SizedBox(width: AppDimensions.spacingXxl),
              canOpenStats
                  ? ProfileTappableStatItem(
                      label: 'Followers',
                      value: followService.getFollowerTier(followerCount),
                      color: primaryColor,
                      onTap: () => onOpenStatsWithTab?.call(initialTabIndex: 0),
                    )
                  : ProfileStatItem(
                      label: 'Followers',
                      value: followService.getFollowerTier(followerCount),
                      color: primaryColor,
                    ),
              const SizedBox(width: AppDimensions.spacingXxl),
              canOpenStats
                  ? ProfileTappableStatItem(
                      label: 'Following',
                      value: followService.getFollowerTier(followingCount),
                      color: primaryColor,
                      onTap: () => onOpenStatsWithTab?.call(initialTabIndex: 1),
                    )
                  : ProfileStatItem(
                      label: 'Following',
                      value: followService.getFollowerTier(followingCount),
                      color: primaryColor,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Auroboard card: rank and score. Whole card is tappable and opens leaderboard.
class ProfileAuroboardCard extends StatelessWidget {
  final bool isDark;
  final int auraScore;
  final Future<int?>? userRankFuture;
  final VoidCallback onOpenLeaderboard;

  const ProfileAuroboardCard({
    super.key,
    required this.isDark,
    required this.auraScore,
    required this.userRankFuture,
    required this.onOpenLeaderboard,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;

    return TransparentToolbox.buildCard(
      context: context,
      onTap: onOpenLeaderboard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AUROBOARD',
            style: AppTheme.cardLabelStyle,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Row(
            children: [
              if (userRankFuture != null)
                FutureBuilder<int?>(
                  future: userRankFuture,
                  builder: (context, snapshot) {
                    final isLoading = snapshot.connectionState == ConnectionState.waiting;
                    final rank = snapshot.data;

                    if (isLoading) {
                      // Show shimmer placeholder while rank is loading
                      final skeletonColor = isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : primaryColor.withValues(alpha: 0.1);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Rank',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: primaryColor.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingXxs),
                          Container(
                            width: 32,
                            height: 14,
                            decoration: BoxDecoration(
                              color: skeletonColor,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                            ),
                          ),
                        ],
                      );
                    }

                    final value = rank != null ? rank.toString() : '—';
                    return ProfileStatItem(
                      label: 'Rank',
                      value: value,
                      color: primaryColor,
                    );
                  },
                ),
              if (userRankFuture != null) const SizedBox(width: AppDimensions.spacingXxl),
              ProfileStatItem(
                label: 'Score',
                value: auraScore.toString(),
                color: primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
