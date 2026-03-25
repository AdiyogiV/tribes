import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/services/audio_service.dart';
import 'package:aurogram/services/global_audio_service.dart';
import 'package:aurogram/services/feed_video_focus_service.dart';
import 'package:aurogram/services/video_controller_pool.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:aurogram/controllers/feed_controller.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/post_header.dart';
import 'package:aurogram/widgets/posts/post_options_sheet.dart';
import 'package:aurogram/widgets/posts/post_action_toolbar.dart';

/// Optimized video player for feed
/// - Eager initialization for smooth autoplay
/// - Isolated video updates (no full rebuilds)
/// - Each widget owns its own controller (no sharing)
class MainPlayer extends StatefulWidget {
  final String? author;
  final String? space;
  final String? videoUrl;
  final int? pageIndex;
  final int? pageDepth;
  final String? postId;
  final String? title;
  final String? link;
  final String? thumbnail;
  final bool? uploading;
  final Timestamp? timestamp;
  final String? label;
  final Color? labelColor;
  final bool hasContentBelow;
  final bool isProfilePost;
  final bool enableVideoAutoplay;
  final bool prewarmVideo;
  final Widget? contentAfterHeader;

  /// When false, do not render PostHeader (for unified post layout).
  final bool showHeader;

  /// When false, do not render toolbar (for unified post layout).
  final bool showToolbar;

  /// When false, do not render caption below (for unified post layout).
  final bool showCaption;

  // NEW: Pre-loaded user/space data for instant header rendering
  final dynamic userData; // Using dynamic to avoid importing batch_data_loader
  final dynamic spaceData;

  const MainPlayer({
    super.key,
    this.postId,
    this.space,
    this.author,
    this.videoUrl,
    this.pageIndex,
    this.pageDepth,
    this.title,
    this.link,
    this.thumbnail,
    this.uploading,
    this.timestamp,
    this.label,
    this.labelColor,
    this.hasContentBelow = false,
    this.isProfilePost = false,
    this.enableVideoAutoplay = false,
    this.prewarmVideo = false,
    this.contentAfterHeader,
    this.showHeader = true,
    this.showToolbar = true,
    this.showCaption = true,
    this.userData,
    this.spaceData,
  });

  @override
  State<MainPlayer> createState() => _MainPlayerState();
}

class _MainPlayerState extends State<MainPlayer> with WidgetsBindingObserver {
  // KISS: Own our own controller
  VideoPlayerController? _controller;
  bool _isDisposed = false;
  final ValueNotifier<bool> _isInitializingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isControllerReadyNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  bool _isVisible = false;
  double _lastVisibleFraction = 0.0;
  bool _loggedPlaceholderShown = false;
  bool _loggedVideoShown = false;
  int _initAttempts = 0;

  // Services
  late GlobalAudioService _globalAudioService;

  // Lazy initialization state
  bool _hasAttemptedInit = false;

  User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _globalAudioService = locator<GlobalAudioService>();
    _globalAudioService.addListener(_onGlobalAudioStateChanged);
    if (widget.postId != null && widget.postId!.isNotEmpty) {
      locator<FeedVideoFocusService>().register(widget.postId!, _pauseVideo);
    }

