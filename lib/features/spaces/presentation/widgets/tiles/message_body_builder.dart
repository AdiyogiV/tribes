import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurogram/shared/models/chat_message.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/chat/domain/internal_link_utils.dart';
import 'package:aurogram/features/chat/domain/external_link_utils.dart';
import 'package:aurogram/core/routing/dynamic_link_navigator.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/features/chat/presentation/widgets/shared_content_card.dart';
import 'package:aurogram/features/chat/presentation/widgets/external_link_preview_card.dart';
import 'package:aurogram/features/chat/presentation/widgets/link_preview_card.dart';
import 'package:aurogram/features/chat/presentation/widgets/voice_message_widget.dart';
import 'package:aurogram/features/spaces/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Builds message body content (text, media, audio, shared content) for chat tiles.
/// Extracted to keep the main ChatMessageTile file under 600 lines.
class MessageBodyBuilder {
  /// Builds the appropriate message body widget based on message type
  static Widget buildMessageBody({
    required BuildContext context,
    required ChatMessage message,
    required bool isOwnMessage,
    required bool isPending,
    required Color Function(BuildContext) sentTextColor,
    required Color Function(BuildContext) receivedTextColor,
  }) {
    switch (message.messageType) {
      case 'text':
        return buildTextWithLinkPreview(
          context: context,
          message: message,
          isOwnMessage: isOwnMessage,
          sentTextColor: sentTextColor,
          receivedTextColor: receivedTextColor,
        );
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
        final duration = message.fileSize ?? 0;
        final isSendingMessage = isPending ||
            message.status == MessageStatus.sending ||
            (message.mediaUrl != null && !message.mediaUrl!.startsWith('http'));
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: VoiceMessageWidget(
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
                  ? sentTextColor(context)
                  : receivedTextColor(context),
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

  static Widget _buildPlayButton() {
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

  static Widget _buildVideoFallback() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: const Icon(Icons.videocam, color: Colors.white38, size: 48),
        ),
        _buildPlayButton(),
      ],
    );
  }

  static void _playVideo(BuildContext context, String videoUrl) {
    context.push('/media/video', extra: {'videoUrl': videoUrl});
  }

  /// Builds text content with optional link preview (internal or external)
  static Widget buildTextWithLinkPreview({
    required BuildContext context,
    required ChatMessage message,
    required bool isOwnMessage,
    required Color Function(BuildContext) sentTextColor,
    required Color Function(BuildContext) receivedTextColor,
  }) {
    final internalLink =
        InternalLinkUtils.extractFirstInternalLink(message.content);
    final externalLink = internalLink == null
        ? ExternalLinkUtils.extractFirstExternalLink(message.content)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLinkifiedText(
          context: context,
          text: message.content,
          isOwnMessage: isOwnMessage,
          sentTextColor: sentTextColor,
          receivedTextColor: receivedTextColor,
        ),
        if (internalLink != null)
          InternalLinkPreviewBuilder(
            link: internalLink,
            isOwnMessage: isOwnMessage,
          ),
        if (externalLink != null)
          ExternalLinkPreviewBuilder(
            key: ValueKey('link_preview_$externalLink'),
            url: externalLink,
            isOwnMessage: isOwnMessage,
          ),
      ],
    );
  }

  /// Builds text with clickable URL links
  static Widget buildLinkifiedText({
    required BuildContext context,
    required String text,
    required bool isOwnMessage,
    required Color Function(BuildContext) sentTextColor,
    required Color Function(BuildContext) receivedTextColor,
  }) {
    final urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final matches = urlPattern.allMatches(text);
    final receivedColor = receivedTextColor(context);
    final sentColor = sentTextColor(context);

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
  static Widget buildFloatingReactions(ChatMessage message) {
    final reactionCounts = <String, int>{};
    for (final reaction in message.reactions.values) {
      reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...reactionCounts.keys.map((emoji) {
            return Text(
              emoji,
              style: const TextStyle(fontSize: 18),
            );
          }),
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
}

/// Stateful widget to fetch and display internal link previews
class InternalLinkPreviewBuilder extends StatefulWidget {
  final InternalLink link;
  final bool isOwnMessage;

  const InternalLinkPreviewBuilder({
    super.key,
    required this.link,
    required this.isOwnMessage,
  });

  @override
  State<InternalLinkPreviewBuilder> createState() =>
      _InternalLinkPreviewBuilderState();
}

class _InternalLinkPreviewBuilderState
    extends State<InternalLinkPreviewBuilder> {
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
    switch (widget.link.type) {
      case InternalLinkType.post:
        DynamicLinkNavigator.navigateToPost(widget.link.id);
        break;
      case InternalLinkType.profile:
      case InternalLinkType.cosmic:
        DynamicLinkNavigator.navigateToUserProfile(widget.link.id);
        break;
      case InternalLinkType.space:
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
