import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/models/dm_conversation.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';

class RecentConversationsList extends StatelessWidget {
  final List<DmConversation> conversations;
  final int conversationsLimit;
  final VoidCallback onLoadMore;
  final ValueChanged<DmConversation> onSelectConversation;
  final ValueChanged<DmConversation> onShowOptions;

  const RecentConversationsList({
    super.key,
    required this.conversations,
    required this.conversationsLimit,
    required this.onLoadMore,
    required this.onSelectConversation,
    required this.onShowOptions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(top: AppHeaderStyle.contentTopPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title: 'Recent', count: conversations.length),
          ...conversations.map((conv) =>
              _ConversationTile(
                conversation: conv,
                isDark: isDark,
                onTap: () => onSelectConversation(conv),
                onLongPress: () => onShowOptions(conv),
              )),
          if (conversations.length >= conversationsLimit)
            _LoadMoreButton(onTap: onLoadMore),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final int count;

  const _SectionLabel({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding + 4,
        0,
        AppHeaderStyle.contentHorizontalPadding,
        12,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final DmConversation conversation;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.conversation,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark
        ? Theme.of(context).colorScheme.surface
        : Colors.white;
    // Prefer firstUserMessage (user's question) over lastMessageContent (AI response)
    final content = conversation.firstUserMessage ?? conversation.lastMessageContent ?? 'Conversation';
    final truncatedContent =
        content.length > 100 ? '${content.substring(0, 100)}...' : content;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        0,
        AppHeaderStyle.contentHorizontalPadding,
        AppHeaderStyle.cardVerticalGap,
      ),
      child: Material(
        color: cardColor,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onLongPress();
          },
          child: Container(
            height: AppHeaderStyle.cardCompactHeight,
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Row(
              children: [
                Material(
                  elevation: 3,
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.15),
                          AppTheme.primaryColor.withValues(alpha: 0.08),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMdLg),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        truncatedContent,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor.withValues(alpha: 0.85),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(conversation.lastActivity),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      size: 20,
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

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LoadMoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        8,
        AppHeaderStyle.contentHorizontalPadding,
        0,
      ),
      child: TransparentToolbox.buildCard(
        context: context,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            Text(
              'Load More',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime? dateTime) {
  if (dateTime == null) return '';

  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';

  return '${dateTime.day}/${dateTime.month}';
}
