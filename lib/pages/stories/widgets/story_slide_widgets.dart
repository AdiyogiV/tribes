import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Displays a single story image with CachedNetworkImage.
/// Calls [onReady] when the image is fully loaded and ready to display.
class StoryImageSlide extends StatefulWidget {
  final String storyId;
  final String imageUrl;
  final VoidCallback onReady;
  final bool isPostCard;

  const StoryImageSlide({
    super.key,
    required this.storyId,
    required this.imageUrl,
    required this.onReady,
    this.isPostCard = false,
  });

  @override
  State<StoryImageSlide> createState() => _StoryImageSlideState();
}

class _StoryImageSlideState extends State<StoryImageSlide> {
  bool _hasCalledReady = false;
  String? _lastImageUrl;

  @override
  void initState() {
    super.initState();
    _lastImageUrl = widget.imageUrl;
  }

  @override
  void didUpdateWidget(StoryImageSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _hasCalledReady = false;
      _lastImageUrl = widget.imageUrl;
    }
  }

  void _notifyReady() {
    if (!_hasCalledReady && mounted && _lastImageUrl == widget.imageUrl) {
      _hasCalledReady = true;
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
            color: AppTheme.pitchBlack,
            child: const AppLoadingIndicator(color: Colors.white),
          );
        }
        final fit = widget.isPostCard ? BoxFit.contain : BoxFit.cover;
        return Container(
          width: w,
          height: h,
          color: AppTheme.pitchBlack,
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            width: w,
            height: h,
            fit: fit,
            alignment: Alignment.center,
            memCacheWidth: (w * 2).toInt(),
            memCacheHeight: (h * 2).toInt(),
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            placeholder: (_, __) => Container(color: AppTheme.pitchBlack),
            imageBuilder: (context, imageProvider) {
              _notifyReady();
              return Container(
                color: AppTheme.pitchBlack,
                width: w,
                height: h,
                child: Image(
                  image: imageProvider,
                  width: w,
                  height: h,
                  fit: fit,
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
              _notifyReady();
              return Container(
                color: AppTheme.pitchBlack,
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.white, size: 48),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Displays a single story video with VideoPlayerController.
/// Calls [onInitialized] when the video is ready to play.
class StoryVideoSlide extends StatefulWidget {
  final String url;
  final String storyId;
  final VoidCallback? onInitialized;
  final void Function(VideoPlayerController?)? controllerCallback;

  const StoryVideoSlide({
    super.key,
    required this.url,
    required this.storyId,
    this.onInitialized,
    this.controllerCallback,
  });

  @override
  State<StoryVideoSlide> createState() => _StoryVideoSlideState();
}

class _StoryVideoSlideState extends State<StoryVideoSlide> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller!.initialize().then((_) {
      widget.controllerCallback?.call(_controller);
      if (mounted) {
        setState(() {});
        _controller?.play();
        widget.onInitialized?.call();
      }
    }).catchError((e, st) {
      AppLogger.e('StoryViewer: video init failed',
          category: LogCategory.general, error: e, stackTrace: st,
          data: {'storyId': widget.storyId});
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
        color: AppTheme.pitchBlack,
        child: const AppLoadingIndicator(color: Colors.white),
      );
    }
    return Container(
      color: AppTheme.pitchBlack,
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
