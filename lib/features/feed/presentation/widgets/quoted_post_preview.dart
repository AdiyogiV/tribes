import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Widget that shows a quoted post preview within another post
class QuotedPostPreview extends StatelessWidget {
  final Map<String, dynamic> quotedPostData;
  final VoidCallback? onTap;

  const QuotedPostPreview({
    super.key,
    required this.quotedPostData,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final authorName = quotedPostData['authorName'] as String? ?? 'Someone';
    final content = quotedPostData['content'] as String?;
    final title = quotedPostData['title'] as String?;
    final thumbnail = quotedPostData['thumbnail'] as String?;
    final postType = quotedPostData['postType'] as String? ?? 'text';
    final timestamp = quotedPostData['timestamp'] as Timestamp?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.textSecondaryColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          color: AppTheme.cardColor.withValues(alpha: 0.3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author header
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              child: Row(
                children: [
                  Icon(
                    _getPostTypeIcon(postType),
                    size: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: AppDimensions.spacingSmMd),
                  Expanded(
                    child: Text(
                      authorName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text(
                      TimeDisplay.getRelativeTime(timestamp.toDate()),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Content
            if (title != null || content != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (title != null && content != null)
                      const SizedBox(height: AppDimensions.spacingXs),
                    if (content != null)
                      Text(
                        content,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

            // Thumbnail if available
            if (thumbnail != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
                child: CachedNetworkImage(
                  imageUrl: thumbnail,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    height: 120,
                    color: AppTheme.cardColor,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getPostTypeIcon(String postType) {
    switch (postType) {
      case 'video':
        return Icons.play_circle_outline;
      case 'audio':
        return Icons.audiotrack;
      case 'image':
        return Icons.image_outlined;
      case 'text':
      default:
        return Icons.article_outlined;
    }
  }
}
