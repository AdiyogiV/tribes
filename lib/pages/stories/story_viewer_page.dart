import 'dart:async';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:aurogram/models/story.dart';
import 'package:aurogram/services/story_service.dart';
import 'package:aurogram/pages/stories/widgets/story_progress_bar.dart';
import 'package:aurogram/pages/stories/widgets/story_top_bar.dart';
import 'package:aurogram/pages/stories/widgets/story_reply_box.dart';
import 'package:aurogram/pages/stories/widgets/story_see_post_button.dart';
import 'package:aurogram/pages/stories/widgets/story_views_section.dart';
import 'package:aurogram/pages/stories/widgets/story_slide_widgets.dart';
import 'package:aurogram/pages/stories/widgets/story_actions.dart';

/// Full-screen story viewer: vertical swipe = user, horizontal/tap = slide, progress bar, auto-advance.
class StoryViewerPage extends StatefulWidget {
  final List<String> userIds;
  final int initialUserIndex;

  const StoryViewerPage({
    super.key,
    required this.userIds,
    this.initialUserIndex = 0,
  });

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with TickerProviderStateMixin {
  final StoryService _storyService = StoryService();
  late int _userIndex;
  List<Story> _stories = [];
  int _slideIndex = 0;
  bool _loading = true;
  bool _paused = false;
  Timer? _autoAdvanceTimer;
  VideoPlayerController? _videoController;
  AnimationController? _progressController;

  // UI visibility state for interactive elements (header always visible)
  bool _showInteractiveUI = false;
  Timer? _uiHideTimer;

  // Reply box state (always visible like Instagram)
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  bool _keyboardVisible = false;
  bool _pausedByKeyboard = false; // Track if paused due to keyboard

  // Swipe gesture tracking
  double? _dragStartX;
  double? _dragStartY;
  double _swipeOffset = 0.0; // Current horizontal swipe offset
  double _verticalSwipeOffset = 0.0; // Current vertical swipe offset
  int? _swipeTargetUserIndex; // Target user index during swipe
  bool _isVerticalSwipe = false; // Track if current gesture is vertical
  bool _gestureDirectionLocked = false; // Lock direction once determined
  bool _isDismissing = false; // Track if dismissing to prevent timer navigation

  // View tracking: track which stories have been viewed in this session
  final Set<String> _viewedStoryIds = {};

  static Duration _durationForStory(Story story) {
    // Optimal durations based on UX research: 5s for images, 15s for videos
    return story.mediaType == StoryMediaType.video
        ? const Duration(seconds: 15)
        : const Duration(seconds: 5);
  }

  @override
  void initState() {
    super.initState();
    _userIndex = widget.initialUserIndex.clamp(0, widget.userIds.length - 1);
    _loadStories();
    _replyController.addListener(() { if (mounted) setState(() {}); });
    _replyFocusNode.addListener(_onReplyFocusChange);
  }

  void _onReplyFocusChange() {
    if (!mounted || _replyFocusNode.hasFocus || !_pausedByKeyboard) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (MediaQuery.of(context).viewInsets.bottom == 0 && _pausedByKeyboard) {
          _pausedByKeyboard = false;
          _onPauseHold(false);
        }
      });
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _uiHideTimer?.cancel();
    _progressController?.dispose();
    _progressController = null;
    _videoController?.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  void _togglePostButton() {
    final isPostCard = _stories.isNotEmpty &&
        _stories[_slideIndex].sourceType == 'post' &&
        _stories[_slideIndex].sourceId != null;

    if (!isPostCard) return;

    setState(() {
      _showInteractiveUI = !_showInteractiveUI;
    });

    // Pause/resume timer when button shows/hides
    if (_showInteractiveUI) {
      _onPauseHold(true); // Pause story
    } else {
      _onPauseHold(false); // Resume story
    }
  }

  void _hidePostButton() {
    if (_showInteractiveUI) {
      setState(() {
        _showInteractiveUI = false;
      });
      _onPauseHold(false); // Resume story
    }
  }

  void _startSegmentProgress() {
    _progressController?.dispose();
    _progressController = null;
    if (_slideIndex >= _stories.length) return;
    final story = _stories[_slideIndex];
    final duration = _durationForStory(story);
    _progressController = AnimationController(
      vsync: this,
      duration: duration,
    );
    if (!_paused) _progressController!.forward();
  }

  String get _currentUserId => widget.userIds[_userIndex];

