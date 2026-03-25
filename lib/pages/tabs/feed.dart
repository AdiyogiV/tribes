import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, ValueListenable;
import 'package:provider/provider.dart';
import 'package:aurogram/pages/helpers/gram_creation_page.dart'
    show SpaceCreationPage;
import 'package:aurogram/utils/media_type_selector.dart';
import 'package:aurogram/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/services/feed_service.dart';
import 'package:aurogram/services/story_service.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/services/feed_layout_cache.dart';
import 'package:aurogram/services/video_prewarm_service.dart';
import 'package:aurogram/services/batch_data_loader.dart';
import 'package:aurogram/controllers/feed_controller.dart';
import 'package:aurogram/utils/feed_performance_monitor.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/widgets/cosmic_dashboard.dart';
import 'package:aurogram/pages/thread_view.dart';
import 'package:aurogram/pages/stories/story_composer_page.dart';
import 'package:aurogram/pages/stories/story_viewer_page.dart';
import 'package:aurogram/widgets/post_switcher.dart';
import 'package:aurogram/widgets/stories/story_ring.dart';
import 'package:aurogram/widgets/preview_boxes/gram_preview_box.dart';
import 'package:aurogram/widgets/ui/size_reporting_widget.dart';
import 'package:aurogram/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';

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
  static int get _prewarmAheadCount => kIsWeb ? 6 : 2;

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

  /// Preload post data ahead of viewport for instant rendering
  /// This fetches post documents from Firestore and caches them in PostDbService
  /// so when Post widgets build, their data is already available
  Future<List<String>> _preloadPostData(int startIndex, int count,
      {List<String>? postIds}) async {
    // Use provided postIds or fall back to feed list
    final feedList = postIds ?? feed;

    if (startIndex >= feedList.length) return [];

    final startTime = DateTime.now();
    final endIndex = (startIndex + count).clamp(0, feedList.length);
    final postsToPreload = feedList.sublist(startIndex, endIndex);
    final validPostIds = <String>[];

    if (kDebugMode) {
      AppLogger.i(
        '⏳ Preload START',
        category: LogCategory.performance,
        data: {'start': startIndex, 'count': postsToPreload.length},
      );
    }

    // Use batch getPosts method for optimal parallel loading
    final results = await _postDbService.getPosts(postsToPreload);
    for (final postId in postsToPreload) {
      final snapshot = results[postId];
      if (snapshot == null || !snapshot.exists) {
        _postDbService.markPostAsMissing(postId);
        _postDbService.cleanupMissingPostReferences(postId);
        continue;
      }
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        _postDbService.markPostAsMissing(postId);
        _postDbService.cleanupMissingPostReferences(postId);
        continue;
      }
      final uploading = data['uploading'] as bool? ?? false;
      final hasRequired = data['timestamp'] != null &&
          data['author'] != null &&
          data['space'] != null;
      if (!hasRequired && !uploading) {
        _postDbService.markPostAsMissing(postId);
        _postDbService.cleanupMissingPostReferences(postId);
        continue;
      }
      validPostIds.add(postId);

      final postType = data['postType'] as String? ?? 'video';
      final videoUrl = data['video'] as String?;
      if (postType == 'video' &&
          videoUrl != null &&
          videoUrl.isNotEmpty &&
          !uploading) {
        VideoPrewarmService().prewarm(postId, videoUrl);
      }
    }
    final successCount = results.values.where((doc) => doc != null).length;
    final errorCount = results.values.where((doc) => doc == null).length;

    final endTime = DateTime.now();
    final durationMs = endTime.difference(startTime).inMilliseconds;

    if (kDebugMode) {
      AppLogger.i(
        '✅ Preload COMPLETE',
        category: LogCategory.performance,
        data: {
          'start': startIndex,
          'total': postsToPreload.length,
          'success': successCount,
          'errors': errorCount,
          'took_ms': durationMs,
          'avg_ms_per_post':
              (durationMs / postsToPreload.length).toStringAsFixed(1),
          'validCount': validPostIds.length,
        },
      );
    }

    // NEW: Batch load counters for these posts (like/reply counts)
    // This loads all counters in parallel instead of one-by-one in each post widget
    if (validPostIds.isNotEmpty) {
      try {
        final feedController = context.read<FeedController>();
        await feedController.batchLoadCounters(validPostIds);

        if (kDebugMode) {
          AppLogger.i(
            '✅ Batch counter load complete',
            category: LogCategory.performance,
            data: {'count': validPostIds.length},
          );
        }
      } catch (e) {
        // FeedController not available or error - posts will load counters individually
        AppLogger.w('Batch counter load failed', data: {'error': e.toString()});
      }
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
        _preloadPostData(preloadStartIndex, _preloadAheadCount).catchError((e) {
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

  void _showCreateSelectionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  height: 4,
                  width: 36,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Post option
                _CreationOptionCard(
                  icon: CupertinoIcons.square_grid_2x2,
                  title: 'Create Post',
                  subtitle: 'Share photos, videos, or notes',
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6366F1), // Indigo
                      Color(0xFFEC4899), // Pink
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _createPost();
                  },
                ),

                const SizedBox(height: 24),

                // Story option
                _CreationOptionCard(
                  icon: CupertinoIcons.camera_fill,
                  title: 'Create Story',
                  subtitle: 'Share moments that disappear in 24h',
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0EA5E9), // Sky blue
                      Color(0xFF10B981), // Green
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _createStory();
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
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
        final validFirstBatch = await _preloadPostData(0, 15, postIds: postIds);
        final preloadCompleteTime = DateTime.now();

        // NEW: Batch load user/space data for all posts BEFORE rendering
        // Extract author/space IDs from preloaded posts and load in bulk
        if (validFirstBatch.isNotEmpty) {
          try {
            final feedController = context.read<FeedController>();
            final userIds = <String>{};
            final spaceIds = <String>{};

            for (final postId in validFirstBatch) {
              final cached = _postDbService.peekPost(postId);
              if (cached != null && cached.exists) {
                final data = cached.data() as Map<String, dynamic>?;
                if (data != null) {
                  final authorId = data['author'] as String?;
                  final spaceId = data['space'] as String?;
                  if (authorId != null) userIds.add(authorId);
                  if (spaceId != null) spaceIds.add(spaceId);
                }
              }
            }

            // Load all users and spaces in parallel
            final userDataFuture =
                _batchLoader.batchLoadUsers(userIds.toList());
            final spaceDataFuture =
                _batchLoader.batchLoadSpaces(spaceIds.toList());
            final results =
                await Future.wait([userDataFuture, spaceDataFuture]);

            final userData = results[0] as Map<String, UserData>;
            final spaceData = results[1] as Map<String, SpaceData>;

            // Store in FeedController for instant access when Posts build
            for (final postId in validFirstBatch) {
              final cached = _postDbService.peekPost(postId);
              if (cached != null && cached.exists) {
                final data = cached.data() as Map<String, dynamic>?;
                if (data != null) {
                  final authorId = data['author'] as String?;
                  final spaceId = data['space'] as String?;
                  if (authorId != null && userData.containsKey(authorId)) {
                    feedController.setUserData(postId, userData[authorId]!);
                  }
                  if (spaceId != null && spaceData.containsKey(spaceId)) {
                    feedController.setSpaceData(postId, spaceData[spaceId]!);
                  }
                }
              }
            }

            AppLogger.i(
              '✓ Feed: User/space data loaded',
              category: LogCategory.performance,
              data: {
                'users': userData.length,
                'spaces': spaceData.length,
              },
            );
          } catch (e) {
            AppLogger.w('Error batch loading user/space data',
                data: {'error': e.toString()});
          }
        }

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
            await _preloadPostData(0, morePosts.length, postIds: morePosts);

        // NEW: Batch load user/space data for new posts BEFORE rendering
        if (validMorePosts.isNotEmpty) {
          try {
            final feedController = context.read<FeedController>();
            final userIds = <String>{};
            final spaceIds = <String>{};

            for (final postId in validMorePosts) {
              final cached = _postDbService.peekPost(postId);
              if (cached != null && cached.exists) {
                final data = cached.data() as Map<String, dynamic>?;
                if (data != null) {
                  final authorId = data['author'] as String?;
                  final spaceId = data['space'] as String?;
                  if (authorId != null) userIds.add(authorId);
                  if (spaceId != null) spaceIds.add(spaceId);
                }
              }
            }

            final userDataFuture =
                _batchLoader.batchLoadUsers(userIds.toList());
            final spaceDataFuture =
                _batchLoader.batchLoadSpaces(spaceIds.toList());
            final results =
                await Future.wait([userDataFuture, spaceDataFuture]);

            final userData = results[0] as Map<String, UserData>;
            final spaceData = results[1] as Map<String, SpaceData>;

            for (final postId in validMorePosts) {
              final cached = _postDbService.peekPost(postId);
              if (cached != null && cached.exists) {
                final data = cached.data() as Map<String, dynamic>?;
                if (data != null) {
                  final authorId = data['author'] as String?;
                  final spaceId = data['space'] as String?;
                  if (authorId != null && userData.containsKey(authorId)) {
                    feedController.setUserData(postId, userData[authorId]!);
                  }
                  if (spaceId != null && spaceData.containsKey(spaceId)) {
                    feedController.setSpaceData(postId, spaceData[spaceId]!);
                  }
                }
              }
            }
          } catch (e) {
            AppLogger.w('Error batch loading user/space data on loadMore',
                data: {'error': e.toString()});
          }
        }

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
        final validFirstBatch = await _preloadPostData(0, 15, postIds: postIds);

        // NEW: Batch load user/space data BEFORE rendering (same as initial load)
        if (validFirstBatch.isNotEmpty) {
          try {
            final feedController = context.read<FeedController>();
            final userIds = <String>{};
            final spaceIds = <String>{};

            for (final postId in validFirstBatch) {
              final cached = _postDbService.peekPost(postId);
              if (cached != null && cached.exists) {
                final data = cached.data() as Map<String, dynamic>?;
                if (data != null) {
                  final authorId = data['author'] as String?;
                  final spaceId = data['space'] as String?;
                  if (authorId != null) userIds.add(authorId);
                  if (spaceId != null) spaceIds.add(spaceId);
                }
              }
            }

            final userDataFuture =
                _batchLoader.batchLoadUsers(userIds.toList());
            final spaceDataFuture =
                _batchLoader.batchLoadSpaces(spaceIds.toList());
            final results =
                await Future.wait([userDataFuture, spaceDataFuture]);

            final userData = results[0] as Map<String, UserData>;
            final spaceData = results[1] as Map<String, SpaceData>;

            for (final postId in validFirstBatch) {
              final cached = _postDbService.peekPost(postId);
              if (cached != null && cached.exists) {
                final data = cached.data() as Map<String, dynamic>?;
                if (data != null) {
                  final authorId = data['author'] as String?;
                  final spaceId = data['space'] as String?;
                  if (authorId != null && userData.containsKey(authorId)) {
                    feedController.setUserData(postId, userData[authorId]!);
                  }
                  if (spaceId != null && spaceData.containsKey(spaceId)) {
                    feedController.setSpaceData(postId, spaceData[spaceId]!);
                  }
                }
              }
            }
          } catch (e) {
            AppLogger.w('Error batch loading user/space data on refresh',
                data: {'error': e.toString()});
          }
        }

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

    // Mobile layout - scroll-to-top chevron above tab bar; bar position from notifier so only button rebuilds
    final padding = MediaQuery.of(context).padding.bottom;
    const scrollButtonBaseBottom = 16.0;
    final barHiddenNotifier = widget.barHiddenNotifier;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Full-width scroll view with optimized cache for web
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            cacheExtent: kIsWeb
                ? 8000
                : 6000, // VERY large cache for smooth scroll-back with highly variable post heights
            slivers: [
              // Standard app header
              AppHeaderStyle.buildStandardHeader(
                context: context,
                title: 'aurogram',
                showSearchField: false,
                backgroundStyle: HeaderBackgroundStyle.gradient,
                isRefreshing: _isRefreshing,
                pinned: false,
                leadingWidget: IconButton(
                  onPressed: _addPost,
                  icon: Icon(
                    CupertinoIcons.plus,
                    color:
                        isDark ? AppTheme.primaryColor : AppTheme.primaryColor,
                    size: AppHeaderStyle.headerIconSize,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                actionButton: IconButton(
                  onPressed: () => CosmicDashboard.show(context),
                  icon: Icon(
                    Icons.notifications_outlined,
                    color:
                        isDark ? AppTheme.primaryColor : AppTheme.primaryColor,
                    size: AppHeaderStyle.headerIconSize,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),

              // Pull to refresh
              CupertinoSliverRefreshControl(
                onRefresh: _handleRefresh,
                builder: (context, refreshState, pulledExtent,
                    refreshTriggerPullDistance, refreshIndicatorExtent) {
                  return const SizedBox.shrink();
                },
              ),

              // Story ring (logged-in only)
              if (user != null)
                SliverToBoxAdapter(
                  key: ValueKey(_storyRingRefreshKey),
                  child: Transform.translate(
                    offset: const Offset(0, -12),
                    child: StoryRing(
                      forceRefresh: _storyRingForceRefresh,
                      onAddStory: () async {
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
                      },
                      onViewUserStories: (userId) async {
                        final storyService = StoryService();
                        final userIds =
                            await storyService.getUsersWithStories();
                        final idx = userIds.indexOf(userId);
                        if (!mounted) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StoryViewerPage(
                              userIds: userIds,
                              initialUserIndex: idx >= 0 ? idx : 0,
                            ),
                          ),
                        );
                        if (mounted) {
                          setState(() {
                            _storyRingRefreshKey++;
                            _storyRingForceRefresh = false;
                          });
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
                      color: AppTheme.primaryColor.withOpacity(0.12),
                    ),
                  ),
                ),

              // Main content – skeleton while loading, then empty or feed.
              // Key each branch so Flutter replaces the sliver instead of updating in place.
              if (!initialized && feed.isEmpty)
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
                )
              else if (feed.isEmpty)
                SliverToBoxAdapter(
                  key: const ValueKey('feed_empty'),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height - 200,
                    child: _buildEmptyState(context),
                  ),
                )
              else
                SliverPadding(
                  key: const ValueKey('feed_posts'),
                  padding: const EdgeInsets.fromLTRB(
                      0, 0, 0, AppHeaderStyle.contentBottomPadding),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // Loading indicator at end
                        if (index == feed.length) {
                          return const SizedBox(height: 60);
                        }

                        final postId = feed[index];
                        final shouldPrewarmVideo =
                            index >= _estimatedVisibleIndex &&
                                index <=
                                    _estimatedVisibleIndex + _prewarmAheadCount;

                        // Rely on Flutter's native cacheExtent (8000px) + massive pool (40 controllers)
                        // SelectiveKeepAlive caused scroll position instability with variable heights
                        final isLastPost = index == feed.length - 1;
                        return RepaintBoundary(
                          child: SizeReportingWidget(
                            onSizeChange: (size) {
                              _layoutCache.updateHeight(postId, size.height);
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
                                          .withOpacity(0.12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount:
                          feed.length + (_feedService.hasMorePosts ? 1 : 0),
                      addRepaintBoundaries: true,
                    ),
                  ),
                ),
            ],
          ),

          // Scroll to top button - aligned above profile avatar in tab bar (moved left from edge)
          Positioned(
            right: 32,
            bottom: scrollButtonBaseBottom + padding,
            child: barHiddenNotifier != null
                ? ValueListenableBuilder<bool>(
                    valueListenable: barHiddenNotifier,
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
                        child: _buildScrollToTopButton(isDark),
                      );
                    },
                  )
                : _buildScrollToTopButton(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToTopButton(bool isDark) {
    final theme = Theme.of(context);
    final Color barBase = isDark ? AppTheme.cardDarkColor : Colors.white;
    return ValueListenableBuilder<bool>(
      valueListenable: _showScrollToTopNotifier,
      builder: (context, show, _) {
        return AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          offset: show ? Offset.zero : const Offset(0, 2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: show ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !show,
              child: GestureDetector(
                onTap: _scrollToTop,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _scrollToTop,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      barBase.withValues(alpha: 0.75),
                                      barBase.withValues(alpha: 0.70),
                                    ]
                                  : [
                                      barBase.withValues(alpha: 0.90),
                                      barBase.withValues(alpha: 0.85),
                                    ],
                            ),
                            border: isDark
                                ? Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    width: 1.0,
                                  )
                                : null,
                          ),
                          child: Icon(
                            CupertinoIcons.chevron_up,
                            color: theme.colorScheme.primary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build desktop layout - header scrolls up with content, aligned with sidebar
  Widget _buildDesktopLayout(bool isDark) {
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              cacheExtent:
                  8000, // VERY large cache for smooth scroll-back with highly variable post heights
              slivers: [
                AppHeaderStyle.buildWideLayoutHeaderSliver(
                  context,
                  title: 'Feed',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Plus icon button for creating posts
                      GestureDetector(
                        onTap: _addPost,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            CupertinoIcons.plus,
                            size: 22,
                            color: isDark
                                ? AppTheme.primaryColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Refresh button
                      _isRefreshing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryColor),
                              ),
                            )
                          : GestureDetector(
                              onTap: _handleRefresh,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
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
                    key: ValueKey(_storyRingRefreshKey),
                    child: Transform.translate(
                      offset: const Offset(0, -12),
                      child: StoryRing(
                        forceRefresh: _storyRingForceRefresh,
                        onAddStory: () async {
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
                        },
                        onViewUserStories: (userId) async {
                          final storyService = StoryService();
                          final userIds =
                              await storyService.getUsersWithStories();
                          final idx = userIds.indexOf(userId);
                          if (!mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StoryViewerPage(
                                userIds: userIds,
                                initialUserIndex: idx >= 0 ? idx : 0,
                              ),
                            ),
                          );
                          if (mounted) {
                            setState(() {
                              _storyRingRefreshKey++;
                              _storyRingForceRefresh = false;
                            });
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
                        color: AppTheme.primaryColor.withOpacity(0.12),
                      ),
                    ),
                  ),
                // Content – key each branch so sliver is replaced, not updated in place
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
                      child: _buildEmptyState(context),
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
                            return const SizedBox(height: 60);
                          }
                          final postId = feed[index];
                          final shouldPrewarmVideo = index >=
                                  _estimatedVisibleIndex &&
                              index <=
                                  _estimatedVisibleIndex + _prewarmAheadCount;
                          final isLastPost = index == feed.length - 1;

                          // Rely on Flutter's native cacheExtent (8000px) + massive pool (40 controllers)
                          // SelectiveKeepAlive caused scroll position instability with variable heights
                          return RepaintBoundary(
                            child: SizeReportingWidget(
                              onSizeChange: (size) {
                                _layoutCache.updateHeight(
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
                                            .withOpacity(0.12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount:
                            feed.length + (_feedService.hasMorePosts ? 1 : 0),
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            );
          },
        ),

        // Scroll to top button (transparent toolbox style)
        Positioned(
          right: 35,
          bottom: 16,
          child: _buildScrollToTopButton(isDark),
        ),
      ],
    );
  }

  /// Same post-card skeleton as PostSwitcher – appears immediately while feed loads
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

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          Icon(
            CupertinoIcons.sparkles,
            size: 64,
            color: AppTheme.primaryColor.withValues(alpha: 0.5),
          ),

          const SizedBox(height: 24),

          Text(
            'Welcome to Aurogram!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textDarkColor : AppTheme.textLightColor,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Create or join a gram to start seeing posts',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppTheme.textSecondaryDarkColor
                  : AppTheme.textSecondaryLightColor,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SpaceCreationPage()),
              );
            },
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Create Gram'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Discover groups
          _buildDiscoverGroups(context, isDark),
        ],
      ),
    );
  }

  Widget _buildDiscoverGroups(BuildContext context, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .where('spaceType', whereIn: [0, 1])
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final publicSpaces = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final spaceType = data['spaceType'] as int? ?? 3;
          final limitedVisibility = data['limitedVisibility'] as bool? ?? false;
          return (spaceType == 0 || spaceType == 1) && !limitedVisibility;
        }).toList();

        if (publicSpaces.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discover Grams',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? AppTheme.textDarkColor : AppTheme.textLightColor,
              ),
            ),
            const SizedBox(height: 12),
            ...publicSpaces.map((doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GramPreviewBox(gram: doc.id),
                )),
          ],
        );
      },
    );
  }
}

/// Individual creation option card - reused from CreationHubPage
class _CreationOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _CreationOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow icon
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
