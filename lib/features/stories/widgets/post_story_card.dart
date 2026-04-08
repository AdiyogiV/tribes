import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/models/post.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Instagram-style post card for stories.
/// Shows author header (avatar + username) + post content.
/// Used when sharing a post to story - this gets captured as an image.
class PostStoryCard extends StatelessWidget {
  final Post post;
  final String authorName;
  final String? authorAvatar;
  final Color backgroundColor;

  const PostStoryCard({
    super.key,
    required this.post,
    required this.authorName,
    this.authorAvatar,
    this.backgroundColor = AppTheme.pitchBlack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 414,
      height: 736,
      color: AppTheme.pitchBlack, // Explicit pitch black
      child: Column(
        children: [
          // Top spacing - reduced for better fit
          const SizedBox(height: AppDimensions.spacingHero),
          
          // Post card - Instagram-style white card
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg), // Match header padding
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Author header (Instagram style)
                    _buildAuthorHeader(),
                    
                    // Post content
                    _buildPostContent(),
                    
                    // Bottom metadata
                    _buildBottomSection(),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom spacing - reduced for better fit
          const SizedBox(height: AppDimensions.spacingHero),
        ],
      ),
    );
  }

  Widget _buildAuthorHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          if (authorAvatar != null && authorAvatar!.isNotEmpty)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: authorAvatar!,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                placeholder: (_, __) => CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                  child: const AppLoadingIndicator(
                    size: 16,
                    strokeWidth: 2,
                    color: Colors.grey,
                  ),
                ),
                errorWidget: (_, __, ___) => CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                  child: Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          else
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: Text(
                authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: AppDimensions.spacingMdSm),
          
          // Author name
          Expanded(
            child: Text(
              authorName,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    // Get image URL from post (could be thumbnail or video field)
    final imageUrl = post.thumbnail ?? post.mediaUrl;
    
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 400,
        minHeight: 200,
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: Colors.black,
                child: const AppLoadingIndicator(
                  color: Colors.white54,
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.black,
                child: const Icon(
                  Icons.image_not_supported,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            )
          : Container(
              color: Colors.black,
              child: const Center(
                child: Icon(
                  Icons.article_outlined,
                  size: 64,
                  color: Colors.white54,
                ),
              ),
            ),
    );
  }

  Widget _buildBottomSection() {
    final hasTitle = post.title != null && post.title!.isNotEmpty;
    final hasContent = post.content != null && post.content!.isNotEmpty;
    
    if (!hasTitle && !hasContent) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasTitle)
            Text(
              post.title!,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (hasTitle && hasContent) const SizedBox(height: AppDimensions.spacingSmMd),
          if (hasContent)
            Text(
              post.content!,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