  Future<void> _loadStories() async {
    setState(() => _loading = true);
    final list = await _storyService.getStoriesForUser(_currentUserId);
    if (!mounted) return;
    _stories = list;
    _slideIndex = 0;
    if (_stories.isNotEmpty) _precacheCurrentAndNext();
    if (!mounted) return;
    setState(() => _loading = false);
    if (_stories.isNotEmpty) {
      _progressController = AnimationController(
        vsync: this, duration: _durationForStory(_stories[0]), value: 0.0,
      );
    }
  }

  Future<void> _precacheCurrentAndNext() async {
    if (!mounted || _stories.isEmpty) return;
    final end = (_slideIndex + 3).clamp(0, _stories.length);
    for (var i = _slideIndex; i < end && mounted; i++) {
      final s = _stories[i];
      if (s.mediaType == StoryMediaType.image && s.mediaUrl.isNotEmpty) {
        try { await precacheImage(CachedNetworkImageProvider(s.mediaUrl), context); } catch (_) {}
      }
    }
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (_slideIndex >= _stories.length || _paused || _isDismissing) return;
    final story = _stories[_slideIndex];
    final duration = _durationForStory(story);
    _autoAdvanceTimer = Timer(duration, () {
      if (mounted && !_paused && !_isDismissing) _onNext();
    });
  }

  void _onStoryMediaReady() {
    if (!mounted || _loading || _stories.isEmpty) return;
    final story = _stories[_slideIndex];
    if (!_viewedStoryIds.contains(story.id)) {
      _viewedStoryIds.add(story.id);
      _storyService.trackStoryView(userId: _currentUserId, storyId: story.id);
    }
    if (story.mediaType == StoryMediaType.image) {
      if (_progressController == null) {
        _progressController = AnimationController(
          vsync: this, duration: _durationForStory(story), value: 0.0,
        );
      } else {
        _progressController!.reset();
      }
      if (!_paused) _progressController!.forward();
      _startAutoAdvance();
    }
  }

  void _resetProgressForSlide() {
    final story = _stories[_slideIndex];
    _progressController?.dispose();
    _progressController = AnimationController(
      vsync: this, duration: _durationForStory(story), value: 0.0,
    );
  }

  void _stopAllPlayback() {
    _autoAdvanceTimer?.cancel();
    _progressController?.stop();
    _progressController?.reset();
    _videoController?.pause();
  }

  void _onNext() {
    _stopAllPlayback();
    if (_slideIndex < _stories.length - 1) {
      setState(() => _slideIndex++);
      _precacheCurrentAndNext();
      _resetProgressForSlide();
    } else {
      _markCurrentUserViewed();
      if (_userIndex < widget.userIds.length - 1) {
        setState(() { _userIndex++; _slideIndex = 0; });
        _loadStories();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  void _onPrev() {
    _stopAllPlayback();
    if (_slideIndex > 0) {
      setState(() => _slideIndex--);
      _resetProgressForSlide();
    } else if (_userIndex > 0) {
      setState(() => _userIndex--);
      _loadStories().then((_) {
        if (mounted && _stories.isNotEmpty) {
          setState(() => _slideIndex = _stories.length - 1);
        }
      });
    }
  }

  void _markCurrentUserViewed() {
    _storyService.markStoriesViewedForUser(_currentUserId);
  }

  void _resetSwipe() => setState(() {
    _swipeOffset = 0.0; _verticalSwipeOffset = 0.0;
    _swipeTargetUserIndex = null; _isVerticalSwipe = false;
    _gestureDirectionLocked = false; _isDismissing = false;
  });

  void _onPauseHold(bool pause) {
    if (_paused == pause) return;
    setState(() => _paused = pause);
    if (pause) {
      _autoAdvanceTimer?.cancel();
      _progressController?.stop();
      _videoController?.pause();
    } else {
      // Clear keyboard pause flag when resuming
      _pausedByKeyboard = false;
      _progressController?.forward();
      _videoController?.play();
      _startAutoAdvance();
    }
  }

  void _focusReplyBox() {
    final isOwnStory = FirebaseAuth.instance.currentUser?.uid == _currentUserId;
    if (isOwnStory) return;

    // Focus on text field - keyboard visibility listener will handle pausing
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _replyFocusNode.requestFocus();
      }
    });
  }

