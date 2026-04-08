import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/providers/ai_chat_provider.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/chat/chat_message_widgets.dart';

/// Renders AI chat messages inside a [CustomScrollView] sliver.
///
/// Extracted from the old inline `_buildChatContent()` in HolyCowPage.
/// Uses [SliverList.builder] for efficient virtualization of long conversations.
class AiChatMessageList extends StatefulWidget {
  const AiChatMessageList({super.key});

  @override
  State<AiChatMessageList> createState() => _AiChatMessageListState();
}

class _AiChatMessageListState extends State<AiChatMessageList> {
  final Map<String, bool> _searchResultsExpansionState = {};
  final Map<String, bool> _thoughtExpansionState = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<AiChatProvider>(
      builder: (context, provider, _) {
        if (provider.messages.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppHeaderStyle.contentHorizontalPadding,
            AppHeaderStyle.contentTopPadding,
            AppHeaderStyle.contentHorizontalPadding,
            12,
          ),
          sliver: SliverList.builder(
            itemCount: provider.messages.length,
            itemBuilder: (context, index) {
              final message = provider.messages[index];
              final isUserMessage = message.role == 'user';

              final hasFollowingAssistant = isUserMessage &&
                  index + 1 < provider.messages.length &&
                  provider.messages[index + 1].role == 'assistant';

              final isNewTurn = isUserMessage &&
                  index > 0 &&
                  provider.messages[index - 1].role == 'assistant';

              return Column(
                key: ValueKey('msg_column_${message.id}'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Subtle separator between conversation turns
                  if (isNewTurn)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),

                  // The message bubble
                  ChatMessageWidgets.buildMessage(
                    message,
                    provider,
                    _searchResultsExpansionState,
                    (messageId, isExpanded) {
                      setState(() {
                        _searchResultsExpansionState[messageId] = isExpanded;
                      });
                    },
                    context,
                    thoughtExpansionState: _thoughtExpansionState,
                    onThoughtExpansionChanged: (messageId, isExpanded) {
                      setState(() {
                        _thoughtExpansionState[messageId] = isExpanded;
                      });
                    },
                  ),

                  // Thoughts box below user message if assistant follows
                  if (hasFollowingAssistant)
                    ChatMessageWidgets.buildThoughtsBoxBelowUserMessage(
                      provider,
                      context,
                      userMessageId: message.id,
                      thoughtExpansionState: _thoughtExpansionState,
                      onThoughtExpansionChanged: (messageId, isExpanded) {
                        setState(() {
                          _thoughtExpansionState[messageId] = isExpanded;
                        });
                      },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
