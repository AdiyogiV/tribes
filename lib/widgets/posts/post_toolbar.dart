import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/media_type_selector.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/posts/post_options_sheet.dart';
import 'package:aurogram/services/share_service.dart';
import 'package:aurogram/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/services/repost_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Clean, minimal post toolbar matching TransparentToolbox style
/// Single row with subtle icons - no borders
class PostToolbar extends StatefulWidget {
  final String? postId;
  final String? author;
  final String? link;

  const PostToolbar({
    super.key,
    this.postId,
    this.author,
    this.link,
  });

  @override
  State<PostToolbar> createState() => _PostToolbarState();
}

class _PostToolbarState extends State<PostToolbar> {
  int _replyCount = 0;
  int _likeCount = 0;
  int _repostCount = 0;
  bool _isLiked = false;
  bool _isReposted = false;
  bool _isLoading = true;

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
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
        space: space ?? '',
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
      } catch (_) {
        AppLogger.w('PostToolbar: failed to launch URL', category: LogCategory.general);
      }
    }
  }

  void _repostPost() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.status != Status.Authenticated) {
      _showLoginDialog();
      return;
    }
    if (widget.postId == null) return;
    if (_isReposted) {
      await RepostService().undoRepost(widget.postId!, null);
      if (mounted) {
        final reposts = await DatabaseService().getRepostCount(widget.postId!);
        setState(() {
          _isReposted = false;
          _repostCount = reposts;
        });
      }
      return;
    }
    await showRepostFlow(
      context,
      postId: widget.postId!,
      authorId: widget.author,
    );
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
    await ShareService.sharePost(
      context: context,
      postId: widget.postId!,
    );
  }

  void _showMoreOptions() {
    if (widget.postId == null) return;
    showPostOptionsSheet(
      context: context,
      postId: widget.postId!,
      authorId: widget.author,
    );
  }

  void _showLoginDialog() {
    showLoginBottomSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark
        ? AppTheme.textSecondaryDarkColor
        : AppTheme.textSecondaryLightColor;

    if (_isLoading) {
      return const SizedBox(height: 48);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          // Like button
          _ActionButton(
            icon: _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            label: _likeCount > 0 ? _formatCount(_likeCount) : null,
            color: _isLiked ? AppTheme.barnRed : iconColor,
            onTap: _toggleLike,
          ),

          const SizedBox(width: AppDimensions.spacingXl),

          // Reply button
          _ActionButton(
            icon: Icons.reply_outlined,
            label: _replyCount > 0 ? _formatCount(_replyCount) : null,
            color: iconColor,
            onTap: _openReply,
          ),

          if (widget.link != null && widget.link!.isNotEmpty) ...[
            const SizedBox(width: AppDimensions.spacingXl),
            _ActionButton(
              icon: CupertinoIcons.link,
              color: AppTheme.primaryColor,
              onTap: _openLink,
            ),
          ],

          const SizedBox(width: AppDimensions.spacingXl),

          // Repost button (green when already reposted, with count)
          _ActionButton(
            icon: CupertinoIcons.arrow_2_squarepath,
            label: _repostCount > 0 ? _formatCount(_repostCount) : null,
            color: _isReposted ? AppTheme.successColor : iconColor,
            onTap: _repostPost,
            iconSize: 18,
          ),

          const SizedBox(width: AppDimensions.spacingXl),

          // Share button
          _ActionButton(
            icon: CupertinoIcons.paperplane_fill,
            color: iconColor,
            onTap: _sharePost,
            iconSize: 18,
          ),

          const Spacer(),

          // More button
          _ActionButton(
            icon: CupertinoIcons.ellipsis,
            color: iconColor,
            onTap: _showMoreOptions,
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;
  final double? iconSize;

  const _ActionButton({
    required this.icon,
    this.label,
    required this.color,
    required this.onTap,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize ?? 22, color: color),
            if (label != null) ...[
              const SizedBox(width: AppDimensions.spacingSmMd),
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
