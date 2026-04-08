import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/posts/post_header.dart';
import 'package:aurogram/widgets/posts/post_options_sheet.dart';
import 'package:aurogram/widgets/posts/post_action_toolbar.dart';
import 'package:aurogram/widgets/posts/quoted_post_preview.dart';
import 'package:aurogram/pages/content/thread_view.dart';
import 'package:aurogram/utils/chat/markdown_utils.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Clean text note player matching TransparentToolbox style
/// - Card with elevation 4
/// - Content area with its own elevation
/// - All text in primary color
class TextNotePlayer extends StatefulWidget {
  final String? author;
  final String? space;
  final String content;
  final String? postId;
  final String? title;
  final String? link;
  final Timestamp? timestamp;
  final String? label;
  final Color? labelColor;
  final bool hasContentBelow;
  final bool isProfilePost;
  final Widget? contentAfterHeader;
  final Map<String, dynamic>? quotedPostData;
  final String? quotedPostId;

  final bool showHeader;
  final bool showToolbar;

  // NEW: Pre-loaded user/space data for instant header rendering
  final dynamic userData;
  final dynamic spaceData;

  const TextNotePlayer({
    super.key,
    this.postId,
    this.space,
    this.author,
    required this.content,
    this.title,
    this.link,
    this.timestamp,
    this.label,
    this.labelColor,
    this.hasContentBelow = false,
    this.isProfilePost = false,
    this.contentAfterHeader,
    this.quotedPostData,
    this.quotedPostId,
    this.showHeader = true,
    this.showToolbar = true,
    this.userData,
    this.spaceData,
  });

  @override
  State<TextNotePlayer> createState() => _TextNotePlayerState();
}

class _TextNotePlayerState extends State<TextNotePlayer> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(TextNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL: Prevent rebuilds when parent rebuilds but our postId/content hasn't changed
    if (oldWidget.postId == widget.postId &&
        oldWidget.content == widget.content &&
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Card styling (background, border radius, shadow) handled by parent (PostSwitcher)
    return VisibilityDetector(
      key: ValueKey('text_${widget.postId}'),
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

            // Content area with elevation - rectangle, no curved clip
            Material(
              color: isDark ? AppTheme.previewDarkColor : AppTheme.previewLightColor,
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.title != null && widget.title!.isNotEmpty) ...[
                      Text(
                        widget.title!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                    ],

                    // Content with markdown support and no line limit
                    MarkdownUtils.buildRichContent(
                      widget.content,
                      context,
                      textColor: isDark
                          ? Colors.white
                          : AppTheme.primaryColor.withValues(alpha: 0.85),
                    ),
                    if (widget.quotedPostData != null) ...[
                      QuotedPostPreview(
                        quotedPostData: widget.quotedPostData!,
                        onTap: widget.quotedPostId != null
                            ? () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (_) => ThreadView(
                                        postId: widget.quotedPostId!),
                                  ),
                                );
                              }
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
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
