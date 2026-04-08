import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/features/feed/presentation/pages/thread_view.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_switcher.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram_picture.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/config/call_ui_config.dart';
import 'package:aurogram/widgets/call/active_call_banner.dart';
import 'package:aurogram/features/calling/presentation/pages/group_call_screen.dart';
import 'package:aurogram/features/calling/domain/group_call_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Theatre - vertical scrolling post list for space or profile posts
/// Matches the Feed tab layout: vertical scroll with horizontal PostSwitcher for replies/originals
///
/// Supports two contexts:
/// - Space posts: When rid (spaceId) is provided
/// - Profile posts: When profileUserId is provided (and rid is null)
class Theatre extends StatefulWidget {
  final String? rid;
  final int? initpage;
  final String? postId;
  final Space? space;
  final VoidCallback? onRefresh;
  final VoidCallback? onToggleGridView;
  final VoidCallback? onOpenChat;
  final VoidCallback? onNavigateToSettings;
  final VoidCallback? onShare;
  final bool gridViewOn;

  /// For profile context - shows posts from a specific user's profile
  final String? profileUserId;

  const Theatre({
    super.key,
    this.rid,
    this.initpage,
    this.postId,
    this.space,
    this.onRefresh,
    this.onToggleGridView,
    this.onOpenChat,
    this.onNavigateToSettings,
    this.onShare,
    this.gridViewOn = false,
    this.profileUserId,
  });

  /// Check if this theatre is showing profile posts
  bool get isProfileContext => profileUserId != null && rid == null;

  @override
  TheatreState createState() => TheatreState();
}

class TheatreState extends State<Theatre> {
  User? user = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();

  List<String> _feed = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _showScrollToTop = false;

  static const int _postsPerPage = 15;
  static const double _scrollToTopThreshold = 1200;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFeed();
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

