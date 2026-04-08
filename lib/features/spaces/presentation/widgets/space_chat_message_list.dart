import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'chat_message_tiles.dart';
import 'space_chat_overlays.dart';

/// The main scrollable message list with timestamp-reveal swipe gesture.
class SpaceChatMessageList extends StatelessWidget {
  final ScrollController scrollController;
  final SpaceChatService chatService;
  final String spaceId;
  final double horizontalPadding;
  final bool isConnected;
  final List<TypingUser> typingUsers;
  final List<ChatMessage> sendingMessages;
  final Map<String, ChatMessage> repliedMessagesCache;
  final bool isDMConversation;
  final String? currentUserId;

  // Timestamp reveal state
  final double timestampRevealOffset;
  final bool isDraggingReveal;

  // Callbacks
  final void Function(PointerDownEvent) onPointerDown;
  final void Function(PointerMoveEvent) onPointerMove;
  final void Function(PointerUpEvent) onPointerUp;
  final void Function(PointerCancelEvent) onPointerCancel;

  // Message tile callbacks
  final void Function(ChatMessage) onReply;
  final void Function(ChatMessage) onQuickReact;
  final void Function(ChatMessage) onShowTime;
  final void Function(ChatMessage, bool) onLongPress;
  final void Function(ChatMessage) onShowReactions;
  final void Function(ChatMessage) onForward;
  final void Function(ChatMessage)? onEdit;
  final void Function(String) onScrollToMessage;

  // Data callbacks
  final List<ChatMessage> Function(List<ChatMessage>) deduplicateMessages;
  final void Function(List<ChatMessage>) onMessagesUpdated;
  final Widget Function(ChatMessage, bool, bool, bool, bool) buildMessageTile;

  static const double kTimestampRevealStripWidth = 80.0;

  const SpaceChatMessageList({
    super.key,
    required this.scrollController,
    required this.chatService,
    required this.spaceId,
    required this.horizontalPadding,
    required this.isConnected,
    required this.typingUsers,
    required this.sendingMessages,
    required this.repliedMessagesCache,
    required this.isDMConversation,
    required this.currentUserId,
    required this.timestampRevealOffset,
    required this.isDraggingReveal,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.onReply,
    required this.onQuickReact,
    required this.onShowTime,
    required this.onLongPress,
    required this.onShowReactions,
    required this.onForward,
    this.onEdit,
    required this.onScrollToMessage,
    required this.deduplicateMessages,
    required this.onMessagesUpdated,
    required this.buildMessageTile,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatMessage>>(
      stream: chatService.getMessages(spaceId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(context);
        }

        if (!snapshot.hasData) return const ChatSkeleton();

        final messages = snapshot.data!;
        final allMessages = deduplicateMessages(messages);
        onMessagesUpdated(allMessages);

        if (allMessages.isEmpty) return const ChatEmptyState();

        return Column(
          children: [
            if (!isConnected) const ChatConnectionBanner(),
            Expanded(
              child: Listener(
                onPointerDown: onPointerDown,
                onPointerMove: onPointerMove,
                onPointerUp: onPointerUp,
                onPointerCancel: onPointerCancel,
                child: IgnorePointer(
                  ignoring: isDraggingReveal,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final contentWidth = w + kTimestampRevealStripWidth;
                      return Container(
                        width: w,
                        decoration: const BoxDecoration(),
                        clipBehavior: Clip.hardEdge,
                        child: OverflowBox(
                          maxWidth: contentWidth,
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: Offset(-timestampRevealOffset, 0),
                            child: SizedBox(
                              width: contentWidth,
                              child: ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.only(
                                    top: 170, bottom: 170),
                                itemCount: allMessages.length +
                                    (typingUsers.isNotEmpty ? 1 : 0),
                                physics: const ClampingScrollPhysics(),
                                cacheExtent: 2000,
                                addAutomaticKeepAlives: false,
                                addRepaintBoundaries: false,
                                shrinkWrap: false,
                                reverse: true,
                                itemBuilder: (context, index) {
                                  if (typingUsers.isNotEmpty && index == 0) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        SizedBox(
                                            width: w,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                  left:
                                                      12 + horizontalPadding,
                                                  right:
                                                      12 + horizontalPadding),
                                              child: ChatTypingIndicator(
                                                  typingUsers: typingUsers),
                                            )),
                                        const SizedBox(
                                            width:
                                                kTimestampRevealStripWidth),
                                      ],
                                    );
                                  }

                                  final messageIndex =
                                      typingUsers.isNotEmpty
                                          ? index - 1
                                          : index;
                                  final actualIndex =
                                      allMessages.length - 1 - messageIndex;

                                  if (actualIndex < 0 ||
                                      actualIndex >= allMessages.length) {
                                    return const SizedBox.shrink();
                                  }

                                  final message = allMessages[actualIndex];
                                  final isOwnMessage =
                                      message.senderId == currentUserId;
                                  final isPending = sendingMessages
                                      .any((m) => m.id == message.id);

                                  bool showDateSeparator =
                                      actualIndex == 0 ||
                                          !_isSameDay(
                                              message.timestamp,
                                              allMessages[actualIndex - 1]
                                                  .timestamp);

                                  bool isFirstInGroup = true;
                                  bool isLastInGroup = true;

                                  if (actualIndex > 0) {
                                    final prev =
                                        allMessages[actualIndex - 1];
                                    final timeDiff = message.timestamp
                                        .difference(prev.timestamp)
                                        .inMinutes;
                                    if (prev.senderId ==
                                            message.senderId &&
                                        timeDiff < 5 &&
                                        _isSameDay(message.timestamp,
                                            prev.timestamp)) {
                                      isFirstInGroup = false;
                                    }
                                  }

                                  if (actualIndex <
                                      allMessages.length - 1) {
                                    final next =
                                        allMessages[actualIndex + 1];
                                    final timeDiff = next.timestamp
                                        .difference(message.timestamp)
                                        .inMinutes;
                                    if (next.senderId ==
                                            message.senderId &&
                                        timeDiff < 5 &&
                                        _isSameDay(message.timestamp,
                                            next.timestamp)) {
                                      isLastInGroup = false;
                                    }
                                  }

                                  final timestampStrip =
                                      TimestampRevealStrip(
                                    message: message,
                                    isOwnMessage: isOwnMessage,
                                    isLastInGroup: isLastInGroup,
                                  );

                                  final content = Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (showDateSeparator)
                                        ChatDateSeparator(
                                            date: message.timestamp),
                                      buildMessageTile(
                                          message,
                                          isOwnMessage,
                                          isPending,
                                          isFirstInGroup,
                                          isLastInGroup),
                                    ],
                                  );

                                  return RepaintBoundary(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        SizedBox(
                                            width: w,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                  left:
                                                      12 + horizontalPadding,
                                                  right:
                                                      12 + horizontalPadding),
                                              child: content,
                                            )),
                                        SizedBox(
                                          width: kTimestampRevealStripWidth,
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                                bottom: isLastInGroup
                                                    ? 16
                                                    : 2),
                                            child: Align(
                                              alignment:
                                                  Alignment.centerRight,
                                              child: timestampStrip,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: AppDimensions.spacingLg),
          Text('Error loading messages',
              style: TextStyle(color: AppTheme.textLightColor)),
          const SizedBox(height: AppDimensions.spacingSm),
          ElevatedButton(
            onPressed: () {
              // Parent will call setState to retry
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
