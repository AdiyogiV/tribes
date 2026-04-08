import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/chat_message.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/features/spaces/presentation/widgets/chat_message_tiles.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// The scrollable message list for the embedded chat view.
///
/// Displays messages in reverse order (newest at bottom), with typing
/// indicators, date separators, and the Instagram-style swipe-to-reveal
/// timestamp strip.
class EmbeddedMessageList extends StatelessWidget {
  final Stream<List<ChatMessage>> messageStream;
  final ScrollController scrollController;
  final List<ChatMessage> sendingMessages;
  final List<TypingUser> typingUsers;
  final String? currentUserId;
  final bool isConnected;
  final bool isDMConversation;
  final Map<String, ChatMessage> repliedMessagesCache;
  final double timestampRevealOffset;
  final bool isDraggingReveal;

  // Callbacks
  final void Function(List<ChatMessage> allMessages) onMessagesUpdated;
  final List<ChatMessage> Function(List<ChatMessage> messages)
      deduplicateMessages;
  final void Function(ChatMessage message) onReply;
  final void Function(ChatMessage message) onQuickReact;
  final void Function(ChatMessage message) onShowExactTime;
  final void Function(String messageId) onScrollToMessage;

  // Gesture callbacks for timestamp reveal
  final void Function() onPointerDown;
  final void Function(PointerMoveEvent event) onPointerMove;
  final void Function() onPointerUp;

  static const double kTimestampRevealStripWidth = 80.0;

