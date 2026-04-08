import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, ValueListenable;
import 'package:provider/provider.dart';
import 'package:aurogram/shared/presentation/widgets/media/media_type_selector.dart';
import 'package:aurogram/shared/presentation/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/features/feed/domain/feed_service.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/features/feed/domain/feed_layout_cache.dart';
import 'package:aurogram/shared/services/batch_data_loader.dart';
import 'package:aurogram/features/feed/presentation/pages/feed_controller.dart';
import 'package:aurogram/features/feed/data/feed_performance_monitor.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/features/stories/pages/story_composer_page.dart';
import 'package:aurogram/shared/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:aurogram/features/feed/presentation/pages/feed_creation_dialog.dart';
import 'package:aurogram/features/feed/presentation/pages/feed_desktop_layout.dart';
import 'package:aurogram/features/feed/presentation/pages/feed_mobile_layout.dart';
import 'package:aurogram/features/feed/presentation/pages/feed_batch_preloader.dart';

class _FeedAnchor {
  final String postId;
  final double offsetInItem;

  const _FeedAnchor({
    required this.postId,
    required this.offsetInItem,
  });
}

/// Main feed page - Pull-based architecture
///
/// Uses FeedService which:
/// - Queries posts directly (no fanout)
/// - Caches locally for instant load
/// - Falls back to global feed if personalized is empty
/// - NEVER shows empty if content exists
///
/// Loading: skeleton post boxes (PostBoxSkeleton) while fetching IDs; then list of Post
/// widgets, each showing PostBoxSkeleton until its own data loads – same box, content fills in.
class Feed extends StatefulWidget {
  const Feed({
    super.key,
    this.onScrollHidesBottomBar,
    this.barHiddenNotifier,
  });

  /// When non-null, called with true when user scrolls down (hide tab bar), false when scroll up or near top.
  final void Function(bool hide)? onScrollHidesBottomBar;

  /// When non-null (mobile), only the scroll-to-top button listens so the rest of Feed doesn't rebuild during bar hide/show.
  final ValueListenable<bool>? barHiddenNotifier;

  @override
  State<Feed> createState() => _FeedState();
}

class _FeedState extends State<Feed> {
  final User? user = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  final FeedService _feedService = FeedService();
  final PostDbService _postDbService = PostDbService();
  final FeedLayoutCache _layoutCache = FeedLayoutCache();
  final BatchDataLoader _batchLoader = BatchDataLoader();
  late final FeedBatchPreloader _preloader;

  List<String> feed = [];
  bool initialized = false;
  bool _isLoadingFeed = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;

  // Track last preloaded index to avoid redundant preloads
  int _lastPreloadedIndex = -1;
  int _estimatedVisibleIndex = 0;

  // Performance monitoring (debug mode only)
  final FeedPerformanceMonitor _perfMonitor = FeedPerformanceMonitor();
  Timer? _perfMonitorTimer;

  // Limit feed size to prevent unbounded growth and cache mismatches
  static const int _maxFeedSize = 100;
  static const int _preloadAheadCount = 16;

  /// ValueNotifier so scroll-to-top button updates without setState (no full Feed rebuild during scroll).
  final ValueNotifier<bool> _showScrollToTopNotifier =
      ValueNotifier<bool>(false);
  double _lastScrollOffset = 0;
  bool _lastReportedHideBar = false;
  DateTime _lastScrollLogicTime = DateTime(0);

  /// Chevron appears first when user has scrolled down this far.
  static const double _scrollToTopThreshold = 200;

  /// Tab bar hides when scrolled past this (pixel-only; must be > chevron threshold).
  static const double _hideBarScrollThreshold = 500;
  static const Duration _scrollLogicThrottle = Duration(milliseconds: 100);

  int _storyRingRefreshKey = 0;
  bool _storyRingForceRefresh = false;

  // Swipe gesture tracking removed - now handled by PageView in TabHandler

