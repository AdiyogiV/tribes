import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/features/chat/presentation/widgets/embedded_chat_view.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/app/tabs/widgets/messages_search_bar.dart';

/// Desktop master-detail layout with conversation list on left and chat on right
class MessagesDesktopLayout extends StatelessWidget {
  final Widget messagesListWidget;
  final String? selectedConversationId;
  final Space? selectedSpace;
  final String? selectedOtherUserId;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;

  const MessagesDesktopLayout({
    super.key,
    required this.messagesListWidget,
    required this.selectedConversationId,
    required this.selectedSpace,
    required this.selectedOtherUserId,
    required this.isRefreshing,
    required this.onRefresh,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Row(
      children: [
        // Left panel - Conversation list (fixed width)
        SizedBox(
          width: 340,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkColor : Colors.white,
              border: Border(
                right: BorderSide(color: dividerColor, width: 1),
              ),
            ),
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async => onRefresh(),
                  color: AppTheme.primaryColor,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      AppHeaderStyle.buildWideLayoutHeaderSliver(
                        context,
                        title: 'Messages',
                        trailing: isRefreshing
                            ? AppLoadingIndicator(
                                size: 20,
                                strokeWidth: 2,
                              )
                            : null,
                      ),
                      SliverToBoxAdapter(child: messagesListWidget),
                      SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: MessagesSearchBar(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    onSearchChanged: onSearchChanged,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right panel - Chat view (fills remaining space)
        Expanded(
          child: selectedConversationId != null
              ? EmbeddedChatView(
                  spaceId: selectedConversationId!,
                  space: selectedSpace,
                  otherUserId: selectedOtherUserId,
                )
              : _MessagesEmptyDetailState(isDark: isDark),
        ),
      ],
    );
  }
}

/// Empty state shown when no conversation is selected in desktop layout
class _MessagesEmptyDetailState extends StatelessWidget {
  final bool isDark;

  const _MessagesEmptyDetailState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_2,
              size: 80,
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppDimensions.spacingXxl),
            Text(
              'Select a conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Choose from your existing conversations\nor start a new one',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
