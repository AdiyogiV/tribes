import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/posts/post_header.dart';
import 'package:aurogram/widgets/posts/post_options_sheet.dart';
import 'package:aurogram/widgets/posts/post_action_toolbar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';

/// Image note player matching TransparentToolbox style
/// - Card with elevation 4
/// - Image area with its own elevation
/// - All text in primary color
/// - Tap to view full screen
class ImageNotePlayer extends StatefulWidget {
  final String? author;
  final String? space;
  final String imageUrl;
  final String? postId;
  final String? title;
  final String? link;
  final Timestamp? timestamp;
  final String? label;
  final Color? labelColor;
  final bool hasContentBelow;
  final bool isProfilePost;
  final Widget? contentAfterHeader;

  final bool showHeader;
  final bool showToolbar;

  // NEW: Pre-loaded user/space data for instant header rendering
  final dynamic userData;
  final dynamic spaceData;

  // Pre-loaded aspect ratio to avoid resize
  final double? aspectRatio;

  const ImageNotePlayer({
    super.key,
    this.postId,
    this.space,
    this.author,
    required this.imageUrl,
    this.title,
    this.link,
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
    this.aspectRatio,
  });

  @override
  State<ImageNotePlayer> createState() => _ImageNotePlayerState();
}

class _ImageNotePlayerState extends State<ImageNotePlayer> {
  bool _isVisible = false;

  double get _aspectRatio => widget.aspectRatio ?? 16 / 9;

  @override
  void didUpdateWidget(ImageNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL: Prevent rebuilds when parent rebuilds but our postId/imageUrl hasn't changed
    if (oldWidget.postId == widget.postId &&
        oldWidget.imageUrl == widget.imageUrl &&
        oldWidget.title == widget.title) {
      // Same post, same content - no rebuild needed
      return;
    }
  }

  void _handleVisibility(VisibilityInfo info) {
    if (!mounted) return;
    final nowVisible = info.visibleFraction > 0.7;
    if (_isVisible != nowVisible) setState(() => _isVisible = nowVisible);
    // Note: markPostAsSeen removed - seen tracking deprecated in pull-based feed
  }

  void _showMoreOptions() {
    if (widget.postId == null) return;
    showPostOptionsSheet(
      context: context,
      postId: widget.postId!,
      authorId: widget.author,
    );
  }

  void _viewFullScreenImage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
          imageUrl: widget.imageUrl,
          title: widget.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Card styling (background, border radius, shadow) handled by parent (PostSwitcher)
    return VisibilityDetector(
      key: ValueKey('image_${widget.postId}'),
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

            // Image area with elevation and curved borders (matching thumbnail)
            // Use AspectRatio to size container to image's natural dimensions
            LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                return Material(
                  color: Colors.transparent,
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                      AppHeaderStyle.postMediaBorderRadius),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                        AppHeaderStyle.postMediaBorderRadius),
                    child: GestureDetector(
                      onTap: _viewFullScreenImage,
                      child: SizedBox(
                        width: maxWidth,
                        child: AspectRatio(
                          aspectRatio: _aspectRatio,
                          child: CachedNetworkImage(
                            imageUrl: widget.imageUrl,
                            fit: BoxFit.contain,
                            // Update aspect ratio when image loads (minimal resize from 16:9 default)
                            imageBuilder: (context, imageProvider) {
                              return Image(
                                image: imageProvider,
                                fit: BoxFit.contain,
                              );
                            },
                            placeholder: (context, url) =>
                                ShimmerImagePlaceholder(
                              borderRadius:
                                  AppHeaderStyle.postMediaBorderRadius,
                            ),
                            errorWidget: (context, url, error) => Container(
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[200],
                              child: Center(
                                child: Icon(
                                  CupertinoIcons.photo,
                                  size: 48,
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
          ],
        ),
      ),
    );
  }
}

/// Full screen image viewer with pinch-to-zoom
class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? title;

  const _FullScreenImageViewer({
    required this.imageUrl,
    this.title,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: widget.title != null
            ? Text(
                widget.title!,
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CupertinoActivityIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
