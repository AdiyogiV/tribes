import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/services/share_service.dart';
import 'package:aurogram/services/share/share_links.dart';
import 'package:aurogram/services/repost_service.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';
import 'package:aurogram/widgets/posts/post_data.dart';
import 'package:aurogram/services/batch_data_loader.dart' show UserData;

// =============================================================================
// POST CONTEXT MENU ACTIONS
// =============================================================================

/// Share a post via the system share sheet.
void handlePostShare(BuildContext context, String? postId) {
  if (postId == null) return;
  ShareService.sharePost(
    context: context,
    postId: postId,
  );
}

/// Copy the post's deep link to the clipboard.
void handlePostCopyLink(BuildContext context, String? postId) {
  if (postId == null) return;
  final link = ShareLinks.post(postId);
  Clipboard.setData(ClipboardData(text: link));
  showCustomSnackBar(context, message: 'Link copied to clipboard', duration: const Duration(seconds: 2));
}

/// Placeholder for the report flow.
void handlePostReport(BuildContext context) {
  // TODO: Implement report functionality
  showCustomSnackBar(context, message: 'Report feature coming soon', duration: const Duration(seconds: 2));
}

/// Toggle repost: undo if already reposted, otherwise repost to profile.
Future<void> handlePostRepost(
  BuildContext context, {
  required String? postId,
  required PostData? data,
  required UserData? userData,
  required VoidCallback onDone,
}) async {
  if (postId == null || data == null) return;

  try {
    final repostService = RepostService();
    final alreadyReposted = await repostService.hasUserReposted(postId);

    if (alreadyReposted) {
      final postMap = {
        'author': data.author,
        'contextType': data.contextType,
        'contextId': data.space,
        'space': data.space,
      };
      await repostService.undoRepost(postId, postMap);
      onDone();
      return;
    }

    final postMap = {
      'author': data.author,
      'authorName': userData?.displayName,
      'authorAvatar': userData?.photoUrl,
      'contextType': data.contextType,
      'contextId': data.space,
      'space': data.space,
      'postType': data.postType,
      'title': data.title,
      'content': data.content,
      'video': data.video,
      'thumbnail': data.thumbnail,
      'audioUrl': data.audioUrl,
      'duration': data.durationInSeconds,
      'link': data.link,
    };
    await repostService.repostToProfile(
      originalPostId: postId,
      originalPostData: postMap,
    );
    onDone();
  } catch (e) {
    if (context.mounted) {
      showCustomSnackBar(
        context,
        message: 'Failed to repost. Please try again.',
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 3),
      );
    }
  }
}

/// Placeholder for the quote-post flow.
void handlePostQuote(BuildContext context, String? postId) {
  if (postId == null) return;
  // TODO: Navigate to composer with quoted post
  showCustomSnackBar(context, message: 'Quote post feature coming in next update', duration: const Duration(seconds: 2));
}
