import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/media_type_selector.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/services/share_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/Dialogs/postDailog.dart';
import 'package:aurogram/widgets/Dialogs/login_bottom_sheet.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Clean, minimal post toolbar matching TransparentToolbox style
/// Single row with subtle icons - no borders
class PostToolbar extends StatefulWidget {
  final String? postId;
  final String? author;
  final String? link;

  const PostToolbar({
    Key? key,
    this.postId,
    this.author,
    this.link,
  }) : super(key: key);

  @override
  State<PostToolbar> createState() => _PostToolbarState();
}

class _PostToolbarState extends State<PostToolbar> {
  int _replyCount = 0;
  int _likeCount = 0;
  bool _isLiked = false;
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
      final isLiked = await db.isPostLikedByUser(widget.postId!);

      if (mounted) {
        setState(() {
          _replyCount = replies.docs.length;
          _likeCount = likes;
          _isLiked = isLiked;
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
      } catch (_) {}
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
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          // Like button
          _ActionButton(
            icon: _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            label: _likeCount > 0 ? _formatCount(_likeCount) : null,
            color: _isLiked ? AppTheme.barnRed : iconColor,
            onTap: _toggleLike,
          ),

          const SizedBox(width: 20),

          // Reply button
          _ActionButton(
            icon: Icons.reply_outlined,
            label: _replyCount > 0 ? _formatCount(_replyCount) : null,
            color: iconColor,
            onTap: _openReply,
          ),

          if (widget.link != null && widget.link!.isNotEmpty) ...[
            const SizedBox(width: 20),
            _ActionButton(
              icon: CupertinoIcons.link,
              color: AppTheme.primaryColor,
              onTap: _openLink,
            ),
          ],

          const SizedBox(width: 20),

          // Share button
          _ActionButton(
            icon: CupertinoIcons.share,
            color: iconColor,
            onTap: _sharePost,
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

  const _ActionButton({
    required this.icon,
    this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
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
