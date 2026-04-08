import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/feed/presentation/pages/thread_view.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/preview_box.dart';

/// Indicator showing that a post is a reply to another post
/// Displays parent post thumbnails above the post header, aligned with post UI
/// Same pattern as PostReplies: receives initialParentPosts from Post widget to avoid duplicate fetches
class ReplyIndicator extends StatelessWidget {
  final String parentPostId;
  final String? parentAuthorName;
  final int?
      additionalParentsCount; // Number of posts above the immediate parent
  final List<DocumentSnapshot>?
      initialParentPosts; // Parent post documents (loaded by Post, like initialReplies)

  const ReplyIndicator({
    super.key,
    required this.parentPostId,
    this.parentAuthorName,
    this.additionalParentsCount,
    this.initialParentPosts,
  });

  void _navigateToParent(BuildContext context, String? postId) {
    final targetId = postId ?? parentPostId;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThreadView(postId: targetId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use initial data if provided (same pattern as PostReplies)
    final parentPosts =
        initialParentPosts != null && initialParentPosts!.isNotEmpty
            ? initialParentPosts!
                .map((snapshot) {
                  final data = snapshot.data() as Map<String, dynamic>?;
                  if (data != null) {
                    return {'id': snapshot.id, ...data};
                  }
                  return null;
                })
                .whereType<Map<String, dynamic>>()
                .toList()
            : <Map<String, dynamic>>[];

    // Don't show if no parents
    if (parentPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show oldest → newest (left to right) so thread flow is clear
    // Immediate parent is the last one (rightmost)
    final immediateParentIndex = parentPosts.length - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final thumbWidth = _thumbnailWidthFromContent(contentWidth);
        return Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Replying to" text - subtle, aligned with post header style
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
                child: GestureDetector(
                  onTap: () => _navigateToParent(context, null),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.arrowshape_turn_up_left_fill,
                              size: 14,
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: AppDimensions.spacingSmMd),
                            Text(
                              parentAuthorName != null
                                  ? 'Replying to $parentAuthorName'
                                  : 'Replying to post',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (parentPosts.length > 1) ...[
                        const SizedBox(width: AppDimensions.spacingSm),
                        Text(
                          '${parentPosts.length} posts in thread',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.primaryColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                      const SizedBox(width: AppDimensions.spacingXs),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 12,
                        color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              _buildThumbnails(
                  context, parentPosts, immediateParentIndex, thumbWidth),
            ],
          ),
        );
      },
    );
  }

  /// Thumbnail width from content/card width (same as main app video scaling).
  static double _thumbnailWidthFromContent(double contentWidth) {
    return (contentWidth / 5).clamp(72.0, 160.0);
  }

  Widget _buildThumbnails(
      BuildContext context,
      List<Map<String, dynamic>> parentPosts,
      int immediateParentIndex,
      double thumbWidth) {
    // Build all thumbnails upfront (same as PostReplies) - NO ListView.builder
    final thumbnails = parentPosts
        .asMap()
        .map((index, parent) {
          final isImmediateParent = index == immediateParentIndex;
          final isLast = index == parentPosts.length - 1;

          return MapEntry(
            index,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thumbnail
                GestureDetector(
                  onTap: () =>
                      _navigateToParent(context, parent['id'] as String?),
                  child: Container(
                    width: thumbWidth,
                    margin: EdgeInsets.only(right: isLast ? 0 : 4),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: PreviewBox(
                              previewUrl: parent['thumbnail'] as String? ?? '',
                              title: parent['title'] as String?,
                              author: parent['author'] as String?,
                              content: parent['content'] as String?,
                              postType:
                                  parent['postType'] as String? ?? 'video',
                              compact: true,
                              showAuthorPicture: false,
                              hideWhileLoading: false,
                              skipIfMissing: false,
                            ),
                          ),
                        ),
                        // Border highlight for immediate parent
                        if (isImmediateParent)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                                border: Border.all(
                                  color: AppTheme.primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Chevron connector (except for last item)
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      size: 12,
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          );
        })
        .values
        .toList();

    // Use SingleChildScrollView + Row (EXACT same as PostReplies)
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
      child: Row(
        children: thumbnails,
      ),
    );
  }
}
