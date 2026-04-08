import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/routing/dynamic_link_navigator.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// A card widget that displays shared content (post, profile, space, insight) in chat
class SharedContentCard extends StatelessWidget {
  final Map<String, dynamic> sharedContent;
  final bool isOwnMessage;
  final String? additionalMessage;

  const SharedContentCard({
    super.key,
    required this.sharedContent,
    required this.isOwnMessage,
    this.additionalMessage,
  });

  String get _type => sharedContent['type'] as String? ?? 'content';
  String get _id => sharedContent['id'] as String? ?? '';
  String? get _title => sharedContent['title'] as String?;
  String? get _subtitle => sharedContent['subtitle'] as String?;
  String? get _imageUrl => sharedContent['imageUrl'] as String?;
  String? get _authorName => sharedContent['authorName'] as String?;
  String? get _authorId {
    // Check extraData first, then direct field
    final extraData = sharedContent['extraData'] as Map<String, dynamic>?;
    return extraData?['authorId'] as String? ??
        sharedContent['authorId'] as String?;
  }

  String? get _authorAvatar {
    // Check extraData first, then direct field
    final extraData = sharedContent['extraData'] as Map<String, dynamic>?;
    return extraData?['authorAvatar'] as String? ??
        sharedContent['authorAvatar'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get text colors that match message bubble styling
    final textColor = isOwnMessage
        ? (isDark ? Colors.white : AppTheme.primaryColor)
        : AppTheme.primaryColor;
    final secondaryTextColor = isOwnMessage
        ? (isDark
            ? Colors.white.withValues(alpha: 0.7)
            : AppTheme.primaryColor.withValues(alpha: 0.7))
        : (isDark ? Colors.grey[400] : Colors.grey[600]);
    final tertiaryTextColor = isOwnMessage
        ? (isDark
            ? Colors.white.withValues(alpha: 0.6)
            : AppTheme.primaryColor.withValues(alpha: 0.6))
        : (isDark ? Colors.grey[500] : Colors.grey[500]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Optional message above the card
        if (additionalMessage != null && additionalMessage!.isNotEmpty) ...[
          Text(
            additionalMessage!,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
        ],

        // Shared content card - transparent, inherits bubble styling
        GestureDetector(
          onTap: () => _handleTap(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image header for posts with thumbnails
              if (_type == 'post' && _imageUrl != null)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: _imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                ),

              // Content row
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingSm),
                child: Row(
                  children: [
                    // Leading icon/avatar
                    _buildLeading(context),
                    const SizedBox(width: AppDimensions.spacingMd),

                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            _title ?? 'Shared $_type',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Subtitle
                          if (_subtitle != null) ...[
                            const SizedBox(height: AppDimensions.spacingXs),
                            Text(
                              _subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          // Author
                          if (_authorName != null) ...[
                            const SizedBox(height: AppDimensions.spacingXs),
                            Text(
                              'by $_authorName',
                              style: TextStyle(
                                fontSize: 11,
                                color: tertiaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Chevron
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: tertiaryTextColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeading(BuildContext context) {
    const double size = 40;

    // Profile or cosmic - show avatar
    if (_type == 'profile' || _type == 'cosmic') {
      return UserAvatar(
        userId: _id,
        imageUrl: _imageUrl,
        size: size,
        loadFromFirestore: _imageUrl == null,
        nameInitials: _title?.isNotEmpty == true
            ? _title!.substring(0, 1).toUpperCase()
            : 'U',
      );
    }

    // Space - show space image or icon
    if (_type == 'space') {
      if (_imageUrl != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
          child: CachedNetworkImage(
            imageUrl: _imageUrl!,
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

    // Post - show author avatar
    if (_type == 'post') {
      // Use authorId if available, otherwise use authorName for initials
      return UserAvatar(
        userId: _authorId,
        imageUrl: _authorAvatar,
        size: size,
        loadFromFirestore: _authorId != null && _authorAvatar == null,
        nameInitials: _authorName?.isNotEmpty == true
            ? _authorName!.substring(0, 1).toUpperCase()
            : 'P',
      );
    }

    // Insight - show icon
    if (_type == 'insight') {
      return _buildIconContainer(context, Icons.auto_awesome, size);
    }

    // Fallback for other types
    return _buildIconContainer(context, Icons.article_outlined, size);
  }

  Widget _buildIconContainer(BuildContext context, IconData icon, double size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOwnMessage
            ? (isDark
                ? Colors.white.withValues(alpha: 0.15)
                : AppTheme.primaryColor.withValues(alpha: 0.12))
            : AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: isOwnMessage
            ? (isDark ? Colors.white : AppTheme.primaryColor)
            : AppTheme.primaryColor,
      ),
    );
  }

  void _handleTap(BuildContext context) {
    switch (_type) {
      case 'post':
        DynamicLinkNavigator.navigateToPost(_id);
        break;
      case 'profile':
      case 'cosmic':
        DynamicLinkNavigator.navigateToUserProfile(_id);
        break;
      case 'space':
        DynamicLinkNavigator.navigateToSpaceInvite(_id, null);
        break;
      default:
        break;
    }
  }
}

/// Widget to show "Forwarded" indicator above a message
class ForwardedIndicator extends StatelessWidget {
  final bool isOwnMessage;

  const ForwardedIndicator({
    super.key,
    required this.isOwnMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.reply_rounded,
            size: 12,
            color: isOwnMessage
                ? Colors.white.withValues(alpha: 0.6)
                : (isDark ? Colors.grey[500] : Colors.grey[500]),
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            'Forwarded',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: isOwnMessage
                  ? Colors.white.withValues(alpha: 0.6)
                  : (isDark ? Colors.grey[500] : Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }
}
