// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// Package imports:
import 'package:cloud_firestore/cloud_firestore.dart';

// Project imports:
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/widgets/posts/orignal.dart';
import 'package:aurogram/widgets/posts/post.dart';
import 'package:aurogram/widgets/posts/reply.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

class PostSwitcher extends StatefulWidget {
  final String postId;
  final int itemIndex;

  const PostSwitcher({Key? key, required this.postId, required this.itemIndex})
      : super(key: key);

  @override
  _PostSwitcherState createState() => _PostSwitcherState();
}

class _PostSwitcherState extends State<PostSwitcher> 
    with AutomaticKeepAliveClientMixin {
  QuerySnapshot? _repliesDocuments;
  int _replyCount = 0;
  int _mainPostIndex = 0;
  List<_PageData> _pageData = [];
  bool _hasError = false;
  bool _isLoading = true;
  
  // Scroll controller
  final ScrollController _scrollController = ScrollController();
  
  // Target scroll offset - set in _populatePages, applied in build
  double _targetScrollOffset = 0.0;
  
  // Track if scroll offset has been applied for thread views
  bool _scrollApplied = false;
  
  // Scroll progress: -1.0 = fully on parents, 0.0 = at main, 1.0 = fully on replies
  double _scrollProgress = 0.0;
  
  // Card dimensions for scroll calculations
  double _cardWidth = 0.0;
  double _maxScrollToParents = 0.0;
  double _maxScrollToReplies = 0.0;
  
  @override
  bool get wantKeepAlive => true; // Keep state when scrolling

  @override
  void initState() {
    super.initState();
    
    // Listen to scroll changes for indicator animations
    _scrollController.addListener(_onScrollChanged);
    
    if (locator<PostDbService>().isPostKnownMissing(widget.postId)) {
      _hasError = true;
      _isLoading = false;
      _pageData = [];
      return;
    }
    _populatePages(widget.postId);
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }
  
  /// Track scroll position to animate indicators - updates immediately for responsiveness
  void _onScrollChanged() {
    if (!mounted || !_scrollController.hasClients) return;
    
    final offset = _scrollController.offset;
    final mainOffset = _targetScrollOffset; // Where main post starts
    
    double progress = 0.0;
    
    if (offset < mainOffset && _maxScrollToParents > 0) {
      // Scrolling toward parents (left)
      progress = -((mainOffset - offset) / _maxScrollToParents).clamp(0.0, 1.0);
    } else if (offset > mainOffset && _maxScrollToReplies > 0) {
      // Scrolling toward replies (right)
      progress = ((offset - mainOffset) / _maxScrollToReplies).clamp(0.0, 1.0);
    }
    
    // Update immediately - no threshold delay
    if (progress != _scrollProgress) {
      setState(() {
        _scrollProgress = progress;
      });
    }
  }

  Future<void> _populatePages(String postId) async {
    List<_PageData> tempPageData = [];

    try {
      if (locator<PostDbService>().isPostKnownMissing(postId)) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
            _pageData = [];
          });
        }
        return;
      }

      DocumentSnapshot? mainPost = await locator<PostDbService>().getPost(postId);
      if (!mainPost.exists) {
        locator<PostDbService>().markPostAsMissing(postId);
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
            _pageData = [];
          });
        }
        return;
      }

      final Map<String, dynamic>? postData = mainPost.data() as Map<String, dynamic>?;
      if (postData == null || postData['timestamp'] == null || postData['author'] == null) {
        locator<PostDbService>().markPostAsMissing(postId);
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
            _pageData = [];
          });
        }
        return;
      }

      _repliesDocuments = await locator<PostDbService>().getPostReplies(postId);
      _replyCount = _repliesDocuments?.docs.length ?? 0;

      // Order: ORIGINALS (LEFT) -> MAIN (CENTER) -> REPLIES (RIGHT)
      
      // First, collect originals (will be reversed later)
      List<_PageData> originals = [];
      await _collectOriginals(postId, originals);
      
      // Add originals in reverse order (oldest first, closest to main last)
      tempPageData.addAll(originals.reversed);

      // Add main post
      final mainContentType = _getContentType(postData);
      tempPageData.add(_PageData(
        id: postId,
        type: _PageType.main,
        contentType: mainContentType,
      ));

      // Add replies (they come after main, to the right)
      for (final element in _repliesDocuments?.docs ?? []) {
        final replyData = await locator<PostDbService>().getPost(element.id);
        final contentType = _getContentType(replyData.data() as Map<String, dynamic>?);
        tempPageData.add(_PageData(
          id: element.id,
          type: _PageType.reply,
          contentType: contentType,
        ));
      }

      if (mounted) {
        // Main post index = number of originals (they come first now)
        final originalsCount = tempPageData.where((p) => p.type == _PageType.original).length;
        final repliesCount = tempPageData.where((p) => p.type == _PageType.reply).length;
        
        // Calculate initial scroll offset to show main post
        final screenWidth = MediaQuery.of(context).size.width;
        final cardWidth = (screenWidth - 32).clamp(0.0, 500.0);
        // Gap between cards: chevron padding (6*2) + icon (12) = 24
        const cardGap = 24.0;
        final initialOffset = originalsCount > 0 ? originalsCount * (cardWidth + cardGap) : 0.0;
        
        // Store dimensions for scroll progress calculation
        _cardWidth = cardWidth;
        _maxScrollToParents = originalsCount > 0 ? originalsCount * (cardWidth + cardGap) : 0.0;
        _maxScrollToReplies = repliesCount > 0 ? repliesCount * (cardWidth + cardGap) : 0.0;
        
        // Store target offset - will be applied via jumpTo after build
        _targetScrollOffset = initialOffset;
        
        // Reset scroll state
        _scrollApplied = false;
        _scrollProgress = 0.0;
        
        setState(() {
          _pageData = tempPageData;
          _mainPostIndex = originalsCount;
          _hasError = false;
          _isLoading = false;
        });
        
        // Apply scroll position after build (for thread views)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _applyScrollOffset();
        });
      }
    } catch (e) {
      if (e.toString().toLowerCase().contains('timeout')) return;
      if (e.toString().contains('Post not found') || e.toString().contains('Post incomplete')) {
        locator<PostDbService>().markPostAsMissing(postId);
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
            _pageData = [];
          });
        }
        return;
      }
      AppLogger.e('Error in _populatePages', category: LogCategory.general, data: {'error': e.toString(), 'postId': widget.postId});
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _pageData = [];
        });
      }
    }
  }

  /// Determine content type from post data
  _ContentType _getContentType(Map<String, dynamic>? data) {
    if (data == null) return _ContentType.text;
    
    // Handle postType being stored as either int or String
    final postTypeValue = data['postType'];
    int postType = 0;
    if (postTypeValue is int) {
      postType = postTypeValue;
    } else if (postTypeValue is String) {
      postType = int.tryParse(postTypeValue) ?? 0;
    }
    
    switch (postType) {
      case 0: return _ContentType.video;
      case 1: return _ContentType.text;
      case 2: return _ContentType.audio;
      default: return _ContentType.text;
    }
  }

  /// Collect original posts (parent thread) recursively
  Future<void> _collectOriginals(String postId, List<_PageData> originals) async {
    try {
      DocumentSnapshot? postDocuments = await locator<PostDbService>().getPost(postId);
      if (!postDocuments.exists) return;

      final Map<String, dynamic>? postData = postDocuments.data() as Map<String, dynamic>?;
      final String? replyTo = postData?['replyTo'] as String?;
      if (replyTo == null || replyTo.isEmpty) return;

      final originalData = await locator<PostDbService>().getPost(replyTo);
      final contentType = _getContentType(originalData.data() as Map<String, dynamic>?);
      
      originals.add(_PageData(
        id: replyTo,
        type: _PageType.original,
        contentType: contentType,
      ));

      await _collectOriginals(replyTo, originals);
    } catch (e) {
      AppLogger.e('Error in _collectOriginals', category: LogCategory.general, data: {'error': e.toString(), 'postId': postId});
    }
  }

  void _onReplySelected(String postId) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    await _populatePages(postId);
  }
  
  /// Apply scroll offset for thread views - called after build
  void _applyScrollOffset() {
    if (!mounted || _scrollApplied) return;
    
    if (_scrollController.hasClients) {
      try {
        if (_scrollController.position.hasContentDimensions) {
          _scrollController.jumpTo(_targetScrollOffset);
          _scrollApplied = true;
        } else {
          // Content not ready yet - schedule another attempt
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_scrollApplied) _applyScrollOffset();
          });
        }
      } catch (e) {
        _scrollApplied = true; // Avoid infinite retries
      }
    }
  }

  Widget _buildPage(_PageData pageData) {
    switch (pageData.type) {
      case _PageType.reply:
        return Reply(
          post: pageData.id,
          onReplySelected: _onReplySelected,
          key: ValueKey('reply_${pageData.id}'),
        );
      case _PageType.main:
        return Post(
          post: pageData.id,
          itemIndex: widget.itemIndex,
          onReplySelected: _onReplySelected,
          key: ValueKey('post_${pageData.id}'),
        );
      case _PageType.original:
        return Orignal(
          post: pageData.id,
          onReplySelected: _onReplySelected,
          key: ValueKey('original_${pageData.id}'),
        );
    }
  }

  Widget _currentStack() {
    // Theme-aware colors - calculated first for both loading and loaded states
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    const double absoluteMaxWidth = 500.0;
    final cardWidth = (screenWidth - 32).clamp(0.0, absoluteMaxWidth);
    
    // Card colors
    final mainCardColor = isDark 
        ? AppTheme.cardDarkColor 
        : Colors.white;
    final originalCardColor = isDark 
        ? const Color(0xFF3D3428)
        : const Color(0xFFF5ECD7);
    final replyCardColor = isDark 
        ? const Color(0xFF2D2820)
        : const Color(0xFFFAF7F2);
    
    // Accent colors
    final originalAccent = isDark ? AppTheme.primaryLightColor : AppTheme.primaryDarkColor;
    final replyAccent = AppTheme.primaryColor;
    
    // More visible placeholder colors for clear skeleton structure
    final placeholder = isDark 
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8E0D5); // Warm beige
    final placeholderDark = isDark 
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFD8CFC2); // Darker beige

    // Error state - minimal, clean
    if (_hasError) {
      return const SizedBox.shrink();
    }

    // Use AnimatedSwitcher for smooth cross-fade between skeleton and content
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildContent(
        isLoading: _isLoading && _pageData.isEmpty,
        cardWidth: cardWidth,
        mainCardColor: mainCardColor,
        originalCardColor: originalCardColor,
        replyCardColor: replyCardColor,
        originalAccent: originalAccent,
        replyAccent: replyAccent,
        placeholder: placeholder,
        placeholderDark: placeholderDark,
        isDark: isDark,
      ),
    );
  }
  
  /// Build skeleton or actual content - used by AnimatedSwitcher
  Widget _buildContent({
    required bool isLoading,
    required double cardWidth,
    required Color mainCardColor,
    required Color originalCardColor,
    required Color replyCardColor,
    required Color originalAccent,
    required Color replyAccent,
    required Color placeholder,
    required Color placeholderDark,
    required bool isDark,
  }) {
    // Loading state - skeleton with unique key for AnimatedSwitcher
    if (isLoading) {
      return Padding(
        key: const ValueKey('skeleton'),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: Material(
            color: mainCardColor,
            elevation: isDark ? 2 : 1,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cardWidth),
              child: SizedBox(
                height: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header skeleton
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          ShimmerBox(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: placeholderDark,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerBox(
                                child: Container(
                                  width: 120,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: placeholderDark,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              ShimmerBox(
                                child: Container(
                                  width: 80,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: placeholder,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Content skeleton
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: ShimmerBox(
                          child: Container(
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Single post - with unique key for AnimatedSwitcher
    if (_pageData.length == 1) {
      return Padding(
        key: ValueKey('post_${_pageData.first.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: Material(
            color: mainCardColor,
            elevation: isDark ? 2 : 1,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cardWidth),
              child: _buildPage(_pageData.first),
            ),
          ),
        ),
      );
    }
    
    // Multi-post thread with unique key for AnimatedSwitcher
    final hasReplies = _replyCount > 0;
    final originalsCount = _pageData.where((p) => p.type == _PageType.original).length;
    final hasOriginals = originalsCount > 0;
    final showIndicators = hasOriginals || hasReplies;
    
    // Unique key for thread view
    final scrollKey = ValueKey('scroll_${widget.itemIndex}_${widget.postId}_${_pageData.length}_$_mainPostIndex');
    
    return Column(
      key: ValueKey('thread_${widget.postId}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Horizontal scrolling thread
        SingleChildScrollView(
          key: scrollKey,
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: _buildThreadCardsWithIndicators(
              cardWidth: cardWidth,
              replyCardColor: replyCardColor,
              mainCardColor: mainCardColor,
              originalCardColor: originalCardColor,
              replyAccent: replyAccent,
              originalAccent: originalAccent,
              hasOriginals: hasOriginals,
              hasReplies: hasReplies,
            ),
          ),
        ),
        
        // Animated indicator row - below cards, properly aligned
        if (showIndicators)
          _buildIndicatorRow(
            hasOriginals: hasOriginals,
            hasReplies: hasReplies,
            originalsCount: originalsCount,
            originalAccent: originalAccent,
            replyAccent: replyAccent,
            isDark: isDark,
            cardWidth: cardWidth,
          ),
      ],
    );
  }
  
  /// Build animated indicator row that responds to scroll position
  Widget _buildIndicatorRow({
    required bool hasOriginals,
    required bool hasReplies,
    required int originalsCount,
    required Color originalAccent,
    required Color replyAccent,
    required bool isDark,
    required double cardWidth,
  }) {
    // Calculate which card is currently visible based on scroll progress
    // _scrollProgress: -1 = all the way to oldest parent, 0 = main, +1 = all the way to last reply
    
    // Calculate current position in parents/replies
    int currentParentIndex = 0; // 0 = closest to main, originalsCount-1 = oldest
    int currentReplyIndex = 0;  // 0 = first reply, _replyCount-1 = last reply
    int remainingParents = originalsCount;
    int remainingReplies = _replyCount;
    
    if (_scrollProgress < 0 && originalsCount > 0) {
      // Viewing parents - calculate which one
      final progress = -_scrollProgress; // 0 to 1
      currentParentIndex = (progress * originalsCount).floor().clamp(0, originalsCount - 1);
      remainingParents = originalsCount - currentParentIndex - 1;
    }
    
    if (_scrollProgress > 0 && _replyCount > 0) {
      // Viewing replies - calculate which one
      currentReplyIndex = (_scrollProgress * _replyCount).floor().clamp(0, _replyCount - 1);
      remainingReplies = _replyCount - currentReplyIndex - 1;
    }
    
    // Calculate opacity and alignment based on scroll progress
    // At center (0): both visible at edges
    // Scrolling left (-1): parents centered and expanded, replies fade out
    // Scrolling right (+1): replies centered and expanded, parents fade out
    
    final parentsOpacity = hasOriginals 
        ? (_scrollProgress >= 0 ? 1.0 - _scrollProgress : 1.0).clamp(0.0, 1.0) 
        : 0.0;
    final repliesOpacity = hasReplies 
        ? (_scrollProgress <= 0 ? 1.0 + _scrollProgress : 1.0).clamp(0.0, 1.0) 
        : 0.0;
    
    // When scrolling toward one side, center that indicator
    // -1 = parents centered, 0 = edges, +1 = replies centered
    final parentsAlignment = _scrollProgress < 0 
        ? Alignment.lerp(Alignment.centerLeft, Alignment.center, -_scrollProgress)!
        : Alignment.centerLeft;
    final repliesAlignment = _scrollProgress > 0 
        ? Alignment.lerp(Alignment.centerRight, Alignment.center, _scrollProgress)!
        : Alignment.centerRight;
    
    // Expand indicator when scrolled into that section
    final parentsExpanded = _scrollProgress < -0.3;
    final repliesExpanded = _scrollProgress > 0.3;
    
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cardWidth),
        child: SizedBox(
          height: 32,
          child: Stack(
            children: [
              // Thread indicator (left side, or centered when scrolling left)
              if (hasOriginals)
                AnimatedAlign(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  alignment: parentsAlignment,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 80),
                    opacity: parentsOpacity,
                    child: _buildParentsIndicator(
                      originalAccent, 
                      isDark, 
                      totalCount: originalsCount,
                      currentIndex: currentParentIndex,
                      remaining: remainingParents,
                      expanded: parentsExpanded,
                    ),
                  ),
                ),
              
              // Replies indicator (right side, or centered when scrolling right)
              if (hasReplies)
                AnimatedAlign(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  alignment: repliesAlignment,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 80),
                    opacity: repliesOpacity,
                    child: _buildRepliesIndicator(
                      replyAccent, 
                      isDark,
                      totalCount: _replyCount,
                      currentIndex: currentReplyIndex,
                      remaining: remainingReplies,
                      expanded: repliesExpanded,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build animated indicator showing thread/context posts exist to the left
  Widget _buildParentsIndicator(
    Color accentColor, 
    bool isDark, {
    required int totalCount,
    required int currentIndex,
    required int remaining,
    bool expanded = false,
  }) {
    // Contextual label
    String label;
    if (expanded) {
      if (remaining > 0) {
        label = '$remaining more';
      } else {
        label = 'Original';
      }
    } else {
      label = 'Thread · $totalCount';
    }
    
    // Use primary color
    final textColor = isDark
        ? AppTheme.primaryLightColor.withValues(alpha: expanded ? 1.0 : 0.7)
        : AppTheme.primaryColor.withValues(alpha: expanded ? 1.0 : 0.7);
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 12 : 8,
        vertical: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chevron
          if (!expanded || remaining > 0)
            Icon(
              CupertinoIcons.chevron_left,
              size: expanded ? 14 : 12,
              color: textColor,
            ),
          if (!expanded || remaining > 0)
            SizedBox(width: expanded ? 4 : 2),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: expanded ? 13 : 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build animated indicator showing replies exist to the right
  Widget _buildRepliesIndicator(
    Color accentColor, 
    bool isDark, {
    required int totalCount,
    required int currentIndex,
    required int remaining,
    bool expanded = false,
  }) {
    // Contextual label
    String label;
    if (expanded) {
      if (remaining > 0) {
        label = '$remaining more';
      } else {
        label = 'Latest';
      }
    } else {
      label = '$totalCount ${totalCount == 1 ? 'reply' : 'replies'}';
    }
    
    // Use primary color
    final textColor = isDark
        ? AppTheme.primaryLightColor.withValues(alpha: expanded ? 1.0 : 0.7)
        : AppTheme.primaryColor.withValues(alpha: expanded ? 1.0 : 0.7);
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 12 : 8,
        vertical: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: expanded ? 13 : 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          // Chevron
          if (!expanded || remaining > 0)
            SizedBox(width: expanded ? 4 : 2),
          if (!expanded || remaining > 0)
            Icon(
              CupertinoIcons.chevron_right,
              size: expanded ? 14 : 12,
              color: textColor,
            ),
        ],
      ),
    );
  }

  /// Build thread cards with scroll indicators inline
  /// Order: ORIGINALS (LEFT) <- MAIN (CENTER) -> REPLIES (RIGHT)
  List<Widget> _buildThreadCardsWithIndicators({
    required double cardWidth,
    required Color replyCardColor,
    required Color mainCardColor,
    required Color originalCardColor,
    required Color replyAccent,
    required Color originalAccent,
    required bool hasOriginals,
    required bool hasReplies,
  }) {
    final List<Widget> items = [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    for (int i = 0; i < _pageData.length; i++) {
      final pageData = _pageData[i];
      final isReply = pageData.type == _PageType.reply;
      final isOriginal = pageData.type == _PageType.original;
      final isLast = i == _pageData.length - 1;
      final cardColor = isReply ? replyCardColor : (isOriginal ? originalCardColor : mainCardColor);
      
      items.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Material(
              color: cardColor,
              elevation: isDark ? 2 : 1,
              shadowColor: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: cardWidth,
                child: _buildPage(pageData),
              ),
            ),
          ],
        ),
      );
      
      // Chevron connector between cards (not at edges)
      if (!isLast) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              CupertinoIcons.chevron_right,
              size: 12,
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
            ),
          ),
        );
      }
    }
    
    return items;
  }
  

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return _currentStack();
  }
}

// Helper classes for page data
enum _PageType { reply, main, original }
enum _ContentType { video, text, audio }

class _PageData {
  final String id;
  final _PageType type;
  final _ContentType contentType;
  
  _PageData({
    required this.id,
    required this.type,
    required this.contentType,
  });
}
