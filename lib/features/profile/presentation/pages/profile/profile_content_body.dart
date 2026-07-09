import 'package:cloud_firestore/cloud_firestore.dart' show QueryDocumentSnapshot, QuerySnapshot;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/features/profile/domain/follow_service.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_hero_section.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_stats_cards.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_astrology_card.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_insights_card.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_ayurveda_card.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_compatibility_card.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_posts_section.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_follow_request_banner.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/routing/route_names.dart';

/// Builds the main profile content body (hero, cards, posts).
/// Used by both mobile and desktop layouts.
class ProfileContentBody extends StatelessWidget {
  final bool isDark;
  final bool isOwnProfile;
  final String? uid;
  final String? currentUid;
  final Map<String, dynamic>? profileData;
  final bool isPrivateProfile;
  final bool theyFollowMe;
  final bool hasPendingRequestToMe;
  final bool isAcceptingRequest;
  final int refreshKey;
  final int followerCount;
  final int followingCount;
  final String? followStatus;
  final int postCount;
  final FollowService followService;
  final Future<AstrologyProfile?>? astrologyProfileFuture;
  final Stream<DailyInsight?>? dailyInsightStream;
  final Stream<AyurvedaProfile?>? ayurvedaProfileStream;
  final AyurvedaProfile? cachedAyurvedaProfile;
  final Future<int?>? userRankFuture;
  final Map<String, dynamic>? cachedProfileData;
  final GlobalKey<dynamic> compatibilityBadgeKey;
  final int profileTabIndex;
  final Stream<QuerySnapshot>? profilePostsStream;
  final Stream<QuerySnapshot>? profileRepostsStream;
  final List<QueryDocumentSnapshot>? cachedProfilePosts;
  final List<QueryDocumentSnapshot>? cachedProfileReposts;
  final VoidCallback onEditProfile;
  final VoidCallback onAcceptFollowRequest;
  final VoidCallback onDeclineFollowRequest;
  final VoidCallback onOpenLeaderboard;
  final void Function({int initialTabIndex}) onOpenStats;
  final VoidCallback onRetryAstrology;
  final ValueChanged<AyurvedaProfile?> onAyurvedaProfileChanged;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<List<QueryDocumentSnapshot>> onPostsCached;
  final ValueChanged<List<QueryDocumentSnapshot>> onRepostsCached;

  const ProfileContentBody({
    super.key,
    required this.isDark,
    required this.isOwnProfile,
    required this.uid,
    required this.currentUid,
    required this.profileData,
    required this.isPrivateProfile,
    required this.theyFollowMe,
    required this.hasPendingRequestToMe,
    required this.isAcceptingRequest,
    required this.refreshKey,
    required this.followerCount,
    required this.followingCount,
    required this.followStatus,
    required this.postCount,
    required this.followService,
    required this.astrologyProfileFuture,
    required this.dailyInsightStream,
    required this.ayurvedaProfileStream,
    required this.cachedAyurvedaProfile,
    required this.userRankFuture,
    required this.cachedProfileData,
    required this.compatibilityBadgeKey,
    required this.profileTabIndex,
    required this.profilePostsStream,
    required this.profileRepostsStream,
    required this.cachedProfilePosts,
    required this.cachedProfileReposts,
    required this.onEditProfile,
    required this.onAcceptFollowRequest,
    required this.onDeclineFollowRequest,
    required this.onOpenLeaderboard,
    required this.onOpenStats,
    required this.onRetryAstrology,
    required this.onAyurvedaProfileChanged,
    required this.onTabChanged,
    required this.onPostsCached,
    required this.onRepostsCached,
  });

