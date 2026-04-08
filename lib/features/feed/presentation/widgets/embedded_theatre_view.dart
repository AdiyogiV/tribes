import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/feed/presentation/pages/thread_view.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_switcher.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram_picture.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/features/chat/presentation/widgets/embedded_chat_view.dart';
import 'package:aurogram/features/calling/presentation/widgets/group_call_button.dart';
import 'package:aurogram/features/spaces/presentation/pages/grid_space_view.dart';
import 'package:aurogram/features/spaces/presentation/pages/edit_space.dart';
import 'package:aurogram/shared/services/share/share_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// An embeddable theatre view that displays gram posts in a nested layout.
/// Unlike Theatre, this doesn't use its own Scaffold and is designed
/// to be embedded within another widget tree (e.g., Grams tab desktop layout).
///
/// Features:
/// - Posts list with PostSwitcher (or grid view)
/// - Sliding chat drawer from the right
/// - All Theatre action buttons in header
class EmbeddedTheatreView extends StatefulWidget {
  final String spaceId;
  final Space? space;

  /// Optional callback when back/close is pressed (for desktop, may want to deselect)
  final VoidCallback? onBack;

  /// Whether to show the header (can hide if parent provides header)
  final bool showHeader;

  const EmbeddedTheatreView({
    super.key,
    required this.spaceId,
    this.space,
    this.onBack,
    this.showHeader = true,
  });

  @override
  EmbeddedTheatreViewState createState() => EmbeddedTheatreViewState();
}

class EmbeddedTheatreViewState extends State<EmbeddedTheatreView> {
  final ScrollController _scrollController = ScrollController();

  // Post feed state
  List<String> _feed = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;

  // Chat drawer state
  bool _isChatDrawerOpen = false;

  // Grid view state
  bool _gridViewOn = false;

