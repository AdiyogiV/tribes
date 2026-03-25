import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/services/audio_service.dart';
import 'package:aurogram/services/global_audio_service.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/services/media/media_compression_service.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/media_type_selector.dart';
import 'package:aurogram/widgets/postHeader.dart';
import 'package:aurogram/widgets/Dialogs/login_bottom_sheet.dart';
import 'package:aurogram/widgets/Dialogs/postDailog.dart';

/// Simple video player for feed
/// - User must tap to play (no auto-play)
/// - Pauses automatically when scrolling away
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

  const MainPlayer({
    Key? key,
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
  }) : super(key: key);

  @override
  State<MainPlayer> createState() => _MainPlayerState();
}

class _MainPlayerState extends State<MainPlayer> with WidgetsBindingObserver {
  // Controller owned exclusively by this widget
  VideoPlayerController? _controller;
  bool _isDisposed = false;
  bool _isInitializing = false;
  bool _isVisible = false;

  // Thumbnail
  ImageProvider? _thumbnailImage;
  double? _thumbnailAspectRatio;
  bool? _previousUploadingStatus;

  // Services
  late GlobalAudioService _globalAudioService;

  // Counters
  int _replyCount = 0;
  int _likeCount = 0;
  bool _isLiked = false;

  User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _previousUploadingStatus = widget.uploading;
    _globalAudioService = locator<GlobalAudioService>();
    _globalAudioService.addListener(_onGlobalAudioStateChanged);
    _loadThumbnail();
    _loadCounters();
  }

  @override
  void didUpdateWidget(MainPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uploading != _previousUploadingStatus) {
      _previousUploadingStatus = widget.uploading;
    }
    if (widget.thumbnail != oldWidget.thumbnail) _loadThumbnail();
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
    WidgetsBinding.instance.removeObserver(this);
    _globalAudioService.removeListener(_onGlobalAudioStateChanged);
    _disposeController();
    super.dispose();
  }

  /// Dispose the controller safely
  void _disposeController() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        controller.pause();
        controller.dispose();
      } catch (e) {
        // Already disposed
      }
    }
  }

  /// Check if controller is valid and initialized
  bool get _hasValidController {
    if (_isDisposed || _controller == null) return false;
    try {
      return _controller!.value.isInitialized;
    } catch (e) {
      return false;
    }
  }

  /// Pause video safely
  void _pauseVideo() {
    if (!_hasValidController) return;
    try {
      _controller!.pause();
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _loadCounters() async {
    if (widget.postId == null) return;
    try {
      final db = DatabaseService();
      final replies = await db.getPostReplies(widget.postId!);
      final likes = await db.getLikeCount(widget.postId!);
      final isLiked = await db.isPostLikedByUser(widget.postId);
      if (mounted) {
        setState(() {
          _replyCount = replies.docs.length;
          _likeCount = likes;
          _isLiked = isLiked;
        });
      }
    } catch (_) {}
  }

  void _loadThumbnail() {
    final thumb = widget.thumbnail;

    if (thumb != null && thumb.isNotEmpty) {
      if (thumb.startsWith('http')) {
        _setThumbnail(NetworkImage(thumb));
        return;
      }
      final path = thumb.startsWith('file://') ? thumb.substring(7) : thumb;
      if (path.isNotEmpty) {
        final file = File(path);
        if (file.existsSync()) {
          _setThumbnail(FileImage(file));
          return;
        }
      }
    }

    if (widget.uploading == true && widget.postId != null) {
      MediaCompressionService()
          .getPostProgress(widget.postId!)
          .then((progress) {
        if (!mounted || progress == null) return;
        final progressThumb = progress['thumbnailPath'] as String?;
        if (progressThumb != null && progressThumb.isNotEmpty) {
          if (progressThumb.startsWith('http')) {
            _setThumbnail(NetworkImage(progressThumb));
          } else {
            final localPath = progressThumb.startsWith('file://')
                ? progressThumb.substring(7)
                : progressThumb;
            final file = File(localPath);
            if (file.existsSync()) _setThumbnail(FileImage(file));
          }
        }
      });
    }
  }

  void _setThumbnail(ImageProvider image) {
    if (!mounted) return;
    setState(() => _thumbnailImage = image);
    _resolveThumbnailAspectRatio(image);
  }

  void _resolveThumbnailAspectRatio(ImageProvider image) {
    final stream = image.resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (w > 0 && h > 0) setState(() => _thumbnailAspectRatio = w / h);
      stream.removeListener(listener!);
    }, onError: (_, __) {
      try {
        stream.removeListener(listener!);
      } catch (_) {}
    });
    stream.addListener(listener);
  }

  /// Initialize and play video - only called when user taps play
  Future<void> _initializeAndPlay() async {
    if (_isDisposed || _isInitializing) return;
    if (widget.uploading == true ||
        widget.videoUrl == null ||
        widget.videoUrl!.isEmpty) {
      return;
    }

    // If already initialized, just play
    if (_hasValidController) {
      try {
        _controller!.play();
        if (mounted) setState(() {});
        return;
      } catch (e) {
        _disposeController();
      }
    }

    _isInitializing = true;
    if (mounted) setState(() {});

    try {
      await AudioService().requestAudioFocus();
      final cacheService = locator<CacheService>();
      final file = await cacheService.getFilefromCache(widget.videoUrl!);

      if (_isDisposed) return;

      final controller = file != null
          ? VideoPlayerController.file(file.file,
              videoPlayerOptions: VideoPlayerOptions(
                  allowBackgroundPlayback: false, mixWithOthers: true))
          : VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!),
              videoPlayerOptions: VideoPlayerOptions(
                  allowBackgroundPlayback: false, mixWithOthers: true));

      if (file == null) cacheService.downloadFile(widget.videoUrl!);

      await controller.initialize();

      if (_isDisposed) {
        controller.dispose();
        return;
      }

      await controller.setLooping(false);
      await controller.setVolume(_globalAudioService.getEffectiveVolume());

      _controller = controller;
      controller.play();
      DatabaseService().markPostAsSeen(widget.postId);

      AppLogger.i('MainPlayer: Initialized video for ${widget.postId}',
          category: LogCategory.media);
    } catch (e) {
      AppLogger.e('MainPlayer: Init failed for ${widget.postId}',
          category: LogCategory.media, error: e);
    } finally {
      _isInitializing = false;
      if (mounted) setState(() {});
    }
  }

  void _handleVisibility(VisibilityInfo info) {
    if (_isDisposed) return;
    final nowVisible = info.visibleFraction > 0.5;

    if (_isVisible != nowVisible) {
      _isVisible = nowVisible;

      // Pause video when scrolling away
      if (!nowVisible && _hasValidController) {
        _pauseVideo();
      }

      // Do NOT auto-resume when scrolling back - user must tap to play

      if (mounted) setState(() {});
    }
  }

  void _onGlobalAudioStateChanged() {
    if (_isDisposed || !_hasValidController) return;
    try {
      _controller!.setVolume(_globalAudioService.getEffectiveVolume());
      if (mounted) setState(() {});
    } catch (e) {
      // Ignore
    }
  }

  void _toggleMute() => _globalAudioService.toggleGlobalMute();

  void _togglePlayPause() {
    if (!_hasValidController) {
      _initializeAndPlay();
      return;
    }

    try {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      if (mounted) setState(() {});
    } catch (e) {
      _disposeController();
      _initializeAndPlay();
    }
  }

  void _toggleLike() {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.status != Status.Authenticated) {
      _showLoginDialog();
      return;
    }
    if (widget.postId == null) return;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    DatabaseService().likePost(widget.postId!);
  }

  void _openReply() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.status != Status.Authenticated) {
      _showLoginDialog();
      return;
    }
    if (widget.postId == null) return;

    final postDbService = PostDbService();
    String? space = await postDbService.getPostSpace(widget.postId!);

    if (mounted) {
      MediaTypeSelector.showMediaTypeSelection(
        context: context,
        space: space ?? widget.space ?? '',
        replyTo: widget.postId,
      );
    }
  }

  void _openLink() async {
    final rawLink = widget.link?.trim();
    if (rawLink == null || rawLink.isEmpty) return;

    Uri? uri = Uri.tryParse(rawLink);
    if (uri == null || uri.scheme.isEmpty) {
      uri = Uri.tryParse('https://$rawLink');
    }

    if (uri != null) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }
  }

  void _showMoreOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => PostDialog(
        post: widget.postId,
        author: widget.author,
      ),
    );
  }

  void _showLoginDialog() {
    showLoginBottomSheet(context);
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

    Navigator.of(context)
        .push(
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
    )
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  double _getAspectRatio() {
    if (_hasValidController) {
      try {
        return _controller!.value.aspectRatio;
      } catch (e) {
        // Ignore
      }
    }
    if (_thumbnailAspectRatio != null) return _thumbnailAspectRatio!;
    return 9.0 / 16.0;
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideoReady = _hasValidController;

    return VisibilityDetector(
      key: ValueKey('video_${widget.postId ?? widget.videoUrl}'),
      onVisibilityChanged: _handleVisibility,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            PostHeader(
              uid: widget.author,
              space: widget.space,
              timestamp: widget.timestamp,
              label: widget.label,
              labelColor: widget.labelColor,
              isProfilePost: widget.isProfilePost,
            ),

            const SizedBox(height: 10),

            // Video content
            Material(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F6F2),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: _buildVideoArea(isVideoReady, isDark),
            ),

            // Title
            if (widget.title != null && widget.title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  widget.title!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const SizedBox(height: 10),

            // Toolbar
            _buildToolbar(isVideoReady, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoArea(bool isVideoReady, bool isDark) {
    final aspectRatio = _getAspectRatio();

    // Get play state safely
    bool isPlaying = false;
    if (isVideoReady) {
      try {
        isPlaying = _controller!.value.isPlaying;
      } catch (e) {
        isVideoReady = false;
      }
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video or thumbnail
          if (isVideoReady)
            GestureDetector(
              onTap: _togglePlayPause,
              child: VideoPlayer(_controller!),
            )
          else if (_thumbnailImage != null)
            GestureDetector(
              onTap: _togglePlayPause,
              child: Image(
                image: _thumbnailImage!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
              ),
            )
          else
            GestureDetector(
              onTap: _togglePlayPause,
              child: _buildPlaceholder(isDark),
            ),

          // Uploading overlay
          if (widget.uploading == true)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const ShimmerLoadingOverlay(text: 'Uploading...'),
            ),

          // Play button - shown when video not playing
          if (!isPlaying)
            GestureDetector(
              onTap: _togglePlayPause,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: _isInitializing
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
              ),
            ),

          // Progress bar
          if (isVideoReady)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 4,
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: AppTheme.primaryColor,
                    bufferedColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isVideoReady, bool isDark) {
    return Row(
      children: [
        // Like button
        _ToolbarButton(
          icon: _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
          label: _likeCount > 0 ? _formatCount(_likeCount) : null,
          isActive: _isLiked,
          onTap: _toggleLike,
        ),

        const SizedBox(width: 16),

        // Reply button
        _ToolbarButton(
          icon: Icons.reply_outlined,
          label: _replyCount > 0 ? _formatCount(_replyCount) : null,
          onTap: _openReply,
        ),

        if (widget.link != null && widget.link!.isNotEmpty) ...[
          const SizedBox(width: 16),
          _ToolbarButton(
            icon: CupertinoIcons.link,
            onTap: _openLink,
          ),
        ],

        const Spacer(),

        // Mute button
        if (isVideoReady)
          _ToolbarButton(
            icon: _globalAudioService.isGloballyMuted
                ? CupertinoIcons.speaker_slash_fill
                : CupertinoIcons.speaker_2_fill,
            onTap: _toggleMute,
          ),

        if (isVideoReady) const SizedBox(width: 8),

        // Fullscreen button
        if (isVideoReady)
          _ToolbarButton(
            icon: CupertinoIcons.fullscreen,
            onTap: _openFullscreen,
          ),

        const SizedBox(width: 8),

        // More button
        _ToolbarButton(
          icon: CupertinoIcons.ellipsis,
          onTap: _showMoreOptions,
        ),
      ],
    );
  }

  Widget _buildPlaceholder(bool isDark) {
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
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.barnRed : AppTheme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
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
