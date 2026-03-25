import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/media_type_selector.dart';
import 'package:aurogram/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/widgets/posts/post_options_sheet.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/services/repost_service.dart';
import 'package:aurogram/services/share_service.dart';
import 'package:aurogram/controllers/feed_controller.dart';

/// Shared post action toolbar: like, reply, link?, repost, share.
/// Used by all post types (video, audio, text, image) for a single place to maintain behavior and UI.
/// Video-specific controls (mute, fullscreen) live on the video overlay, not here.
class PostActionToolbar extends StatefulWidget {
  final String? postId;
  final String? author;
  final String? space;
  final String? link;

  const PostActionToolbar({
    super.key,
    this.postId,
    this.author,
    this.space,
    this.link,
  });

  @override
  State<PostActionToolbar> createState() => _PostActionToolbarState();
}

class _PostActionToolbarState extends State<PostActionToolbar> {
  int _replyCount = 0;
  int _likeCount = 0;
  int _repostCount = 0;
  bool _isLiked = false;
  bool _isReposted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _hydrateFromFeedController();
    _loadCounters();
  }

  @override
  void didUpdateWidget(PostActionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload counters if postId changed
    if (oldWidget.postId != widget.postId) {
      _loadCounters();
    }
  }

  void _hydrateFromFeedController() {
    if (widget.postId == null) return;
    try {
      final feedController = context.read<FeedController>();
      final state = feedController.getPostState(widget.postId!);
      _replyCount = state.replyCount;
      _likeCount = state.likeCount;
      _isLiked = state.isLiked;
    } catch (_) {}
  }

  Future<void> _loadCounters() async {
    if (widget.postId == null) return;
    try {
      final db = DatabaseService();
      final replies = await db.getPostReplies(widget.postId!);
      final likes = await db.getLikeCount(widget.postId!);
      final reposts = await db.getRepostCount(widget.postId!);
      final isLiked = await db.isPostLikedByUser(widget.postId!);
      final isReposted = await RepostService().hasUserReposted(widget.postId!);
      if (mounted) {
        setState(() {
          _replyCount = replies.docs.length;
          _likeCount = likes;
          _repostCount = reposts;
          _isLiked = isLiked;
          _isReposted = isReposted;
          _isLoading = false;
        });
        _syncToFeedController();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncToFeedController() {
    if (widget.postId == null) return;
    try {
      final feedController = context.read<FeedController>();
      feedController.updateLike(widget.postId!, _likeCount, _isLiked);
      feedController.updateReplyCount(widget.postId!, _replyCount);
    } catch (_) {}
  }

  void _toggleLike() {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.status != Status.Authenticated) {
      showLoginBottomSheet(context);
      return;
    }
    if (widget.postId == null) return;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    DatabaseService().likePost(widget.postId!);
    _syncToFeedController();
  }

  void _openReply() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.status != Status.Authenticated) {
      showLoginBottomSheet(context);
      return;
    }
    if (widget.postId == null) return;
    final postDbService = PostDbService();
    final space = await postDbService.getPostSpace(widget.postId!);
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
    if (uri == null || uri.scheme.isEmpty)
      uri = Uri.tryParse('https://$rawLink');
    if (uri != null) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }
  }

  void _repostPost() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.status != Status.Authenticated) {
      showLoginBottomSheet(context);
      return;
    }
    if (widget.postId == null) return;

    // If already reposted, undo it
    if (_isReposted) {
      try {
        await RepostService().undoRepost(widget.postId!, null);
        // Refresh state after successful undo
        if (mounted) {
          final isReposted =
              await RepostService().hasUserReposted(widget.postId!);
          final reposts =
              await DatabaseService().getRepostCount(widget.postId!);
          setState(() {
            _isReposted = isReposted;
            _repostCount = reposts;
          });
        }
      } catch (e) {
        // If undo fails, refresh state to check actual status
        if (mounted) {
          final isReposted =
              await RepostService().hasUserReposted(widget.postId!);
          final reposts =
              await DatabaseService().getRepostCount(widget.postId!);
          setState(() {
            _isReposted = isReposted;
            _repostCount = reposts;
          });
        }
      }
      return;
    }

    // If not reposted, create repost
    try {
      await showRepostFlow(
        context,
        postId: widget.postId!,
        authorId: widget.author,
      );
    } catch (e) {
      // Error already shown in showRepostFlow, just refresh state
    }

    // Always refresh state after repost attempt (success or failure)
    if (mounted) {
      final isReposted = await RepostService().hasUserReposted(widget.postId!);
      final reposts = await DatabaseService().getRepostCount(widget.postId!);
      setState(() {
        _isReposted = isReposted;
        _repostCount = reposts;
      });
    }
  }

  void _sharePost() async {
    if (widget.postId == null) return;
    await ShareService.sharePost(context: context, postId: widget.postId!);
  }

  static String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark
        ? AppTheme.textSecondaryDarkColor
        : AppTheme.textSecondaryLightColor;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SizedBox(height: 40),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _PostToolbarButton(
            icon: _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            label: _likeCount > 0 ? _formatCount(_likeCount) : null,
            isActive: _isLiked,
            activeColor: AppTheme.barnRed,
            onTap: _toggleLike,
          ),
          const SizedBox(width: 8),
          _PostToolbarButton(
            icon: Icons.reply_outlined,
            label: _replyCount > 0 ? _formatCount(_replyCount) : null,
            color: iconColor,
            onTap: _openReply,
          ),
          if (widget.link != null && widget.link!.isNotEmpty) ...[
            const SizedBox(width: 8),
            _PostToolbarButton(
              icon: CupertinoIcons.link,
              color: AppTheme.primaryColor,
              onTap: _openLink,
            ),
          ],
          const SizedBox(width: 8),
          _PostToolbarButton(
            icon: CupertinoIcons.arrow_2_squarepath,
            label: _repostCount > 0 ? _formatCount(_repostCount) : null,
            isActive: _isReposted,
            activeColor: AppTheme.successColor,
            onTap: _repostPost,
            iconSize: 22,
          ),
          const SizedBox(width: 8),
          _PostToolbarButton(
            icon: CupertinoIcons.paperplane_fill,
            color: iconColor,
            onTap: _sharePost,
            iconSize: 22,
          ),
        ],
      ),
    );
  }
}

class _PostToolbarButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool isActive;
  final Color? color;
  final Color? activeColor;
  final VoidCallback onTap;
  final double? iconSize;

  const _PostToolbarButton({
    required this.icon,
    this.label,
    this.isActive = false,
    this.color,
    this.activeColor,
    required this.onTap,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = color ??
        (isDark
            ? AppTheme.textSecondaryDarkColor
            : AppTheme.textSecondaryLightColor);
    final resolvedColor =
        isActive ? (activeColor ?? AppTheme.barnRed) : defaultColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize ?? 22, color: resolvedColor),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: resolvedColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