  void _unfocusReplyBox() {
    // Unfocus - this will dismiss keyboard
    // The focus listener will handle resuming when keyboard dismisses
    _replyFocusNode.unfocus();
  }

  Future<void> _sendReply() async {
    await sendStoryReply(
      context: context,
      authorUserId: _currentUserId,
      replyController: _replyController,
      replyFocusNode: _replyFocusNode,
    );
  }

  void _deleteCurrentStory() async {
    if (_stories.isEmpty || _slideIndex >= _stories.length) return;

    final result = await deleteStoryWithConfirmation(
      context: context,
      userId: _currentUserId,
      story: _stories[_slideIndex],
      storyService: _storyService,
    );

    if (result != true || !mounted) return;

    setState(() => _stories.removeAt(_slideIndex));
    if (_stories.isEmpty) { Navigator.of(context).pop(); return; }
    if (_slideIndex >= _stories.length) _slideIndex = _stories.length - 1;
    _progressController?.dispose();
    _progressController = null;
    _videoController?.dispose();
    _videoController = null;
    _startSegmentProgress();
    _startAutoAdvance();
  }

  // ── Gesture handlers ──────────────────────────────────────

  void _handleTapUp(TapUpDetails d) {
    if (_replyFocusNode.hasFocus) {
      final tapY = d.localPosition.dy;
      if (tapY < MediaQuery.of(context).size.height - 80.0) _unfocusReplyBox();
      return;
    }
    if (_showInteractiveUI) { _hidePostButton(); return; }

    final w = MediaQuery.of(context).size.width;
    final tapX = d.localPosition.dx;
    final isPostCard = _stories.isNotEmpty &&
        _stories[_slideIndex].sourceType == 'post' &&
        _stories[_slideIndex].sourceId != null;
    final isOwn = FirebaseAuth.instance.currentUser?.uid == _currentUserId;

    if (!_paused) {
      if (tapX < w * 0.33) {
        _onPrev();
      } else if (tapX > w * 0.66) {
        _onNext();
      } else if (isPostCard) {
        _togglePostButton();
      } else if (!isOwn) {
        _focusReplyBox();
      } else {
        _onPauseHold(!_paused);
      }
    }
  }

  void _handlePanStart(DragStartDetails d) {
    _dragStartX = d.globalPosition.dx;
    _dragStartY = d.globalPosition.dy;
    _swipeOffset = 0.0;
    _verticalSwipeOffset = 0.0;
    _swipeTargetUserIndex = null;
    _isVerticalSwipe = false;
    _gestureDirectionLocked = false;
    _isDismissing = false;
  }

  void _handlePanUpdate(DragUpdateDetails d) {
    if (_dragStartX == null || _dragStartY == null) return;
    final deltaX = d.globalPosition.dx - _dragStartX!;
    final deltaY = d.globalPosition.dy - _dragStartY!;

    if (!_gestureDirectionLocked && (deltaX.abs() > 20 || deltaY.abs() > 20)) {
      if (deltaY.abs() > deltaX.abs() * 1.2) {
        _isVerticalSwipe = true;
        _gestureDirectionLocked = true;
        _autoAdvanceTimer?.cancel();
        _progressController?.stop();
        _videoController?.pause();
        setState(() => _isDismissing = true);
      } else if (deltaX.abs() > deltaY.abs() * 1.2) {
        _isVerticalSwipe = false;
        _gestureDirectionLocked = true;
      }
    }

    if (_isVerticalSwipe && _gestureDirectionLocked) {
      if (deltaY > 0) {
        _verticalSwipeOffset = deltaY.clamp(0, MediaQuery.of(context).size.height);
        setState(() {});
      }
      return;
    }
    if (!_isVerticalSwipe && _gestureDirectionLocked) {
      final sw = MediaQuery.of(context).size.width;
      _swipeOffset = deltaX.clamp(-sw, sw);
      if (deltaX > 50 && _userIndex > 0) {
        _swipeTargetUserIndex = _userIndex - 1;
      } else if (deltaX < -50 && _userIndex < widget.userIds.length - 1) {
        _swipeTargetUserIndex = _userIndex + 1;
      } else {
        _swipeTargetUserIndex = null;
      }
      setState(() {});
    }
  }

