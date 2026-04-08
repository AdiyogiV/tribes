import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/models/dm_conversation.dart';
import 'package:aurogram/providers/ai_chat_provider.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/chat/chat_dialogs.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/pages/ai/ai_chat_page.dart';
import 'package:aurogram/pages/tabs/holycow/holycow_empty_states.dart';
import 'package:intl/intl.dart';

/// Desktop master-detail layout: conversation sidebar on the left,
/// AiChatPage (inline) or cosmic dashboard on the right.
class HolyCowDesktopLayout extends StatefulWidget {
  final VoidCallback onStartNewChat;
  final Widget Function() cosmicDashboardBuilder;

  const HolyCowDesktopLayout({
    super.key,
    required this.onStartNewChat,
    required this.cosmicDashboardBuilder,
  });

  @override
  State<HolyCowDesktopLayout> createState() => _HolyCowDesktopLayoutState();
}

class _HolyCowDesktopLayoutState extends State<HolyCowDesktopLayout> {
  String? _selectedConversationId;

  void _selectConversation(String conversationId) {
    setState(() => _selectedConversationId = conversationId);
  }

  void _startNewChat() {
    final provider = Provider.of<AiChatProvider>(context, listen: false);
    provider.startNewSession();
    setState(() => _selectedConversationId = null);
    widget.onStartNewChat();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Row(
      children: [
        // Left panel — conversation history
        SizedBox(
          width: 340,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkColor : Colors.white,
              border: Border(right: BorderSide(color: dividerColor, width: 1)),
            ),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                AppHeaderStyle.buildWideLayoutHeaderSliver(
                  context,
                  title: 'HolyCow',
                  trailing: IconButton(
                    onPressed: _startNewChat,
                    icon: Icon(
                      Icons.add_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                    tooltip: 'New Chat',
                  ),
                ),
              ],
              body: _ConversationHistoryList(
                isDark: isDark,
                selectedId: _selectedConversationId,
                onSelectConversation: _selectConversation,
              ),
            ),
          ),
        ),

        // Right panel — AiChatPage (own Scaffold) or cosmic dashboard
        Expanded(
          child: _selectedConversationId != null
              ? AiChatPage(
                  key: ValueKey(_selectedConversationId),
                  conversationId: _selectedConversationId,
                  embedded: true,
                )
              : widget.cosmicDashboardBuilder(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Conversation History List
// ─────────────────────────────────────────────────────────────

class _ConversationHistoryList extends StatelessWidget {
  final bool isDark;
  final String? selectedId;
  final ValueChanged<String> onSelectConversation;

  const _ConversationHistoryList({
    required this.isDark,
    required this.selectedId,
    required this.onSelectConversation,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AiChatProvider>(
      builder: (context, provider, _) {
        if (!provider.isUserAuthenticated) {
          return HolyCowSignInPrompt(isDark: isDark);
        }

        return StreamBuilder<List<DmConversation>>(
          stream: provider.getRecentAiConversations(limit: 20),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const HolyCowHistorySkeleton();
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading conversations',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                ),
              );
            }

            final conversations = snapshot.data ?? [];
            if (conversations.isEmpty) {
              return HolyCowEmptyHistory(isDark: isDark);
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSm),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final convo = conversations[index];
                      return _ConversationHistoryItem(
                        key: ValueKey(convo.id),
                        conversation: convo,
                        isDark: isDark,
                        isSelected: convo.id == selectedId,
                        onTap: () => onSelectConversation(convo.id),
                      );
                    },
                  ),
                ),
                _ClearAllHistoryButton(isDark: isDark),
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Individual conversation item
// ─────────────────────────────────────────────────────────────

class _ConversationHistoryItem extends StatelessWidget {
  final DmConversation conversation;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConversationHistoryItem({
    super.key,
    required this.conversation,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
  });

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final title = conversation.firstUserMessage ??
        conversation.lastMessageContent ??
        'New conversation';
    final truncatedTitle =
        title.length > 40 ? '${title.substring(0, 40)}...' : title;
    final timeAgo = _formatTimeAgo(conversation.lastActivity);

    return Material(
      color: isSelected
          ? (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.primaryColor.withValues(alpha: 0.08))
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingLg,
            vertical: AppDimensions.paddingMd,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      truncatedTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXxs),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize - 2,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Clear all history button
// ─────────────────────────────────────────────────────────────

class _ClearAllHistoryButton extends StatelessWidget {
  final bool isDark;

  const _ClearAllHistoryButton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: TextButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          ChatDialogs.showClearAllConversationsDialog(context);
        },
        icon: Icon(
          Icons.delete_sweep_outlined,
          size: 18,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
        label: Text(
          'Clear All History',
          style: TextStyle(
            fontSize: AppTheme.holyCowTextSize,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMd,
            vertical: AppDimensions.paddingSm,
          ),
        ),
      ),
    );
  }
}