  @override
  void initState() {
    super.initState();
    _preloader = FeedBatchPreloader(
      postDbService: _postDbService,
      batchLoader: _batchLoader,
    );
    _scrollController.addListener(_onScroll);

    // Start performance monitoring session (debug only)
    _perfMonitor.startSession();

    AppLogger.i('🔄 Feed: Starting initialization',
        category: LogCategory.performance);

    _loadFeed();

    // Start performance monitoring immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startPerformanceMonitoring();
      }
    });
  }

  void _startPerformanceMonitoring() {
    // Only in debug mode
    if (!kDebugMode) return;

    // Log performance report every 60 seconds (less spam)
    _perfMonitorTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final feedController = context.read<FeedController>();
        _perfMonitor.logReport(
          feedController: feedController,
        );
      } catch (e) {
        // Controller not available
      }
    });

    AppLogger.i(
      '🚀 Feed: Viewport system active (reports every 60s)',
      category: LogCategory.performance,
    );
  }

  // ViewportTracker removed - using simple VisibilityDetector pattern instead

  /// Preload post data + batch load counters via FeedBatchPreloader.
  Future<List<String>> _preloadAndCountPosts(int startIndex, int count,
      {required List<String> postIds}) async {
    final validPostIds = await _preloader.preloadPostData(
      startIndex, count, postIds: postIds,
    );
    if (validPostIds.isNotEmpty) {
      try {
        final feedController = context.read<FeedController>();
        await _preloader.batchLoadCounters(validPostIds, feedController);
      } catch (_) {}
    }
    return validPostIds;
  }

  _FeedAnchor? _captureAnchor() {
    if (feed.isEmpty || !_scrollController.hasClients) return null;
    final offset = _scrollController.position.pixels;
    final estimatedIndex = _layoutCache.estimateIndexForOffset(feed, offset);
    if (estimatedIndex < 0 || estimatedIndex >= feed.length) return null;
    final heightBefore =
        _layoutCache.estimateRangeHeight(feed.sublist(0, estimatedIndex));
    final offsetInItem = offset - heightBefore;
    return _FeedAnchor(
        postId: feed[estimatedIndex], offsetInItem: offsetInItem);
  }

  bool _restoreAnchor(_FeedAnchor anchor) {
    if (!_scrollController.hasClients || feed.isEmpty) return false;
    final index = feed.indexOf(anchor.postId);
    if (index < 0) return false;
    final heightBefore =
        _layoutCache.estimateRangeHeight(feed.sublist(0, index));
    final targetOffset = (heightBefore + anchor.offsetInItem).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    if (kDebugMode) {
      AppLogger.d(
        'Feed: anchor restore',
        category: LogCategory.performance,
        data: {
          'postId': anchor.postId.substring(0, 4),
          'index': index,
          'target': targetOffset.toStringAsFixed(1),
        },
      );
    }
    _scrollController.jumpTo(targetOffset);
    return true;
  }

  @override
  void dispose() {
    _showScrollToTopNotifier.dispose();
    _perfMonitorTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.position.pixels;
    final previousOffset = _lastScrollOffset;
    _lastScrollOffset = offset;

    // Load more when near bottom (lightweight check, async work is guarded)
    if (offset >= _scrollController.position.maxScrollExtent - 500) {
      if (kDebugMode) {
        AppLogger.d(
          'Feed: near bottom, attempting loadMore',
          category: LogCategory.performance,
          data: {
            'offset': offset.toStringAsFixed(1),
            'max':
                _scrollController.position.maxScrollExtent.toStringAsFixed(1),
          },
        );
      }
      _loadMorePosts();
    }

    // Simple continuous preloading based on scroll position
    // Removed complex ViewportTracker - keep it simple
    if (feed.isNotEmpty) {
      // Estimate current index using actual measured heights
      final estimatedIndex = _layoutCache.estimateIndexForOffset(feed, offset);
      _estimatedVisibleIndex = estimatedIndex;
      final preloadStartIndex = estimatedIndex + 8;

      if (preloadStartIndex > _lastPreloadedIndex &&
          preloadStartIndex < feed.length) {
        _lastPreloadedIndex = preloadStartIndex;
        if (kDebugMode) {
          AppLogger.d(
            'Feed: preload window',
            category: LogCategory.performance,
            data: {
              'estimatedIndex': estimatedIndex,
              'preloadStart': preloadStartIndex,
              'count': _preloadAheadCount,
              'avgHeight': _layoutCache.averageHeight.toStringAsFixed(1),
              'measured': _layoutCache.measuredCount,
            },
          );
        }
        _preloader.preloadPostData(preloadStartIndex, _preloadAheadCount, postIds: feed).catchError((e) {
          // Silently handle preload errors
          return <String>[];
        });
      }
    }

    // Throttle: run scroll-to-top and hide-bar logic at most every 100ms to avoid work every frame
    final now = DateTime.now();
    if (now.difference(_lastScrollLogicTime) < _scrollLogicThrottle) return;
    _lastScrollLogicTime = now;

    // Scroll-to-top visibility — update notifier only when changed (no setState, no full rebuild)
    final shouldShow = offset > _scrollToTopThreshold;
    if (shouldShow != _showScrollToTopNotifier.value) {
      _showScrollToTopNotifier.value = shouldShow;
    }

    // Hide tab bar: pixel-only; hide when scrolling down past threshold
    final isScrollingDown = offset > previousOffset;
    final pastThreshold = offset > _hideBarScrollThreshold;
    final shouldHideBar = isScrollingDown && pastThreshold;
    if (shouldHideBar && !_lastReportedHideBar) {
      _lastReportedHideBar = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onScrollHidesBottomBar?.call(true);
      });
    } else if (!shouldHideBar && _lastReportedHideBar) {
      _lastReportedHideBar = false;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onScrollHidesBottomBar?.call(false);
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeInOutCubic,
    );
  }

  void _addPost() {
    if (user == null) {
      showLoginBottomSheet(context);
      return;
    }
    // Show selection dialog for story or post
    _showCreateSelectionDialog();
  }

  void _showCreateSelectionDialog() async {
    final choice = await showCreateSelectionDialog(context);
    if (!mounted || choice == null) return;
    if (choice == 'post') {
      _createPost();
    } else if (choice == 'story') {
      _createStory();
    }
  }

  void _createPost() {
    // Open post creation dialog for profile posts (same as profile tab)
    MediaTypeSelector.showMediaTypeSelection(
      context: context,
      space: 'profile', // Special marker for profile posts
      isProfilePost: true, // Indicates profile context
    );
  }

  void _createStory() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const StoryComposerPage(),
      ),
    );
    if (result == true && mounted) {
      setState(() {
        _storyRingRefreshKey++;
        _storyRingForceRefresh = false;
      });
    }
  }

  Future<void> _loadFeed() async {
    if (_isLoadingFeed) return;
    _isLoadingFeed = true;

    setState(() {
      initialized = false;
      feed = [];
      _lastPreloadedIndex = -1; // Reset preload tracker
    });

    try {
      final startTime = DateTime.now();
      AppLogger.i('📊 Feed: Fetching post IDs',
          category: LogCategory.performance);

      var postIds = await _feedService.getFeed();
      final idsLoadedTime = DateTime.now();

      AppLogger.i(
        '✓ Feed: Post IDs loaded',
        category: LogCategory.performance,
        data: {
          'count': postIds.length,
          'took_ms': idsLoadedTime.difference(startTime).inMilliseconds
        },
      );

      if (mounted) {
        // CRITICAL: Preload data AND batch load user/space data BEFORE setState
        // This eliminates the "User" → "Real Name" flicker
        AppLogger.i('📥 Feed: Preloading first 15 posts BEFORE setState',
            category: LogCategory.performance);
        final validFirstBatch = await _preloadAndCountPosts(0, 15, postIds: postIds);
        final preloadCompleteTime = DateTime.now();

        // Batch load user/space data BEFORE rendering to avoid flicker
        try {
          final feedController = context.read<FeedController>();
          await _preloader.batchLoadUserSpaceData(validFirstBatch, feedController);
        } catch (_) {}

        AppLogger.i(
          '✓ Feed: Preload complete, now triggering rebuild',
          category: LogCategory.performance,
          data: {
            'preload_ms':
                preloadCompleteTime.difference(idsLoadedTime).inMilliseconds
          },
        );

        // ViewportTracker removed - simple VisibilityDetector pattern instead

        postIds = postIds
            .where((id) => !_postDbService.isPostKnownMissing(id))
            .toList();
        if (validFirstBatch.isNotEmpty) {
          final validSet = validFirstBatch.toSet();
          postIds = postIds.where((id) => validSet.contains(id)).toList();
        }
        setState(() {
          feed = postIds;
          initialized = true;
        });

        // Trim old states from FeedController to prevent unbounded growth
        try {
          final feedController = context.read<FeedController>();
          feedController.trimStatesForFeed(feed);
        } catch (e) {
          // FeedController not available yet
        }

        final totalTime = DateTime.now();
        AppLogger.i(
          '🎉 Feed: Load complete',
          category: LogCategory.performance,
          data: {'total_ms': totalTime.difference(startTime).inMilliseconds},
        );
      }

      // Track feed view for engagement analytics
      AnalyticsService().trackFeedViewed(
        count: postIds.length,
        isAuthenticated: user != null,
      );
    } catch (e) {
      AppLogger.e('Feed: Error loading', error: e);
      if (mounted) {
        setState(() => initialized = true);
      }
    } finally {
      _isLoadingFeed = false;
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_feedService.hasMorePosts || feed.isEmpty) return;
    _isLoadingMore = true;

    try {
      final morePosts = await _feedService.loadMore();

      if (mounted && morePosts.isNotEmpty) {
        // Preload newly loaded posts BEFORE adding to feed - pass morePosts directly
        AppLogger.i('📥 LoadMore: Preloading ${morePosts.length} posts',
            category: LogCategory.performance);
        final validMorePosts =
            await _preloadAndCountPosts(0, morePosts.length, postIds: morePosts);

        // Batch load user/space data for new posts BEFORE rendering
        try {
          final feedController = context.read<FeedController>();
          await _preloader.batchLoadUserSpaceData(validMorePosts, feedController);
        } catch (_) {}

        AppLogger.i('✓ LoadMore: Preload complete',
            category: LogCategory.performance);

        // Removed ViewportTracker complexity

        final anchor = _captureAnchor();
        bool didTrim = false;
        int removedCount = 0;
        double removedHeight = 0;
        double currentOffset = 0;

        final filteredMorePosts = validMorePosts.isNotEmpty
            ? validMorePosts
            : morePosts
                .where((id) => !_postDbService.isPostKnownMissing(id))
                .toList();

        setState(() {
          feed.addAll(filteredMorePosts);

          // Only trim when user is at bottom AND scrolling down (avoid scroll-back jumps)
          if (feed.length > _maxFeedSize * 1.5 &&
              _scrollController.hasClients) {
            final position = _scrollController.position;
            final isNearBottom =
                (position.maxScrollExtent - position.pixels) < 200;
            final isScrollingDown =
                position.userScrollDirection == ScrollDirection.reverse;

            if (isNearBottom && isScrollingDown) {
              removedCount = feed.length - _maxFeedSize;
              currentOffset = position.pixels;
              removedHeight = _layoutCache
                  .estimateRangeHeight(feed.sublist(0, removedCount));
              feed.removeRange(0, removedCount);
              didTrim = true;

              AppLogger.d('Feed: Trimmed old posts (user at bottom)',
                  category: LogCategory.ui,
                  data: {'removed': removedCount, 'currentSize': feed.length});
            }
          }
        });

        if (didTrim && mounted && _scrollController.hasClients) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients) return;
            if (anchor != null) {
              final didRestore = _restoreAnchor(anchor);
              if (didRestore) return;
            }
            final fallbackOffset = (currentOffset - removedHeight).clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            );
            if (kDebugMode) {
              AppLogger.d(
                'Feed: trim applied (fallback)',
                category: LogCategory.performance,
                data: {
                  'removedCount': removedCount,
                  'removedHeight': removedHeight.toStringAsFixed(1),
                  'from': currentOffset.toStringAsFixed(1),
                  'to': fallbackOffset.toStringAsFixed(1),
                },
              );
            }
            _scrollController.jumpTo(fallbackOffset);
          });
        }

        // Trim old states from FeedController after pagination
        try {
          final feedController = context.read<FeedController>();
          feedController.trimStatesForFeed(feed);
        } catch (e) {
          // FeedController not available
        }
      }
    } catch (e) {
      AppLogger.e('Feed: Error loading more', error: e);
    } finally {
      _isLoadingMore = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    // Yield a frame so shimmer appears before work starts
    await Future.delayed(Duration.zero);

    try {
      // Refresh stories by incrementing the key and setting forceRefresh flag
      setState(() {
        _storyRingRefreshKey++;
        _storyRingForceRefresh = true;
      });

      // Reset preload tracking to ensure fresh preloading
      _lastPreloadedIndex = -1;

      // Invalidate PostDbService cache for current feed posts to ensure fresh data
      for (final postId in feed) {
        _postDbService.invalidateUpdatedPostCache(postId);
      }

      var postIds = await _feedService.getFeed(forceRefresh: true);
      if (mounted) {
        // Preload first 15 posts BEFORE setState - pass postIds directly
        AppLogger.i('📥 Refresh: Preloading first 15 posts',
            category: LogCategory.performance);
        final validFirstBatch = await _preloadAndCountPosts(0, 15, postIds: postIds);

        // Batch load user/space data BEFORE rendering
        try {
          final feedController = context.read<FeedController>();
          await _preloader.batchLoadUserSpaceData(validFirstBatch, feedController);
        } catch (_) {}

        AppLogger.i('✓ Refresh: Preload complete',
            category: LogCategory.performance);

        // Removed ViewportTracker complexity
        postIds = postIds
            .where((id) => !_postDbService.isPostKnownMissing(id))
            .toList();
        if (validFirstBatch.isNotEmpty) {
          final validSet = validFirstBatch.toSet();
          postIds = postIds.where((id) => validSet.contains(id)).toList();
        }
        setState(() {
          feed = postIds;
          // Reset forceRefresh flag after stories have been refreshed
          _storyRingForceRefresh = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    // Simple feed content - no ViewportTracker wrapper needed
    return _buildFeedContent(context, isDark, isDesktop);
  }

  Widget _buildFeedContent(BuildContext context, bool isDark, bool isDesktop) {
    // On desktop web, use layout with right sidebar
    if (Responsive.isWideLayout(context)) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: _buildDesktopLayout(isDark),
      );
    }

    // Mobile layout - delegated to FeedMobileLayout widget
    return FeedMobileLayout(
      isDark: isDark,
      user: user,
      scrollController: _scrollController,
      feed: feed,
      initialized: initialized,
      isRefreshing: _isRefreshing,
      storyRingRefreshKey: _storyRingRefreshKey,
      storyRingForceRefresh: _storyRingForceRefresh,
      estimatedVisibleIndex: _estimatedVisibleIndex,
      feedService: _feedService,
      layoutCache: _layoutCache,
      showScrollToTopNotifier: _showScrollToTopNotifier,
      barHiddenNotifier: widget.barHiddenNotifier,
      onAddPost: _addPost,
      onRefresh: _handleRefresh,
      onScrollToTop: _scrollToTop,
      onStoryRefresh: (key, force) => setState(() {
        _storyRingRefreshKey = key;
        _storyRingForceRefresh = force;
      }),
    );
  }

  /// Build desktop layout - delegates to FeedDesktopLayout widget.
  Widget _buildDesktopLayout(bool isDark) {
    return FeedDesktopLayout(
      isDark: isDark,
      user: user,
      scrollController: _scrollController,
      feed: feed,
      initialized: initialized,
      isRefreshing: _isRefreshing,
      storyRingRefreshKey: _storyRingRefreshKey,
      storyRingForceRefresh: _storyRingForceRefresh,
      estimatedVisibleIndex: _estimatedVisibleIndex,
      feedService: _feedService,
      layoutCache: _layoutCache,
      showScrollToTopNotifier: _showScrollToTopNotifier,
      onAddPost: _addPost,
      onRefresh: _handleRefresh,
      onScrollToTop: _scrollToTop,
      onStoryRefresh: (key, force) => setState(() {
        _storyRingRefreshKey = key;
        _storyRingForceRefresh = force;
      }),
    );
  }


}
