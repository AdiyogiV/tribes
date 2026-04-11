import 'package:cloud_firestore/cloud_firestore.dart' show QueryDocumentSnapshot, QuerySnapshot;
import 'package:flutter/cupertino.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/preview_box.dart';
import 'package:aurogram/features/profile/domain/follow_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:go_router/go_router.dart';

/// Profile posts grid section with Posts | Reposts tabs.
class ProfilePostsSection extends StatelessWidget {
  final bool isDark;
  final String? uid;
  final String? currentUid;
  final bool isPrivateProfile;
  final String? followStatus;
  final int profileTabIndex;
  final ValueChanged<int> onTabChanged;
  final Stream<QuerySnapshot>? profilePostsStream;
  final Stream<QuerySnapshot>? profileRepostsStream;
  final List<QueryDocumentSnapshot>? cachedProfilePosts;
  final List<QueryDocumentSnapshot>? cachedProfileReposts;
  final ValueChanged<List<QueryDocumentSnapshot>> onPostsCached;
  final ValueChanged<List<QueryDocumentSnapshot>> onRepostsCached;

  const ProfilePostsSection({
    super.key,
    required this.isDark,
    required this.uid,
    required this.currentUid,
    required this.isPrivateProfile,
    required this.followStatus,
    required this.profileTabIndex,
    required this.onTabChanged,
    required this.profilePostsStream,
    required this.profileRepostsStream,
    required this.cachedProfilePosts,
    required this.cachedProfileReposts,
    required this.onPostsCached,
    required this.onRepostsCached,
  });

  bool get _isOwnProfile => uid == currentUid;

  @override
  Widget build(BuildContext context) {
    if (uid == null) return const SizedBox.shrink();

    // For private profiles of other users, check if we're a confirmed follower
    if (!_isOwnProfile && isPrivateProfile) {
      final isConfirmedFollower =
          followStatus == FollowService.statusFollowing;
      if (!isConfirmedFollower) {
        return _buildPrivateProfileLockedState(context);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfilePostsTabBar(context),
        SizedBox(height: AppHeaderStyle.cardVerticalGap),
        _buildProfilePostsGrid(context, profileTabIndex),
      ],
    );
  }

  Widget _buildProfilePostsTabBar(BuildContext context) {
    final c = AppTheme.primaryColor;
    final activeColor = c;
    final inactiveColor = c.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppHeaderStyle.contentHorizontalPadding),
      child: Row(
        children: [
          _ProfileTabChip(
            label: 'Posts',
            isSelected: profileTabIndex == 0,
            onTap: () => onTabChanged(0),
            activeColor: activeColor,
            inactiveColor: inactiveColor,
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          _ProfileTabChip(
            label: 'Reposts',
            icon: CupertinoIcons.arrow_2_squarepath,
            isSelected: profileTabIndex == 1,
            onTap: () => onTabChanged(1),
            activeColor: AppTheme.successColor,
            inactiveColor: inactiveColor,
          ),
        ],
      ),
    );
  }

  /// Build locked state for private profiles (non-followers)
  Widget _buildPrivateProfileLockedState(BuildContext context) {
    final c = AppTheme.primaryColor;

    // Contextual message based on follow status
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
            Text(
              'POSTS PRIVATE',
              style: AppTheme.cardLabelStyle,
            ),
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
                Icon(
                  icon,
                  size: 14,
                  color: iconColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build the posts grid from user's profile posts (tab 0 = originals, tab 1 = reposts)
  Widget _buildProfilePostsGrid(BuildContext context, int tabIndex) {
    if (uid == null) return const SizedBox.shrink();
    final isRepostsTab = tabIndex == 1;
    final stream = isRepostsTab ? profileRepostsStream : profilePostsStream;
    if (stream == null) return const SizedBox.shrink();

    // Key so switching tabs gives a fresh StreamBuilder and we don't show the other tab's snapshot
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey<bool>(isRepostsTab),
      stream: stream,
      builder: (context, snapshot) {
        final List<QueryDocumentSnapshot> posts;
        if (snapshot.hasData && snapshot.data != null) {
          final docs = snapshot.data!.docs;
          if (isRepostsTab) {
            onRepostsCached(docs);
            posts = docs;
          } else {
            // Posts tab: originals only (isRepost != true; includes docs with missing isRepost)
            final originals = docs
                .where((d) =>
                    (d.data() as Map<String, dynamic>)['isRepost'] != true)
                .toList();
            onPostsCached(originals);
            posts = originals;
          }
        } else {
          posts = isRepostsTab
              ? (cachedProfileReposts ?? [])
              : (cachedProfilePosts ?? []);
        }

        if (posts.isEmpty) {
          if (isRepostsTab) {
            return _buildProfileEmptyState(
              icon: CupertinoIcons.arrow_2_squarepath,
              message: 'No reposts yet',
            );
          }
          return _buildProfileEmptyState(
            icon: CupertinoIcons.doc_text,
            message: 'No posts yet',
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppHeaderStyle.cardVerticalGap,
            crossAxisSpacing: AppHeaderStyle.cardVerticalGap,
            childAspectRatio: 1.0,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final postData = posts[index].data() as Map<String, dynamic>;
            final postId = posts[index].id;
            final isUploading = postData['uploading'] as bool? ?? false;
            final postType = postData['postType'] as String?;

            String previewUrl = '';
            if (postType == 'image') {
              previewUrl = postData['video'] as String? ?? '';
            } else {
              previewUrl = postData['thumbnail'] as String? ?? '';
            }

            return GestureDetector(
              onTap: isUploading ? null : () => _openPost(context, postId, index, posts),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                child: PreviewBox(
                  key: ValueKey('$postId-$isUploading'),
                  previewUrl: previewUrl,
                  title: postData['title'] as String?,
                  author: postData['author'] as String?,
                  content: postData['content'] as String?,
                  postType: postType,
                  uploading: isUploading,
                  audioUrl: postData['audioUrl'] as String?,
                  durationInSeconds: postData['durationInSeconds'] as int?,
                  showAuthorPicture: false,
                  isRepost: false,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileEmptyState(
      {required IconData icon, required String message}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 40, color: AppTheme.primaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Open a profile post in thread view. For reposts, open the original post (same post, like Twitter)
  /// and pass reposter info so the post shows "X reposted" at the top.
  void _openPost(BuildContext context, String postId, int index, List<QueryDocumentSnapshot> posts) {
    final postData = posts[index].data() as Map<String, dynamic>;
    final isRepost = postData['isRepost'] as bool? ?? false;
    final originalPostId = postData['originalPostId'] as String?;
    final idToOpen =
        (isRepost && originalPostId != null && originalPostId.isNotEmpty)
            ? originalPostId
            : postId;
    final reposterName = postData['authorName'] as String?;
    final reposterAvatar = postData['authorAvatar'] as String?;
    context.push('/thread/$idToOpen', extra: {
      'repostedByName': isRepost ? (reposterName ?? '') : null,
      'repostedByAvatarUrl': isRepost ? reposterAvatar : null,
    });
  }
}

/// Tab chip for profile Posts | Reposts
class _ProfileTabChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;

  const _ProfileTabChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppDimensions.spacingSmMd),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
