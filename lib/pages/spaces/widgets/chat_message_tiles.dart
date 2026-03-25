import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/chat/internal_link_utils.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/widgets/context_menu.dart';
import 'package:aurogram/widgets/chat/link_preview_card.dart';
import 'package:aurogram/widgets/chat/shared_content_card.dart';
import 'package:aurogram/widgets/chat/external_link_preview_card.dart';
import 'package:aurogram/widgets/chat/voice_message_widget.dart';
import 'package:aurogram/utils/chat/external_link_utils.dart';
import 'package:aurogram/utils/navigation/dynamic_link_navigator.dart';
import 'swipeable_message.dart';
import 'fullscreen_image_viewer.dart';

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
  // Border color for received (other user) bubbles - transparent fill, border only (Instagram-style)
  Color _receivedBubbleBorderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.06);
  Color _receivedTextColor(BuildContext context) => AppTheme.primaryColor;

  // Sent bubble: same as header/typing box (cardDark in dark, white in light), no opacity
  Color _sentBubbleColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.cardDarkColor
          : Colors.white;

  // Text on sent bubble: dark on light bubble (light mode), white on dark bubble (dark mode)
  Color _sentTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : AppTheme.primaryColor;

  @override
  Widget build(BuildContext context) {
    // On web, wrap with MouseRegion for hover detection
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
          // In group chats show sender name/avatar above; in 1:1 (DM) we show avatar inline with bubble instead
          if (isFirstInGroup && !isDMConversation) _buildSenderRow(context),

          // Message bubble with hover actions on web (DM: receiver gets inline avatar inside this row)
          _buildMessageBubbleWithHoverActions(context),

          // Timestamp/status now shown in swipe-left reveal strip (Instagram-style), not below each message
        ],
      ),
    );

    // Wrap with SwipeableMessage for swipe-to-reply
    return SwipeableMessage(
      isOwnMessage: isOwnMessage,
      onSwipe: onReply,
      child: content,
    );
  }

  /// Builds message bubble with hover action buttons on web
  Widget _buildMessageBubbleWithHoverActions(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // On mobile, just return the bubble
    if (!kIsWeb) {
      return _buildMessageBubble(context);
    }

    // On web, wrap with MouseRegion and show action buttons on hover
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildMessageBubble(context),
          // Hover action buttons
          if (_isHovered)
            Positioned(
              top: -4,
              // Position above the message, on the opposite side
              right: isOwnMessage ? null : 8,
              left: isOwnMessage ? 8 : null,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDarkColor : Colors.white,
                  borderRadius: BorderRadius.circular(8),
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
                      onTap:
                          onLongPress, // Opens full options sheet with emoji picker
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
      padding: const EdgeInsets.only(bottom: 8),
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
            const SizedBox(width: 8),
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
            const SizedBox(width: 8),
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

  /// In DM, receiver's avatar shown inline left of bubble (Instagram-style). Same-width spacer when not first in group.
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
        // DM 1:1: small avatar to the left of receiver's bubble (only first in group), or spacer to align
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
          const SizedBox(width: 8),
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
                // Small bottom padding when reactions exist (they float semi-overlapped on message)
                padding: EdgeInsets.only(bottom: hasReactions ? 6 : 0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Message bubble
                    isMediaMessage
                        ? _buildMediaBubble(context)
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
                    // Floating reactions semi-overlapped on bottom corner of message
                    if (hasReactions)
                      Positioned(
                        bottom: -14,
                        left: isOwnMessage ? 8 : null,
                        right: isOwnMessage ? null : 8,
                        child: GestureDetector(
                          onTap: onShowReactions,
                          child: _buildFloatingReactions(),
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

  Widget _buildMediaBubble(BuildContext context) {
    // Media with minimal styling - reactions handled by parent Stack
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: _buildMessageBody(context),
    );
  }

  List<ContextMenuItem> _buildContextMenuItems(BuildContext context) {
    return [
      ContextMenuItems.reply(onTap: onReply),
      ContextMenuItems.react(
          onTap: onLongPress), // Opens full sheet with emoji picker
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildMessageContent(BuildContext context) {
    // Reactions handled by parent Stack - floating outside bubble
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Forwarded indicator
        if (message.isForwarded) ForwardedIndicator(isOwnMessage: isOwnMessage),
        // Reply reference
        if (message.replyTo != null && message.replyTo!.isNotEmpty)
          _buildReplyReference(context),
        _buildMessageBody(context),
      ],
    );
  }

  Widget _buildReplyReference(BuildContext context) {
    final repliedMessage = repliedMessagesCache[message.replyTo];
    // Reply box mimics the *opposite* bubble: in my bubble → received style (scaffold so it contrasts with white); in their bubble → sent style
    final useReceivedStyle = isOwnMessage;
    final boxColor =
        useReceivedStyle ? AppTheme.scaffoldColor : _sentBubbleColor(context);
    final textColor = useReceivedStyle
        ? _receivedTextColor(context)
        : _sentTextColor(context);

    return GestureDetector(
      onTap: () => onScrollToMessage(message.replyTo!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(8),
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
            const SizedBox(height: 2),
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

  Widget _buildMessageBody(BuildContext context) {
    switch (message.messageType) {
      case 'text':
        return _buildTextWithLinkPreview(context);
      case 'image':
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240, maxHeight: 320),
          child: GestureDetector(
            onTap: () => FullscreenImageViewer.show(context, message.mediaUrl!),
            child: Hero(
              tag: 'image_${message.id}',
              child: CachedNetworkImage(
                imageUrl: message.mediaUrl!,
                fit: BoxFit.contain,
                placeholder: (context, url) => const ShimmerImagePlaceholder(
                  width: 240,
                  height: 320,
                  borderRadius: 0,
                ),
                errorWidget: (context, url, error) => Container(
                  width: 240,
                  height: 320,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
        );
      case 'video':
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240, maxHeight: 320),
          child: GestureDetector(
            onTap: () => _playVideo(context, message.mediaUrl!),
            child: message.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: message.thumbnailUrl!,
                    fit: BoxFit.contain,
                    fadeInDuration: Duration.zero,
                    placeholderFadeInDuration: Duration.zero,
                    placeholder: (context, url) => const SizedBox.shrink(),
                    imageBuilder: (context, imageProvider) => Stack(
                      alignment: Alignment.center,
                      children: [
                        Image(image: imageProvider, fit: BoxFit.contain),
                        _buildPlayButton(),
                      ],
                    ),
                    errorWidget: (context, url, error) => _buildVideoFallback(),
                  )
                : _buildVideoFallback(),
          ),
        );
      case 'audio':
        // Voice message - use fileSize as duration in seconds
        final duration = message.fileSize ?? 0;
        // Check if this is an optimistic (sending) message by checking status or URL
        final isSendingMessage = isPending ||
            message.status == MessageStatus.sending ||
            (message.mediaUrl != null && !message.mediaUrl!.startsWith('http'));
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: VoiceMessageWidget(
            // Use unique key to prevent widget reuse issues
            key: ValueKey('voice_${message.id}_${message.mediaUrl ?? ''}'),
            transcript: message.content,
            audioUrl: message.mediaUrl ?? '',
            durationInSeconds: duration,
            isUserMessage: isOwnMessage,
            isSending: isSendingMessage,
          ),
        );
      case 'shared_content':
        if (message.sharedContent == null) {
          return Text(
            message.content,
            style: TextStyle(
              color: isOwnMessage
                  ? _sentTextColor(context)
                  : _receivedTextColor(context),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          );
        }
        return SharedContentCard(
          sharedContent: message.sharedContent!,
          isOwnMessage: isOwnMessage,
          additionalMessage: message.content.isNotEmpty &&
                  !message.content.startsWith('Shared a')
              ? message.content
              : null,
        );
      default:
        return Text(
          'Unsupported message type',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        );
    }
  }

  Widget _buildPlayButton() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  Widget _buildVideoFallback() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.videocam, color: Colors.white38, size: 48),
        ),
        _buildPlayButton(),
      ],
    );
  }

  void _playVideo(BuildContext context, String videoUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoUrl: videoUrl),
      ),
    );
  }

  Widget _buildTextWithLinkPreview(BuildContext context) {
    // Check for internal link first (takes priority)
    final internalLink =
        InternalLinkUtils.extractFirstInternalLink(message.content);

    // Check for external link if no internal link found
    final externalLink = internalLink == null
        ? ExternalLinkUtils.extractFirstExternalLink(message.content)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLinkifiedText(context, message.content),
        // Internal link preview (app links)
        if (internalLink != null)
          _InternalLinkPreviewBuilder(
            link: internalLink,
            isOwnMessage: isOwnMessage,
          ),
        // External link preview (web links with OG data)
        if (externalLink != null)
          ExternalLinkPreviewBuilder(
            key: ValueKey('link_preview_$externalLink'),
            url: externalLink,
            isOwnMessage: isOwnMessage,
          ),
      ],
    );
  }

  Widget _buildLinkifiedText(BuildContext context, String text) {
    final urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final matches = urlPattern.allMatches(text);
    final receivedColor = _receivedTextColor(context);
    final sentColor = _sentTextColor(context);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: isOwnMessage ? sentColor : receivedColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            color: isOwnMessage ? sentColor : receivedColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ));
      }

      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: isOwnMessage ? sentColor : receivedColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: isOwnMessage
              ? sentColor.withValues(alpha: 0.7)
              : receivedColor.withValues(alpha: 0.6),
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          color: isOwnMessage ? sentColor : receivedColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// Floating reaction pill that appears at the bottom corner of the message
  Widget _buildFloatingReactions() {
    // Group reactions by emoji
    final reactionCounts = <String, int>{};
    for (final reaction in message.reactions.values) {
      reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show unique emojis
          ...reactionCounts.keys.map((emoji) {
            return Text(
              emoji,
              style: const TextStyle(fontSize: 18),
            );
          }),
          // Show total count if more than 1
          if (message.reactions.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '${message.reactions.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
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

/// Namaste message tile - just the icon, no bubble
class NamasteMessageTile extends StatelessWidget {
  final ChatMessage message;
  final bool isOwnMessage;
  final bool isLastInGroup;
  final VoidCallback onShowTime;

  const NamasteMessageTile({
    super.key,
    required this.message,
    required this.isOwnMessage,
    this.isLastInGroup = true,
    required this.onShowTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        bottom: isLastInGroup ? 16 : 8,
        left: 4,
        right: 4,
      ),
      child: Column(
        crossAxisAlignment:
            isOwnMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onShowTime,
                child: Image.asset(
                  'assets/icons/namaste.png',
                  width: 48,
                  height: 48,
                  errorBuilder: (_, __, ___) => const Text(
                    '🙏',
                    style: TextStyle(fontSize: 40),
                  ),
                ),
              ),
            ],
          ),
          // Time shown in swipe-left reveal strip (Instagram-style)
        ],
      ),
    );
  }
}

