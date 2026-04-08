import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/services/share/share_service.dart';
import 'package:aurogram/shared/services/share/share_links.dart';
import 'package:aurogram/services/repost_service.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/services/post_service.dart';
import 'package:aurogram/shared/presentation/widgets/dialogs/report_post_dialog.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/shared/presentation/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/creation/pages/text_composer.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Repost to profile immediately (or undo if already reposted). No gram selector.
Future<void> showRepostFlow(
  BuildContext context, {
  required String postId,
  Map<String, dynamic>? postData,
  String? authorId,
  String? authorName,
  String? authorAvatar,
}) async {
  await _onRepost(
      context, postId, postData, authorId, authorName, authorAvatar);
}

/// Single post options sheet: Repost, Quote, Share, Copy Link, Report, Delete (if own).
/// Use from toolbar Share/More and from header options (•••).
void showPostOptionsSheet({
  required BuildContext context,
  required String postId,
  required String? authorId,
  Map<String, dynamic>? postData,
  String? authorName,
  String? authorAvatar,
}) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    showLoginBottomSheet(context);
    return;
  }

  final isOwnPost = authorId != null && authorId == user.uid;

  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('Options'),
      actions: [
        _Action(
          icon: CupertinoIcons.arrow_2_squarepath,
          label: 'Repost',
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _onRepost(
                context, postId, postData, authorId, authorName, authorAvatar);
          },
        ),
        _Action(
          icon: CupertinoIcons.quote_bubble,
          label: 'Quote',
          onPressed: () {
            Navigator.of(ctx).pop();
            _onQuote(context, postId, postData, authorName, authorAvatar);
          },
        ),
        _Action(
          icon: CupertinoIcons.paperplane_fill,
          label: 'Share',
          onPressed: () async {
            Navigator.of(ctx).pop();
            await ShareService.sharePost(context: context, postId: postId);
          },
        ),
        _Action(
          icon: CupertinoIcons.doc_on_clipboard,
          label: 'Copy Link',
          onPressed: () {
            Navigator.of(ctx).pop();
            Clipboard.setData(ClipboardData(text: ShareLinks.post(postId)));
            if (context.mounted) {
              showCustomSnackBar(context, message: 'Link copied to clipboard', duration: const Duration(seconds: 2));
            }
          },
        ),
        if (isOwnPost)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _showDeleteConfirmation(context, postId);
            },
            child: const Text('Delete'),
          )
        else
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              showCupertinoModalPopup(
                context: context,
                builder: (_) => ReportDialog(post: postId),
              );
            },
            child: const Text('Report'),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(ctx).pop(),
        child: Text('Cancel', style: TextStyle(color: AppTheme.primaryColor)),
      ),
    ),
  );
}

Future<void> _onRepost(
  BuildContext context,
  String postId,
  Map<String, dynamic>? postData,
  String? authorId,
  String? authorName,
  String? authorAvatar,
) async {
  final repostService = RepostService();
  final alreadyReposted = await repostService.hasUserReposted(postId);
  if (alreadyReposted) {
    try {
      await repostService.undoRepost(postId, postData);
      if (context.mounted) {
        showCustomSnackBar(
          context,
          message: 'Repost removed',
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      AppLogger.e('Error undoing repost', error: e);
      if (context.mounted) {
        showCustomSnackBar(
          context,
          message: 'Failed to remove repost. Please try again.',
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
        );
      }
    }
    return;
  }

  Map<String, dynamic> data = postData ?? {};
  if (data.isEmpty) {
    try {
      final snap = await PostDbService().getPost(postId);
      if (snap.exists) {
        final d = snap.data() as Map<String, dynamic>? ?? {};
        data = {
          'author': d['author'],
          'authorName': d['authorName'] ?? authorName,
          'authorAvatar': d['authorAvatar'] ?? authorAvatar,
          'contextType': d['contextType'],
          'contextId': d['contextId'] ?? d['space'],
          'space': d['space'] ?? d['contextId'],
          'postType': d['postType'],
          'title': d['title'],
          'content': d['content'],
          'video': d['video'],
          'thumbnail': d['thumbnail'],
          'audioUrl': d['audioUrl'],
          'duration': d['duration'],
          'link': d['link'],
        };
      }
    } catch (e) {
      AppLogger.e('Failed to load post for repost', error: e);
      if (context.mounted) {
        showCustomSnackBar(context, message: 'Could not load post', duration: const Duration(seconds: 2));
      }
      return;
    }
  }

  try {
    await RepostService().repostToProfile(
      originalPostId: postId,
      originalPostData: data,
    );
    if (context.mounted) {
      showCustomSnackBar(
        context,
        message: 'Reposted successfully',
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 2),
      );
    }
  } catch (e) {
    AppLogger.e('Error reposting', error: e);
    if (context.mounted) {
      showCustomSnackBar(
        context,
        message: 'Failed to repost. Please try again.',
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 3),
      );
    }
    rethrow; // Re-throw so caller can handle state refresh
  }
}

Future<void> _onQuote(
  BuildContext context,
  String postId,
  Map<String, dynamic>? postData,
  String? authorName,
  String? authorAvatar,
) async {
  Map<String, dynamic> data = postData ?? {};
  if (data.isEmpty) {
    try {
      final snap = await PostDbService().getPost(postId);
      if (snap.exists) {
        final d = snap.data() as Map<String, dynamic>? ?? {};
        data = {
          'author': d['author'],
          'authorName': d['authorName'] ?? authorName,
          'authorAvatar': d['authorAvatar'] ?? authorAvatar,
          'postType': d['postType'] ?? 'text',
          'title': d['title'],
          'content': d['content'],
          'thumbnail': d['thumbnail'],
          'timestamp': d['timestamp'],
        };
      }
    } catch (e) {
      AppLogger.e('Failed to load post for quote', error: e);
      if (context.mounted) {
        showCustomSnackBar(context, message: 'Could not load post', duration: const Duration(seconds: 2));
      }
      return;
    }
  }
  if (data.isEmpty || !context.mounted) return;
  // Ensure timestamp for embed
  if (!data.containsKey('timestamp')) data['timestamp'] = null;
  Navigator.of(context).push(
    CupertinoPageRoute(
      builder: (_) => TextComposer(
        space: 'profile',
        isProfilePost: true,
        quotedPostId: postId,
        quotedPostData: data,
      ),
    ),
  );
}

void _showDeleteConfirmation(BuildContext context, String postId) async {
  final shouldDelete = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Delete Post'),
      content: const Text(
        'Are you sure you want to delete this post? This action cannot be undone.',
      ),
      actions: <Widget>[
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor)),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (shouldDelete != true || !context.mounted) return;

  showCupertinoDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Deleting Post'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingDots(size: 8),
          const SizedBox(height: AppDimensions.spacingMdSm),
          const Text('Please wait...'),
        ],
      ),
    ),
  );

  final success = await PostService().deleteSpacePost(postId);

  if (!context.mounted) return;
  Navigator.of(context).pop(); // close loading

  showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(success ? 'Deleted' : 'Error'),
      content: Text(
        success
            ? 'The post was successfully deleted.'
            : 'Failed to delete the post. Please try again.',
      ),
      actions: <Widget>[
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
        ),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _Action(
      {required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return CupertinoActionSheetAction(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: AppDimensions.spacingMdSm),
          Text(label, style: TextStyle(color: AppTheme.primaryColor)),
        ],
      ),
    );
  }
}
