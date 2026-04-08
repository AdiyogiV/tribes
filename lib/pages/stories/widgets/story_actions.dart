import 'package:flutter/material.dart';
import 'package:aurogram/models/story.dart';
import 'package:aurogram/services/story_service.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

/// Sends a reply message to a story author via DM.
Future<void> sendStoryReply({
  required BuildContext context,
  required String authorUserId,
  required TextEditingController replyController,
  required FocusNode replyFocusNode,
}) async {
  final message = replyController.text.trim();
  if (message.isEmpty) return;

  try {
    final chatService = SpaceChatService();
    final conversationId = await chatService.createDirectMessage(authorUserId);
    await chatService.sendTextMessage(conversationId, message);
    replyController.clear();
    replyFocusNode.unfocus();

    if (context.mounted) {
      showCustomSnackBar(context, message: 'Reply sent', backgroundColor: Colors.black87, duration: const Duration(seconds: 1));
    }
  } catch (e) {
    AppLogger.e('Story reply: failed to send',
        category: LogCategory.general, error: e);
    if (context.mounted) {
      showCustomSnackBar(context, message: 'Failed to send reply', backgroundColor: Colors.red.shade700);
    }
  }
}

/// Shows a confirmation dialog and deletes the current story.
/// Returns the result: null if cancelled, true if deleted, false if failed.
Future<bool?> deleteStoryWithConfirmation({
  required BuildContext context,
  required String userId,
  required Story story,
  required StoryService storyService,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Story'),
      content: const Text('Are you sure you want to delete this story?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return null;

  final success = await storyService.deleteStory(
    userId: userId,
    storyId: story.id,
  );

  if (!context.mounted) return null;

  if (success) {
    showCustomSnackBar(context, message: 'Story deleted', duration: const Duration(seconds: 2));
  } else {
    showCustomSnackBar(context, message: 'Failed to delete story', backgroundColor: Colors.red.shade700);
  }
  return success;
}