/// Call message tile - shows call history
class CallMessageTile extends StatelessWidget {
  final ChatMessage message;
  final bool isLastInGroup;
  final String? currentUserId;
  final VoidCallback onShowTime;
  final VoidCallback? onCallback;

  const CallMessageTile({
    super.key,
    required this.message,
    this.isLastInGroup = true,
    this.currentUserId,
    required this.onShowTime,
    this.onCallback,
  });

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.senderId == currentUserId;
    final isVideo = message.callType == 'video';
    final status = message.callStatus ?? 'missed';
    final duration = message.callDuration ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData callIcon;
    Color statusColor;
    String statusText;

    switch (status) {
      case 'answered':
        callIcon = isVideo ? Icons.videocam_rounded : Icons.call_rounded;
        statusColor = const Color(0xFF4CAF50);
        statusText = _formatCallDuration(duration);
        break;
      case 'missed':
        callIcon = Icons.phone_missed_rounded;
        statusColor = const Color(0xFFE53935);
        statusText = isOutgoing ? 'No answer' : 'Missed';
        break;
      case 'rejected':
        callIcon = Icons.call_end_rounded;
        statusColor = const Color(0xFFE53935);
        statusText = 'Declined';
        break;
      case 'cancelled':
      default:
        callIcon = Icons.phone_disabled_rounded;
        statusColor = isDark ? Colors.grey[500]! : Colors.grey[600]!;
        statusText = 'Cancelled';
        break;
    }

