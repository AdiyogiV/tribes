import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_header.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_options_sheet.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_action_toolbar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/shared/services/media/audio_player_pool.dart';
import 'package:aurogram/features/feed/presentation/pages/feed_controller.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Clean audio player matching TransparentToolbox style
/// - Card with elevation 4
/// - Audio controls area with its own elevation
/// - All text in primary color
class AudioNotePlayer extends StatefulWidget {
  final String? author;
  final String? space;
  final String audioUrl;
  final int durationInSeconds;
  final String? postId;
  final String? title;
  final Timestamp? timestamp;
  final String? label;
  final Color? labelColor;
  final bool hasContentBelow;
  final bool isProfilePost;
  final Widget? contentAfterHeader;

  /// When false, do not render PostHeader (for unified post layout).
  final bool showHeader;

  /// When false, do not render toolbar (for unified post layout).
  final bool showToolbar;

  // NEW: Pre-loaded user/space data for instant header rendering
  final dynamic userData;
  final dynamic spaceData;

  const AudioNotePlayer({
    super.key,
    this.postId,
    this.space,
    this.author,
    required this.audioUrl,
    required this.durationInSeconds,
    this.title,
    this.timestamp,
    this.label,
    this.labelColor,
    this.hasContentBelow = false,
    this.isProfilePost = false,
    this.contentAfterHeader,
    this.showHeader = true,
    this.showToolbar = true,
    this.userData,
    this.spaceData,
  });

  @override
  State<AudioNotePlayer> createState() => _AudioNotePlayerState();
}

