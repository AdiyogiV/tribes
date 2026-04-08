import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/core/theme/app_theme.dart';

import 'space_chat_header.dart';

/// The header row containing back button, name/status, and action icons.
///
/// Extracted from space_chat_screen.dart to reduce file size.
class SpaceChatHeaderRow extends StatelessWidget {
  final String? displayName;
  final String? otherUserId;
  final String spaceId;
  final bool isDMConversation;
  final bool isLoadingName;
  final bool isOtherUserOnline;
  final DateTime? otherUserLastSeen;
  final Space? space;
  final VoidCallback onNavigateToHeader;
  final VoidCallback onConversationOptions;
  final VoidCallback onGalleryTap;
  final VoidCallback onSearchTap;

  const SpaceChatHeaderRow({
    super.key,
    required this.displayName,
    required this.otherUserId,
    required this.spaceId,
    required this.isDMConversation,
    required this.isLoadingName,
    required this.isOtherUserOnline,
    this.otherUserLastSeen,
    this.space,
    required this.onNavigateToHeader,
    required this.onConversationOptions,
    required this.onGalleryTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Icon(Icons.arrow_back_ios,
                  color: AppTheme.primaryColor, size: 22),
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onNavigateToHeader,
              onLongPress: onConversationOptions,
              behavior: HitTestBehavior.opaque,
              child: SpaceChatHeaderContent(
                key: ValueKey('header_${otherUserId ?? spaceId}'),
                displayName: displayName,
                otherUserId: otherUserId,
                isDMConversation: isDMConversation,
                isLoadingName: isLoadingName,
                isOtherUserOnline: isOtherUserOnline,
                otherUserLastSeen: otherUserLastSeen,
                space: space,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SpaceChatHeaderActions(
            spaceId: spaceId,
            displayName: displayName,
            otherUserId: otherUserId,
            isDMConversation: isDMConversation,
            onInfoTap: onNavigateToHeader,
            onGalleryTap: onGalleryTap,
            onSearchTap: onSearchTap,
          ),
        ),
      ],
    );
  }
}