    final bubbleColor = isOutgoing
        ? (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppTheme.primaryColor.withValues(alpha: 0.15))
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.1));

    return Container(
      margin: EdgeInsets.only(
        bottom: isLastInGroup ? 12 : 4,
        left: 8,
        right: 8,
        top: 4,
      ),
      child: Row(
        mainAxisAlignment:
            isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: GestureDetector(
              onTap: onShowTime,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
                    bottomRight: Radius.circular(isOutgoing ? 4 : 16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(callIcon, size: 18, color: statusColor),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOutgoing
                                    ? Icons.call_made_rounded
                                    : Icons.call_received_rounded,
                                size: 12,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  isVideo ? 'Video call' : 'Voice call',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : Colors.grey[800],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$statusText • ${_formatMessageTime(message.timestamp)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: status == 'missed' && !isOutgoing
                                  ? statusColor.withValues(alpha: 0.8)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if ((status == 'missed' || status == 'rejected') &&
                        !isOutgoing &&
                        onCallback != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onCallback,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVideo
                                ? Icons.videocam_rounded
                                : Icons.call_rounded,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCallDuration(int seconds) {
    if (seconds <= 0) return 'Connected';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}

/// Group call message tile - centered display
class GroupCallMessageTile extends StatelessWidget {
  final ChatMessage message;
  final bool isLastInGroup;
  final VoidCallback onShowTime;

  const GroupCallMessageTile({
    super.key,
    required this.message,
    this.isLastInGroup = true,
    required this.onShowTime,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = message.content;

    return Container(
      margin: EdgeInsets.only(
        bottom: isLastInGroup ? 16 : 6,
        left: 16,
        right: 16,
        top: 6,
      ),
      child: Center(
        child: GestureDetector(
          onTap: onShowTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                  : const Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    size: 16,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Started by ${message.senderName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Content for the left-side strip revealed when user swipes chat left (Instagram-style).
/// Shows time, "edited" if any, and status icon for own messages.
class TimestampRevealStrip extends StatelessWidget {
  final ChatMessage message;
  final bool isOwnMessage;
  final bool isLastInGroup;

  const TimestampRevealStrip({
    super.key,
    required this.message,
    required this.isOwnMessage,
    required this.isLastInGroup,
  });

  static String formatRevealTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.primaryColor.withValues(alpha: 0.5);
    final isEdited = message.editedAt != null;
    final isRead = message.readBy.isNotEmpty &&
        message.readBy.any((userId) => userId != message.senderId);

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isEdited)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                'edited',
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isOwnMessage && isLastInGroup) ...[
                _buildStatusIcon(color, isRead),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(
                  formatRevealTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(Color color, bool isRead) {
    switch (message.status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 14,
          height: 14,
          child: MessageSendingIndicator(),
        );
      case MessageStatus.sent:
        return Icon(Icons.done, size: 14, color: color);
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: isRead ? Colors.blue : color,
        );
    }
  }
}

/// Date separator between messages
class ChatDateSeparator extends StatelessWidget {
  final DateTime date;

  const ChatDateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDateSeparator(date),
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else if (date.year == now.year) {
      return DateFormat('MMM d').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}

/// Stateful widget to fetch and display internal link previews
class _InternalLinkPreviewBuilder extends StatefulWidget {
  final InternalLink link;
  final bool isOwnMessage;

  const _InternalLinkPreviewBuilder({
    required this.link,
    required this.isOwnMessage,
  });

  @override
  State<_InternalLinkPreviewBuilder> createState() =>
      _InternalLinkPreviewBuilderState();
}

class _InternalLinkPreviewBuilderState
    extends State<_InternalLinkPreviewBuilder> {
  InternalLinkPreview? _preview;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchPreview();
  }

  Future<void> _fetchPreview() async {
    try {
      final preview = await InternalLinkUtils.fetchPreview(widget.link);
      if (mounted) {
        setState(() {
          _preview = preview;
          _isLoading = false;
          _hasError = preview == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _handleTap() {
    // Navigate to the appropriate screen based on link type
    switch (widget.link.type) {
      case InternalLinkType.post:
        DynamicLinkNavigator.navigateToPost(widget.link.id);
        break;
      case InternalLinkType.profile:
      case InternalLinkType.cosmic:
        DynamicLinkNavigator.navigateToUserProfile(widget.link.id);
        break;
      case InternalLinkType.space:
        // No inviter ID when opening from chat link preview
        DynamicLinkNavigator.navigateToSpaceInvite(widget.link.id, null);
        break;
      case InternalLinkType.unknown:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LinkPreviewLoading();
    }

    if (_hasError || _preview == null) {
      return const SizedBox.shrink();
    }

    return LinkPreviewCard(
      preview: _preview!,
      onTap: _handleTap,
      compact: true,
    );
  }
}

/// Simple fullscreen video player for chat videos
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
        _controller.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: _hasError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white54, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load video',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              )
            : !_isInitialized
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_controller.value.isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                        // Play/pause overlay
                        if (!_controller.value.isPlaying)
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        // Progress bar at bottom
                        Positioned(
                          bottom: 40,
                          left: 20,
                          right: 20,
                          child: VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: AppTheme.primaryColor,
                              bufferedColor: Colors.white30,
                              backgroundColor: Colors.white10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? (isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
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
