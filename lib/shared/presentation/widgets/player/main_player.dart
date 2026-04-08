import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/shared/services/media/audio_service.dart';
import 'package:aurogram/shared/services/media/global_audio_service.dart';
import 'package:aurogram/services/feed_video_focus_service.dart';
import 'package:aurogram/shared/services/media/video_controller_pool.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:aurogram/features/feed/presentation/pages/feed_controller.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_header.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_options_sheet.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_action_toolbar.dart';
import 'package:aurogram/shared/presentation/widgets/player/player_controls.dart';
import 'package:aurogram/shared/presentation/widgets/player/player_fullscreen.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

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
  void _setupLazyInitialization() {
    // Do nothing - VisibilityDetector in _handleVisibility will trigger init
  }

  @override
  void didUpdateWidget(MainPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.postId == widget.postId &&
        oldWidget.videoUrl == widget.videoUrl &&
        oldWidget.uploading == widget.uploading) {
      return;
    }
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

      if (mounted) {
        try {
          final feedController = context.read<FeedController>();

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
  bool get _hasValidController {
    if (_isDisposed || _controller == null) return false;
    try {
      final controller = _controller!;
      final value = controller.value;
      return value.isInitialized;
    } catch (e) {
      _controller = null;
      _hasAttemptedInit = false;
      if (!_isDisposed) {
        try {
          _isControllerReadyNotifier.value = false;
        } catch (_) {}
      }
      return false;
    }
  }

  /// Pause video safely
  void _pauseVideo() {
    if (_isDisposed || !mounted) return;
    if (!_hasValidController) return;
    try {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        controller.pause();
      }
    } catch (e) {
      _controller = null;
    }
  }

  /// Initialize controller without auto-playing
  Future<void> _initializeController() async {
    if (_isDisposed || _isInitializingNotifier.value || _hasValidController) {
      return;
    }
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
        return;
      }
    }

    final startTime = DateTime.now();

    try {
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

      _controller = controller;
      if (!_isDisposed) {
        try {
          _isControllerReadyNotifier.value = true;
        } catch (e) {
          // Already disposed
        }
      }

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
    if (_isDisposed || !mounted) return;
    _lastVisibleFraction = info.visibleFraction;

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
        if (_hasValidController) {
          _pauseVideo();
        } else if (_controller != null) {
          AppLogger.w('MainPlayer: Controller ref invalid, clearing', category: LogCategory.media);
          _controller = null;
          _hasAttemptedInit = false;
        }
      }

      if (nowVisible && widget.enableVideoAutoplay && widget.postId != null) {
        locator<FeedVideoFocusService>().requestFocus(widget.postId);
        if (_hasValidController) {
          try {
            _controller!.play();
          } catch (e) {
            AppLogger.w('MainPlayer: Controller disposed, re-initializing', category: LogCategory.media);
            _controller = null;
            _hasAttemptedInit = false;
            _initializeController();
          }
        } else if (_controller != null) {
          AppLogger.w('MainPlayer: Stale controller ref, re-initializing', category: LogCategory.media);
          _controller = null;
          _hasAttemptedInit = false;
          _initializeController();
        } else {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!mounted || _isDisposed) return;
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
    } catch (e) {
      // Ignore
    }
  }

  void _toggleMute() => _globalAudioService.toggleGlobalMute();

  void _togglePlayPause() {
    if (widget.postId != null && widget.postId!.isNotEmpty) {
      locator<FeedVideoFocusService>().requestFocus(widget.postId);
    }

    if (!_hasValidController) {
      _initializeController().then((_) {
        if (mounted && _hasValidController) {
          final hasFocus = widget.postId != null
              ? locator<FeedVideoFocusService>().hasFocus(widget.postId)
              : true;
          if (hasFocus) {
            try {
              AudioService().requestAudioFocus();
              _controller!.play();
            } catch (_) {
              AppLogger.w('MainPlayer: failed to play video after focus',
                  category: LogCategory.general);
            }
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
      if (_controller != null) {
        try {
          _controller!.removeListener(_onPlayStateChanged);
        } catch (_) {
          AppLogger.w(
              'MainPlayer: failed to remove listener from disposed controller',
              category: LogCategory.general);
        }
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
          return FullscreenVideoPage(
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
    return 9.0 / 16.0;
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

            if (widget.contentAfterHeader != null) widget.contentAfterHeader!,

            ValueListenableBuilder<bool>(
              valueListenable: _isControllerReadyNotifier,
              builder: (context, isVideoReady, child) {
                return Material(
                  color: isDark
                      ? AppTheme.nearBlackColor
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
              const SizedBox(height: AppDimensions.spacingSm),
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

            Positioned.fill(
              child: GestureDetector(
                onTap: _togglePlayPause,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),

            if (widget.uploading == true)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: const ShimmerLoadingOverlay(text: 'Uploading...'),
              ),

            ValueListenableBuilder<bool>(
              valueListenable: _isPlayingNotifier,
              builder: (context, isPlaying, child) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _isInitializingNotifier,
                  builder: (context, isInitializing, child) {
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
                                  padding: EdgeInsets.all(AppDimensions.paddingLg),
                                  child: AppLoadingIndicator(
                                    color: Colors.white,
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
                        return VideoOverlayButton(
                          icon: _globalAudioService.isGloballyMuted
                              ? CupertinoIcons.speaker_slash_fill
                              : CupertinoIcons.speaker_2_fill,
                          onTap: _toggleMute,
                        );
                      },
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    VideoOverlayButton(
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
              ? [AppTheme.darkElevatedSurface, AppTheme.nearBlackColor]
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
