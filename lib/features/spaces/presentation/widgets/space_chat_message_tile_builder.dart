import 'package:flutter/material.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';

import 'chat_message_tiles.dart';
import 'space_chat_dialogs.dart';

/// Builds the appropriate message tile widget for a given [ChatMessage].
///
/// Extracted from space_chat_screen.dart to reduce file size.
class SpaceChatMessageTileBuilder {
  final String? currentUserId;
  final String? otherUserId;
  final String? displayName;
  final bool isDMConversation;
  final SpaceChatService chatService;
  final Map<String, ChatMessage> repliedMessagesCache;
  final void Function(ChatMessage) onStartReply;
  final void Function(ChatMessage) onQuickReact;
  final void Function(ChatMessage) onShowExactTime;
  final void Function(ChatMessage, bool isOwnMessage) onShowMessageOptions;
  final void Function(ChatMessage) onShowReactionsSheet;
  final void Function(String messageId) onScrollToMessage;
  final void Function(bool isVideo) onCallBack;

  const SpaceChatMessageTileBuilder({
    required this.currentUserId,
    required this.otherUserId,
    required this.displayName,
    required this.isDMConversation,
    required this.chatService,
    required this.repliedMessagesCache,
    required this.onStartReply,
    required this.onQuickReact,
    required this.onShowExactTime,
    required this.onShowMessageOptions,
    required this.onShowReactionsSheet,
    required this.onScrollToMessage,
    required this.onCallBack,
  });

  Widget build(
    BuildContext context,
    ChatMessage message,
    bool isOwnMessage,
    bool isPending,
    bool isFirstInGroup,
    bool isLastInGroup,
  ) {
    if (message.messageType == 'namaste') {
      return NamasteMessageTile(
        message: message,
        isOwnMessage: isOwnMessage,
        isLastInGroup: isLastInGroup,
        onShowTime: () => onShowExactTime(message),
      );
    }

    if (message.messageType == 'call') {
      return CallMessageTile(
        message: message,
        isLastInGroup: isLastInGroup,
        currentUserId: currentUserId,
        onShowTime: () => onShowExactTime(message),
        onCallback: otherUserId != null
            ? () => onCallBack(message.callType == 'video')
            : null,
      );
    }

    if (message.messageType == 'group_call') {
      return GroupCallMessageTile(
        message: message,
        isLastInGroup: isLastInGroup,
        onShowTime: () => onShowExactTime(message),
      );
    }

    return ChatMessageTile(
      message: message,
      isOwnMessage: isOwnMessage,
      isPending: isPending,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
      currentUserId: currentUserId,
      onReply: () => onStartReply(message),
      onQuickReact: () => onQuickReact(message),
      onShowTime: () => onShowExactTime(message),
      onLongPress: () => onShowMessageOptions(message, isOwnMessage),
      onShowReactions: message.reactions.isNotEmpty
          ? () => onShowReactionsSheet(message)
          : null,
      onForward: () => SpaceChatDialogs.forwardMessage(context,
          message: message, chatService: chatService),
      onEdit: chatService.canEditMessage(message)
          ? () => SpaceChatDialogs.showEditMessage(context,
              message: message, chatService: chatService)
          : null,
      repliedMessagesCache: repliedMessagesCache,
      onScrollToMessage: onScrollToMessage,
      isDMConversation: isDMConversation,
    );
  }
}
