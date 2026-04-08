import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_models.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/chat/presentation/widgets/voice_message_widget.dart';
import 'package:aurogram/features/ai_chat/presentation/widgets/thoughts_widget.dart';
import 'package:aurogram/features/ai_chat/presentation/widgets/ai_message_builder.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_provider.dart';

// Re-export extracted widgets so existing imports don't break
export 'package:aurogram/features/ai_chat/presentation/widgets/thoughts_widget.dart';
export 'package:aurogram/features/ai_chat/presentation/widgets/typing_indicator.dart';
export 'package:aurogram/features/ai_chat/presentation/widgets/ai_message_builder.dart';

// NOTE: Removed complex _ThoughtsCache - was causing sync issues
// Thoughts now flow from single source: provider.currentThoughtProcess OR message.thoughtProcess

class ChatMessageWidgets {
  /// Build thoughts box below user message
  ///
  /// SINGLE SOURCE OF TRUTH: Thoughts always come from message.thoughtProcess
  /// No session-level thought process, no caching - just the message.
  static Widget buildThoughtsBoxBelowUserMessage(
    AiChatProvider provider,
    BuildContext context, {
    required String userMessageId,
    Map<String, bool>? thoughtExpansionState,
    Function(String, bool)? onThoughtExpansionChanged,
  }) {
    final userMessageIndex =
        provider.messages.indexWhere((m) => m.id == userMessageId);

    if (userMessageIndex == -1) {
      return const SizedBox.shrink();
    }

    // Find the associated assistant message (next message after user)
    AiMessage? assistantMessage;
    for (int i = userMessageIndex + 1; i < provider.messages.length; i++) {
      final msg = provider.messages[i];
      if (msg.role == 'user') break;
      if (msg.role == 'assistant') {
        assistantMessage = msg;
        break;
      }
    }

    // No assistant message = no thoughts to show
    if (assistantMessage == null) {
      return const SizedBox.shrink();
    }

    // SINGLE SOURCE: thoughts always from message.thoughtProcess
    final thoughtProcess = assistantMessage.thoughtProcess;
    final hasThoughts =
        thoughtProcess != null && thoughtProcess.steps.isNotEmpty;

    // ONLY show thoughts box when we actually have thoughts
    // Don't show empty box just because streaming is happening
    if (!hasThoughts) {
      return const SizedBox.shrink();
    }

    final thoughtsKey = 'thoughts_$userMessageId';
    final isExpanded = thoughtExpansionState?[thoughtsKey] ?? false;
    final isStreaming = assistantMessage.pending;

    return ThoughtsOnlyWidget(
      key: ValueKey(thoughtsKey),
      userMessageId: userMessageId,
      thoughtProcess: thoughtProcess,
      isStreaming: isStreaming,
      isExpanded: isExpanded,
      onToggleExpansion: () {
        onThoughtExpansionChanged?.call(thoughtsKey, !isExpanded);
      },
    );
  }

  static Widget buildMessage(
    AiMessage message,
    AiChatProvider provider,
    Map<String, bool> searchResultsExpansionState,
    Function(String, bool) onExpansionChanged,
    BuildContext context, {
    Map<String, bool>? thoughtExpansionState,
    Function(String, bool)? onThoughtExpansionChanged,
  }) {
    final isUser = message.role == 'user';
    final content = message.content;
    final isLastMessage =
        provider.messages.isNotEmpty && provider.messages.last == message;

    final hasSearchResults = !isUser &&
        ((message.searchResults != null && message.searchResults!.isNotEmpty) ||
            (isLastMessage &&
                provider.currentSession.searchResults.isNotEmpty &&
                !provider.isStreaming));

    if (isUser) {
      return _buildUserMessage(message, context);
    } else {
      return AiMessageBuilder.buildAiMessage(
        content,
        hasSearchResults,
        provider,
        message,
        searchResultsExpansionState,
        onExpansionChanged,
        context,
      );
    }
  }

  static Color _sentBubbleColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF3A3A3C)
          : AppTheme.primaryColor;

  static Widget _buildUserMessage(AiMessage message, BuildContext context) {
    final sentColor = _sentBubbleColor(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 1),
          Flexible(
            flex: 5,
            child: message.isVoiceMessage &&
                    message.audioUrl != null &&
                    message.audioUrl!.isNotEmpty &&
                    message.audioUrl != 'local' // Has actual URL for playback
                ? VoiceMessageWidget(
                    transcript: message.content,
                    audioUrl: message.audioUrl!,
                    durationInSeconds: message.audioDuration ?? 0,
                    isUserMessage: true,
                  )
                : message.isVoiceMessage && message.audioUrl == 'local'
                    // Local-only voice message (logged out user) - no upload, no loading
                    ? _buildLocalOnlyVoiceMessage(message, context)
                    : message.isVoiceMessage &&
                            (message.audioUrl == null ||
                                message.audioUrl!.isEmpty)
                        // Still uploading - show loading indicator
                        ? _buildUploadingVoiceMessage(message, sentColor)
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: sentColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: Text(
                              message.content,
                              style: const TextStyle(
                                fontSize: AppTheme.holyCowTextSize,
                                color: Colors.white,
                                height: 1.45,
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// Build uploading voice message bubble
  static Widget _buildUploadingVoiceMessage(
      AiMessage message, Color sentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: sentColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Small loading indicator while uploading
          SizedBox(
            width: 32,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              padding: const EdgeInsets.all(AppDimensions.paddingSm),
              child: const AppLoadingIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMdSm),
          // Duration info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Simple progress placeholder
              Container(
                width: 80,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                message.audioDuration != null
                    ? '${(message.audioDuration! ~/ 60).toString().padLeft(1, '0')}:${(message.audioDuration! % 60).toString().padLeft(2, '0')}'
                    : '0:00',
                style: TextStyle(
                  fontSize: AppTheme.holyCowTextSize,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build local-only voice message bubble (for logged out users)
  /// Shows mic icon instead of loading spinner since upload was skipped
  static Widget _buildLocalOnlyVoiceMessage(
      AiMessage message, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _sentBubbleColor(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mic icon (not loading) - indicates voice sent successfully
          SizedBox(
            width: 32,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              padding: const EdgeInsets.all(AppDimensions.paddingSm),
              child: const Icon(
                Icons.mic,
                size: 16,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMdSm),
          // Duration info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Static progress bar
              Container(
                width: 80,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                message.audioDuration != null
                    ? '${(message.audioDuration! ~/ 60).toString().padLeft(1, '0')}:${(message.audioDuration! % 60).toString().padLeft(2, '0')}'
                    : '0:00',
                style: TextStyle(
                  fontSize: AppTheme.holyCowTextSize,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
