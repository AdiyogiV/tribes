import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:aurogram/models/story.dart';
import 'package:aurogram/pages/thread_view.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/services/story_service.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/user_avatar.dart';

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
    AppLogger.i('StoryViewer: open', category: LogCategory.general, data: {
      'userIdsCount': widget.userIds.length,
      'initialUserIndex': widget.initialUserIndex,
      'resolvedUserIndex': _userIndex,
      'currentUserId': _currentUserId,
    });
    _loadStories();

    // Listen to text changes to update send button
    _replyController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    // Listen to focus changes to handle keyboard dismissal
    _replyFocusNode.addListener(_onReplyFocusChange);
  }

  void _onReplyFocusChange() {
    if (!mounted) return;

    // When focus is lost, check if keyboard is dismissed and resume if needed
    if (!_replyFocusNode.hasFocus && _pausedByKeyboard) {
      // Wait a bit for keyboard to dismiss, then check and resume
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        // Check keyboard state via MediaQuery in next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          if (keyboardHeight == 0 && _pausedByKeyboard) {
            // Keyboard is dismissed, resume story
            _pausedByKeyboard = false;
            _onPauseHold(false);
          }
        });
      });
    }
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
    if (mounted) {
      AppLogger.i('StoryViewer: _loadStories done',
          category: LogCategory.general,
          data: {
            'userId': _currentUserId,
            'count': list.length,
            'firstStoryId': list.isNotEmpty ? list.first.id : null,
            'firstMediaUrlLength':
                list.isNotEmpty ? list.first.mediaUrl.length : 0,
            'firstMediaUrlEmpty':
                list.isNotEmpty ? list.first.mediaUrl.isEmpty : null,
            'firstMediaType': list.isNotEmpty
                ? (list.first.mediaType == StoryMediaType.video
                    ? 'video'
                    : 'image')
                : null,
          });

      _stories = list;
      _slideIndex = 0;

      // Images should already be precached by StoryRing, but precache current as fallback
      if (_stories.isNotEmpty) {
        // Quick precache check (should be instant if already cached)
        _precacheCurrentAndNext();
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });

        // Initialize progress controller immediately for UI display (but don't start it)
        if (_stories.isNotEmpty) {
          final story = _stories[0];
          final duration = _durationForStory(story);
          _progressController = AnimationController(
            vsync: this,
            duration: duration,
            value: 0.0, // Start at 0
          );
        }
      }
    }
  }

  Future<void> _precacheCurrentAndNext() async {
    if (!mounted || _stories.isEmpty) return;

    // Precache current + next 2 stories for instant navigation
    final endIndex = (_slideIndex + 3).clamp(0, _stories.length);

    for (var i = _slideIndex; i < endIndex; i++) {
      if (!mounted) break;

      final story = _stories[i];
      if (story.mediaType == StoryMediaType.image &&
          story.mediaUrl.isNotEmpty) {
        try {
          await precacheImage(
              CachedNetworkImageProvider(story.mediaUrl), context);
        } catch (e) {
          // Silent fail
        }
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
    // Called when the current story's media is fully loaded and ready
    if (!mounted || _loading || _stories.isEmpty) return;
    final story = _stories[_slideIndex];

    // Track view (only once per story per session)
    if (!_viewedStoryIds.contains(story.id)) {
      _viewedStoryIds.add(story.id);
      _storyService.trackStoryView(
        userId: _currentUserId,
        storyId: story.id,
      );
    }

    if (story.mediaType == StoryMediaType.image) {
      // Ensure controller exists and is at 0, then start animation
      if (_progressController == null) {
        final duration = _durationForStory(story);
        _progressController = AnimationController(
          vsync: this,
          duration: duration,
          value: 0.0,
        );
      } else {
        // Reset to 0 if it was already started
        _progressController!.reset();
      }

      if (!_paused) {
        _progressController!.forward();
      }
      _startAutoAdvance();
    }
  }

  void _onNext() {
    _autoAdvanceTimer?.cancel();
    _progressController?.stop();
    _progressController?.reset();
    _videoController?.pause();
    if (_slideIndex < _stories.length - 1) {
      setState(() => _slideIndex++);

      // Precache next stories for instant navigation
      _precacheCurrentAndNext();

      // Reset progress controller for new slide (at 0, paused until image loads)
      final story = _stories[_slideIndex];
      final duration = _durationForStory(story);
      _progressController?.dispose();
      _progressController = AnimationController(
        vsync: this,
        duration: duration,
        value: 0.0,
      );
      // Image might already be cached, so check if we should start immediately
      if (story.mediaType == StoryMediaType.image) {
        // Will be started by _onStoryMediaReady when image loads
      }
    } else {
      _markCurrentUserViewed();
      if (_userIndex < widget.userIds.length - 1) {
        setState(() {
          _userIndex++;
          _slideIndex = 0;
        });
        _loadStories();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  void _onPrev() {
    _autoAdvanceTimer?.cancel();
    _progressController?.stop();
    _progressController?.reset();
    _videoController?.pause();
    if (_slideIndex > 0) {
      setState(() => _slideIndex--);

      // Reset progress controller for new slide (at 0, paused until image loads)
      final story = _stories[_slideIndex];
      final duration = _durationForStory(story);
      _progressController?.dispose();
      _progressController = AnimationController(
        vsync: this,
        duration: duration,
        value: 0.0,
      );
      // Image might already be cached, so check if we should start immediately
      if (story.mediaType == StoryMediaType.image) {
        // Will be started by _onStoryMediaReady when image loads
      }
    } else {
      if (_userIndex > 0) {
        setState(() => _userIndex--);
        _loadStories().then((_) {
          if (mounted && _stories.isNotEmpty) {
            setState(() => _slideIndex = _stories.length - 1);
            // DON'T start timer here - let image slide report when it's ready
          }
        });
      }
    }
  }

  void _markCurrentUserViewed() {
    _storyService.markStoriesViewedForUser(_currentUserId);
  }

  void _resetSwipe() {
    setState(() {
      _swipeOffset = 0.0;
      _verticalSwipeOffset = 0.0;
      _swipeTargetUserIndex = null;
      _isVerticalSwipe = false;
      _gestureDirectionLocked = false;
      _isDismissing = false;
    });
  }

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
    final message = _replyController.text.trim();
    if (message.isEmpty) return;

    final authorId = _currentUserId;
    try {
      final chatService = SpaceChatService();
      final conversationId = await chatService.createDirectMessage(authorId);

      // Send the message
      await chatService.sendTextMessage(
        conversationId,
        message,
      );

      // Clear input and unfocus (box stays visible)
      _replyController.clear();
      _unfocusReplyBox();

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply sent'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('Story reply: failed to send',
          category: LogCategory.general, error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send reply'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _deleteCurrentStory() async {
    if (_stories.isEmpty || _slideIndex >= _stories.length) return;

    final story = _stories[_slideIndex];

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Story'),
        content: const Text('Are you sure you want to delete this story?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Delete the story
    final success = await _storyService.deleteStory(
      userId: _currentUserId,
      storyId: story.id,
    );

    if (!mounted) return;

    if (success) {
      // Remove from local list
      setState(() {
        _stories.removeAt(_slideIndex);
      });

      // If no more stories, close viewer
      if (_stories.isEmpty) {
        Navigator.of(context).pop();
        return;
      }

      // Adjust index if needed
      if (_slideIndex >= _stories.length) {
        _slideIndex = _stories.length - 1;
      }

      // Reload current story
      _progressController?.dispose();
      _progressController = null;
      _videoController?.dispose();
      _videoController = null;

      _startSegmentProgress();
      _startAutoAdvance();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete story'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

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
        backgroundColor: const Color(0xFF000000), // Explicit pitch black
        resizeToAvoidBottomInset:
            false, // Prevent layout resize when keyboard appears
        body: GestureDetector(
          onTapUp: (d) {
            // If reply box is focused, unfocus on tap outside
            if (_replyFocusNode.hasFocus) {
              final tapY = d.localPosition.dy;
              final screenHeight = MediaQuery.of(context).size.height;
              final replyBoxHeight = 80.0; // Approximate reply box height

              // If tap is outside reply box area, unfocus it
              if (tapY < screenHeight - replyBoxHeight) {
                _unfocusReplyBox();
              }
              return;
            }

            // If button is showing, hide it and resume (tap outside button)
            if (_showInteractiveUI) {
              _hidePostButton();
              return;
            }

            final w = MediaQuery.of(context).size.width;
            final tapX = d.localPosition.dx;

            // Divide screen into three zones: left (0-33%), middle (33-66%), right (66-100%)
            final leftZone = w * 0.33;
            final rightZone = w * 0.66;

            final isPostCard = _stories.isNotEmpty &&
                _stories[_slideIndex].sourceType == 'post' &&
                _stories[_slideIndex].sourceId != null;

            final isOwnStory =
                FirebaseAuth.instance.currentUser?.uid == _currentUserId;

            if (!_paused) {
              if (tapX < leftZone) {
                // Left zone: previous story
                _onPrev();
              } else if (tapX > rightZone) {
                // Right zone: next story
                _onNext();
              } else {
                // Middle zone: show button for post cards, focus reply box for others' stories
                if (isPostCard) {
                  _togglePostButton();
                } else if (!isOwnStory) {
                  // Focus reply box for others' stories
                  _focusReplyBox();
                } else {
                  // Toggle pause for own stories
                  _onPauseHold(!_paused);
                }
              }
            }
          },
          onLongPressStart: (_) => _onPauseHold(true),
          onLongPressEnd: (_) => _onPauseHold(false),
          onPanStart: (d) {
            _dragStartX = d.globalPosition.dx;
            _dragStartY = d.globalPosition.dy;
            _swipeOffset = 0.0;
            _verticalSwipeOffset = 0.0;
            _swipeTargetUserIndex = null;
            _isVerticalSwipe = false;
            _gestureDirectionLocked = false;
            _isDismissing = false;
          },
          onPanUpdate: (d) {
            if (_dragStartX == null || _dragStartY == null) return;

            final currentX = d.globalPosition.dx;
            final currentY = d.globalPosition.dy;
            final deltaX = currentX - _dragStartX!;
            final deltaY = currentY - _dragStartY!;

            // Determine primary direction on first significant movement (20px threshold)
            if (!_gestureDirectionLocked &&
                (deltaX.abs() > 20 || deltaY.abs() > 20)) {
              if (deltaY.abs() > deltaX.abs() * 1.2) {
                // Primarily vertical - lock to vertical
                _isVerticalSwipe = true;
                _gestureDirectionLocked = true;
                // Pause timer when vertical swipe starts to prevent double navigation
                _autoAdvanceTimer?.cancel();
                _progressController?.stop();
                _videoController?.pause();
                setState(() => _isDismissing = true);
              } else if (deltaX.abs() > deltaY.abs() * 1.2) {
                // Primarily horizontal - lock to horizontal
                _isVerticalSwipe = false;
                _gestureDirectionLocked = true;
              }
            }

            // Handle vertical swipe (dismiss)
            if (_isVerticalSwipe && _gestureDirectionLocked) {
              // Only allow downward swipes
              if (deltaY > 0) {
                final screenHeight = MediaQuery.of(context).size.height;
                _verticalSwipeOffset = deltaY.clamp(0, screenHeight);
                setState(() {}); // Update UI to show story moving down
              }
              return; // Don't process horizontal during vertical swipe
            }

            // Handle horizontal swipe (navigate between users)
            if (!_isVerticalSwipe && _gestureDirectionLocked) {
              final screenWidth = MediaQuery.of(context).size.width;
              _swipeOffset = deltaX.clamp(-screenWidth, screenWidth);

              // Determine target user based on swipe direction
              if (deltaX > 50 && _userIndex > 0) {
                _swipeTargetUserIndex = _userIndex - 1;
              } else if (deltaX < -50 &&
                  _userIndex < widget.userIds.length - 1) {
                _swipeTargetUserIndex = _userIndex + 1;
              } else {
                _swipeTargetUserIndex = null;
              }

              setState(() {}); // Update UI to show swipe preview
            }
          },
          onPanEnd: (d) {
            if (_dragStartX == null || _dragStartY == null) {
              _resetSwipe();
              return;
            }

            final dragEndX = d.globalPosition.dx;
            final dragEndY = d.globalPosition.dy;
            final deltaX = dragEndX - _dragStartX!;
            final deltaY = dragEndY - _dragStartY!;
            final velocity = d.velocity.pixelsPerSecond;
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;

            // Handle vertical swipe end (dismiss)
            if (_isVerticalSwipe && _gestureDirectionLocked) {
              // Dismiss if swiped down significantly (>20% of screen) or fast downward velocity
              if (deltaY > screenHeight * 0.2 || velocity.dy > 500) {
                // Ensure timer is cancelled before dismissing
                _autoAdvanceTimer?.cancel();
                _progressController?.stop();
                _videoController?.pause();
                _markCurrentUserViewed();
                Navigator.of(context).pop();
              } else {
                // Snap back if not enough swipe - resume timer
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

            // Handle horizontal swipe end (navigate between users)
            if (!_isVerticalSwipe && _gestureDirectionLocked) {
              // Require minimum distance (30% of screen) or velocity for swipe
              if (deltaX.abs() > screenWidth * 0.3 || velocity.dx.abs() > 500) {
                // Swipe right: previous user
                if (deltaX > 0 && _userIndex > 0) {
                  _markCurrentUserViewed();
                  setState(() {
                    _userIndex--;
                    _slideIndex = 0;
                  });
                  _loadStories();
                }
                // Swipe left: next user
                else if (deltaX < 0 && _userIndex < widget.userIds.length - 1) {
                  _markCurrentUserViewed();
                  setState(() {
                    _userIndex++;
                    _slideIndex = 0;
                  });
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
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Black background to ensure no grey shows through
              Positioned.fill(
                child: Container(
                    color: const Color(0xFF000000)), // Explicit pitch black
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
                    color: const Color(0xFF000000), // Explicit pitch black
                    child: const Center(
                        child: CircularProgressIndicator(color: Colors.white)),
                  ),
                )
              else if (_stories.isEmpty)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF000000), // Explicit pitch black
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
                              builder: (_, __) => _buildProgressBar(),
                            ),
                          _buildTopBar(),
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
                    child: IgnorePointer(
                      ignoring: !_showInteractiveUI,
                      child: AnimatedOpacity(
                        opacity: _showInteractiveUI ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Center(
                          child: _buildSeePostButton(
                              _stories[_slideIndex].sourceId!),
                        ),
                      ),
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
                      child: _buildReplyBox(),
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
                        child: _buildViewsSection(),
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
      return Container(color: const Color(0xFF000000)); // Explicit pitch black
    }

    final targetUserId = widget.userIds[targetUserIndex];

    return FutureBuilder<List<Story>>(
      future: _storyService.getStoriesForUser(targetUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
              color: const Color(0xFF000000)); // Explicit pitch black
        }

        final previewStory = snapshot.data!.first;
        return _buildSlide(
            previewStory); // This will handle isPostCard detection
      },
    );
  }

  Widget _buildSlide(Story story) {
    if (story.mediaUrl.isEmpty) {
      AppLogger.w('StoryViewer: showing empty media icon (mediaUrl is empty)',
          category: LogCategory.general, data: {'storyId': story.id});
      return const Center(
        child: Icon(Icons.image_not_supported, color: Colors.white54, size: 64),
      );
    }
    if (story.mediaType == StoryMediaType.video) {
      // Track view for video (only once per story per session)
      if (!_viewedStoryIds.contains(story.id)) {
        _viewedStoryIds.add(story.id);
        _storyService.trackStoryView(
          userId: _currentUserId,
          storyId: story.id,
        );
      }

      return _StoryVideoSlide(
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
        child: _StoryImageSlide(
          storyId: story.id,
          imageUrl: story.mediaUrl,
          onReady: _onStoryMediaReady,
          isPostCard: isPostCard,
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwnStory = currentUid != null && currentUid == _currentUserId;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(16, 12, 16, 12), // Instagram-style padding
      child: Row(
        children: [
          // Avatar - Instagram size (36px)
          UserAvatar(
            userId: _currentUserId,
            size: 36,
            loadFromFirestore: true,
          ),

          const SizedBox(width: 12), // Instagram spacing

          // Username
          Expanded(
            child: _UserNameText(userId: _currentUserId),
          ),

          // Delete button (only for own stories)
          if (isOwnStory && _stories.isNotEmpty)
            GestureDetector(
              onTap: _deleteCurrentStory,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 24),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyBox() {
    return Container(
      // Completely transparent
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 12, // Bottom padding (SafeArea handles safe area insets)
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Vertically aligned
        children: [
          // Text input field - Instagram style (transparent with white border)
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                color: Colors.transparent, // Completely transparent
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3), // White border
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _replyController,
                focusNode: _replyFocusNode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendReply(),
                decoration: InputDecoration(
                  hintText: 'Send message',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 15,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button - Paper plane icon (same as tabs bar)
          GestureDetector(
            onTap: _sendReply,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                CupertinoIcons.paperplane, // Same icon as tabs bar
                color: _replyController.text.trim().isEmpty
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_stories.isEmpty) return const SizedBox.shrink();
    final progress = _progressController?.value ?? 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          16, 12, 16, 4), // Match header horizontal padding
      child: Row(
        children: List.generate(_stories.length, (i) {
          double fill = 0.0;
          if (i < _slideIndex) {
            fill = 1.0;
          } else if (i == _slideIndex) {
            fill = progress;
          }
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: c.maxWidth * fill,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSeePostButton(String postId) {
    return GestureDetector(
      onTap: () async {
        // Hide button and resume story
        _hidePostButton();

        // Small delay to ensure button hides smoothly
        await Future.delayed(const Duration(milliseconds: 100));

        // Navigate to post thread
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ThreadView(postId: postId),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.article_outlined, color: Colors.black87, size: 18),
            const SizedBox(width: 8),
            const Text(
              'See post',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewsSection() {
    if (_stories.isEmpty || _slideIndex >= _stories.length) {
      return const SizedBox.shrink();
    }

    final story = _stories[_slideIndex];

    return FutureBuilder<int>(
      future: _storyService.getStoryViewCount(
        userId: _currentUserId,
        storyId: story.id,
      ),
      builder: (context, snapshot) {
        final viewCount = snapshot.data ?? 0;

        if (viewCount == 0) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => _showViewersList(story.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.remove_red_eye,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  viewCount == 1 ? '1 view' : '$viewCount views',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showViewersList(String storyId) async {
    final viewers = await _storyService.getStoryViewers(
      userId: _currentUserId,
      storyId: storyId,
      limit: 100,
    );

    if (!mounted) return;

    if (viewers.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Views',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${viewers.length}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: viewers.length,
                itemBuilder: (context, index) {
                  final viewerId = viewers[index];
                  return ListTile(
                    leading: UserAvatar(
                      userId: viewerId,
                      size: 40,
                      loadFromFirestore: true,
                    ),
                    title: _ViewerNameText(userId: viewerId),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _UserNameText extends StatelessWidget {
  final String userId;

  const _UserNameText({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final name =
            data?['name'] as String? ?? data?['nickname'] as String? ?? 'Story';
        return Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14, // Instagram font size
            fontWeight: FontWeight.w600,
            letterSpacing: 0.0, // Instagram letter spacing
            shadows: [
              Shadow(
                color: Colors.black54, // Stronger shadow for readability
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _ViewerNameText extends StatelessWidget {
  final String userId;

  const _ViewerNameText({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final name =
            data?['name'] as String? ?? data?['nickname'] as String? ?? 'User';
        return Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _StoryImageSlide extends StatefulWidget {
  final String storyId;
  final String imageUrl;
  final VoidCallback onReady;
  final bool isPostCard;

  const _StoryImageSlide({
    required this.storyId,
    required this.imageUrl,
    required this.onReady,
    this.isPostCard = false,
  });

  @override
  State<_StoryImageSlide> createState() => _StoryImageSlideState();
}

class _StoryImageSlideState extends State<_StoryImageSlide> {
  bool _hasCalledReady = false;
  String? _lastImageUrl;

  @override
  void didUpdateWidget(_StoryImageSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset ready flag when image URL changes
    if (oldWidget.imageUrl != widget.imageUrl) {
      _hasCalledReady = false;
      _lastImageUrl = widget.imageUrl;
    }
  }

  @override
  void initState() {
    super.initState();
    _lastImageUrl = widget.imageUrl;
  }

  void _notifyReady() {
    if (!_hasCalledReady && mounted && _lastImageUrl == widget.imageUrl) {
      _hasCalledReady = true;
      // Use post-frame callback to ensure the widget is fully built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _lastImageUrl == widget.imageUrl) {
          widget.onReady();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0) {
          return Container(
            color: const Color(0xFF000000), // Explicit pitch black
            child: const Center(
                child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        return Container(
          width: w,
          height: h,
          color: const Color(0xFF000000), // Explicit pitch black
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            width: w,
            height: h,
            fit: widget.isPostCard
                ? BoxFit.contain
                : BoxFit
                    .cover, // Contain for post cards to preserve padding, cover for regular images
            alignment: Alignment.center,
            memCacheWidth: (w * 2).toInt(), // Cache at 2x for quality
            memCacheHeight: (h * 2).toInt(),
            fadeInDuration: Duration.zero, // No fade for instant display
            fadeOutDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            placeholder: (_, __) => Container(
              color: const Color(0xFF000000), // Explicit pitch black
              // Minimal placeholder - should rarely show if precached
            ),
            imageBuilder: (context, imageProvider) {
              // Image is fully loaded - notify parent to start timer
              _notifyReady();
              return Container(
                color: const Color(0xFF000000), // Explicit pitch black
                width: w,
                height: h,
                child: Image(
                  image: imageProvider,
                  width: w,
                  height: h,
                  fit: widget.isPostCard
                      ? BoxFit.contain
                      : BoxFit
                          .cover, // Contain for post cards to preserve padding, cover for regular images
                  alignment: Alignment.center,
                ),
              );
            },
            errorWidget: (_, __, ___) {
              AppLogger.w('StoryViewer: image load error',
                  category: LogCategory.general,
                  data: {
                    'storyId': widget.storyId,
                    'urlLength': widget.imageUrl.length,
                  });
              // Even on error, notify ready so we don't get stuck
              _notifyReady();
              return Container(
                color: const Color(0xFF000000), // Explicit pitch black
                child: const Center(
                  child:
                      Icon(Icons.broken_image, color: Colors.white, size: 48),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StoryVideoSlide extends StatefulWidget {
  final String url;
  final String storyId;
  final VoidCallback? onInitialized;
  final void Function(VideoPlayerController?)? controllerCallback;

  const _StoryVideoSlide({
    required this.url,
    required this.storyId,
    this.onInitialized,
    this.controllerCallback,
  });

  @override
  State<_StoryVideoSlide> createState() => _StoryVideoSlideState();
}

class _StoryVideoSlideState extends State<_StoryVideoSlide> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    AppLogger.d('StoryViewer: video init start',
        category: LogCategory.general,
        data: {'storyId': widget.storyId, 'urlLength': widget.url.length});
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller!.initialize().then((_) {
      AppLogger.d('StoryViewer: video initialized',
          category: LogCategory.general, data: {'storyId': widget.storyId});
      widget.controllerCallback?.call(_controller);
      if (mounted) {
        setState(() {});
        _controller?.play();
        widget.onInitialized?.call();
      }
    }).catchError((e, st) {
      AppLogger.e('StoryViewer: video init failed',
          category: LogCategory.general,
          error: e,
          stackTrace: st,
          data: {'storyId': widget.storyId, 'urlLength': widget.url.length});
    });
  }

  @override
  void dispose() {
    widget.controllerCallback?.call(null);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !(_controller!.value.isInitialized)) {
      return Container(
        color: const Color(0xFF000000), // Explicit pitch black
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    return Container(
      color: const Color(0xFF000000), // Explicit pitch black
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      ),
    );
  }
}
