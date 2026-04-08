import 'package:flutter/cupertino.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/features/profile/domain/follow_service.dart';
import 'package:aurogram/features/profile/presentation/pages/social/follow_list_page.dart';

/// Stats card showing Aura, Followers, Following
class ProfileStatsCard extends StatelessWidget {
  final int auraScore;
  final int followerCount;
  final int followingCount;
  final FollowService followService;
  final VoidCallback onOpenLeaderboard;
  final void Function(FollowListType) onOpenFollowList;

  const ProfileStatsCard({
    super.key,
    required this.auraScore,
    required this.followerCount,
    required this.followingCount,
    required this.followService,
    required this.onOpenLeaderboard,
    required this.onOpenFollowList,
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
          Text('STATS', style: AppTheme.cardLabelStyle),
          const SizedBox(height: AppDimensions.spacingXs),
          Row(
            children: [
              _buildStatItem('Auro Score', auraScore.toString(), primaryColor),
              const SizedBox(width: AppDimensions.spacingXxl),
              _buildTappableStatItem(
                label: 'Followers',
                value: followService.getFollowerTier(followerCount),
                color: primaryColor,
                onTap: () => onOpenFollowList(FollowListType.followers),
              ),
              const SizedBox(width: AppDimensions.spacingXxl),
              _buildTappableStatItem(
                label: 'Following',
                value: followService.getFollowerTier(followingCount),
                color: primaryColor,
                onTap: () => onOpenFollowList(FollowListType.following),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
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

  Widget _buildTappableStatItem({
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
              const SizedBox(width: 3),
              Icon(
                CupertinoIcons.chevron_right,
                size: 10,
                color: color.withValues(alpha: 0.5),
              ),
            ],
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
      ),
    );
  }
}

/// Astrology card showing Rising, Sun, Moon signs
class ProfileAstrologyCard extends StatelessWidget {
  final Future<AstrologyProfile?>? profileFuture;
  final bool isOwnProfile;
  final VoidCallback onNavigateToDetails;
  final VoidCallback onNavigateToSetup;

  const ProfileAstrologyCard({
    super.key,
    required this.profileFuture,
    required this.isOwnProfile,
    required this.onNavigateToDetails,
    required this.onNavigateToSetup,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<AstrologyProfile?>(
      future: profileFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final profile = snapshot.data;

        final hasProfile = profile != null && profile.isEnabled;
        final hasCalculatedData =
            profile != null && profile.isEnabled && profile.hasCalculatedData;
        final isCalculating = hasProfile && !hasCalculatedData;

        if (!hasProfile && !isOwnProfile && !isLoading) {
          return const SizedBox.shrink();
        }

        return TransparentToolbox.buildCard(
          context: context,
          onTap: isOwnProfile
              ? () {
                  if (hasCalculatedData) {
                    onNavigateToDetails();
                  } else if (!isCalculating) {
                    onNavigateToSetup();
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
                    Text('STARS', style: AppTheme.cardLabelStyle),
                    if (isLoading) ...[
                      const SizedBox(height: AppDimensions.spacingXs),
                      _buildLoadingSkeleton(primaryColor, isDark),
                    ] else if (hasCalculatedData) ...[
                      const SizedBox(height: AppDimensions.spacingXs),
                      Row(
                        children: [
                          _buildSignItem('Rising', profile.ascendant ?? '—',
                              primaryColor),
                          const SizedBox(width: AppDimensions.spacingXxl),
                          _buildSignItem(
                              'Sun', profile.sunSign ?? '—', primaryColor),
                          const SizedBox(width: AppDimensions.spacingXxl),
                          _buildSignItem(
                              'Moon', profile.moonSign ?? '—', primaryColor),
                        ],
                      ),
                    ] else if (isCalculating) ...[
                      const SizedBox(height: AppDimensions.spacingSm),
                      _buildCalculatingState(primaryColor, isDark),
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
              if (isOwnProfile && !isCalculating)
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppTheme.primaryLow),
            ],
          ),
        );
      },
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
              fontSize: 14, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton(Color primaryColor, bool isDark) {
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

  Widget _buildCalculatingState(Color primaryColor, bool isDark) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Row(
          children: [
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
              onEnd: () => setState(() {}),
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
      },
    );
  }
}

/// Insights card showing daily cosmic insight
class ProfileInsightsCard extends StatelessWidget {
  final Future<AstrologyProfile?>? profileFuture;
  final Stream<DailyInsight?>? insightStream;
  final VoidCallback onTap;

  const ProfileInsightsCard({
    super.key,
    required this.profileFuture,
    required this.insightStream,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<AstrologyProfile?>(
      future: profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final hasProfile =
            profile != null && profile.isEnabled && profile.hasCalculatedData;

        if (!hasProfile) return const SizedBox.shrink();

        return TransparentToolbox.buildCard(
          context: context,
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('INSIGHTS', style: AppTheme.cardLabelStyle),
                    const SizedBox(height: AppDimensions.spacingSm),
                    StreamBuilder<DailyInsight?>(
                      stream: insightStream,
                      builder: (context, insightSnapshot) {
                        final insight = insightSnapshot.data;
                        final isLoading = insightSnapshot.connectionState ==
                            ConnectionState.waiting;

                        if (isLoading) {
                          return _buildInsightSkeleton(
                              isDark, primaryColor, context);
                        } else if (insight != null &&
                            insight.message.isNotEmpty) {
                          return _buildFormattedInsightText(
                              insight.message, primaryColor);
                        } else {
                          return Text(
                            'Tap to generate your personalized insight.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: primaryColor.withValues(alpha: 0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppTheme.primaryLow),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInsightSkeleton(
      bool isDark, Color primaryColor, BuildContext context) {
    final skeletonBase = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : primaryColor.withValues(alpha: 0.1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 12,
          decoration: BoxDecoration(
              color: skeletonBase, borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd)),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Container(
          width: MediaQuery.of(context).size.width * 0.7,
          height: 12,
          decoration: BoxDecoration(
              color: skeletonBase, borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd)),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Container(
          width: MediaQuery.of(context).size.width * 0.5,
          height: 12,
          decoration: BoxDecoration(
              color: skeletonBase, borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd)),
        ),
      ],
    );
  }

  Widget _buildFormattedInsightText(String text, Color baseColor) {
    final List<TextSpan> spans = [];
    final RegExp pattern = RegExp(r'\*\*(.+?)\*\*|_(.+?)_|([^*_]+)');

    final baseStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: baseColor.withValues(alpha: 0.85),
      height: 1.5,
    );

    for (final match in pattern.allMatches(text)) {
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(fontWeight: FontWeight.w700, color: baseColor),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
              fontStyle: FontStyle.italic,
              color: baseColor.withValues(alpha: 0.85)),
        ));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(text: match.group(3)));
      }
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }
}

/// Follow request banner card
class FollowRequestBanner extends StatelessWidget {
  final String userName;
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const FollowRequestBanner({
    super.key,
    required this.userName,
    required this.isLoading,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    final displayName = userName.isNotEmpty ? userName : 'Someone';

    return TransparentToolbox.buildCard(
      context: context,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('FOLLOW REQUEST', style: AppTheme.cardLabelStyle),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              '$displayName has requested to follow you',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: isLoading ? null : onAccept,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Center(
                        child: isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CupertinoActivityIndicator(
                                    color: Colors.white),
                              )
                            : const Text(
                                'Accept',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMdSm),
                Expanded(
                  child: GestureDetector(
                    onTap: isLoading ? null : onDecline,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        border: Border.all(
                            color: c.withValues(alpha: 0.2), width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          'Decline',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Private profile locked state card
class PrivateProfileLockedCard extends StatelessWidget {
  final String? followStatus;

  const PrivateProfileLockedCard({super.key, this.followStatus});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;

    final String message;
    final IconData icon;
    final Color iconColor;

    if (followStatus == FollowService.statusPending) {
      message = 'Request pending';
      icon = CupertinoIcons.hourglass;
      iconColor = c.withValues(alpha: 0.5);
    } else {
      message = 'Follow to see their posts';
      icon = CupertinoIcons.lock_fill;
      iconColor = c.withValues(alpha: 0.5);
    }

    return TransparentToolbox.buildCard(
      context: context,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('POSTS PRIVATE', style: AppTheme.cardLabelStyle),
            const SizedBox(height: AppDimensions.spacingXs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSmMd),
                Icon(icon, size: 14, color: iconColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