  void _handlePanEnd(DragEndDetails d) {
    if (_dragStartX == null || _dragStartY == null) { _resetSwipe(); return; }
    final deltaX = d.globalPosition.dx - _dragStartX!;
    final deltaY = d.globalPosition.dy - _dragStartY!;
    final velocity = d.velocity.pixelsPerSecond;
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    if (_isVerticalSwipe && _gestureDirectionLocked) {
      if (deltaY > sh * 0.2 || velocity.dy > 500) {
        _autoAdvanceTimer?.cancel();
        _progressController?.stop();
        _videoController?.pause();
        _markCurrentUserViewed();
        Navigator.of(context).pop();
      } else {
        setState(() => _isDismissing = false);
        if (!_paused) {
          _progressController?.forward();
          _videoController?.play();
          _startAutoAdvance();
        }
        _resetSwipe();
      }
      return;
    }

    if (!_isVerticalSwipe && _gestureDirectionLocked) {
      if (deltaX.abs() > sw * 0.3 || velocity.dx.abs() > 500) {
        if (deltaX > 0 && _userIndex > 0) {
          _markCurrentUserViewed();
          setState(() { _userIndex--; _slideIndex = 0; });
          _loadStories();
        } else if (deltaX < 0 && _userIndex < widget.userIds.length - 1) {
          _markCurrentUserViewed();
          setState(() { _userIndex++; _slideIndex = 0; });
          _loadStories();
        } else {
          _resetSwipe();
        }
      } else {
        _resetSwipe();
      }
    } else {
      _resetSwipe();
    }
    _dragStartX = null;
    _dragStartY = null;
    _gestureDirectionLocked = false;
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isOwnStory = FirebaseAuth.instance.currentUser?.uid == _currentUserId;

    // Check keyboard visibility and pause/resume timer accordingly
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final keyboardIsVisible = keyboardHeight > 0;

    // Update keyboard visibility state and pause/resume if needed
    if (keyboardIsVisible != _keyboardVisible) {
      _keyboardVisible = keyboardIsVisible;

      if (!isOwnStory) {
        if (_keyboardVisible) {
          // Keyboard shown - pause story (only if not already paused manually)
          if (!_paused) {
            _pausedByKeyboard = true;
            _onPauseHold(true);
          }
        } else {
          // Keyboard hidden - resume story only if it was paused by keyboard
          if (_pausedByKeyboard && !_replyFocusNode.hasFocus) {
            _pausedByKeyboard = false;
            // Use post-frame callback to ensure state is updated
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _onPauseHold(false);
              }
            });
          }
        }
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.pitchBlack,
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          onTapUp: _handleTapUp,
          onLongPressStart: (_) => _onPauseHold(true),
          onLongPressEnd: (_) => _onPauseHold(false),
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Black background to ensure no grey shows through
              Positioned.fill(
                child: Container(
                    color: AppTheme.pitchBlack), // Explicit pitch black
              ),

