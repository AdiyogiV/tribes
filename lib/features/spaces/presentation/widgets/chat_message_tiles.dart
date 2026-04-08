import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/models/chat_message.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/media/context_menu.dart';
import 'package:aurogram/features/chat/presentation/widgets/shared_content_card.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'swipeable_message.dart';
import 'tiles/message_body_builder.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

// Re-export extracted tile widgets so existing imports don't break
export 'tiles/namaste_message_tile.dart';
export 'tiles/call_message_tile.dart';
export 'tiles/group_call_message_tile.dart';
export 'tiles/timestamp_reveal_strip.dart';
export 'tiles/chat_date_separator.dart';
export 'tiles/video_player_screen.dart';

/// Builds a standard text/image message tile
class ChatMessageTile extends StatefulWidget {
  final ChatMessage message;
  final bool isOwnMessage;
  final bool isPending;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final String? currentUserId;
  final VoidCallback onReply;
  final VoidCallback onQuickReact;
  final VoidCallback onShowTime;
  final VoidCallback onLongPress;
  final VoidCallback? onDelete;
  final VoidCallback? onShowReactions;
  final VoidCallback? onForward;
  final VoidCallback? onEdit;
  final Map<String, ChatMessage> repliedMessagesCache;
  final void Function(String messageId) onScrollToMessage;

  /// When true (1:1 chat): no names, receiver's avatar inline left of bubble; sender has no label.
  final bool isDMConversation;

  const ChatMessageTile({
    super.key,
    required this.message,
    required this.isOwnMessage,
    this.isPending = false,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.currentUserId,
    required this.onReply,
    required this.onQuickReact,
    required this.onShowTime,
    required this.onLongPress,
    this.onDelete,
    this.onShowReactions,
    this.onForward,
    this.onEdit,
    required this.repliedMessagesCache,
    required this.onScrollToMessage,
    this.isDMConversation = false,
  });

  @override
  State<ChatMessageTile> createState() => _ChatMessageTileState();
}

class _ChatMessageTileState extends State<ChatMessageTile> {
  bool _isHovered = false;

  // Shortcut getters to access widget properties
  ChatMessage get message => widget.message;
  bool get isOwnMessage => widget.isOwnMessage;
  bool get isPending => widget.isPending;
  bool get isFirstInGroup => widget.isFirstInGroup;
  bool get isLastInGroup => widget.isLastInGroup;
  String? get currentUserId => widget.currentUserId;
  VoidCallback get onReply => widget.onReply;
  VoidCallback get onQuickReact => widget.onQuickReact;
  VoidCallback get onShowTime => widget.onShowTime;
  VoidCallback get onLongPress => widget.onLongPress;
  VoidCallback? get onDelete => widget.onDelete;
  VoidCallback? get onShowReactions => widget.onShowReactions;
  VoidCallback? get onForward => widget.onForward;
  VoidCallback? get onEdit => widget.onEdit;
  Map<String, ChatMessage> get repliedMessagesCache =>
      widget.repliedMessagesCache;
  void Function(String messageId) get onScrollToMessage =>
      widget.onScrollToMessage;
  bool get isDMConversation => widget.isDMConversation;

