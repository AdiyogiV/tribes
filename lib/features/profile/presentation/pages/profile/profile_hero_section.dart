import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/core/storage/image_optimizer.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/app/tabs/widgets/fullscreen_avatar_viewer.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Profile hero section with avatar, name, and follow status badges.
class ProfileHeroSection extends StatelessWidget {
  final bool isDark;
  final String name;
  final String nickname;
  final String? displayPicture;
  final int auraScore;
  final bool isOwnProfile;
  final String? uid;
  final bool isPrivateProfile;
  final bool theyFollowMe;
  final VoidCallback? onEditProfile;

  const ProfileHeroSection({
    super.key,
    required this.isDark,
    required this.name,
    required this.nickname,
    this.displayPicture,
    required this.auraScore,
    required this.isOwnProfile,
    required this.uid,
    required this.isPrivateProfile,
    required this.theyFollowMe,
    this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;
    final avatarSize = 56.0;
    final heroTag = 'profile_avatar_${uid ?? 'unknown'}';
    final stableKey = ValueKey('avatar_${uid}_$avatarSize');

    // Match header structure: sideWidth=86, left padding=30
    // Card has 16px outer margin, so internal left padding = 30 - 16 = 14
    const double sideWidth = 70.0; // 86 - 16 (margin)

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppHeaderStyle.contentHorizontalPadding),
      child: TransparentToolbox.buildCard(
        context: context,
        onTap: isOwnProfile ? onEditProfile : null,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left avatar area - aligns with header icon (30px from screen edge)
            SizedBox(
              width: sideWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 14), // 16 (margin) + 14 = 30
                  child: uid != null &&
                          displayPicture != null &&
                          displayPicture!.isNotEmpty
                      ? Hero(
                          tag: heroTag,
                          // Use flightShuttleBuilder to show a clean image during transition
                          flightShuttleBuilder: (
                            flightContext,
                            animation,
                            flightDirection,
                            fromHeroContext,
                            toHeroContext,
                          ) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                return Material(
                                  elevation: 2 * (1 - animation.value),
                                  shadowColor: Colors.black
                                      .withValues(alpha: isDark ? 0.5 : 0.3),
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  color: Colors.transparent,
                                  child: ClipOval(
                                    child: ImageOptimizer.buildOptimizedImage(
                                      url: displayPicture!,
                                      width: avatarSize +
                                          (MediaQuery.of(context).size.width -
                                                  avatarSize) *
                                              animation.value,
                                      height: avatarSize +
                                          (MediaQuery.of(context).size.width -
                                                  avatarSize) *
                                              animation.value,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Material(
                            elevation: 2,
                            shadowColor: Colors.black
                                .withValues(alpha: isDark ? 0.5 : 0.3),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: InkWell(
                              onTap: () => FullScreenAvatarViewer.show(
                                context,
                                heroTag: heroTag,
                                imageUrl: displayPicture!,
                                name: name,
                              ),
                              customBorder: const CircleBorder(),
                              child: UserAvatar(
                                key: stableKey,
                                userId: uid,
                                imageUrl: displayPicture,
                                size: avatarSize,
                                borderRadius:
                                    BorderRadius.circular(avatarSize / 2),
                                nameInitials: name.isNotEmpty
                                    ? name.substring(0, 1)
                                    : null,
                                showBorder: false,
                              ),
                            ),
                          ),
                        )
                      : Material(
                          elevation: 2,
                          shadowColor: Colors.black
                              .withValues(alpha: isDark ? 0.5 : 0.3),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: SizedBox(
                            width: avatarSize,
                            height: avatarSize,
                            child: Icon(
                              Icons.person_rounded,
                              size: avatarSize * 0.5,
                              color: primaryColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // Name and username - centered like header title
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            name.isEmpty ? '—' : name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Private profile indicator
                        if (isPrivateProfile && !isOwnProfile) ...[
                          const SizedBox(width: AppDimensions.spacingSmMd),
                          Icon(
                            CupertinoIcons.lock_fill,
                            size: 14,
                            color: primaryColor.withValues(alpha: 0.5),
                          ),
                        ],
                      ],
                    ),
                    // "Follows You" badge - shows when they follow the current user
                    if (!isOwnProfile && theyFollowMe) ...[
                      const SizedBox(height: AppDimensions.spacingSmMd),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                        ),
                        child: Text(
                          'Follows you',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: primaryColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                    // Username/nickname display - hidden from UI, kept as backend-only
                    // if (nickname.isNotEmpty) ...[
                    //   const SizedBox(height: AppDimensions.spacingXs),
                    //   Text(
                    //     nickname,
                    //     style: TextStyle(
                    //       fontSize: 13,
                    //       fontWeight: FontWeight.w700,
                    //       color: primaryColor.withValues(alpha: 0.5),
                    //     ),
                    //     textAlign: TextAlign.center,
                    //   ),
                    // ],
                  ],
                ),
              ),
            ),

            // Right side - chevron arrow for own profile, spacer for others
            SizedBox(
              width: sideWidth,
              child: isOwnProfile
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppTheme.primaryLow,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
