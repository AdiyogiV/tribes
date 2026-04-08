import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/services/share/chat_picker_sheet.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

/// Dialogs for message actions: delete, edit, report, block, and forward.
class SpaceChatDialogs {
  /// Confirm and delete a message.
  static void confirmDelete(
    BuildContext context, {
    required ChatMessage message,
    required SpaceChatService chatService,
  }) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
            'Are you sure you want to delete this message? This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              chatService.deleteMessage(message.id);
            },
          ),
        ],
      ),
    );
  }

  /// Show edit message dialog.
  static void showEditMessage(
    BuildContext context, {
    required ChatMessage message,
    required SpaceChatService chatService,
  }) {
    final textController = TextEditingController(text: message.content);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Edit Message'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: textController,
            placeholder: 'Enter new message',
            maxLines: 5,
            minLines: 1,
            autofocus: true,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Save'),
            onPressed: () async {
              final newContent = textController.text.trim();
              if (newContent.isEmpty) return;
              if (newContent == message.content) {
                Navigator.pop(context);
                return;
              }

              Navigator.pop(context);

              try {
                await chatService.editMessage(message.id, newContent);
                if (context.mounted) {
                  showCustomSnackBar(context, message: 'Message edited', backgroundColor: AppTheme.primaryColor, duration: const Duration(seconds: 2));
                }
              } catch (e) {
                if (context.mounted) {
                  showCustomSnackBar(context, message: 'Failed to edit message: ${e.toString()}', backgroundColor: AppTheme.errorColor, duration: const Duration(seconds: 3));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  /// Show report message dialog.
  static void showReportMessage(
    BuildContext context, {
    required ChatMessage message,
    required SpaceChatService chatService,
  }) {
    final textController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Report Message'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Why are you reporting this message?',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              CupertinoTextField(
                controller: textController,
                placeholder: 'Enter reason',
                maxLines: 4,
                minLines: 2,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            isDefaultAction: true,
            child: const Text('Report'),
            onPressed: () async {
              final reason = textController.text.trim();
              if (reason.isEmpty) return;

              Navigator.pop(context);

              await chatService.reportChatMessage(message.id, reason);

              if (context.mounted) {
                showCupertinoDialog(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: const Text('Reported'),
                    content: const Text(
                        'Thank you for reporting this message. It will be reviewed by our team within 24 hours.\n\nIt is our priority to keep Aurogram free of objectionable content and your support for the same is appreciated.'),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text('OK'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// Show block user confirmation dialog.
  static void showBlockUser(
    BuildContext context, {
    required String otherUserId,
    required String? displayName,
  }) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Block User'),
        content: Text(
            'Are you sure you want to block ${displayName ?? 'this user'}? You will no longer receive messages from them.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Block'),
            onPressed: () async {
              Navigator.pop(context);

              try {
                final userService = UserService();
                await userService.blockUser(otherUserId);

                if (context.mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('User Blocked'),
                      content: const Text(
                          'This user has been blocked. You will no longer receive messages from them.'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('OK'),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context); // Also pop chat screen
                          },
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                AppLogger.e('Error blocking user',
                    category: LogCategory.general, error: e);
                if (context.mounted) {
                  showCustomSnackBar(context, message: 'Failed to block user', backgroundColor: AppTheme.errorColor);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  /// Forward a message to other conversations.
  static Future<void> forwardMessage(
    BuildContext context, {
    required ChatMessage message,
    required SpaceChatService chatService,
  }) async {
    final content = ShareableContent(
      type: 'message',
      id: message.id,
      title: message.messageType == 'text'
          ? (message.content.length > 50
              ? '${message.content.substring(0, 50)}...'
              : message.content)
          : _getMessageTypeLabel(message.messageType),
      subtitle: message.senderName,
      imageUrl: message.thumbnailUrl ??
          (message.messageType == 'image' ? message.mediaUrl : null),
    );

    final result = await ChatPickerBottomSheet.show(
      context,
      content: content,
      allowMultiSelect: true,
    );

    if (result != null && result.selectedConversations.isNotEmpty) {
      int successCount = 0;
      for (final conversation in result.selectedConversations) {
        try {
          await chatService.forwardMessage(
            targetSpaceId: conversation.id,
            originalMessage: message,
            additionalMessage: result.message,
          );
          successCount++;
        } catch (e) {
          AppLogger.e('Failed to forward to ${conversation.id}',
              category: LogCategory.general, error: e);
        }
      }

      if (context.mounted && successCount > 0) {
        showCustomSnackBar(context, message: successCount == 1
                ? 'Message forwarded'
                : 'Message forwarded to $successCount chats', backgroundColor: AppTheme.primaryColor, duration: const Duration(seconds: 2));
      }
    }
  }

  static String _getMessageTypeLabel(String messageType) {
    switch (messageType) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Voice message';
      case 'file':
        return 'File';
      case 'shared_content':
        return 'Shared content';
      default:
        return 'Message';
    }
  }
}
