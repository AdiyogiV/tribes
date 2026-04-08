import 'package:flutter/material.dart';
import 'package:aurogram/features/feed/domain/feed_service.dart';
import 'package:aurogram/services/feed_layout_cache.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/features/feed/presentation/pages/thread_view.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_switcher.dart';
import 'package:aurogram/shared/presentation/widgets/layout/size_reporting_widget.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';

import 'feed_empty_state.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Builds the main feed content slivers (skeleton, empty, or post list).
///
/// Returns a list of slivers representing the current feed state.
List<Widget> buildFeedContentSlivers({
  required BuildContext context,
  required List<String> feed,
  required bool initialized,
  required int estimatedVisibleIndex,
  required FeedService feedService,
  required FeedLayoutCache layoutCache,
  required int prewarmAheadCount,
}) {
  if (!initialized && feed.isEmpty) {
    return [
      SliverPadding(
        key: const ValueKey('feed_skeleton'),
        padding: const EdgeInsets.fromLTRB(
            0, 0, 0, AppHeaderStyle.contentBottomPadding),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildSkeletonItem(context),
            childCount: 3,
          ),
        ),
      ),
    ];
  }

  if (feed.isEmpty) {
    return [
      SliverToBoxAdapter(
        key: const ValueKey('feed_empty'),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 200,
          child: const FeedEmptyState(),
        ),
      ),
    ];
  }

  return [
    SliverPadding(
      key: const ValueKey('feed_posts'),
      padding: const EdgeInsets.fromLTRB(
          0, 0, 0, AppHeaderStyle.contentBottomPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // Loading indicator at end
            if (index == feed.length) {
              return const SizedBox(height: AppDimensions.spacingHero);
            }

            final postId = feed[index];
            final shouldPrewarmVideo = index >= estimatedVisibleIndex &&
                index <= estimatedVisibleIndex + prewarmAheadCount;

            final isLastPost = index == feed.length - 1;
            return RepaintBoundary(
              child: SizeReportingWidget(
                onSizeChange: (size) {
                  layoutCache.updateHeight(postId, size.height);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PostSwitcher(
                      key: ValueKey(postId),
                      postId: postId,
                      itemIndex: index,
                      onOpenThread: (id) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ThreadView(postId: id),
                        ),
                      ),
                      enableVideoAutoplay: true,
                      prewarmVideo: shouldPrewarmVideo,
                    ),
                    if (!isLastPost)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Divider(
                          height: 1,
                          thickness: 0.33,
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          childCount: feed.length + (feedService.hasMorePosts ? 1 : 0),
          addRepaintBoundaries: true,
        ),
      ),
    ),
  ];
}

/// Same post-card skeleton as PostSwitcher -- appears immediately while feed loads.
Widget _buildSkeletonItem(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final cardWidth = screenWidth.clamp(0.0, 500.0);
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: cardWidth),
      child: const PostBoxSkeleton(),
    ),
  );
}
