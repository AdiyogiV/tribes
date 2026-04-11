import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/feed/presentation/widgets/post.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Full-screen thread view: main post on top, replies below (chronological).
/// Single destination for "open this post" from feed, notifications, profile, deep link.
/// When opened from a reposter's profile, pass [repostedByName] and [repostedByAvatarUrl]
/// so the post shows "X reposted" at the top (Twitter-style).
class ThreadView extends StatefulWidget {
  final String postId;
  final String? repostedByName;
  final String? repostedByAvatarUrl;

  const ThreadView({
    super.key,
    required this.postId,
    this.repostedByName,
    this.repostedByAvatarUrl,
  });

  @override
  State<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<ThreadView> {
  late PostDbService _postDbService;
  bool _isLoading = true;
  bool _mainPostMissing = false;
  List<String> _replyIds = [];
  bool _repliesError = false;
  List<String> _parentChainIds = []; // Parent posts in order (oldest first)

  // Key for auto-scrolling to main post
  final GlobalKey _mainPostKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _postDbService = locator<PostDbService>();
    _loadReplies();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Auto-scroll to main post after content loads
  void _scrollToMainPost() {
    if (!mounted) return;

    // Wait for initial layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait for posts to build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Wait for reply sections to load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Wait for everything to stabilize
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients) return;

            final mainContext = _mainPostKey.currentContext;
            if (mainContext == null) return;

            final RenderBox? mainRenderBox =
                mainContext.findRenderObject() as RenderBox?;
            if (mainRenderBox == null) return;

            // Get the scroll view's render object
            final RenderAbstractViewport viewport =
                RenderAbstractViewport.of(mainRenderBox);

            // Calculate the scroll offset to position main post at absolute top
            final RevealedOffset revealed =
                viewport.getOffsetToReveal(mainRenderBox, 0.0);

            // SUBTRACT kToolbarHeight to compensate for AppBar hiding
            final double targetScroll = revealed.offset - kToolbarHeight;

            // Jump to that position
            _scrollController.jumpTo(
              targetScroll.clamp(
                  0.0, _scrollController.position.maxScrollExtent),
            );
          });
        });
      });
    });
  }

  /// Load thread data: main post, parent chain, and replies
  /// CRITICAL: Preloads all post data BEFORE showing widgets to prevent
  /// loading during scroll (which causes jank and loading skeletons)
  Future<void> _loadReplies() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _mainPostMissing = false;
      _replyIds = [];
      _repliesError = false;
      _parentChainIds = [];
    });

    try {
      final mainSnapshot = await _postDbService.getPost(widget.postId);
      if (!mounted) return;
      if (!mainSnapshot.exists) {
        setState(() {
          _mainPostMissing = true;
          _isLoading = false;
        });
        return;
      }

      // Load parent chain if main post is a reply
      final mainData = mainSnapshot.data() as Map<String, dynamic>?;
      final replyTo = mainData?['replyTo'] as String?;
      if (replyTo != null && replyTo.isNotEmpty) {
        await _loadParentChain(replyTo);
      }

      final snapshot = await _postDbService.getPostReplies(widget.postId);
      if (!mounted) return;
      if (snapshot == null) {
        setState(() {
          _repliesError = true;
          _replyIds = [];
          _isLoading = false;
        });
        return;
      }
      final ids = snapshot.docs.map((d) => d.id).toList();
      final reversedIds = ids.reversed.toList();

      // CRITICAL: Preload all reply data BEFORE showing posts
      // This prevents replies from loading while scrolling (causes jank)
      // Uses batch getPosts for optimal performance - same as feed
      if (reversedIds.isNotEmpty) {
        await _preloadReplyData(reversedIds);
      }

      setState(() {
        _replyIds = reversedIds;
        _isLoading = false;
      });

      // Auto-scroll to main post after data loads
      _scrollToMainPost();
    } catch (e) {
      if (mounted) {
        setState(() {
          _repliesError = true;
          _replyIds = [];
          _isLoading = false;
        });
      }
    }
  }

  /// Preload reply data to prevent loading during scroll
  /// Uses batch getPosts for optimal parallel loading (same as feed)
  Future<void> _preloadReplyData(List<String> replyIds) async {
    if (replyIds.isEmpty || !mounted) return;

    try {
      // Batch load all replies in parallel (production-grade approach)
      final results = await _postDbService.getPosts(replyIds);

      // Mark any missing posts
      for (final replyId in replyIds) {
        final snapshot = results[replyId];
        if (snapshot == null || !snapshot.exists) {
          _postDbService.markPostAsMissing(replyId);
          _postDbService.cleanupMissingPostReferences(replyId);
          continue;
        }

        final data = snapshot.data() as Map<String, dynamic>?;
        if (data == null) {
          _postDbService.markPostAsMissing(replyId);
          _postDbService.cleanupMissingPostReferences(replyId);
          continue;
        }

        // Check for required fields (skip uploading posts)
        final uploading = data['uploading'] as bool? ?? false;
        final hasRequired = data['timestamp'] != null &&
            data['author'] != null &&
            data['space'] != null;
        if (!hasRequired && !uploading) {
          _postDbService.markPostAsMissing(replyId);
          _postDbService.cleanupMissingPostReferences(replyId);
        }
      }
    } catch (e) {
      // Silently handle preload errors - posts will load individually as fallback
    }
  }

  /// Load the full parent chain by following replyTo links
  Future<void> _loadParentChain(String startPostId) async {
    final chain = <String>[];
    String? currentId = startPostId;

    while (currentId != null && currentId.isNotEmpty && mounted) {
      try {
        final snapshot = await _postDbService.getPost(currentId);
        if (!snapshot.exists) break;

        chain.add(currentId);
        final data = snapshot.data() as Map<String, dynamic>?;
        currentId = data?['replyTo'] as String?;
      } catch (e) {
        // Stop if we can't load an ancestor
        break;
      }
    }

    // Reverse to get oldest first (root post at index 0)
    final reversedChain = chain.reversed.toList();

    // CRITICAL: Preload parent chain data BEFORE showing posts
    // Parent posts are already loaded individually above, but this ensures
    // all related data (replies, counters, etc.) is ready
    // Note: The individual getPost calls above already cache the data,
    // so this preload call will be very fast (cache hits)
    if (reversedChain.isNotEmpty) {
      await _preloadReplyData(reversedChain);
    }

    if (mounted) {
      setState(() {
        _parentChainIds = reversedChain;
      });
    }
  }

  void _onReplyInThread(String replyId) {
    context.push('/thread/$replyId');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_mainPostMissing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48,
                  color: AppTheme.primaryColor.withValues(alpha: 0.6)),
              const SizedBox(height: AppDimensions.spacingLg),
              Text(
                'Post not found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark ? AppTheme.textDarkColor : AppTheme.textLightColor,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXxl),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShimmerBox(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE0E0E0),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingMd),
                      ShimmerBox(
                        child: Container(
                          width: 120,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  ShimmerBox(
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _skeletonReply(isDark),
              _skeletonReply(isDark),
            ]),
          ),
        ],
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Scrollable AppBar
        SliverAppBar(
          title: const Text('Thread'),
          backgroundColor: isDark
              ? AppTheme.cardDarkColor.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.9),
          foregroundColor:
              isDark ? AppTheme.textDarkColor : AppTheme.textLightColor,
          elevation: 0,
          floating: true, // Reappears when scrolling up
          snap: true, // Snaps into view
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),

        // Parents with chevron connectors and left line
        if (_parentChainIds.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final parentId = _parentChainIds[index];
                final isFirst = index == 0;
                final isLastParent = index == _parentChainIds.length - 1;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildThreadPost(
                      context: context,
                      postId: parentId,
                      index: index,
                      isMainPost: false,
                      isFirstPost: isFirst,
                      isLastPost: false,
                      isDark: isDark,
                      showLeftBorder: true, // Show left border for parents
                    ),
                    // Chevron connector (not after last parent)
                    if (!isLastParent) _buildThreadConnector(isDark),
                  ],
                );
              },
              childCount: _parentChainIds.length,
            ),
          ),

        // Connector from last parent to main post
        if (_parentChainIds.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildThreadConnector(isDark),
          ),

        // Main post (optionally with "X reposted" when opened from reposter's profile)
        SliverToBoxAdapter(
          child: Container(
            key: _mainPostKey,
            child: _buildThreadPost(
              context: context,
              postId: widget.postId,
              index: _parentChainIds.length,
              isMainPost: true,
              isFirstPost: _parentChainIds.isEmpty,
              isLastPost: _replyIds.isEmpty,
              isDark: isDark,
              showLeftBorder: true, // Show left border for main post
              repostedByName: widget.repostedByName,
              repostedByAvatarUrl: widget.repostedByAvatarUrl,
            ),
          ),
        ),

        // Replies indicator banner (only if there are replies)
        if (_replyIds.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRepliesBanner(isDark, _replyIds.length),
          ),

        // Replies
        if (_repliesError)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Center(
                child: Text(
                  'Could not load replies',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppTheme.textSecondaryDarkColor
                        : AppTheme.textSecondaryLightColor,
                  ),
                ),
              ),
            ),
          )
        else if (_replyIds.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final replyId = _replyIds[index];
                final isLast = index == _replyIds.length - 1;
                return _buildThreadPost(
                  context: context,
                  postId: replyId,
                  index: _parentChainIds.length + 1 + index,
                  isMainPost: false,
                  isFirstPost: false,
                  isLastPost: isLast,
                  isDark: isDark,
                  showLeftBorder: false, // No left border for replies
                );
              },
              childCount: _replyIds.length,
            ),
          ),

        // Bottom spacing
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  /// Chevron connector between thread posts
  Widget _buildThreadConnector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSm),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.15),
            width: 3,
          ),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 20), // Padding from left border
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 24,
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  /// Minimal full-width banner indicating replies section starts
  Widget _buildRepliesBanner(bool isDark, int replyCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Text(
        '$replyCount ${replyCount == 1 ? 'Reply' : 'Replies'}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark
              ? AppTheme.textSecondaryDarkColor
              : AppTheme.textSecondaryLightColor,
        ),
      ),
    );
  }

  /// Thread post without visual connectors - clean layout
  Widget _buildThreadPost({
    required BuildContext context,
    required String postId,
    required int index,
    required bool isMainPost,
    required bool isFirstPost,
    required bool isLastPost,
    required bool isDark,
    required bool showLeftBorder,
    String? repostedByName,
    String? repostedByAvatarUrl,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double absoluteMaxWidth = 600.0;
    final cardWidth = screenWidth.clamp(0.0, absoluteMaxWidth);

    return Container(
      decoration: BoxDecoration(
        color: isMainPost
            ? (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04))
            : null,
        border: showLeftBorder
            ? Border(
                left: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.15),
                  width: 3,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: isFirstPost ? 8 : 0,
          bottom: isLastPost ? 8 : 0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cardWidth),
            child: Post(
              key: ValueKey('thread_post_$postId'),
              post: postId,
              itemIndex: index,
              onReplySelected: _onReplyInThread,
              showReplySection:
                  !isMainPost, // Show for parent posts, hide for main (replies shown below)
              showReplyIndicator: false, // Hide "Replying to X" at top
              enableVideoAutoplay: isMainPost,
              repostedByName: repostedByName,
              repostedByAvatarUrl: repostedByAvatarUrl,
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeletonReply(bool isDark) {
    final color = isDark ? AppTheme.darkElevatedSurface : const Color(0xFFE8E8E8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: ShimmerBox(
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        ),
      ),
    );
  }
}
