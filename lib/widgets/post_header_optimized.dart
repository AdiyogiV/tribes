import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/pages/spaces/space_screen.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/services/batch_data_loader.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Optimized post header - ZERO async fetches, all data passed as props
///
/// OLD APPROACH (slow):
/// - _UserAvatar, _UserName, _SpaceName all fetched data async
/// - 3 separate setState calls per post
/// - Cache checks still triggered rebuilds
///
/// NEW APPROACH (fast):
/// - All data loaded in Post widget via BatchDataLoader
/// - Passed down as props to stateless components
/// - No setState, no rebuilds, no async work
/// - Instant rendering
class PostHeaderOptimized extends StatelessWidget {
  final String? uid;
  final String? space;
  final Timestamp? timestamp;
  final String? label;
  final Color? labelColor;
  final bool isProfilePost; // When true, hide the space/gram name
  final VoidCallback? onMoreTap;

  // NEW: User and space data passed directly
  final UserData? userData;
  final SpaceData? spaceData;

  const PostHeaderOptimized({
    super.key,
    this.uid,
    this.space,
    this.timestamp,
    this.label,
    this.labelColor,
    this.isProfilePost = false,
    this.onMoreTap,
    this.userData,
    this.spaceData,
  });

  static const double _avatarSize = 40.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      child: Row(
        children: [
          // Avatar (Instagram: smaller, left)
          GestureDetector(
            onTap: () => _navigateToProfile(context),
            child: _buildAvatar(),
          ),

          const SizedBox(width: AppDimensions.spacingMd),

          // Username + Gram (left-aligned, single line or two)
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToProfile(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserName(),
                  if (!isProfilePost && space != null && space!.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacingXxs),
                    GestureDetector(
                      onTap: () => _navigateToSpace(context),
                      child: _buildSpaceName(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Label badge (REPLY, ORIGINAL)
          if (label != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: (labelColor ?? AppTheme.primaryColor)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Text(
                label!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: labelColor ?? AppTheme.primaryColor,
                ),
              ),
            ),

          // Three dots (Instagram-style) - right side of header
          if (onMoreTap != null) ...[
            if (label != null) const SizedBox(width: AppDimensions.spacingSm),
            GestureDetector(
              onTap: onMoreTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Icon(
                  CupertinoIcons.ellipsis,
                  size: 22,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final photoUrl = userData?.photoUrl;

    return Container(
      width: _avatarSize,
      height: _avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                width: _avatarSize,
                height: _avatarSize,
                placeholder: (_, __) => _avatarIcon(),
                errorWidget: (_, __, ___) => _avatarIcon(),
                fadeInDuration: const Duration(milliseconds: 150),
                fadeOutDuration: const Duration(milliseconds: 150),
              )
            : _avatarIcon(),
      ),
    );
  }

  Widget _avatarIcon() {
    return Icon(
      CupertinoIcons.person_fill,
      size: _avatarSize * 0.5,
      color: AppTheme.primaryColor.withValues(alpha: 0.5),
    );
  }

  Widget _buildUserName() {
    final name = userData?.displayName ?? 'User';

    return Text(
      name,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.primaryColor,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSpaceName() {
    final name = spaceData?.name ?? 'Gram';

    return Text(
      name,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme.primaryColor.withValues(alpha: 0.7),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _navigateToProfile(BuildContext context) {
    if (uid == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => UserProfilePage(uid: uid)),
    );
  }

  void _navigateToSpace(BuildContext context) {
    if (space == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => SpaceScreen(rid: space!)),
    );
  }
}