  // Light = Instagram-style (light gray + dark text). Dark = holycow-style (cardDarkColor + white text)
  Color _receivedBubbleColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.cardDarkColor.withValues(alpha: 0.85)
          : const Color(0xFFEFEFEF);
  Color _receivedBubbleBorderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.06);
  Color _receivedTextColor(BuildContext context) => AppTheme.primaryColor;

  Color _sentBubbleColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.cardDarkColor
          : Colors.white;
  Color _sentTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : AppTheme.primaryColor;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      margin: EdgeInsets.only(
        bottom: isLastInGroup ? 16 : 2,
        left: 4,
        right: 4,
      ),
      child: Column(
        crossAxisAlignment:
            isOwnMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (isFirstInGroup && !isDMConversation) _buildSenderRow(context),
          _buildMessageBubbleWithHoverActions(context),
        ],
      ),
    );

    return SwipeableMessage(
      isOwnMessage: isOwnMessage,
      onSwipe: onReply,
      child: content,
    );
  }

  Widget _buildMessageBubbleWithHoverActions(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (!kIsWeb) {
      return _buildMessageBubble(context);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildMessageBubble(context),
          if (_isHovered)
            Positioned(
              top: -4,
              right: isOwnMessage ? null : 8,
              left: isOwnMessage ? 8 : null,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDarkColor : Colors.white,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HoverActionButton(
                      icon: Icons.reply_rounded,
                      tooltip: 'Reply',
                      onTap: onReply,
                    ),
                    _HoverActionButton(
                      icon: Icons.emoji_emotions_outlined,
                      tooltip: 'React',
                      onTap: onLongPress,
                    ),
                    _HoverActionButton(
                      icon: Icons.more_horiz,
                      tooltip: 'More',
                      onTap: onLongPress,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSenderRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
      child: Row(
        mainAxisAlignment:
            isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isOwnMessage) ...[
            UserAvatar(
              userId: message.senderId,
              imageUrl: message.senderAvatar,
              size: 24,
              loadFromFirestore: true,
              nameInitials: message.senderName.isNotEmpty
                  ? message.senderName.substring(0, 1).toUpperCase()
                  : 'U',
              showBorder: false,
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            Text(
              message.senderName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _receivedTextColor(context),
              ),
            ),
          ],
          if (isOwnMessage) ...[
            Text(
              message.senderName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _receivedTextColor(context),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            UserAvatar(
              userId: message.senderId,
              imageUrl: message.senderAvatar,
              size: 24,
              loadFromFirestore: true,
              nameInitials: message.senderName.isNotEmpty
                  ? message.senderName.substring(0, 1).toUpperCase()
                  : 'U',
              showBorder: false,
            ),
          ],
        ],
      ),
    );
  }

  static const double _dmInlineAvatarSize = 28.0;

  Widget _buildMessageBubble(BuildContext context) {
    final isMediaMessage =
        message.messageType == 'image' || message.messageType == 'video';
    final hasReactions = message.reactions.isNotEmpty;
    final showInlineAvatar = isDMConversation && !isOwnMessage;

    return Row(
      mainAxisAlignment:
          isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showInlineAvatar) ...[
          SizedBox(
            width: _dmInlineAvatarSize,
            height: _dmInlineAvatarSize,
            child: isFirstInGroup
                ? UserAvatar(
                    userId: message.senderId,
                    imageUrl: message.senderAvatar,
                    size: _dmInlineAvatarSize,
                    loadFromFirestore: true,
                    nameInitials: message.senderName.isNotEmpty
                        ? message.senderName.substring(0, 1).toUpperCase()
                        : 'U',
                    showBorder: false,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
        ],
        Flexible(
          flex: 4,
          child: ContextMenuWrapper(
            items: _buildContextMenuItems(context),
            child: GestureDetector(
              onLongPress: onLongPress,
              onDoubleTap: onQuickReact,
              onTap: onShowTime,
              child: Padding(
                padding: EdgeInsets.only(bottom: hasReactions ? 6 : 0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    isMediaMessage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            child: MessageBodyBuilder.buildMessageBody(
                              context: context,
                              message: message,
                              isOwnMessage: isOwnMessage,
                              isPending: isPending,
                              sentTextColor: _sentTextColor,
                              receivedTextColor: _receivedTextColor,
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isOwnMessage
                                  ? (isPending
                                      ? _sentBubbleColor(context)
                                          .withValues(alpha: 0.8)
                                      : _sentBubbleColor(context))
                                  : (isPending
                                      ? _receivedBubbleColor(context)
                                          .withValues(alpha: 0.95)
                                      : Colors.transparent),
                              border: isOwnMessage
                                  ? null
                                  : Border.all(
                                      color:
                                          _receivedBubbleBorderColor(context),
                                      width: 1,
                                    ),
                              borderRadius: _getBorderRadius(
                                  isOwnMessage, isFirstInGroup, isLastInGroup),
                            ),
                            child: _buildMessageContent(context),
                          ),
                    if (hasReactions)
                      Positioned(
                        bottom: -14,
                        left: isOwnMessage ? 8 : null,
                        right: isOwnMessage ? null : 8,
                        child: GestureDetector(
                          onTap: onShowReactions,
                          child: MessageBodyBuilder.buildFloatingReactions(
                              message),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<ContextMenuItem> _buildContextMenuItems(BuildContext context) {
    return [
      ContextMenuItems.reply(onTap: onReply),
      ContextMenuItems.react(onTap: onLongPress),
      if (message.content.isNotEmpty)
        ContextMenuItems.copy(onTap: () => _handleCopy(context)),
      if (onForward != null) ContextMenuItems.forward(onTap: onForward!),
      if (onEdit != null) ContextMenuItems.edit(onTap: onEdit!),
      if (isOwnMessage && onDelete != null)
        ContextMenuItems.delete(onTap: onDelete!),
    ];
  }

  void _handleCopy(BuildContext context) {
    final text = message.content;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      showCustomSnackBar(context, message: 'Message copied', duration: const Duration(seconds: 2));
    }
  }

  Widget _buildMessageContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.isForwarded) ForwardedIndicator(isOwnMessage: isOwnMessage),
        if (message.replyTo != null && message.replyTo!.isNotEmpty)
          _buildReplyReference(context),
        MessageBodyBuilder.buildMessageBody(
          context: context,
          message: message,
          isOwnMessage: isOwnMessage,
          isPending: isPending,
          sentTextColor: _sentTextColor,
          receivedTextColor: _receivedTextColor,
        ),
      ],
    );
  }

  Widget _buildReplyReference(BuildContext context) {
    final repliedMessage = repliedMessagesCache[message.replyTo];
    final useReceivedStyle = isOwnMessage;
    final boxColor =
        useReceivedStyle ? AppTheme.scaffoldColor : _sentBubbleColor(context);
    final textColor = useReceivedStyle
        ? _receivedTextColor(context)
        : _sentTextColor(context);

    return GestureDetector(
      onTap: () => onScrollToMessage(message.replyTo!),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: useReceivedStyle
              ? Border.all(
                  color: _receivedBubbleBorderColor(context),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              repliedMessage?.senderName ?? 'Message',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXxs),
            Text(
              repliedMessage?.content ?? 'Original message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static BorderRadius _getBorderRadius(
      bool isOwnMessage, bool isFirstInGroup, bool isLastInGroup) {
    const double radius = 16.0;
    const double smallRadius = 4.0;

    if (isFirstInGroup && isLastInGroup) {
      return BorderRadius.circular(radius);
    } else if (isFirstInGroup) {
      if (isOwnMessage) {
        return const BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(smallRadius),
        );
      } else {
        return const BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(smallRadius),
          bottomRight: Radius.circular(radius),
        );
      }
    } else if (isLastInGroup) {
      if (isOwnMessage) {
        return const BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(smallRadius),
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        );
      } else {
        return const BorderRadius.only(
          topLeft: Radius.circular(smallRadius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        );
      }
    } else {
      if (isOwnMessage) {
        return const BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(smallRadius),
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(smallRadius),
        );
      } else {
        return const BorderRadius.only(
          topLeft: Radius.circular(smallRadius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(smallRadius),
          bottomRight: Radius.circular(radius),
        );
      }
    }
  }
}

/// Small action button shown on hover for web
class _HoverActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HoverActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<_HoverActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.paddingSm),
            decoration: BoxDecoration(
              color: _isHovered
                  ? (isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