              // Preview of next/previous user's story during swipe
              if (_swipeTargetUserIndex != null && _swipeOffset != 0)
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(
                      _swipeOffset > 0
                          ? -MediaQuery.of(context).size.width + _swipeOffset
                          : MediaQuery.of(context).size.width + _swipeOffset,
                      0,
                    ),
                    child: _buildSwipePreview(_swipeTargetUserIndex!),
                  ),
                ),

              // Current story with swipe transform
              if (_loading)
                Positioned.fill(
                  child: Container(
                    color: AppTheme.pitchBlack, // Explicit pitch black
                    child: const AppLoadingIndicator(color: Colors.white),
                  ),
                )
              else if (_stories.isEmpty)
                Positioned.fill(
                  child: Container(
                    color: AppTheme.pitchBlack, // Explicit pitch black
                    child: const Center(
                        child: Text('No stories',
                            style: TextStyle(color: Colors.white))),
                  ),
                )
              else
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(
                      _isVerticalSwipe
                          ? 0
                          : _swipeOffset, // Only horizontal offset for horizontal swipes
                      _isVerticalSwipe
                          ? _verticalSwipeOffset
                          : 0, // Only vertical offset for vertical swipes
                    ),
                    child: Opacity(
                      opacity: _isVerticalSwipe
                          ? (1.0 -
                              (_verticalSwipeOffset /
                                      MediaQuery.of(context).size.height)
                                  .clamp(0.0, 0.5))
                          : 1.0,
                      child: _buildSlide(_stories[_slideIndex]),
                    ),
                  ),
                ),

              // Top gradient overlay for better text readability
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    _isVerticalSwipe ? _verticalSwipeOffset : 0,
                  ),
                  child: IgnorePointer(
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.5),
                              Colors.black.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Top UI (progress bar + header) - always visible
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    _isVerticalSwipe ? _verticalSwipeOffset : 0,
                  ),
                  child: Opacity(
                    opacity: _isVerticalSwipe
                        ? (1.0 -
                            (_verticalSwipeOffset /
                                    MediaQuery.of(context).size.height)
                                .clamp(0.0, 0.5))
                        : 1.0,
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_stories.isNotEmpty &&
                              _progressController != null)
                            AnimatedBuilder(
                              animation: _progressController!,
                              builder: (_, __) => StoryProgressBar(
                                storyCount: _stories.length,
                                currentIndex: _slideIndex,
                                progressController: _progressController,
                              ),
                            ),
                          StoryTopBar(
                            userId: _currentUserId,
                            isOwnStory: isOwnStory,
                            hasStories: _stories.isNotEmpty,
                            onDelete: _deleteCurrentStory,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // "See post" button for shared posts - centered on post card
              if (!_loading &&
                  _stories.isNotEmpty &&
                  _stories[_slideIndex].sourceType == 'post' &&
                  _stories[_slideIndex].sourceId != null)
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      _isVerticalSwipe ? _verticalSwipeOffset : 0,
                    ),
                    child: StorySeePostButton(
                      postId: _stories[_slideIndex].sourceId!,
                      isVisible: _showInteractiveUI,
                      onHide: _hidePostButton,
                    ),
                  ),
                ),

              // Reply typing box at bottom (Instagram-style) - always visible
              if (!isOwnStory)
                Positioned(
                  bottom: MediaQuery.of(context)
                      .viewInsets
                      .bottom, // Move up with keyboard
                  left: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      _isVerticalSwipe ? _verticalSwipeOffset : 0,
                    ),
                    child: SafeArea(
                      top: false,
                      child: StoryReplyBox(
                        replyController: _replyController,
                        replyFocusNode: _replyFocusNode,
                        onSend: _sendReply,
                      ),
                    ),
                  ),
                ),

              // Views section at bottom for own stories (Instagram-style)
              if (isOwnStory && _stories.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      _isVerticalSwipe ? _verticalSwipeOffset : 0,
                    ),
                    child: Opacity(
                      opacity: _isVerticalSwipe
                          ? (1.0 -
                              (_verticalSwipeOffset /
                                      MediaQuery.of(context).size.height)
                                  .clamp(0.0, 0.5))
                          : 1.0,
                      child: SafeArea(
                        top: false,
                        child: StoryViewsSection(
                          userId: _currentUserId,
                          storyId: _stories[_slideIndex].id,
                          storyService: _storyService,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipePreview(int targetUserIndex) {
    if (targetUserIndex < 0 || targetUserIndex >= widget.userIds.length) {
      return Container(color: AppTheme.pitchBlack); // Explicit pitch black
    }

    final targetUserId = widget.userIds[targetUserIndex];

    return FutureBuilder<List<Story>>(
      future: _storyService.getStoriesForUser(targetUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
              color: AppTheme.pitchBlack); // Explicit pitch black
        }

        final previewStory = snapshot.data!.first;
        return _buildSlide(
            previewStory); // This will handle isPostCard detection
      },
    );
  }

  Widget _buildSlide(Story story) {
    if (story.mediaUrl.isEmpty) {
      return const Center(
        child: Icon(Icons.image_not_supported, color: Colors.white54, size: 64),
      );
    }
    if (story.mediaType == StoryMediaType.video) {
      if (!_viewedStoryIds.contains(story.id)) {
        _viewedStoryIds.add(story.id);
        _storyService.trackStoryView(userId: _currentUserId, storyId: story.id);
      }
      return StoryVideoSlide(
        url: story.mediaUrl,
        storyId: story.id,
        onInitialized: () {
          _startSegmentProgress();
          _startAutoAdvance();
        },
        controllerCallback: (c) {
          if (_videoController != c) {
            _videoController?.dispose();
            _videoController = c;
          }
        },
      );
    }
    final isPostCard = story.sourceType == 'post' && story.sourceId != null;
    return SizedBox.expand(
      child: RepaintBoundary(
        child: StoryImageSlide(
          storyId: story.id,
          imageUrl: story.mediaUrl,
          onReady: _onStoryMediaReady,
          isPostCard: isPostCard,
        ),
      ),
    );
  }
}
