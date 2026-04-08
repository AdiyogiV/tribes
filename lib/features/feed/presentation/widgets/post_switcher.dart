// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/features/feed/presentation/widgets/post.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';

/// Thin wrapper around Post for the feed. Only handles known-missing early exit;
/// Post owns all data fetching and the full block (content + reply section + time).
class PostSwitcher extends StatefulWidget {
  final String postId;
  final int itemIndex;
  final void Function(String postId)? onOpenThread;
  final bool enableVideoAutoplay;
  final bool prewarmVideo;

  const PostSwitcher({
    super.key,
    required this.postId,
    required this.itemIndex,
    this.onOpenThread,
    this.enableVideoAutoplay = false,
    this.prewarmVideo = false,
  });

  @override
  _PostSwitcherState createState() => _PostSwitcherState();
}

class _PostSwitcherState extends State<PostSwitcher> {
  @override
  void didUpdateWidget(PostSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL: Prevent rebuilds when parent rebuilds but our postId hasn't changed
    // This is essential for scroll performance - stops FeedController rebuilds from cascading
    if (oldWidget.postId == widget.postId &&
        oldWidget.enableVideoAutoplay == widget.enableVideoAutoplay &&
        oldWidget.prewarmVideo == widget.prewarmVideo) {
      // Same post, same config - no rebuild needed
      return;
    }

    // PostId changed (widget recycled) or autoplay config changed - let child rebuild
  }

  @override
  Widget build(BuildContext context) {
    if (locator<PostDbService>().isPostKnownMissing(widget.postId)) {
      return const PostUnavailableCard();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    const double absoluteMaxWidth = 500.0;
    final cardWidth = screenWidth.clamp(0.0, absoluteMaxWidth);

    return Center(
      child: ConstrainedBox(
        key: ValueKey('flat_${widget.postId}'),
        constraints: BoxConstraints(maxWidth: cardWidth),
        child: Post(
          key: ValueKey('post_${widget.postId}'),
          post: widget.postId,
          itemIndex: widget.itemIndex,
          onReplySelected: widget.onOpenThread,
          enableVideoAutoplay: widget.enableVideoAutoplay,
          prewarmVideo: widget.prewarmVideo,
          showReplySection: true,
        ),
      ),
    );
  }
}