    // Set up viewport-aware lazy initialization and preload listening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupLazyInitialization();
    });

    if (widget.prewarmVideo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hasAttemptedInit) return;
        if (kDebugMode && widget.postId != null) {
          AppLogger.d(
            'MainPlayer: prewarm init request',
            category: LogCategory.media,
            data: {'postId': widget.postId, 'visible': _isVisible},
          );
        }
        _initializeController();
      });
    }
  }

  /// Setup lazy initialization - deferred until VisibilityDetector triggers
  /// This is the simple pattern that actually works in production
  void _setupLazyInitialization() {
    // Do nothing - VisibilityDetector in _handleVisibility will trigger init
    // when video becomes 30% visible. Simple, predictable, fast.
  }

  @override
  void didUpdateWidget(MainPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL: Prevent rebuilds when parent rebuilds but our postId hasn't changed
    // This stops cascade rebuilds from FeedController or parent state changes
    if (oldWidget.postId == widget.postId &&
        oldWidget.videoUrl == widget.videoUrl &&
        oldWidget.uploading == widget.uploading) {
      // Same post and same content, no need to do anything
      // Controller lifecycle managed by visibility, no thumbnail updates needed
      return;
    }

    // Post content changed - may need to reinitialize controller
    // (This should be rare in feed - mostly happens in thread view)
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _pauseVideo();
    }
    // Do NOT auto-resume when app comes back - user must tap to play
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (kDebugMode && widget.postId != null) {
      AppLogger.d(
        'MainPlayer: dispose',
        category: LogCategory.media,
        data: {
          'postId': widget.postId,
          'hasController': _controller != null,
          'initialized': _controller?.value.isInitialized,
          'playing': _controller?.value.isPlaying,
          'positionMs': _controller?.value.position.inMilliseconds,
        },
      );
    }
    if (widget.postId != null && widget.postId!.isNotEmpty) {
      locator<FeedVideoFocusService>().unregister(widget.postId!);

      // Save video position and interaction state to FeedController before disposing
      if (mounted) {
        try {
          final feedController = context.read<FeedController>();

          // Save video position
          if (_controller != null) {
            final position = _controller!.value.position;
            if (position.inSeconds > 0) {
              feedController.updateVideoPosition(widget.postId!, position);
            }
          }
        } catch (e) {
          // FeedController not available or context invalid
        }
      }
    }

    WidgetsBinding.instance.removeObserver(this);
    _globalAudioService.removeListener(_onGlobalAudioStateChanged);

    // Release controller to pool for reuse when possible
    if (_controller != null) {
      try {
        _controller!.removeListener(_onPlayStateChanged);
        _controller!.pause();
        if (widget.postId != null &&
            _controller!.value.isInitialized &&
            !_isDisposed) {
          VideoControllerPool().addController(widget.postId!, _controller!);
        } else {
          _controller!.dispose();
        }
      } catch (e) {
        // Already disposed or error
      }
      _controller = null;
    }

    // Dispose notifiers
    if (!_isDisposed) {
      try {
        _isControllerReadyNotifier.value = false;
      } catch (e) {
        // Already disposed
      }
      try {
        _isPlayingNotifier.value = false;
      } catch (e) {
        // Already disposed
      }
    }

    _isInitializingNotifier.dispose();
    _isControllerReadyNotifier.dispose();
    _isPlayingNotifier.dispose();
    super.dispose();
  }

  /// Check if controller is valid and initialized
  /// CRITICAL: This must check if controller is disposed to prevent errors
  bool get _hasValidController {
    if (_isDisposed || _controller == null) return false;
    try {
      final controller = _controller!;
      // Accessing .value will throw StateError if disposed
      final value = controller.value;
      return value.isInitialized;
    } catch (e) {
      // Controller was disposed (either by pool or manually)
      _controller = null; // Clear stale reference
      _hasAttemptedInit = false; // Allow re-init if needed
      // CRITICAL: Update notifier so VideoPlayer widget doesn't get the disposed controller
      if (!_isDisposed) {
        try {
          _isControllerReadyNotifier.value = false;
        } catch (_) {
          // Notifier already disposed
        }
      }
      return false;
    }
  }

  /// Pause video safely
  void _pauseVideo() {
    if (_isDisposed || !mounted) return; // Early exit if disposed
    if (!_hasValidController) return;
    try {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        controller.pause();
      }
    } catch (e) {
      // Controller was disposed between check and usage - ignore silently
      _controller = null;
    }
  }

  /// Initialize controller without auto-playing
  /// Uses VideoControllerPool for resource reuse (production-grade approach)
  Future<void> _initializeController() async {
    if (_isDisposed || _isInitializingNotifier.value || _hasValidController)
      return;
    if (widget.uploading == true ||
        widget.videoUrl == null ||
        widget.videoUrl!.isEmpty ||
        widget.postId == null) {
      return;
    }
    _hasAttemptedInit = true;
    _initAttempts += 1;
    if (kDebugMode && widget.postId != null) {
      AppLogger.d(
        'MainPlayer: init start',
        category: LogCategory.media,
        data: {
          'postId': widget.postId,
          'attempt': _initAttempts,
          'visible': _isVisible,
          'prewarm': widget.prewarmVideo,
        },
      );
    }

    if (!_isDisposed) {
      try {
        _isInitializingNotifier.value = true;
      } catch (e) {
        // Already disposed
        return;
      }
    }

    final startTime = DateTime.now();

    try {
      // Create new controller - each MainPlayer owns its own controller (KISS)
      VideoPlayerController controller;

      final pooled = VideoControllerPool().takeController(widget.postId!);
      if (pooled != null && pooled.controller.value.isInitialized) {
        _controller = pooled.controller;
        _isControllerReadyNotifier.value = true;
        _controller!.addListener(_onPlayStateChanged);
        if (kDebugMode) {
          AppLogger.d(
            'MainPlayer: init from pool',
            category: LogCategory.media,
            data: {'postId': widget.postId, 'attempt': _initAttempts},
          );
        }
        return;
      }

      if (kIsWeb) {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl!),
          videoPlayerOptions: VideoPlayerOptions(
            allowBackgroundPlayback: false,
            mixWithOthers: true,
          ),
        );
      } else {
        // On mobile, try to use cached file for faster loading
        final cacheService = locator<CacheService>();
        final file = await cacheService.getFilefromCache(widget.videoUrl!);

        if (_isDisposed) return;

        controller = file != null
            ? VideoPlayerController.file(file.file,
                videoPlayerOptions: VideoPlayerOptions(
                    allowBackgroundPlayback: false, mixWithOthers: true))
            : VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!),
                videoPlayerOptions: VideoPlayerOptions(
                    allowBackgroundPlayback: false, mixWithOthers: true));

        if (file == null) cacheService.downloadFile(widget.videoUrl!);
        if (kDebugMode) {
          AppLogger.d(
            'MainPlayer: init source',
            category: LogCategory.media,
            data: {
              'postId': widget.postId,
              'source': file != null ? 'cache' : 'network',
            },
          );
        }
      }

      await controller.initialize();

      if (_isDisposed) {
        controller.dispose();
        return;
      }

      await controller.setLooping(false);
      await controller.setVolume(_globalAudioService.getEffectiveVolume());

      // Set controller (MainPlayer owns it now)
      _controller = controller;
      if (!_isDisposed) {
        try {
          _isControllerReadyNotifier.value = true;
        } catch (e) {
          // Already disposed
        }
      }

      // Add listener to track play state changes only
      controller.addListener(_onPlayStateChanged);

      final duration = DateTime.now().difference(startTime);
      if (kDebugMode) {
        AppLogger.d(
          'MainPlayer: init complete',
          category: LogCategory.performance,
          data: {
            'postId': widget.postId,
            'ms': duration.inMilliseconds,
            'attempt': _initAttempts,
          },
        );
      }
    } catch (e) {
      AppLogger.e('MainPlayer: Init failed for ${widget.postId}',
          category: LogCategory.media, error: e);
    } finally {
      if (!_isDisposed) {
        try {
          _isInitializingNotifier.value = false;
        } catch (e) {
          // Already disposed
        }
      }
    }
  }

  void _onPlayStateChanged() {
    if (_isDisposed || !_hasValidController) return;
    final isPlaying = _controller!.value.isPlaying;
    if (_isPlayingNotifier.value != isPlaying) {
      try {
        _isPlayingNotifier.value = isPlaying;
      } catch (e) {
        // Already disposed
      }
    }
  }

  void _handleVisibility(VisibilityInfo info) {
    if (_isDisposed || !mounted)
      return; // Don't process if disposed or unmounted
    _lastVisibleFraction = info.visibleFraction;

    // Lazy initialization trigger: Initialize when post becomes 30% visible
    // Simple, predictable pattern used by Instagram/TikTok
    if (!_hasAttemptedInit && info.visibleFraction > 0.2) {
      if (kDebugMode && widget.postId != null) {
        AppLogger.d(
          'MainPlayer: visibility init trigger',
          category: LogCategory.media,
          data: {
            'postId': widget.postId,
            'visibleFraction': info.visibleFraction.toStringAsFixed(2),
          },
        );
      }
      _initializeController();
    }

    final nowVisible = info.visibleFraction > 0.5;

    if (_isVisible != nowVisible) {
      _isVisible = nowVisible;
      if (kDebugMode && widget.postId != null) {
        AppLogger.d(
          'MainPlayer: visibility changed',
          category: LogCategory.media,
          data: {
            'postId': widget.postId,
            'nowVisible': nowVisible,
            'fraction': info.visibleFraction.toStringAsFixed(2),
          },
        );
      }

      if (!nowVisible) {
        // Pause video - but check validity first to avoid disposed controller errors
        if (_hasValidController) {
          _pauseVideo();
        } else if (_controller != null) {
          // Widget has controller ref but it's invalid (disposed by pool)
          print(
              '⚠️ MainPlayer ${widget.postId}: Controller ref invalid, clearing');
          _controller = null;
          _hasAttemptedInit = false; // Allow re-init
        }
      }

      if (nowVisible && widget.enableVideoAutoplay && widget.postId != null) {
        locator<FeedVideoFocusService>().requestFocus(widget.postId);
        if (_hasValidController) {
          try {
            _controller!.play();
          } catch (e) {
            // Controller was disposed by pool - re-initialize
            print(
                '⚠️ MainPlayer ${widget.postId}: Controller disposed, re-initializing');
            _controller = null;
            _hasAttemptedInit = false;
            _initializeController();
          }
        } else if (_controller != null) {
          // Have stale ref - clear and re-init
          print(
              '⚠️ MainPlayer ${widget.postId}: Stale controller ref, re-initializing');
          _controller = null;
          _hasAttemptedInit = false;
          _initializeController();
        } else {
          // Controller should already be initializing from lazy trigger above
          // Wait for it to complete
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!mounted || _isDisposed) return; // Safety check
            if (_hasValidController && _isVisible) {
              final stillHasFocus =
                  locator<FeedVideoFocusService>().hasFocus(widget.postId);
              if (stillHasFocus) {
                try {
                  AudioService().requestAudioFocus();
                  _controller!.play();
                } catch (e) {
                  // Controller might have been disposed, ignore
                }
              }
            }
          });
        }
      }
    }
  }

  void _onGlobalAudioStateChanged() {
    if (_isDisposed || !_hasValidController) return;
    try {
      _controller!.setVolume(_globalAudioService.getEffectiveVolume());
      // No setState - AnimatedBuilder handles video area updates
    } catch (e) {
      // Ignore
    }
  }

  void _toggleMute() => _globalAudioService.toggleGlobalMute();

  void _togglePlayPause() {
    // Request focus to pause other videos (manual tap should also use focus service)
    if (widget.postId != null && widget.postId!.isNotEmpty) {
      locator<FeedVideoFocusService>().requestFocus(widget.postId);
    }

    if (!_hasValidController) {
      _initializeController().then((_) {
        if (mounted && _hasValidController) {
          // Verify we still have focus after async init (user may have scrolled away)
          final hasFocus = widget.postId != null
              ? locator<FeedVideoFocusService>().hasFocus(widget.postId)
              : true;
          if (hasFocus) {
            try {
              AudioService().requestAudioFocus();
              _controller!.play();
            } catch (_) {}
          }
        }
      });
      return;
    }

    try {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        AudioService().requestAudioFocus();
        _controller!.play();
      }
    } catch (e) {
      // Controller error - remove listener and reinitialize
      if (_controller != null) {
        try {
          _controller!.removeListener(_onPlayStateChanged);
        } catch (_) {}
        _controller = null;
      }
      _initializeController();
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

  void _openFullscreen() {
    if (!_hasValidController) return;

    bool wasPlaying = false;
    try {
      wasPlaying = _controller!.value.isPlaying;
      _controller!.pause();
    } catch (e) {
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenVideoPage(
            controller: _controller!,
            wasPlaying: wasPlaying,
            globalAudioService: _globalAudioService,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  double _getAspectRatio() {
    if (_hasValidController) {
      try {
        return _controller!.value.aspectRatio;
      } catch (e) {
        // Ignore
      }
    }
    return 9.0 / 16.0; // Default vertical video aspect ratio
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return VisibilityDetector(
      key: ValueKey('video_${widget.postId ?? widget.videoUrl}'),
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
                label: widget.label,
                labelColor: widget.labelColor,
                isProfilePost: widget.isProfilePost,
                onMoreTap: _showMoreOptions,
                userData: widget.userData,
                spaceData: widget.spaceData,
              ),

            // Content after header (e.g., reply indicator)
            if (widget.contentAfterHeader != null) widget.contentAfterHeader!,

            // Video content - only rebuilds video area when controller ready state changes
            ValueListenableBuilder<bool>(
              valueListenable: _isControllerReadyNotifier,
              builder: (context, isVideoReady, child) {
                return Material(
                  color: isDark
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFF8F6F2),
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(
                      AppHeaderStyle.postMediaBorderRadius),
                  clipBehavior: Clip.antiAlias,
                  child: _buildVideoArea(isVideoReady, isDark),
                );
              },
            ),

            if (widget.showToolbar)
              PostActionToolbar(
                postId: widget.postId,
                author: widget.author,
                space: widget.space,
                link: widget.link,
              ),

            if (widget.showCaption &&
                widget.title != null &&
                widget.title!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.title!,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoArea(bool isVideoReady, bool isDark) {
    final aspectRatio = _getAspectRatio();
    if (kDebugMode && widget.postId != null) {
      if (isVideoReady && !_loggedVideoShown) {
        _loggedVideoShown = true;
        _loggedPlaceholderShown = false;
        AppLogger.d(
          'MainPlayer: video ready (swap from placeholder)',
          category: LogCategory.media,
          data: {
            'postId': widget.postId,
            'visibleFraction': _lastVisibleFraction.toStringAsFixed(2),
          },
        );
      } else if (!isVideoReady && !_loggedPlaceholderShown) {
        _loggedPlaceholderShown = true;
        _loggedVideoShown = false;
        AppLogger.d(
          'MainPlayer: placeholder shown',
          category: LogCategory.media,
          data: {
            'postId': widget.postId,
            'hasThumb': widget.thumbnail?.isNotEmpty == true,
            'visibleFraction': _lastVisibleFraction.toStringAsFixed(2),
          },
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppHeaderStyle.postMediaBorderRadius),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video or placeholder - isolated with RepaintBoundary
            if (isVideoReady)
              RepaintBoundary(
                child: kIsWeb
                    ? IgnorePointer(child: VideoPlayer(_controller!))
                    : GestureDetector(
                        onTap: _togglePlayPause,
                        child: VideoPlayer(_controller!),
                      ),
              )
            else
              _buildPlaceholder(isDark),

            // Transparent tap overlay - essential on web
            Positioned.fill(
              child: GestureDetector(
                onTap: _togglePlayPause,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),

            // Uploading overlay
            if (widget.uploading == true)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: const ShimmerLoadingOverlay(text: 'Uploading...'),
              ),

            // Play/Pause button overlay - only rebuilds when play or init state changes
            ValueListenableBuilder<bool>(
              valueListenable: _isPlayingNotifier,
              builder: (context, isPlaying, child) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _isInitializingNotifier,
                  builder: (context, isInitializing, child) {
                    // Hide button when playing and not initializing
                    if (isVideoReady && isPlaying && !isInitializing) {
                      return const SizedBox.shrink();
                    }
                    return Center(
                      child: GestureDetector(
                        onTap: _togglePlayPause,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: isInitializing
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // Progress bar - built-in efficient updates
            if (isVideoReady)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: RepaintBoundary(
                  child: SizedBox(
                    height: 4,
                    child: VideoProgressIndicator(
                      _controller!,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: AppTheme.primaryColor,
                        bufferedColor:
                            AppTheme.primaryColor.withValues(alpha: 0.3),
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
              ),

            // Video-only controls on video overlay (mute, fullscreen)
            if (isVideoReady)
              Positioned(
                bottom: 12,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListenableBuilder(
                      listenable: _globalAudioService,
                      builder: (context, child) {
                        return _VideoOverlayButton(
                          icon: _globalAudioService.isGloballyMuted
                              ? CupertinoIcons.speaker_slash_fill
                              : CupertinoIcons.speaker_2_fill,
                          onTap: _toggleMute,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _VideoOverlayButton(
                      icon: CupertinoIcons.fullscreen,
                      onTap: _openFullscreen,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    if (widget.thumbnail != null && widget.thumbnail!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.thumbnail!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _gradientPlaceholder(isDark),
        errorWidget: (_, __, ___) => _gradientPlaceholder(isDark),
      );
    }
    return _gradientPlaceholder(isDark);
  }

  Widget _gradientPlaceholder(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)]
              : [const Color(0xFFF5F5F5), const Color(0xFFE8E8E8)],
        ),
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.videocam,
          size: 48,
          color: isDark ? Colors.white24 : Colors.black12,
        ),
      ),
    );
  }
}

/// Toolbar button
/// Small overlay button for video (mute, fullscreen)
class _VideoOverlayButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _VideoOverlayButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

/// Fullscreen video page
class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final bool wasPlaying;
  final GlobalAudioService globalAudioService;

  const _FullscreenVideoPage({
    required this.controller,
    required this.wasPlaying,
    required this.globalAudioService,
  });

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _showControls = true;
  Timer? _hideControlsTimer;

  bool get _isControllerValid {
    try {
      return widget.controller.value.isInitialized;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    if (_isControllerValid) {
      widget.controller.addListener(_onVideoUpdate);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isControllerValid) {
          widget.controller.play();
          _startHideControlsTimer();
        }
      });
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    if (_isControllerValid) {
      try {
        widget.controller.removeListener(_onVideoUpdate);
      } catch (e) {
        // Ignore
      }
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isControllerValid && widget.controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideControlsTimer();
  }

  void _togglePlayPause() {
    if (!_isControllerValid) {
      Navigator.of(context).pop();
      return;
    }
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
      setState(() => _showControls = true);
    } else {
      widget.controller.play();
      _startHideControlsTimer();
    }
    setState(() {});
  }

  void _toggleMute() {
    widget.globalAudioService.toggleGlobalMute();
    setState(() {});
  }

  void _seekRelative(Duration offset) {
    if (!_isControllerValid) return;
    final current = widget.controller.value.position;
    widget.controller.seekTo(current + offset);
    _startHideControlsTimer();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isControllerValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    final value = widget.controller.value;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),

            // Controls overlay
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0.0, 0.2, 0.8, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            _FullscreenButton(
                              icon: CupertinoIcons.xmark,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            const Spacer(),
                            _FullscreenButton(
                              icon: widget.globalAudioService.isGloballyMuted
                                  ? CupertinoIcons.speaker_slash_fill
                                  : CupertinoIcons.speaker_2_fill,
                              onTap: _toggleMute,
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Center controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FullscreenButton(
                            icon: CupertinoIcons.gobackward_10,
                            onTap: () =>
                                _seekRelative(const Duration(seconds: -10)),
                            size: 48,
                          ),
                          const SizedBox(width: 40),
                          _FullscreenButton(
                            icon: value.isPlaying
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            onTap: _togglePlayPause,
                            size: 72,
                            isPrimary: true,
                          ),
                          const SizedBox(width: 40),
                          _FullscreenButton(
                            icon: CupertinoIcons.goforward_10,
                            onTap: () =>
                                _seekRelative(const Duration(seconds: 10)),
                            size: 48,
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Bottom bar with progress
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 20,
                              child: VideoProgressIndicator(
                                widget.controller,
                                allowScrubbing: true,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                colors: VideoProgressColors(
                                  playedColor: AppTheme.primaryColor,
                                  bufferedColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.3),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(value.position),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                                Text(
                                  _formatDuration(value.duration),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Button for fullscreen controls
class _FullscreenButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool isPrimary;

  const _FullscreenButton({
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isPrimary
              ? AppTheme.primaryColor
              : Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}
