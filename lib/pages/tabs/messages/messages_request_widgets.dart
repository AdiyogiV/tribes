import 'package:flutter/material.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:aurogram/models/dm_conversation.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/common/user_avatar.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Tab chip selector for switching between Chats and Requests tabs
class MessagesTabChips extends StatelessWidget {
  final int selectedIndex; // 0 = chats, 1 = requests
  final int chatCount;
  final int pendingCount;
  final ValueChanged<int> onTabChanged;

  const MessagesTabChips({
    super.key,
    required this.selectedIndex,
    required this.chatCount,
    required this.pendingCount,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Row(
      children: [
        Expanded(
          child: _MessagesTabChip(
            label: 'Chats',
            count: chatCount,
            selected: selectedIndex == 0,
            onSelected: () => onTabChanged(0),
            cardColor: cardColor,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingMd),
        Expanded(
          child: _MessagesTabChip(
            label: 'Requests',
            count: pendingCount,
            selected: selectedIndex == 1,
            onSelected: () => onTabChanged(1),
            cardColor: cardColor,
          ),
        ),
      ],
    );
  }
}

class _MessagesTabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;
  final Color cardColor;

  const _MessagesTabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        selected ? AppTheme.primaryColor : AppTheme.textSecondaryColor;
    return GestureDetector(
      onTap: onSelected,
      child: Material(
        color: selected ? cardColor : Colors.transparent,
        elevation: selected ? 0.8 : 0.0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
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

/// Inline message request card with accept/decline buttons
class MessagesRequestCard extends StatelessWidget {
  final DmConversation request;
  final bool isDark;
  final Future<void> Function(DmConversation request) onAccept;
  final Future<void> Function(String conversationId) onDecline;

  const MessagesRequestCard({
    super.key,
    required this.request,
    required this.isDark,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkColor : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLg),
            child: Row(
              children: [
                UserAvatar(
                  userId: request.otherUserId,
                  size: 56,
                  loadFromFirestore: true,
                  nameInitials: request.otherUserId.isNotEmpty
                      ? request.otherUserId[0].toUpperCase()
                      : 'U',
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.spaceName ?? request.otherUserId,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        'Wants to send you a message',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (request.lastMessageContent != null &&
              request.lastMessageContent!.isNotEmpty) ...[
            Divider(
              height: 1,
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingLg),
              child: Text(
                request.lastMessageContent!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.primaryColor.withValues(alpha: 0.8),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onDecline(request.id),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppTheme.errorColor,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onAccept(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      'View',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds the full message requests content with StreamBuilder,
/// loading/error states, and request cards.
class MessagesRequestsSliverContent extends StatelessWidget {
  final Stream<List<DmConversation>> conversationsStream;
  final String? currentUserId;
  final List<DmConversation> cachedConversations;
  final Future<void> Function(DmConversation request) onAccept;
  final Future<void> Function(String conversationId) onDecline;

  const MessagesRequestsSliverContent({
    super.key,
    required this.conversationsStream,
    required this.currentUserId,
    required this.cachedConversations,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return EmptyStateWidget(
        icon: Icons.inbox_outlined,
        iconSize: 64,
        iconColor: AppTheme.primaryColor.withValues(alpha: 0.3),
        title: 'Please log in to view message requests',
        padding: const EdgeInsets.all(AppDimensions.paddingXxl),
      );
    }

    return StreamBuilder<List<DmConversation>>(
      stream: conversationsStream,
      builder: (context, snapshot) {
        // Show loading only on initial load
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            cachedConversations.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingXxl),
            child: const AppLoadingIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingXxl),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Text(
                    'Error loading message requests',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final conversations = snapshot.data ?? cachedConversations;
        final pendingRequests = conversations.where((c) =>
          c.status == 'pending' &&
          c.requestedBy != currentUserId
        ).toList();

        if (pendingRequests.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.inbox_outlined,
            iconSize: 64,
            iconColor: AppTheme.primaryColor.withValues(alpha: 0.3),
            title: 'No message requests',
            subtitle:
                'When someone wants to message you, their request will appear here.',
            padding: const EdgeInsets.all(AppDimensions.paddingXxl),
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          children: pendingRequests.map((request) => MessagesRequestCard(
            request: request,
            isDark: isDark,
            onAccept: onAccept,
            onDecline: onDecline,
          )).toList(),
        );
      },
    );
  }
}

