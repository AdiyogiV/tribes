import 'package:flutter/cupertino.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:aurogram/features/feed/presentation/pages/thread_view.dart';
import 'package:aurogram/features/stories/pages/story_composer_page.dart';
import 'package:aurogram/features/stories/pages/story_viewer_page.dart';
import 'package:aurogram/features/feed/domain/feed_service.dart';
import 'package:aurogram/features/feed/domain/feed_layout_cache.dart';
import 'package:aurogram/features/stories/story_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_switcher.dart';
import 'package:aurogram/features/stories/widgets/story_ring.dart';
import 'package:aurogram/shared/presentation/widgets/layout/size_reporting_widget.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'feed_empty_state.dart';
import 'feed_scroll_to_top_button.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Desktop/wide layout for the feed.
class FeedDesktopLayout extends StatelessWidget {
  final bool isDark;
  final User? user;
  final ScrollController scrollController;
  final List<String> feed;
  final bool initialized;
  final bool isRefreshing;
  final int storyRingRefreshKey;
  final bool storyRingForceRefresh;
  final int estimatedVisibleIndex;
  final FeedService feedService;
  final FeedLayoutCache layoutCache;
  final ValueNotifier<bool> showScrollToTopNotifier;
  final VoidCallback onAddPost;
  final VoidCallback onRefresh;
  final VoidCallback onScrollToTop;
  final void Function(int refreshKey, bool forceRefresh) onStoryRefresh;

  const FeedDesktopLayout({
    super.key,
    required this.isDark,
    required this.user,
    required this.scrollController,
    required this.feed,
    required this.initialized,
    required this.isRefreshing,
    required this.storyRingRefreshKey,
    required this.storyRingForceRefresh,
    required this.estimatedVisibleIndex,
    required this.feedService,
    required this.layoutCache,
    required this.showScrollToTopNotifier,
    required this.onAddPost,
    required this.onRefresh,
    required this.onScrollToTop,
    required this.onStoryRefresh,
  });

  static int get _prewarmAheadCount => kIsWeb ? 6 : 2;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return CustomScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              cacheExtent: 8000,
              slivers: [
                AppHeaderStyle.buildWideLayoutHeaderSliver(
                  context,
                  title: 'Feed',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onAddPost,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.paddingSm),
                          child: Icon(
                            CupertinoIcons.plus,
                            size: 22,
                            color: isDark
                                ? AppTheme.primaryColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                      isRefreshing
                          ? AppLoadingIndicator(
                              size: 20,
                              strokeWidth: 2,
                            )
                          : GestureDetector(
                              onTap: onRefresh,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.all(AppDimensions.paddingSm),
                                child: Icon(
                                  Icons.refresh_rounded,
                                  size: 22,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : Colors.black.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                // Story ring (logged-in only)
                if (user != null)
                  SliverToBoxAdapter(
                    key: ValueKey(storyRingRefreshKey),
                    child: Transform.translate(
                      offset: const Offset(0, -12),
                      child: StoryRing(
                        forceRefresh: storyRingForceRefresh,
                        onAddStory: () async {
                          final result =
                              await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => const StoryComposerPage(),
                            ),
                          );
                          if (result == true && context.mounted) {
                            onStoryRefresh(
                                storyRingRefreshKey + 1, false);
                          }
                        },
                        onViewUserStories: (userId) async {
                          final storyService = StoryService();
                          final userIds =
                              await storyService.getUsersWithStories();
                          final idx = userIds.indexOf(userId);
                          if (!context.mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StoryViewerPage(
                                userIds: userIds,
                                initialUserIndex: idx >= 0 ? idx : 0,
                              ),
                            ),
                          );
                          if (context.mounted) {
                            onStoryRefresh(
                                storyRingRefreshKey + 1, false);
                          }
                        },
                      ),
                    ),
                  ),
                // Divider after stories
                if (user != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Divider(
                        height: 1,
                        thickness: 0.33,
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                // Content
                if (!initialized && feed.isEmpty)
                  SliverPadding(
                    key: const ValueKey('feed_skeleton'),
                    padding: EdgeInsets.zero,
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildSkeletonItem(context),
                        childCount: 3,
                      ),
                    ),
                  )
                else if (feed.isEmpty)
                  SliverToBoxAdapter(
                    key: const ValueKey('feed_empty'),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height - 200,
                      child: const FeedEmptyState(),
                    ),
                  )
                else
                  SliverPadding(
                    key: const ValueKey('feed_posts'),
                    padding: EdgeInsets.zero,
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == feed.length) {
                            return const SizedBox(height: AppDimensions.spacingHero);
                          }
                          final postId = feed[index];
                          final shouldPrewarmVideo =
                              index >= estimatedVisibleIndex &&
                                  index <=
                                      estimatedVisibleIndex +
                                          _prewarmAheadCount;
                          final isLastPost = index == feed.length - 1;

                          return RepaintBoundary(
                            child: SizeReportingWidget(
                              onSizeChange: (size) {
                                layoutCache.updateHeight(
                                  postId,
                                  size.height,
                                );
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PostSwitcher(
                                    key: ValueKey(postId),
                                    postId: postId,
                                    itemIndex: index,
                                    onOpenThread: (id) =>
                                        Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ThreadView(postId: id),
                                      ),
                                    ),
                                    enableVideoAutoplay: true,
                                    prewarmVideo: shouldPrewarmVideo,
                                  ),
                                  if (!isLastPost)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 2, bottom: 4),
                                      child: Divider(
                                        height: 1,
                                        thickness: 0.33,
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount:
                            feed.length + (feedService.hasMorePosts ? 1 : 0),
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.spacingHero)),
              ],
            );
          },
        ),

        // Scroll to top button
        Positioned(
          right: 35,
          bottom: 16,
          child: FeedScrollToTopButton(
            isDark: isDark,
            showNotifier: showScrollToTopNotifier,
            onTap: onScrollToTop,
          ),
        ),
      ],
    );
  }

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
}
