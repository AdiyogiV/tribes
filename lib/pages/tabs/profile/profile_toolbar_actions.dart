import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/services/follow_service.dart';
import 'package:aurogram/pages/tabs/widgets/profile_nav_item.dart';

/// Builds the follow button content based on current follow status.
class ProfileFollowButtonContent extends StatelessWidget {
  final bool isFollowing;
  final String? followStatus;
  final bool theyFollowMe;
  final Color primaryColor;
  final double iconSize;

  const ProfileFollowButtonContent({
    super.key,
    required this.isFollowing,
    required this.followStatus,
    required this.theyFollowMe,
    required this.primaryColor,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    // Not following - show follow button with label
    if (!isFollowing) {
      final label = theyFollowMe ? 'Follow\nBack' : 'Follow';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.person_badge_plus_fill,
            color: theyFollowMe ? AppTheme.honeyAmber : primaryColor,
            size: iconSize - 4,
          ),
          const SizedBox(height: AppDimensions.spacingXxs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: theyFollowMe
                  ? AppTheme.honeyAmber.withValues(alpha: 0.9)
                  : primaryColor.withValues(alpha: 0.7),
              height: 1.1,
            ),
          ),
        ],
      );
    }

    // Pending request - show clock/hourglass icon with label
    if (followStatus == FollowService.statusPending) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.clock_fill,
            color: AppTheme.honeyAmber.withValues(alpha: 0.85),
            size: iconSize - 4,
          ),
          const SizedBox(height: AppDimensions.spacingXxs),
          Text(
            'Requested',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppTheme.honeyAmber.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }

    // Confirmed following - show following status
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.checkmark_circle_fill,
          color: AppTheme.successColor.withValues(alpha: 0.7),
          size: iconSize - 4,
        ),
        const SizedBox(height: AppDimensions.spacingXxs),
        Text(
          'Following',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppTheme.successColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// Builds the action items for own profile toolbar.
List<Widget> buildOwnProfileActions({
  required bool isDark,
  required VoidCallback onNamaste,
  required VoidCallback onInvites,
  required VoidCallback onAddPost,
  required VoidCallback onNotifications,
  required VoidCallback onSettings,
}) {
  final primaryColor = AppTheme.primaryColor.withValues(alpha: 0.85);
  const double iconSize = 26;
  return [
    // 1. Namaste (first)
    ProfileNavItem(
      onTap: onNamaste,
      child: Opacity(
        opacity: 0.85,
        child: Center(
          child: Image.asset(
            'assets/icons/namaste.png',
            width: 40,
            height: 40,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    ),
    // 2. Invites (second)
    ProfileNavItem(
      onTap: onInvites,
      child: Icon(
        Icons.mail_outline,
        color: primaryColor,
        size: iconSize,
      ),
    ),
    // 3. Plus (centered)
    ProfileNavItem(
      onTap: onAddPost,
      child: Icon(
        CupertinoIcons.plus,
        color: primaryColor,
        size: iconSize,
      ),
    ),
    // 4. Notifications (fourth)
    ProfileNavItem(
      onTap: onNotifications,
      child: Icon(
        Icons.notifications_outlined,
        color: primaryColor,
        size: iconSize,
      ),
    ),
    // 5. Settings (last)
    ProfileNavItem(
      onTap: onSettings,
      child: Icon(
        Icons.settings_outlined,
        color: primaryColor,
        size: iconSize,
      ),
    ),
  ];
}

/// Builds the action items for other user's profile toolbar.
List<Widget> buildOtherUserProfileActions({
  required bool isFollowing,
  required bool isFollowLoading,
  required String? followStatus,
  required bool theyFollowMe,
  required bool isUserBlocked,
  required VoidCallback onFollowTap,
  required VoidCallback onNamaste,
  required VoidCallback onDirectMessage,
  required VoidCallback onToggleBlock,
}) {
  final primaryColor = AppTheme.primaryColor.withValues(alpha: 0.85);
  const double iconSize = 26;
  return [
    // Follow/Unfollow/Requested button
    ProfileNavItem(
      onTap: onFollowTap,
      child: isFollowLoading
          ? SizedBox(
              width: iconSize,
              height: iconSize,
              child: CupertinoActivityIndicator(),
            )
          : ProfileFollowButtonContent(
              isFollowing: isFollowing,
              followStatus: followStatus,
              theyFollowMe: theyFollowMe,
              primaryColor: primaryColor,
              iconSize: iconSize,
            ),
    ),
    ProfileNavItem(
      onTap: onNamaste,
      child: Opacity(
        opacity: 0.85,
        child: Center(
          child: Image.asset(
            'assets/icons/namaste.png',
            width: 40,
            height: 40,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    ),
    ProfileNavItem(
      onTap: onDirectMessage,
      child: Icon(
        CupertinoIcons.paperplane_fill,
        color: primaryColor,
        size: iconSize,
      ),
    ),
    // Hidden for App Store Guideline 1.2 compliance
    // ProfileNavItem(
    //   onTap: onSendAnonymousMessage,
    //   child: Icon(
    //     Icons.visibility_off_outlined,
    //     color: primaryColor,
    //     size: iconSize,
    //   ),
    // ),
    ProfileNavItem(
      onTap: onToggleBlock,
      child: Icon(
        isUserBlocked ? Icons.block : Icons.block_outlined,
        color: isUserBlocked
            ? AppTheme.errorColor.withValues(alpha: 0.85)
            : primaryColor,
        size: iconSize,
      ),
    ),
  ];
}
