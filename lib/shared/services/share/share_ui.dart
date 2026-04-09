import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/services/share/chat_picker_sheet.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

// Conditional import for web share API
import 'package:aurogram/shared/services/share/web_share_stub.dart'
    if (dart.library.html) 'package:aurogram/services/share/web_share_impl.dart';

class ShareUi {
  static Future<void> showShareOptions({
    required BuildContext context,
    required String shareText,
    String? shareUrl,
    required String contentType,
    ShareableContent? chatShareContent,
    Future<void> Function()? onAddToStory,
  }) async {
    // On web, try native Web Share API first (works on mobile browsers)
    if (kIsWeb) {
      if (shareUrl != null) {
        final shared = await _tryWebShare(shareText, shareUrl, contentType);
        if (shared) return;
      }

      // Web Share API not available or failed, show simplified dialog
      if (!context.mounted) return;
      // ignore: use_build_context_synchronously — guarded by context.mounted above
      await _showWebShareDialog(
          context, shareUrl, contentType, chatShareContent);
      return;
    }

    // Mobile: show standard share sheet with chat option
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: Text('Share $contentType'),
        actions: [
          // Add to Story option (first, for easy access)
          if (onAddToStory != null && !kIsWeb)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await onAddToStory();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.add_circled,
                      color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Text('Add to Story',
                      style: TextStyle(color: AppTheme.primaryColor)),
                ],
              ),
            ),
          // Send in Chat option
          if (chatShareContent != null)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _shareToChat(context, chatShareContent);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.chat_bubble,
                      color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Text('Send in Chat',
                      style: TextStyle(color: AppTheme.primaryColor)),
                ],
              ),
            ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // ignore: deprecated_member_use
              await Share.share(shareText);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.share,
                    color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: AppDimensions.spacingSm),
                Text('Share via...',
                    style: TextStyle(color: AppTheme.primaryColor)),
              ],
            ),
          ),
          if (shareUrl != null)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Clipboard.setData(ClipboardData(text: shareUrl));
                if (context.mounted) {
                  showSuccessSnackbar(context, 'Link copied to clipboard');
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.doc_on_clipboard,
                      color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Text('Copy Link',
                      style: TextStyle(color: AppTheme.primaryColor)),
                ],
              ),
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

  /// Share content to chat via ChatPickerBottomSheet
  static Future<void> _shareToChat(
    BuildContext context,
    ShareableContent content,
  ) async {
    final result = await ChatPickerBottomSheet.show(
      context,
      content: content,
      allowMultiSelect: true,
    );

    if (result != null && result.selectedConversations.isNotEmpty) {
      final chatService = SpaceChatService();
      int successCount = 0;

      for (final conversation in result.selectedConversations) {
        try {
          await chatService.sendSharedContent(
            spaceId: conversation.id,
            sharedContent: content.toJson(),
            message: result.message,
          );
          successCount++;
        } catch (e) {
          AppLogger.e('Failed to share to ${conversation.id}',
              category: LogCategory.general, error: e);
        }
      }

      if (context.mounted && successCount > 0) {
        showSuccessSnackbar(
          context,
          successCount == 1 ? 'Sent to chat' : 'Sent to $successCount chats',
        );
      }
    }
  }

  /// Try to use native Web Share API
  static Future<bool> _tryWebShare(
      String text, String url, String title) async {
    try {
      return await WebShareHelper.share(text: text, url: url, title: title);
    } catch (e) {
      AppLogger.d('Web Share API failed: $e', category: LogCategory.general);
      return false;
    }
  }

  /// Show simplified share dialog for web when native API not available
  static Future<void> _showWebShareDialog(
    BuildContext context,
    String? shareUrl,
    String contentType,
    ShareableContent? chatShareContent,
  ) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: Text('Share $contentType'),
        message: const Text('Copy the link to share'),
        actions: [
          // Send in Chat option (first, for easy access)
          if (chatShareContent != null)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _shareToChat(context, chatShareContent);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.chat_bubble,
                      color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Text('Send in Chat',
                      style: TextStyle(color: AppTheme.primaryColor)),
                ],
              ),
            ),
          if (shareUrl != null)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Clipboard.setData(ClipboardData(text: shareUrl));
                if (context.mounted) {
                  showSuccessSnackbar(context, 'Link copied to clipboard');
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.doc_on_clipboard,
                      color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Text('Copy Link',
                      style: TextStyle(color: AppTheme.primaryColor)),
                ],
              ),
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

  static void showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
