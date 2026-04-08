import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/features/feed/domain/feed_service.dart';
import 'package:aurogram/services/feed_layout_cache.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/widgets/cosmic_dashboard.dart';
import 'package:aurogram/features/feed/presentation/pages/feed_scroll_to_top_button.dart';
import 'package:aurogram/features/feed/presentation/pages/feed_story_row.dart';
import 'package:aurogram/features/feed/presentation/pages/feed_post_list.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Mobile layout for the feed page.
class FeedMobileLayout extends StatelessWidget {
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
  final ValueListenable<bool>? barHiddenNotifier;
  final VoidCallback onAddPost;
  final Future<void> Function() onRefresh;
  final VoidCallback onScrollToTop;
  final void Function(int key, bool force) onStoryRefresh;

  static int get prewarmAheadCount => kIsWeb ? 6 : 2;

  const FeedMobileLayout({
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
    required this.barHiddenNotifier,
    required this.onAddPost,
    required this.onRefresh,
    required this.onScrollToTop,
    required this.onStoryRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding.bottom;
    const scrollButtonBaseBottom = 16.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            cacheExtent: kIsWeb ? 8000 : 6000,
            slivers: [
              AppHeaderStyle.buildStandardHeader(
                context: context,
                title: 'aurogram',
                showSearchField: false,
                backgroundStyle: HeaderBackgroundStyle.gradient,
                isRefreshing: isRefreshing,
                pinned: false,
                leadingWidget: IconButton(
                  onPressed: onAddPost,
                  icon: Icon(
                    CupertinoIcons.plus,
                    color: AppTheme.primaryColor,
                    size: AppHeaderStyle.headerIconSize,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                actionButton: IconButton(
                  onPressed: () => CosmicDashboard.show(context),
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: AppTheme.primaryColor,
                    size: AppHeaderStyle.headerIconSize,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              CupertinoSliverRefreshControl(
                onRefresh: onRefresh,
                builder: (context, refreshState, pulledExtent,
                    refreshTriggerPullDistance, refreshIndicatorExtent) {
                  return const SizedBox.shrink();
                },
              ),
              if (user != null)
                FeedStoryRow(
                  key: ValueKey(storyRingRefreshKey),
                  storyRingRefreshKey: storyRingRefreshKey,
                  storyRingForceRefresh: storyRingForceRefresh,
                  onStoryRefresh: onStoryRefresh,
                ),
              if (user != null) const FeedStoryDivider(),
              ...buildFeedContentSlivers(
                context: context,
                feed: feed,
                initialized: initialized,
                estimatedVisibleIndex: estimatedVisibleIndex,
                feedService: feedService,
                layoutCache: layoutCache,
                prewarmAheadCount: prewarmAheadCount,
              ),
            ],
          ),
          Positioned(
            right: 32,
            bottom: scrollButtonBaseBottom + padding,
            child: barHiddenNotifier != null
                ? ValueListenableBuilder<bool>(
                    valueListenable: barHiddenNotifier!,
                    builder: (context, barHidden, _) {
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(barHidden),
                        tween: Tween(
                            begin: barHidden ? 0.0 : 1.0,
                            end: barHidden ? 1.0 : 0.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                        builder: (context, t, child) => Transform.translate(
                          offset: Offset(0, 80 * t),
                          child: child,
                        ),
                        child: FeedScrollToTopButton(
                          isDark: isDark,
                          showNotifier: showScrollToTopNotifier,
                          onTap: onScrollToTop,
                        ),
                      );
                    },
                  )
                : FeedScrollToTopButton(
                    isDark: isDark,
                    showNotifier: showScrollToTopNotifier,
                    onTap: onScrollToTop,
                  ),
          ),
        ],
      ),
    );
  }
}