class _AudioNotePlayerState extends State<AudioNotePlayer>
    with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  bool _isVisible = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  late AnimationController _pulseController;
  final AudioPlayerPool _pool = AudioPlayerPool();

  // Lazy initialization state
  bool _hasAttemptedInit = false;
  bool _isPlayerInitialized = false;

  @override
  void initState() {
    super.initState();

    // Defer player initialization - will be triggered by VisibilityDetector
    // This is the production-grade lazy initialization approach
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Set up viewport-aware lazy initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupLazyInitialization();
    });
  }

  /// Setup lazy initialization - deferred until VisibilityDetector triggers
  void _setupLazyInitialization() {
    // Do nothing - VisibilityDetector in _handleVisibilityChanged will trigger init
    // Simple pattern that works in production
  }

  @override
  void didUpdateWidget(AudioNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL: Prevent rebuilds when parent rebuilds but our postId/audio hasn't changed
    if (oldWidget.postId == widget.postId &&
        oldWidget.audioUrl == widget.audioUrl &&
        oldWidget.durationInSeconds == widget.durationInSeconds) {
      // Same post, same audio - no rebuild needed
      return;
    }

    // Audio changed - need to reinitialize player
    // (This should be rare in feed - mostly happens in thread view)
    if (_isPlayerInitialized) {
      try {
        _audioPlayer.stop();
      } catch (e) {
        // Already stopped or error
      }
      _hasAttemptedInit = false;
      _isPlayerInitialized = false;
    }
  }

  Future<void> _initPlayer() async {
    if (_hasAttemptedInit) return; // Prevent double initialization
    _hasAttemptedInit = true;

    final startTime = DateTime.now();

    // Try to get player from pool first (fast path)
    if (widget.postId != null) {
      final pooled = _pool.getPlayer(widget.postId!);
      if (pooled != null) {
        _audioPlayer = pooled.player;
        _isPlayerInitialized = true;

        // Restore audio position from FeedController
        if (mounted) {
          try {
            final feedController = context.read<FeedController>();
            final state = feedController.getPostState(widget.postId!);
            if (state.audioPosition != null &&
                state.audioPosition!.inSeconds > 0) {
              await _audioPlayer.seek(state.audioPosition!);
            }
          } catch (e) {
            // FeedController not available yet
          }
        }

        // Set up streams
        _setupStreams();

        // Pool hit - fast path (don't spam logs)
        return;
      }
    }

    // Create new player (slow path)
    _audioPlayer = AudioPlayer();
    _totalDuration = Duration(seconds: widget.durationInSeconds);

    try {
      await _audioPlayer.setUrl(widget.audioUrl);

      // Add to pool for reuse
      if (widget.postId != null) {
        _pool.addPlayer(widget.postId!, _audioPlayer);
      }

      _setupStreams();
      _isPlayerInitialized = true;

      final duration = DateTime.now().difference(startTime);
      // Only log slow initializations (>100ms)
      if (duration.inMilliseconds > 100) {
        AppLogger.d('Audio init: ${duration.inMilliseconds}ms',
            category: LogCategory.performance,
            data: {'postId': widget.postId ?? 'unknown'});
      }
    } catch (e) {
      AppLogger.e('Audio player init failed', error: e);
    }
  }

  void _setupStreams() {
    _positionSub = _audioPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _currentPosition = pos);
    });

    _durationSub = _audioPlayer.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _totalDuration = dur);
    });

    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
        _isLoading = state.processingState == ProcessingState.loading;
      });

      if (_isPlaying) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }

      if (state.processingState == ProcessingState.completed) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.stop();
      }
    });
  }

  @override
  void dispose() {
    // Save audio position and interaction state to FeedController before disposing
    if (widget.postId != null && mounted) {
      try {
        final feedController = context.read<FeedController>();

        // Save audio position
        final position = _currentPosition;
        if (position.inSeconds > 0) {
          feedController.updateAudioPosition(widget.postId!, position);
        }
      } catch (e) {
        // FeedController not available or context invalid
      }
    }

    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _pulseController.dispose();

    // DON'T dispose player - pool manages lifecycle
    // Just stop and null reference
    if (_isPlayerInitialized) {
      try {
        _audioPlayer.stop();
      } catch (e) {
        // Already stopped or error
      }
    }

    super.dispose();
  }

  void _handleVisibility(VisibilityInfo info) {
    if (!mounted) return;

    // Lazy initialization trigger: Initialize when post enters viewport vicinity
    if (!_hasAttemptedInit && info.visibleFraction > 0.1) {
      _initPlayer();
    }

    final nowVisible = info.visibleFraction > 0.7;
    if (_isVisible != nowVisible && mounted) {
      setState(() => _isVisible = nowVisible);
    }

    // Handle playback when visibility changes
    if (nowVisible && !_isPlayerInitialized) {
      // Visible but player not initialized - might have been disposed by pool
      if (_hasAttemptedInit) {
        AppLogger.w('AudioNotePlayer: Player disposed, re-initializing', category: LogCategory.media);
        _hasAttemptedInit = false;
        _isPlayerInitialized = false;
        _initPlayer();
      }
    }

    // Pause when not visible
    if (!nowVisible && _isPlaying && _isPlayerInitialized && mounted) {
      try {
        _audioPlayer.pause();
      } catch (e) {
        // Player might have been disposed by pool
        AppLogger.w('AudioNotePlayer: Failed to pause (disposed), clearing state', category: LogCategory.media);
        _isPlayerInitialized = false;
        _hasAttemptedInit = false;
      }
    }
  }

  void _togglePlayback() async {
    // Initialize player if not already done (user tapped play before lazy init)
    if (!_isPlayerInitialized) {
      await _initPlayer();
      if (!_isPlayerInitialized) return; // Init failed
    }

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      AppLogger.e('Playback toggle failed', error: e);
    }
  }

  void _seekTo(double value) {
    if (!_isPlayerInitialized) return; // Player not ready yet
    try {
      final pos = Duration(seconds: (value * _totalDuration.inSeconds).round());
      _audioPlayer.seek(pos);
    } catch (e) {
      // Player error
    }
  }

  void _showMoreOptions() {
    if (widget.postId == null) return;
    showPostOptionsSheet(
      context: context,
      postId: widget.postId!,
      authorId: widget.author,
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Card styling (background, border radius, shadow) handled by parent (PostSwitcher)
    return VisibilityDetector(
      key: ValueKey('audio_${widget.postId}'),
      onVisibilityChanged: _handleVisibility,
      child: Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeader)
              PostHeader(
                uid: widget.author,
                space: widget.space,
                timestamp: widget.timestamp,
                userData: widget.userData,
                spaceData: widget.spaceData,
                isProfilePost: widget.isProfilePost,
                label: widget.label,
                labelColor: widget.labelColor,
                onMoreTap: _showMoreOptions,
              ),

            // Content after header (e.g., reply indicator)
            if (widget.contentAfterHeader != null) widget.contentAfterHeader!,

            // Audio controls area with elevation
            Material(
              color: isDark ? const Color(0xFF1A2535) : const Color(0xFFE8F2FC),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
                child: Column(
                  children: [
                    // Type badge (8h / 4v for consistency)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic,
                              size: 14, color: AppTheme.primaryColor),
                          const SizedBox(width: AppDimensions.spacingSmMd),
                          Text(
                            'Voice',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Title
                    if (widget.title != null && widget.title!.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.spacingSm),
                      Text(
                        widget.title!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: AppDimensions.spacingSm),

                    // Play button
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale = _isPlaying
                            ? 1.0 + (_pulseController.value * 0.08)
                            : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: GestureDetector(
                            onTap: _togglePlayback,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primaryColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: _isLoading
                                  ? const Padding(
                                      padding: EdgeInsets.all(AppDimensions.paddingXl),
                                      child: PulsingDots(
                                          color: Colors.white, size: 8),
                                    )
                                  : Icon(
                                      _isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: AppDimensions.spacingSm),

                    // Progress bar
                    Row(
                      children: [
                        Text(
                          _formatDuration(_currentPosition),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14),
                                activeTrackColor: AppTheme.primaryColor,
                                inactiveTrackColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.2),
                                thumbColor: AppTheme.primaryColor,
                                overlayColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.15),
                              ),
                              child: Slider(
                                value: _totalDuration.inMilliseconds > 0
                                    ? (_currentPosition.inMilliseconds /
                                            _totalDuration.inMilliseconds)
                                        .clamp(0.0, 1.0)
                                    : 0.0,
                                onChanged: _seekTo,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_totalDuration),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (widget.showToolbar)
              PostActionToolbar(
                postId: widget.postId,
                author: widget.author,
                space: widget.space,
                link: null,
              ),
          ],
        ),
      ),
    );
  }
}
