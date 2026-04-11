import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/features/profile/domain/namaste_service.dart';
import 'package:aurogram/features/calling/domain/call_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/chat/presentation/widgets/message_search_sheet.dart';
import 'package:aurogram/features/chat/presentation/widgets/conversation_options_sheet.dart';
import 'package:get_it/get_it.dart';

import 'space_chat_message_options.dart';
import 'space_chat_reactions_sheet.dart';
import 'space_chat_dialogs.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:go_router/go_router.dart';

/// Non-widget action methods extracted from [SpaceChatScreenState].
///
/// These are collected as a mixin to keep the main file focused on state
/// management and the build tree.
mixin SpaceChatActionsMixin<T extends StatefulWidget> on State<T> {
  // ─── Subclasses must provide these ────────────────────────────────────

  String get actionSpaceId;
  String? get actionOtherUserId;
  String? get actionDisplayName;
  bool get actionIsDMConversation;
  SpaceChatService get actionChatService;
  String? get actionCurrentUserId;
  String? get actionSpaceName;

  void actionSetNamasteSent();
  void actionSetReplyingTo(ChatMessage? message);
  FocusNode get actionTextFieldFocusNode;
  bool get actionIsAtBottom;
  void actionScrollToBottomInstant();
  void actionScrollToMessage(String messageId);

  // ─── Namaste ──────────────────────────────────────────────────────────

  Future<void> sendNamaste() async {
    if (!actionIsDMConversation || actionOtherUserId == null) return;

    final result = await NamasteService()
        .sendNamaste(actionOtherUserId!, dmId: actionSpaceId);

    if (!mounted) return;

    if (result.success) {
      actionSetNamasteSent();
      final points = result.senderPointsAwarded ?? 0;
      if (points > 0 && mounted) {
        showCustomSnackBar(context, message: '+$points Auro for sending Namaste!', backgroundColor: AppTheme.primaryColor, behavior: SnackBarBehavior.floating);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (actionIsAtBottom) actionScrollToBottomInstant();
      });
    } else {
      String msg;
      if (result.quotaExceeded) {
        msg = 'Daily limit reached. You can send 3 namastes per day.';
      } else if (result.alreadySentToday) {
        msg = 'Already sent namaste to this person today.';
      } else if (result.blocked) {
        msg = 'Unable to send namaste to this user.';
      } else {
        msg = 'Failed to send Namaste. Please try again.';
      }

      showCustomSnackBar(context, message: msg, backgroundColor: result.quotaExceeded || result.alreadySentToday
              ? AppTheme.primaryColor
              : AppTheme.errorColor, behavior: SnackBarBehavior.floating);
    }
  }

  // ─── Navigation & actions ─────────────────────────────────────────────

  void navigateToHeader() {
    if (actionIsDMConversation && actionOtherUserId != null) {
      context.push('/user/profile/$actionOtherUserId');
    } else if (!actionIsDMConversation) {
      context.push('/space/$actionSpaceId');
    }
  }

  void openMediaGallery() {
    context.push('/media/gallery/$actionSpaceId', extra: {
      'title': actionDisplayName ?? 'Media',
    });
  }

  void openMessageSearch() {
    MessageSearchSheet.show(
      context,
      spaceId: actionSpaceId,
      onMessageSelected: (message) => actionScrollToMessage(message.id),
    );
  }

  void openConversationOptions() {
    ConversationOptionsSheet.show(
      context,
      conversationId: actionSpaceId,
      conversationName: actionDisplayName ?? 'Chat',
      onSettingsChanged: () {},
    );
  }

  void startReply(ChatMessage message) {
    if (!kIsWeb) HapticFeedback.lightImpact();
    actionSetReplyingTo(message);
    actionTextFieldFocusNode.requestFocus();
  }

  void cancelReply() => actionSetReplyingTo(null);

  void quickReact(ChatMessage message) {
    if (!kIsWeb) HapticFeedback.mediumImpact();
    actionChatService.addReaction(message.id, '\u2764\uFE0F');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\u2764\uFE0F', style: TextStyle(fontSize: 16)),
            SizedBox(width: AppDimensions.spacingSm),
            Text('Reacted'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 80, right: 80),
      ),
    );
  }

  void showExactTime(ChatMessage message) {
    final exactTime =
        DateFormat('EEEE, MMM d, yyyy \u2022 h:mm a').format(message.timestamp);
    ScaffoldMessenger.of(context).clearSnackBars();
    showCustomSnackBar(context, message: exactTime, backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating);
  }

  void callBack(bool isVideo) {
    if (actionOtherUserId == null) return;
    final callService = GetIt.I<CallService>();
    callService.startCall(
      calleeId: actionOtherUserId!,
      calleeName: actionDisplayName ?? 'User',
      type: isVideo ? CallType.video : CallType.voice,
    );
  }

  // ─── Message request accept / decline ─────────────────────────────────

  Future<void> acceptRequest() async {
    final success =
        await actionChatService.acceptMessageRequest(actionSpaceId);
    if (!mounted) return;

    showCustomSnackBar(context, message: success
            ? 'Message request accepted'
            : 'Failed to accept request', backgroundColor: success ? AppTheme.primaryColor : AppTheme.errorColor, duration: const Duration(seconds: 2));
  }

  Future<void> declineRequest() async {
    final success =
        await actionChatService.declineMessageRequest(actionSpaceId);
    if (!mounted) return;

    if (success) {
      showCustomSnackBar(context, message: 'Message request deleted', backgroundColor: AppTheme.primaryColor, duration: const Duration(seconds: 2));
      Navigator.of(context).pop();
    } else {
      showCustomSnackBar(context, message: 'Failed to decline request', backgroundColor: AppTheme.errorColor);
    }
  }

  // ─── Dialogs / sheets ─────────────────────────────────────────────────

  void showMessageOptions(ChatMessage message, bool isOwnMessage) {
    MessageOptionsSheet.show(
      context,
      message: message,
      isOwnMessage: isOwnMessage,
      isDMConversation: actionIsDMConversation,
      otherUserId: actionOtherUserId,
      chatService: actionChatService,
      onReply: () => startReply(message),
      onForward: () => SpaceChatDialogs.forwardMessage(context,
          message: message, chatService: actionChatService),
      onEdit: actionChatService.canEditMessage(message)
          ? () => SpaceChatDialogs.showEditMessage(context,
              message: message, chatService: actionChatService)
          : null,
      onDelete: () => SpaceChatDialogs.confirmDelete(context,
          message: message, chatService: actionChatService),
      onReport: () => SpaceChatDialogs.showReportMessage(context,
          message: message, chatService: actionChatService),
      onBlockUser: actionOtherUserId != null
          ? () => SpaceChatDialogs.showBlockUser(context,
              otherUserId: actionOtherUserId!,
              displayName: actionDisplayName)
          : null,
    );
  }

  void showReactionsSheet(ChatMessage message) {
    ReactionsSheet.show(
      context,
      message: message,
      currentUserId: actionCurrentUserId,
      chatService: actionChatService,
    );
  }
}