  @override
  Widget build(BuildContext context) {
    final name = profileData?['name'] ?? '';
    final nickname = profileData?['nickname'] ?? '';
    final displayPicture = profileData?['displayPicture'];
    final auraScore = profileData?['auraScore'] ?? 0;

    return Column(
      children: [
        const SizedBox(height: AppHeaderStyle.contentTopPadding),

        // Profile card with avatar and name
        ProfileHeroSection(
          isDark: isDark,
          name: name,
          nickname: nickname,
          displayPicture: displayPicture,
          auraScore: auraScore,
          isOwnProfile: isOwnProfile,
          uid: uid,
          isPrivateProfile: isPrivateProfile,
          theyFollowMe: theyFollowMe,
          onEditProfile: onEditProfile,
        ),

        SizedBox(height: AppHeaderStyle.cardVerticalGap),

        // Follow Request Card
        if (!isOwnProfile && hasPendingRequestToMe) ...[
          ProfileFollowRequestBanner(
            userName: name,
            isAcceptingRequest: isAcceptingRequest,
            onAccept: onAcceptFollowRequest,
            onDecline: onDeclineFollowRequest,
          ),
          SizedBox(height: AppHeaderStyle.cardVerticalGap),
        ],

        // Other cards with standard horizontal padding
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppHeaderStyle.contentHorizontalPadding),
          child: Column(
            // NOTE: Do NOT add a ValueKey keyed on refreshKey here.
            // A changing key causes Flutter to unmount/remount ALL children,
            // which destroys FutureBuilder/StreamBuilder internal state and
            // forces insights, rank, and astrology cards back into loading
            // states. Instead, FutureBuilders detect future-object changes
            // via didUpdateWidget and re-subscribe automatically.
            children: [
              // Auroboard card hidden — rank lives on the leaderboard and the
              // aura score now shows inside the Stats card below.

              // Stats (posts, followers, following, score)
              ProfileStatsCardWidget(
                isDark: isDark,
                isOwnProfile: isOwnProfile,
                postCount: postCount,
                followerCount: followerCount,
                followingCount: followingCount,
                auraScore: auraScore,
                followStatus: followStatus,
                theyFollowMe: theyFollowMe,
                followService: followService,
                onOpenStats: () => onOpenStats(),
                onOpenStatsWithTab: onOpenStats,
              ),

              SizedBox(height: AppHeaderStyle.cardVerticalGap),

              // Astrology (stars)
              if (uid != null)
                ProfileAstrologyCard(
                  isDark: isDark,
                  isOwnProfile: isOwnProfile,
                  astrologyProfileFuture: astrologyProfileFuture,
                  onTapDetails: () {
                    context.push('/astrology/details/$uid');
                  },
                  onTapRetry: onRetryAstrology,
                  onTapSetup: () {
                    context.push('/astrology/setup');
                  },
                ),

              // Ayurveda (own profile only)
              if (uid != null && isOwnProfile) ...[
                SizedBox(height: AppHeaderStyle.cardVerticalGap),
                ProfileAyurvedaCard(
                  isDark: isDark,
                  uid: uid!,
                  astrologyProfileFuture: astrologyProfileFuture,
                  ayurvedaProfileStream: ayurvedaProfileStream,
                  cachedAyurvedaProfile: cachedAyurvedaProfile,
                  onAyurvedaProfileChanged: onAyurvedaProfileChanged,
                  onOpenDetails: () {
                    context.push('/ayurveda/details/$uid');
                  },
                ),
              ],

              // Compatibility (for other users)
              if (uid != null && !isOwnProfile) ...[
                SizedBox(height: AppHeaderStyle.cardVerticalGap),
                ProfileCompatibilityCard(
                  isDark: isDark,
                  otherUserId: uid!,
                  followStatus: followStatus,
                  theyFollowMe: theyFollowMe,
                  cachedProfileData: cachedProfileData,
                  compatibilityBadgeKey: compatibilityBadgeKey,
                ),
              ],

              // Insights (own profile only) — shown last, just above posts
              if (uid != null && isOwnProfile) ...[
                SizedBox(height: AppHeaderStyle.cardVerticalGap),
                ProfileInsightsCard(
                  isDark: isDark,
                  astrologyProfileFuture: astrologyProfileFuture,
                  dailyInsightStream: dailyInsightStream,
                  onTap: () {
                    context.push(RouteNames.dailyInsight, extra: {'uid': uid!});
                  },
                ),
              ],

              // Profile Posts Section
              if (uid != null) ...[
                SizedBox(height: AppHeaderStyle.cardVerticalGap),
                ProfilePostsSection(
                  isDark: isDark,
                  uid: uid,
                  currentUid: currentUid,
                  isPrivateProfile: isPrivateProfile,
                  followStatus: followStatus,
                  profileTabIndex: profileTabIndex,
                  onTabChanged: onTabChanged,
                  profilePostsStream: profilePostsStream,
                  profileRepostsStream: profileRepostsStream,
                  cachedProfilePosts: cachedProfilePosts,
                  cachedProfileReposts: cachedProfileReposts,
                  onPostsCached: onPostsCached,
                  onRepostsCached: onRepostsCached,
                ),
                const SizedBox(height: 200),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
