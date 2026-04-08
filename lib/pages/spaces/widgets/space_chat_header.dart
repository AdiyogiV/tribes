import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/common/user_avatar.dart';
import 'package:aurogram/widgets/call/call_button.dart';
import 'package:aurogram/widgets/call/group_call_button.dart';

/// Chat header content widget showing avatar, name, and online status
class SpaceChatHeaderContent extends StatelessWidget {
  final String? displayName;
  final String? otherUserId;
  final bool isDMConversation;
  final bool isLoadingName;
  final bool isOtherUserOnline;
  final DateTime? otherUserLastSeen;
  final Space? space;

  const SpaceChatHeaderContent({
    super.key,
    this.displayName,
    this.otherUserId,
    required this.isDMConversation,
    this.isLoadingName = false,
    this.isOtherUserOnline = false,
    this.otherUserLastSeen,
    this.space,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingName) {
      return _buildLoadingSkeleton();
    }

    final name = displayName ?? space?.name ?? 'Chat';

    // Build status text
    String? statusText;
    Color statusColor = AppTheme.primaryColor.withValues(alpha: 0.5);

    if (isDMConversation) {
      if (isOtherUserOnline) {
        statusText = 'Active now';
        statusColor = AppTheme.activeGreen;
      } else if (otherUserLastSeen != null) {
        statusText = 'Last seen ${_formatLastSeen(otherUserLastSeen!)}';
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar with online indicator
        Stack(
          children: [
            if (isDMConversation && otherUserId != null)
              Material(
                key: ValueKey('header_avatar_material_$otherUserId'),
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.3),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: UserAvatar(
                  key: ValueKey('header_avatar_$otherUserId'),
                  userId: otherUserId!,
                  size: 34,
                  loadFromFirestore: true,
                  nameInitials: name.isNotEmpty
                      ? name.substring(0, 1).toUpperCase()
                      : 'U',
                  showBorder: false,
                ),
              )
            else
              Material(
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.3),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.group_rounded,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                    size: 18,
                  ),
                ),
              ),
            // Online indicator dot
            if (isDMConversation && isOtherUserOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.activeGreen,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: AppDimensions.spacingMdSm),
        // Name and status column - wrapped in Flexible to prevent overflow
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w300,
                  fontSize: 17,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (statusText != null) ...[
                const SizedBox(height: AppDimensions.spacingXxs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOtherUserOnline) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.activeGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingXs),
                    ],
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingMdSm),
        Container(
          width: 80,
          height: 14,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ],
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastSeen.month}/${lastSeen.day}';
    }
  }
}

/// Header actions (call buttons, gallery button, search button)
class SpaceChatHeaderActions extends StatelessWidget {
  final String spaceId;
  final String? displayName;
  final String? otherUserId;
  final bool isDMConversation;
  final VoidCallback onInfoTap;
  final VoidCallback? onGalleryTap;
  final VoidCallback? onSearchTap;

  const SpaceChatHeaderActions({
    super.key,
    required this.spaceId,
    this.displayName,
    this.otherUserId,
    required this.isDMConversation,
    required this.onInfoTap,
    this.onGalleryTap,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    // 1:1 calls work on web via WebRTC
    if (isDMConversation && otherUserId != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search button
          if (onSearchTap != null)
            _HeaderIconButton(
              icon: Icons.search,
              tooltip: 'Search messages',
              onTap: onSearchTap!,
            ),
          // Gallery button
          if (onGalleryTap != null)
            _HeaderIconButton(
              icon: Icons.photo_library_outlined,
              tooltip: 'Media gallery',
              onTap: onGalleryTap!,
            ),
          CallButtons(
            userId: otherUserId!,
            userName: displayName ?? 'User',
            iconSize: 22,
            spacing: 4,
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search button
        if (onSearchTap != null)
          _HeaderIconButton(
            icon: Icons.search,
            tooltip: 'Search messages',
            onTap: onSearchTap!,
          ),
        // Gallery button
        if (onGalleryTap != null)
          _HeaderIconButton(
            icon: Icons.photo_library_outlined,
            tooltip: 'Media gallery',
            onTap: onGalleryTap!,
          ),
        // Group call button (same color as other header icons)
        GroupCallButton(
          spaceId: spaceId,
          spaceName: displayName ?? 'Group Call',
          size: 22,
          iconColor: AppTheme.primaryColor.withValues(alpha: 0.6),
        ),
      ],
    );
  }
}

/// Reusable header icon button with web tooltip and hover support
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Icon(
            icon,
            color: AppTheme.primaryColor.withValues(alpha: 0.6),
            size: 22,
          ),
        ),
      ),
    );

    return Tooltip(
      message: tooltip,
      child: button,
    );
  }
}
