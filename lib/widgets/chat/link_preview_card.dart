import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/utils/chat/internal_link_utils.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/user_avatar.dart';

/// A card widget that displays a preview of an internal app link
class LinkPreviewCard extends StatelessWidget {
  final InternalLinkPreview preview;
  final VoidCallback? onTap;
  final bool compact;

  const LinkPreviewCard({
    super.key,
    required this.preview,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child:
            compact ? _buildCompactLayout(context) : _buildFullLayout(context),
      ),
    );
  }

  Widget _buildFullLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image if available (for posts with thumbnails)
        if (preview.imageUrl != null && preview.type == InternalLinkType.post)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: preview.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                    size: 32,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                    size: 32,
                  ),
                ),
              ),
            ),
          ),

        // Content section
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon or avatar
              _buildLeadingWidget(context),
              const SizedBox(width: 12),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Type indicator
                    _buildTypeChip(context),
                    const SizedBox(height: 4),

                    // Title
                    Text(
                      preview.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Subtitle
                    if (preview.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        preview.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Extra info
                    _buildExtraInfo(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          // Icon or avatar
          _buildLeadingWidget(context, size: 36),
          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildTypeChip(context, small: true),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        preview.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (preview.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    preview.subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Arrow indicator
          Icon(
            Icons.chevron_right,
            size: 20,
            color: isDark ? Colors.grey[500] : Colors.grey[400],
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingWidget(BuildContext context, {double size = 44}) {
    // For profiles and cosmic, show avatar
    if (preview.type == InternalLinkType.profile ||
        preview.type == InternalLinkType.cosmic) {
      return UserAvatar(
        userId: preview.id,
        imageUrl: preview.imageUrl,
        size: size,
        loadFromFirestore: preview.imageUrl == null,
        nameInitials: preview.title.isNotEmpty
            ? preview.title.substring(0, 1).toUpperCase()
            : 'U',
      );
    }

    // For spaces, show space image or icon
    if (preview.type == InternalLinkType.space) {
      if (preview.imageUrl != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size / 4),
          child: CachedNetworkImage(
            imageUrl: preview.imageUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _buildIconContainer(
              context,
              Icons.groups_rounded,
              size,
            ),
          ),
        );
      }
      return _buildIconContainer(context, Icons.groups_rounded, size);
    }

    // For posts, show post type icon
    final postType = preview.extraData?['postType'] as String?;
    IconData icon;
    switch (postType) {
      case 'video':
        icon = Icons.play_circle_outline_rounded;
        break;
      case 'audio':
        icon = Icons.mic_rounded;
        break;
      default:
        icon = Icons.article_outlined;
    }

    return _buildIconContainer(context, icon, size);
  }

  Widget _buildIconContainer(BuildContext context, IconData icon, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildTypeChip(BuildContext context, {bool small = false}) {
    String label;
    IconData icon;

    switch (preview.type) {
      case InternalLinkType.post:
        label = 'Post';
        icon = Icons.article_outlined;
        break;
      case InternalLinkType.profile:
        label = 'Profile';
        icon = Icons.person_outline;
        break;
      case InternalLinkType.space:
        label = 'Gram';
        icon = Icons.groups_outlined;
        break;
      case InternalLinkType.cosmic:
        label = 'Cosmic';
        icon = Icons.auto_awesome;
        break;
      case InternalLinkType.unknown:
        label = 'Link';
        icon = Icons.link;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: small ? 10 : 12,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: small ? 9 : 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraInfo(BuildContext context) {
    final extraData = preview.extraData;
    if (extraData == null) return const SizedBox.shrink();

    List<Widget> items = [];

    switch (preview.type) {
      case InternalLinkType.post:
        final likes = extraData['likeCount'] as int? ?? 0;
        final replies = extraData['replyCount'] as int? ?? 0;
        if (likes > 0 || replies > 0) {
          items = [
            if (likes > 0)
              _buildStatItem(Icons.favorite_outline, '$likes', context),
            if (likes > 0 && replies > 0) const SizedBox(width: 12),
            if (replies > 0)
              _buildStatItem(Icons.chat_bubble_outline, '$replies', context),
          ];
        }
        break;
      case InternalLinkType.profile:
        final followers = extraData['followerCount'] as int? ?? 0;
        if (followers > 0) {
          items = [
            _buildStatItem(
                Icons.people_outline, '$followers followers', context)
          ];
        }
        break;
      case InternalLinkType.space:
        final members = extraData['memberCount'] as int? ?? 0;
        if (members > 0) {
          items = [
            _buildStatItem(Icons.people_outline, '$members members', context)
          ];
        }
        break;
      default:
        break;
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: items),
    );
  }

  Widget _buildStatItem(IconData icon, String text, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: isDark ? Colors.grey[500] : Colors.grey[500],
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[500] : Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

/// A loading placeholder for link previews
class LinkPreviewLoading extends StatelessWidget {
  const LinkPreviewLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
