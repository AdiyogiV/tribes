import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/media_type_selector.dart';
import 'package:aurogram/widgets/postHeader.dart';
import 'package:aurogram/widgets/Dialogs/login_bottom_sheet.dart';
import 'package:aurogram/widgets/Dialogs/postDailog.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/services/data/post_db_service.dart';

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

  const TextNotePlayer({
    Key? key,
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
  }) : super(key: key);

  @override
  State<TextNotePlayer> createState() => _TextNotePlayerState();
}

class _TextNotePlayerState extends State<TextNotePlayer> {
  bool _isVisible = false;
  int _likeCount = 0;
  int _replyCount = 0;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _loadCounters();
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

  void _handleVisibility(VisibilityInfo info) {
    if (!mounted) return;
    final nowVisible = info.visibleFraction > 0.7;
    if (_isVisible != nowVisible) setState(() => _isVisible = nowVisible);
    if (nowVisible && widget.postId != null) {
      DatabaseService().markPostAsSeen(widget.postId);
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

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Card styling (background, border radius, shadow) handled by parent (PostSwitcher)
    return VisibilityDetector(
      key: ValueKey('text_${widget.postId}'),
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
                isProfilePost: widget.isProfilePost,
                label: widget.label,
                labelColor: widget.labelColor,
              ),

              const SizedBox(height: 10),

              // Content area with elevation
              Material(
                color: isDark ? const Color(0xFF2A2520) : const Color(0xFFFFFBE8),
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.title != null && widget.title!.isNotEmpty) ...[
                        Text(
                          widget.title!,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Content
                      Text(
                        widget.content,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: AppTheme.primaryColor.withValues(alpha: 0.85),
                        ),
                        maxLines: 12,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Toolbar
              Row(
                children: [
                  _ToolbarButton(
                    icon: _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    label: _likeCount > 0 ? _formatCount(_likeCount) : null,
                    isActive: _isLiked,
                    onTap: _toggleLike,
                  ),
                  const SizedBox(width: 16),
                  _ToolbarButton(
                    icon: Icons.reply_outlined,
                    label: _replyCount > 0 ? _formatCount(_replyCount) : null,
                    onTap: _openReply,
                  ),
                  if (widget.link != null && widget.link!.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    _ToolbarButton(icon: CupertinoIcons.link, onTap: _openLink),
                  ],
                  const Spacer(),
                  _ToolbarButton(icon: CupertinoIcons.ellipsis, onTap: _showMoreOptions),
                ],
              ),
            ],
          ),
        ),
    );
  }
}

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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