  static const int _postsPerPage = 15;
  static const double _chatDrawerWidth = 400.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFeed();
  }

  @override
  void didUpdateWidget(EmbeddedTheatreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If spaceId changes, reload feed and close chat drawer
    if (oldWidget.spaceId != widget.spaceId) {
      _feed.clear();
      _isChatDrawerOpen = false;
      _gridViewOn = false;
      _loadFeed();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMorePosts();
    }
  }

  Future<void> _loadFeed() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _feed = [];
      _hasMorePosts = true;
    });

    try {
      // Query posts directly with space field
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('space', isEqualTo: widget.spaceId)
          .orderBy('timestamp', descending: true)
          .limit(_postsPerPage)
          .get();

      final postIds = snapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['uploading'] != true;
          })
          .map((e) => e.id)
          .toList();

      if (mounted) {
        setState(() {
          _feed = postIds;
          _isLoading = false;
          _hasMorePosts = snapshot.docs.length >= _postsPerPage;
        });
      }
    } catch (e) {
      AppLogger.e('Error loading embedded theatre feed', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts || _feed.isEmpty) return;
    _isLoadingMore = true;

    try {
      final lastPostId = _feed.last;

      // Get the timestamp of the last post
      final lastPostDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(lastPostId)
          .get();

      if (!lastPostDoc.exists) {
        _hasMorePosts = false;
        _isLoadingMore = false;
        return;
      }

      final lastTimestamp = lastPostDoc.data()?['timestamp'];
      if (lastTimestamp == null) {
        _hasMorePosts = false;
        _isLoadingMore = false;
        return;
      }

      // Load more posts
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('space', isEqualTo: widget.spaceId)
          .orderBy('timestamp', descending: true)
          .startAfter([lastTimestamp])
          .limit(_postsPerPage)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final newPostIds = snapshot.docs
            .where((doc) {
              final data = doc.data();
              return data['uploading'] != true;
            })
            .map((e) => e.id)
            .toList();

        if (mounted && newPostIds.isNotEmpty) {
          setState(() {
            _feed.addAll(newPostIds);
            _hasMorePosts = snapshot.docs.length >= _postsPerPage;
          });
        } else {
          _hasMorePosts = false;
        }
      } else {
        _hasMorePosts = false;
      }
    } catch (e) {
      AppLogger.e('Error loading more posts in embedded theatre', error: e);
    } finally {
      _isLoadingMore = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      await _loadFeed();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _toggleChatDrawer() {
    HapticFeedback.lightImpact();
    setState(() {
      _isChatDrawerOpen = !_isChatDrawerOpen;
    });
  }

  void _closeChatDrawer() {
    setState(() {
      _isChatDrawerOpen = false;
    });
  }

  void _toggleGridView() {
    HapticFeedback.lightImpact();
    setState(() {
      _gridViewOn = !_gridViewOn;
    });
  }

  void _openSettings() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => EditSpace(space: widget.spaceId),
      ),
    );
  }

  void _shareGram() {
    HapticFeedback.lightImpact();
    ShareService.shareSpace(
      context: context,
      spaceId: widget.spaceId,
      spaceName: widget.space?.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldColor =
        isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor;

    return Container(
      color: scaffoldColor,
      child: Row(
        children: [
          // Main content area (posts or grid)
          Expanded(
            child: Column(
              children: [
                // Header
                if (widget.showHeader) _buildHeader(isDark),

                // Posts content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: AppTheme.primaryColor,
                    child: _gridViewOn
                        ? _buildGridView()
                        : _buildPostsList(isDark),
                  ),
                ),
              ],
            ),
          ),

          // Sliding chat drawer
          _buildChatDrawer(isDark),
        ],
      ),
    );
  }

  static const double _theatreHeaderRowHeight = 56.0;

  Widget _buildHeader(bool isDark) {
    final topInset = MediaQuery.of(context).padding.top;
    final headerHeight = topInset +
        AppHeaderStyle.wideLayoutHeaderTitleTopPadding +
        _theatreHeaderRowHeight +
        10;
    final headerBase = isDark ? AppTheme.cardDarkColor : Colors.white;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      height: headerHeight,
      decoration: BoxDecoration(
        color: headerBase,
        border: Border(
          bottom: BorderSide(color: dividerColor, width: 1),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: topInset + AppHeaderStyle.wideLayoutHeaderTitleTopPadding,
            left: 0,
            right: 0,
            height: _theatreHeaderRowHeight,
            child: Row(
              children: [
                // Gram picture
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: GestureDetector(
                    onTap: _openSettings,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      child: GramPicture(
                        displayPicture: widget.space?.displayPicture,
                        size: 36,
                        spaceId: widget.spaceId,
                        borderRadius: 8,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: AppDimensions.spacingMd),

                // Gram name
                Expanded(
                  child: Text(
                    widget.space?.name ?? 'Gram',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Action buttons (uniform 40x40 tap target, icon 22)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Grid toggle button
                    _buildHeaderButton(
                      icon: _gridViewOn
                          ? CupertinoIcons.list_bullet
                          : CupertinoIcons.square_grid_2x2,
                      onTap: _toggleGridView,
                      tooltip: _gridViewOn ? 'List View' : 'Grid View',
                    ),

                    // Chat button (toggles drawer)
                    _buildHeaderButton(
                      icon: _isChatDrawerOpen
                          ? CupertinoIcons.chat_bubble_fill
                          : CupertinoIcons.chat_bubble,
                      onTap: _toggleChatDrawer,
                      isActive: _isChatDrawerOpen,
                      tooltip: _isChatDrawerOpen ? 'Close Chat' : 'Open Chat',
                    ),

                    // Group call button (same color as other header icons)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: GroupCallButton(
                          spaceId: widget.spaceId,
                          spaceName: widget.space?.name ?? 'Group Call',
                          size: 22,
                          iconColor:
                              AppTheme.primaryColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),

                    // Share button
                    _buildHeaderButton(
                      icon: Icons.open_in_new_rounded,
                      onTap: _shareGram,
                      tooltip: 'Share',
                    ),

                    // Settings button
                    _buildHeaderButton(
                      icon: CupertinoIcons.settings,
                      onTap: _openSettings,
                      tooltip: 'Settings',
                    ),

                    const SizedBox(width: AppDimensions.spacingSm),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const double _headerButtonSize = 40.0;
  static const double _headerIconSize = 22.0;

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
    bool isActive = false,
    required String tooltip,
  }) {
    return SizedBox(
      width: _headerButtonSize,
      height: _headerButtonSize,
      child: IconButton(
        onPressed: isLoading ? null : onTap,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: isLoading
            ? AppLoadingIndicator(
                size: _headerIconSize,
                strokeWidth: 2,
              )
            : Icon(
                icon,
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.7),
                size: _headerIconSize,
              ),
        tooltip: tooltip,
      ),
    );
  }

  /// Sliding chat drawer that appears from the right
  Widget _buildChatDrawer(bool isDark) {
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: _isChatDrawerOpen ? _chatDrawerWidth : 0,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: _chatDrawerWidth,
          minWidth: _chatDrawerWidth,
          child: Container(
            width: _chatDrawerWidth,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkColor : Colors.white,
              border: Border(
                left: BorderSide(color: dividerColor, width: 1),
              ),
            ),
            child: _isChatDrawerOpen
                ? EmbeddedChatView(
                    key: ValueKey('chat_${widget.spaceId}'),
                    spaceId: widget.spaceId,
                    space: widget.space,
                    onBack: _closeChatDrawer,
                    showHeader: true,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildGridView() {
    return GridSpaceView(
      rid: widget.spaceId,
      setPageView: (int pageIndex) {
        // Could be used to navigate to a specific post
      },
    );
  }

  Widget _buildPostsList(bool isDark) {
    // Loading state
    if (_isLoading && _feed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CupertinoActivityIndicator(radius: 14),
              const SizedBox(height: AppDimensions.spacingLg),
              Text(
                'Loading posts...',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (_feed.isEmpty) {
      return _buildEmptyState(isDark);
    }

    // Posts list
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: _feed.length + (_hasMorePosts ? 1 : 0),
      cacheExtent: 800,
      itemBuilder: (context, index) {
        // Loading indicator at end
        if (index == _feed.length) {
          return _hasMorePosts
              ? const PaginationLoader()
              : const SizedBox(height: AppDimensions.spacingHero);
        }

        final postId = _feed[index];

        return RepaintBoundary(
          child: Column(
            children: [
              // The post with PostSwitcher
              PostSwitcher(
                key: ValueKey(postId),
                postId: postId,
                itemIndex: index,
                onOpenThread: (id) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ThreadView(postId: id),
                  ),
                ),
                enableVideoAutoplay: false,
              ),

              // Separator between posts
              if (index < _feed.length - 1)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          isDark
                              ? AppTheme.primaryColor.withValues(alpha: 0.4)
                              : AppTheme.primaryColor.withValues(alpha: 0.25),
                          isDark
                              ? AppTheme.primaryColor.withValues(alpha: 0.4)
                              : AppTheme.primaryColor.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.15, 0.85, 1.0],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.photo_on_rectangle,
              size: 64,
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              'No posts yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? AppTheme.textDarkColor : AppTheme.textLightColor,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Be the first to share something!',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppTheme.textSecondaryDarkColor
                    : AppTheme.textSecondaryLightColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