  const EmbeddedMessageList({
    super.key,
    required this.messageStream,
    required this.scrollController,
    required this.sendingMessages,
    required this.typingUsers,
    required this.currentUserId,
    required this.isConnected,
    required this.isDMConversation,
    required this.repliedMessagesCache,
    required this.timestampRevealOffset,
    required this.isDraggingReveal,
    required this.onMessagesUpdated,
    required this.deduplicateMessages,
    required this.onReply,
    required this.onQuickReact,
    required this.onShowExactTime,
    required this.onScrollToMessage,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatMessage>>(
      stream: messageStream,
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
            if (!isConnected) const ConnectionBanner(),
            Expanded(
              child: Listener(
                onPointerDown: (_) => onPointerDown(),
                onPointerMove: onPointerMove,
                onPointerUp: (_) => onPointerUp(),
                onPointerCancel: (_) => onPointerUp(),
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
                                    top: 70, bottom: 170),
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
                                            padding: const EdgeInsets.only(
                                                left: 12, right: 12),
                                            child: TypingIndicator(
                                                typingUsers: typingUsers),
                                          ),
                                        ),
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

                                  return _buildMessageRow(
                                    context,
                                    allMessages,
                                    actualIndex,
                                    w,
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

  Widget _buildMessageRow(
    BuildContext context,
    List<ChatMessage> allMessages,
    int actualIndex,
    double listWidth,
  ) {
    final message = allMessages[actualIndex];
    final isOwnMessage = message.senderId == currentUserId;
    final isPending = sendingMessages.any((m) => m.id == message.id);

    bool showDateSeparator = actualIndex == 0 ||
        !_isSameDay(
            message.timestamp, allMessages[actualIndex - 1].timestamp);

    bool isFirstInGroup = true;
    bool isLastInGroup = true;

    if (actualIndex > 0) {
      final prev = allMessages[actualIndex - 1];
      final timeDiff =
          message.timestamp.difference(prev.timestamp).inMinutes;
      if (prev.senderId == message.senderId &&
          timeDiff < 5 &&
          _isSameDay(message.timestamp, prev.timestamp)) {
        isFirstInGroup = false;
      }
    }

    if (actualIndex < allMessages.length - 1) {
      final next = allMessages[actualIndex + 1];
      final timeDiff =
          next.timestamp.difference(message.timestamp).inMinutes;
      if (next.senderId == message.senderId &&
          timeDiff < 5 &&
          _isSameDay(message.timestamp, next.timestamp)) {
        isLastInGroup = false;
      }
    }

    final timestampStrip = TimestampRevealStrip(
      message: message,
      isOwnMessage: isOwnMessage,
      isLastInGroup: isLastInGroup,
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDateSeparator) ChatDateSeparator(date: message.timestamp),
        _buildMessageTile(
          message,
          isOwnMessage,
          isPending,
          isFirstInGroup,
          isLastInGroup,
        ),
      ],
    );

    return RepaintBoundary(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: listWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 12),
              child: content,
            ),
          ),
          SizedBox(
            width: kTimestampRevealStripWidth,
            child: Padding(
              padding:
                  EdgeInsets.only(bottom: isLastInGroup ? 16 : 2),
              child: Align(
                alignment: Alignment.centerRight,
                child: timestampStrip,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(
    ChatMessage message,
    bool isOwnMessage,
    bool isPending,
    bool isFirstInGroup,
    bool isLastInGroup,
  ) {
    // Handle namaste messages
    if (message.messageType == 'namaste') {
      return NamasteMessageTile(
        message: message,
        isOwnMessage: isOwnMessage,
        isLastInGroup: isLastInGroup,
        onShowTime: () => onShowExactTime(message),
      );
    }

    // Handle call messages
    if (message.messageType == 'call') {
      return CallMessageTile(
        message: message,
        isLastInGroup: isLastInGroup,
        currentUserId: currentUserId,
        onShowTime: () => onShowExactTime(message),
        onCallback: null, // Callbacks not supported in embedded view
      );
    }

    // Handle group call messages
    if (message.messageType == 'group_call') {
      return GroupCallMessageTile(
        message: message,
        isLastInGroup: isLastInGroup,
        onShowTime: () => onShowExactTime(message),
      );
    }

    // Default: text, image, etc.
    return ChatMessageTile(
      message: message,
      isOwnMessage: isOwnMessage,
      isPending: isPending,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
      currentUserId: currentUserId,
      onReply: () => onReply(message),
      onQuickReact: () => onQuickReact(message),
      onShowTime: () => onShowExactTime(message),
      onLongPress: () => onShowExactTime(message),
      repliedMessagesCache: repliedMessagesCache,
      onScrollToMessage: onScrollToMessage,
      isDMConversation: isDMConversation,
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle,
              size: 48, color: AppTheme.errorColor),
          const SizedBox(height: AppDimensions.spacingLg),
          Text('Error loading messages',
              style: TextStyle(color: AppTheme.textLightColor)),
          const SizedBox(height: AppDimensions.spacingSm),
          ElevatedButton(
            onPressed: () {
              // Trigger rebuild by parent
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small extracted widgets
// ---------------------------------------------------------------------------

/// Skeleton loading placeholder for the chat message list.
class ChatSkeleton extends StatelessWidget {
  const ChatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      reverse: true,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        SkeletonChatMessage(isUser: true, lineCount: 1),
        SkeletonChatMessage(lineCount: 3),
        SkeletonChatMessage(isUser: true, lineCount: 2),
        SkeletonChatMessage(lineCount: 2),
        SkeletonChatMessage(lineCount: 1),
        SkeletonChatMessage(isUser: true, lineCount: 3),
        SkeletonChatMessage(lineCount: 2),
        SkeletonChatMessage(isUser: true, lineCount: 1),
      ],
    );
  }
}

/// Empty state shown when there are no messages yet.
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: CupertinoIcons.chat_bubble_2,
      iconSize: 64,
      iconColor: AppTheme.primaryColor.withValues(alpha: 0.3),
      title: 'No messages yet',
      subtitle: 'Start the conversation!',
    );
  }
}

/// Banner shown when the chat connection is lost.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.orange.withValues(alpha: 0.9),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppLoadingIndicator(
            size: 12,
            strokeWidth: 2,
            color: Colors.white,
          ),
          SizedBox(width: AppDimensions.spacingSm),
          Text(
            'Connecting...',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Animated typing indicator bubble.
class TypingIndicator extends StatelessWidget {
  final List<TypingUser> typingUsers;

  const TypingIndicator({super.key, required this.typingUsers});

  @override
  Widget build(BuildContext context) {
    if (typingUsers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd, vertical: AppDimensions.paddingSm),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDots(),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  typingUsers.length == 1
                      ? '${typingUsers.first.userName.trim().isEmpty ? 'Someone' : typingUsers.first.userName} is typing'
                      : '${typingUsers.length} people are typing',
                  style: TextStyle(
                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          margin: const EdgeInsets.only(right: 2),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
