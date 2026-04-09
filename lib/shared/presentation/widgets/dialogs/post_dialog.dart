import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/features/feed/domain/post_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/dialogs/report_post_dialog.dart';
import 'package:aurogram/shared/presentation/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class PostDialog extends StatefulWidget {
  final String? post;
  final String? author;

  const PostDialog({super.key, this.post, this.author});

  @override
  PostDialogState createState() => PostDialogState();
}

class PostDialogState extends State<PostDialog> {
  final User? user = FirebaseAuth.instance.currentUser;
  final PostService _postService = PostService();

  Future<void> _showDeleteConfirmation() async {
    bool? shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('Delete Post'),
        content: Text(
            'Are you sure you want to delete this post? This action cannot be undone.'),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            textStyle: TextStyle(color: AppTheme.textSecondaryLightColor),
            child: Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            textStyle: TextStyle(color: AppTheme.errorColor),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      _deletePost();
    }
  }

  Future<void> _deletePost() async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Deleting Post'),
        content: const Column(
          children: [
            PulsingDots(size: 8),
            SizedBox(height: AppDimensions.spacingMdSm),
            Text('Please wait...'),
          ],
        ),
      ),
    );

    bool success = await _postService.deleteSpacePost(widget.post!);

    if (!mounted) return;
    Navigator.of(context).pop(); // Close the loading dialog
    _showResultDialog(success);
  }

  void _showResultDialog(bool success) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(success ? 'Deleted' : 'Error'),
        content: Text(success
            ? 'The post was successfully deleted.'
            : 'Failed to delete the post. Please try again.'),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              if (success) {
                Navigator.of(context).pop(); // Close the PostDialog
              }
            },
            textStyle: TextStyle(color: AppTheme.primaryColor),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    Navigator.of(context).pop(); // Close the action sheet
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => ReportDialog(post: widget.post!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      // Schedule login bottom sheet after this dialog closes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        showLoginBottomSheet(context);
      });
      return const SizedBox.shrink();
    }

    return CupertinoActionSheet(
      actions: <Widget>[
        if (widget.author == user!.uid)
          CupertinoActionSheetAction(
            onPressed: _showDeleteConfirmation,
            child: Text(
              'Delete',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          )
        else
          CupertinoActionSheetAction(
            onPressed: _showReportDialog,
            child: Text(
              'Report',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('Cancel', style: TextStyle(color: AppTheme.primaryColor)),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
