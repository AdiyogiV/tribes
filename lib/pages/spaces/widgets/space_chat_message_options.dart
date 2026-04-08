import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

/// Bottom sheet showing message actions (reply, copy, edit, delete, etc.)
class MessageOptionsSheet {
  static void show(
    BuildContext context, {
    required ChatMessage message,
    required bool isOwnMessage,
    required bool isDMConversation,
    required String? otherUserId,
    required SpaceChatService chatService,
    required VoidCallback onReply,
    required VoidCallback onForward,
    VoidCallback? onEdit,
    required VoidCallback onDelete,
    required VoidCallback onReport,
    VoidCallback? onBlockUser,
  }) {
    if (!kIsWeb) HapticFeedback.mediumImpact();

    AppBottomSheet.show(
      context,
      maxHeightFraction: 0.6,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reactions at the top
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children:
                            ['❤️', '👍', '😂', '😮', '😢', '🙏'].map((emoji) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              chatService.addReaction(message.id, emoji);
                              if (!kIsWeb) HapticFeedback.lightImpact();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(AppDimensions.paddingSm),
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 24)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.reply_rounded,
                          color: AppTheme.primaryColor),
                      title: Text('Reply',
                          style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(context);
                        onReply();
                      },
                    ),
                    if (message.messageType == 'text')
                      ListTile(
                        leading: Icon(Icons.copy_rounded,
                            color: AppTheme.primaryColor),
                        title: Text('Copy message',
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500)),
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: message.content));
                          Navigator.pop(context);
                          showCustomSnackBar(context, message: 'Message copied', backgroundColor: AppTheme.primaryColor, duration: const Duration(seconds: 2));
                        },
                      ),
                    if (onEdit != null)
                      ListTile(
                        leading: Icon(Icons.edit_rounded,
                            color: AppTheme.primaryColor),
                        title: Text('Edit message',
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500)),
                        onTap: () {
                          Navigator.pop(context);
                          onEdit();
                        },
                      ),
                    ListTile(
                      leading: Icon(Icons.shortcut_rounded,
                          color: AppTheme.primaryColor),
                      title: Text('Forward',
                          style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(context);
                        onForward();
                      },
                    ),
                    if (!isOwnMessage) ...[
                      ListTile(
                        leading: Icon(Icons.flag_outlined,
                            color: AppTheme.errorColor),
                        title: Text('Report message',
                            style: TextStyle(
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.w500)),
                        onTap: () {
                          Navigator.pop(context);
                          onReport();
                        },
                      ),
                      if (isDMConversation &&
                          otherUserId != null &&
                          onBlockUser != null)
                        ListTile(
                          leading: Icon(Icons.block,
                              color: AppTheme.errorColor),
                          title: Text('Block user',
                              style: TextStyle(
                                  color: AppTheme.errorColor,
                                  fontWeight: FontWeight.w500)),
                          onTap: () {
                            Navigator.pop(context);
                            onBlockUser();
                          },
                        ),
                    ],
                    if (isOwnMessage)
                      ListTile(
                        leading: Icon(Icons.delete_outline_rounded,
                            color: AppTheme.errorColor),
                        title: Text('Delete message',
                            style: TextStyle(
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.w500)),
                        onTap: () {
                          Navigator.pop(context);
                          onDelete();
                        },
                      ),
                    const SizedBox(height: AppDimensions.spacingSm),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