    // Show/hide scroll to top button
    final shouldShow =
        _scrollController.position.pixels > _scrollToTopThreshold;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadFeed() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _feed = [];
      _hasMorePosts = true;
    });

    try {
      QuerySnapshot snapshot;

      // Load posts based on context (space or profile)
      // Both use posts/ collection directly with contextId filter
      if (widget.isProfileContext && widget.profileUserId != null) {
        // Profile context - load user's profile posts
        snapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where('author', isEqualTo: widget.profileUserId)
            .where('contextType', isEqualTo: 'profile')
            .orderBy('timestamp', descending: true)
            .limit(_postsPerPage)
            .get();
      } else {
        // Space context - query posts/ directly with space field
        // This is the single source of truth (no spacePosts collection)
        // Use space field only (not contextType) to include legacy posts
        snapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where('space', isEqualTo: widget.rid)
            .orderBy('timestamp', descending: true)
            .limit(_postsPerPage)
            .get();
      }

      final postIds = snapshot.docs.map((e) => e.id).toList();

      // Handle navigation to a specific post
      if (widget.postId != null && widget.postId!.isNotEmpty) {
        int postIndex = postIds.indexOf(widget.postId!);

        if (postIndex == -1) {
          // Post not in current page, add it at the top
          postIds.insert(0, widget.postId!);
          AppLogger.d('Theatre postId not in feed, inserting at index 0',
              category: LogCategory.navigation,
              data: {'postId': widget.postId});
        }
      }

      // Posts from posts/ collection are already valid - no validation needed
      // Filter out uploading posts only
      final validIds = postIds.where((id) {
        // Find the document for this post ID
        final docIndex = snapshot.docs.indexWhere((d) => d.id == id);
        if (docIndex == -1) {
          // Post ID was manually inserted (e.g., from postId param), include it
          return true;
        }
        final data = snapshot.docs[docIndex].data() as Map<String, dynamic>?;
        return data?['uploading'] != true;
      }).toList();

      _hasMorePosts = snapshot.docs.length >= _postsPerPage;

      if (mounted) {
        setState(() {
          _feed = validIds;
          _isLoading = false;
        });

        // Determine which index to scroll to
        int scrollToIndex = -1;

        // Priority 1: Specific post ID
        if (widget.postId != null && widget.postId!.isNotEmpty) {
          scrollToIndex = _feed.indexOf(widget.postId!);
        }
        // Priority 2: initpage (from grid view selection)
        else if (widget.initpage != null &&
            widget.initpage! > 0 &&
            widget.initpage! < _feed.length) {
          scrollToIndex = widget.initpage!;
        }

        if (scrollToIndex > 0) {
          // Delay to allow layout to complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollController.hasClients) {
              // Approximate scroll position (estimated post height with separator)
              _scrollController.animateTo(
                scrollToIndex * 400.0, // Estimated post height with separator
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    } catch (e) {
      AppLogger.e('Error loading theatre feed', error: e);
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

      // Get the timestamp of the last post from main posts collection
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

      QuerySnapshot snapshot;

      // Load more based on context - both use posts/ collection
      if (widget.isProfileContext && widget.profileUserId != null) {
        // Profile context - load more profile posts
        snapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where('author', isEqualTo: widget.profileUserId)
            .where('contextType', isEqualTo: 'profile')
            .orderBy('timestamp', descending: true)
            .startAfter([lastTimestamp])
            .limit(_postsPerPage)
            .get();
      } else {
        // Space context - query posts/ directly with space field
        // Use space field only (not contextType) to include legacy posts
        snapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where('space', isEqualTo: widget.rid)
            .orderBy('timestamp', descending: true)
            .startAfter([lastTimestamp])
            .limit(_postsPerPage)
            .get();
      }

      if (snapshot.docs.isNotEmpty) {
        // Filter out uploading posts - posts from posts/ are already valid
        final newPostIds = snapshot.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return data?['uploading'] != true;
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
      AppLogger.e('Error loading more posts', error: e);
    } finally {
      _isLoadingMore = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      await _loadFeed();
      widget.onRefresh?.call();
    } finally {
      _isRefreshing = false;
    }
  }

  void _startGroupCall(String spaceName) {
    if (widget.rid == null) return;

    HapticFeedback.lightImpact();

    // Check if already in a call
    final groupCallService = GroupCallService();
    if (groupCallService.isInCall) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: AppDimensions.spacingMd),
              Text('Already in a call'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Navigate to group call screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupCallScreen(
          spaceId: widget.rid!,
          spaceName: spaceName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 700 : double.infinity,
              ),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                cacheExtent: 800,
                slivers: [
                  // Spacious header with space info
                  _buildSpaciousHeader(context, isDark),

                  // Active call banner for spaces (not profile context)
                  if (widget.rid != null && !widget.isProfileContext)
                    SliverToBoxAdapter(
                      child: ActiveCallBanner(
                        spaceId: widget.rid!,
                        spaceName: widget.space?.name ?? 'Group Call',
                      ),
                    ),

                  // Pull to refresh
                  CupertinoSliverRefreshControl(
                    onRefresh: _handleRefresh,
                  ),

                  // Loading state - single centered skeleton
                  if (_isLoading && _feed.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildSkeletonItem(context),
                    )
                  // Empty state
                  else if (_feed.isEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height - 200,
                        child: _buildEmptyState(context),
                      ),
                    )
                  // Posts list
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            // Loading indicator at end
                            if (index == _feed.length) {
                              return _hasMorePosts
                                  ? const PaginationLoader()
                                  : const SizedBox(height: AppDimensions.spacingHero);
                            }

                            final postId = _feed[index];
                            // Posts from posts/ collection are valid - PostSwitcher handles errors gracefully

                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;

                            return RepaintBoundary(
                              child: Column(
                                children: [
                                  // The post with PostSwitcher
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
                                    enableVideoAutoplay: false,
                                  ),

                                  // Separator between posts
                                  if (index < _feed.length - 1)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 16),
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(maxWidth: 500),
                                        height: 1,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              isDark
                                                  ? AppTheme.primaryColor
                                                      .withValues(alpha: 0.4)
                                                  : AppTheme.primaryColor
                                                      .withValues(alpha: 0.25),
                                              isDark
                                                  ? AppTheme.primaryColor
                                                      .withValues(alpha: 0.4)
                                                  : AppTheme.primaryColor
                                                      .withValues(alpha: 0.25),
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
                          childCount: _feed.length + (_hasMorePosts ? 1 : 0),
                          addAutomaticKeepAlives: true,
                          addRepaintBoundaries: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Scroll to top button
          Positioned(
            left: 0,
            right: 0,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: Center(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                offset: _showScrollToTop ? Offset.zero : const Offset(0, 2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _showScrollToTop ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showScrollToTop,
                    child: GestureDetector(
                      onTap: _scrollToTop,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.primaryColor.withValues(alpha: 0.9)
                              : AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_up,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a minimal header with space or profile info that scrolls up
  Widget _buildSpaciousHeader(BuildContext context, bool isDark) {
    final c = AppTheme.primaryColor;

    // Use minimal header for profile context
    if (widget.isProfileContext) {
      return _buildProfileHeader(context, isDark, c);
    }

    // Space context header
    return _buildSpaceHeader(context, isDark, c);
  }

  /// Minimal header for profile posts - just back button and title
  Widget _buildProfileHeader(BuildContext context, bool isDark, Color c) {
    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // Back button
              IconButton(
                icon:
                    Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: c),
                onPressed: () => Navigator.pop(context),
              ),
              // Centered title
              Expanded(
                child: Center(
                  child: Text(
                    'Posts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              // Refresh button only
              IconButton(
                icon: _isRefreshing
                    ? AppLoadingIndicator(
                        size: 18,
                        strokeWidth: 2,
                        color: c,
                      )
                    : Icon(CupertinoIcons.refresh, size: 20, color: c),
                onPressed: _isRefreshing ? null : _handleRefresh,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full header for space context with space info and action buttons
  Widget _buildSpaceHeader(BuildContext context, bool isDark, Color c) {
    final space = widget.space;
    const spacing = 20.0;

    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Back button + Title centered (like astro pages)
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
              child: Row(
                children: [
                  // Back button - simple, no elevation
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20, color: c),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  // Centered title in primary color
                  Expanded(
                    child: Center(
                      child: Text(
                        space?.name ?? 'Gram',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: c,
                          letterSpacing: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Spacer for symmetry
                  const SizedBox(width: 40),
                ],
              ),
            ),

            SizedBox(height: spacing - 8),

            // Row 2: Large round space picture - centered
            GestureDetector(
              onTap: widget.onNavigateToSettings,
              child: Material(
                elevation: 4,
                shape: const CircleBorder(),
                shadowColor: c.withValues(alpha: 0.3),
                child: ClipOval(
                  child: GramPicture(
                    displayPicture: space?.displayPicture,
                    size: 100,
                    borderRadius: 0,
                  ),
                ),
              ),
            ),

            SizedBox(height: spacing),

            // Row 3: Action buttons (including settings)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIconButton(
                    icon: CupertinoIcons.refresh,
                    onTap: _handleRefresh,
                    isDark: isDark,
                    isLoading: _isRefreshing,
                  ),
                  const SizedBox(width: AppDimensions.spacingLg),
                  _buildIconButton(
                    icon: widget.gridViewOn
                        ? CupertinoIcons.list_bullet
                        : CupertinoIcons.square_grid_2x2,
                    onTap: widget.onToggleGridView,
                    isDark: isDark,
                  ),
                  const SizedBox(width: AppDimensions.spacingLg),
                  _buildIconButton(
                    icon: CupertinoIcons.paperplane,
                    onTap: widget.onOpenChat,
                    isDark: isDark,
                  ),
                  // Group call button - icon turns green when call is active
                  if (widget.rid != null) ...[
                    const SizedBox(width: AppDimensions.spacingLg),
                    _buildCallButton(
                      spaceId: widget.rid!,
                      spaceName: space?.name ?? 'Group Call',
                      isDark: isDark,
                    ),
                  ],
                  const SizedBox(width: AppDimensions.spacingLg),
                  _buildIconButton(
                    icon: Icons.open_in_new_rounded,
                    onTap: widget.onShare,
                    isDark: isDark,
                  ),
                  const SizedBox(width: AppDimensions.spacingLg),
                  _buildIconButton(
                    icon: CupertinoIcons.settings,
                    onTap: widget.onNavigateToSettings,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            SizedBox(height: spacing),
          ],
        ),
      ),
    );
  }

  /// Build an icon button with elevation for the header
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isDark,
    bool isLoading = false,
  }) {
    return Material(
      color: isDark ? AppTheme.cardDarkColor : Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isLoading ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingSm),
            child: isLoading
                ? InlineShimmerLoader(size: 18)
                : Icon(
                    icon,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
          ),
        ),
      ),
    );
  }

  /// Build call button that changes color when call is active
  /// Works on all platforms (Agora SDK 6.x supports web)
  Widget _buildCallButton({
    required String spaceId,
    required String spaceName,
    required bool isDark,
  }) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('calls')
          .doc('active')
          .snapshots(),
      builder: (context, snapshot) {
        bool hasActiveCall = false;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final participants = data?['participants'] as List<dynamic>? ?? [];
          hasActiveCall = participants.isNotEmpty;
        }

        final iconColor =
            hasActiveCall ? AppTheme.activeGreen : AppTheme.primaryColor;

        return Material(
          color: isDark ? AppTheme.cardDarkColor : Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
          child: InkWell(
            onTap: () => _startGroupCall(spaceName),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.paddingSm),
              decoration: hasActiveCall
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                      border: Border.all(
                        color: AppTheme.activeGreen,
                        width: 2,
                      ),
                    )
                  : null,
              child: Icon(
                hasActiveCall
                    ? CallUIConfig.callActiveIcon
                    : CallUIConfig.callIcon,
                size: 18,
                color: iconColor,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Simple loading indicator
  Widget _buildSkeletonItem(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: CupertinoActivityIndicator(radius: 14),
      ),
    );
  }

  /// Empty state when no posts
  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isProfile = widget.isProfileContext;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isProfile
                  ? CupertinoIcons.person_crop_circle
                  : CupertinoIcons.photo_on_rectangle,
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
              isProfile
                  ? 'This profile has no posts'
                  : 'Be the first to share something!',
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
