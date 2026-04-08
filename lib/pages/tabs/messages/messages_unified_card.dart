import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/models/dm_conversation.dart';
import 'package:aurogram/models/space_types.dart';
import 'package:aurogram/models/contact_match.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/common/user_avatar.dart';
import 'package:aurogram/widgets/preview_boxes/gram_picture.dart';
import 'package:aurogram/pages/tabs/widgets/namaste_button.dart';

/// Callback types for card interactions
typedef CardTapCallback = void Function({
  DmConversation? conversation,
  ContactMatch? contact,
  bool isInvite,
});
typedef NamasteSendCallback = Future<void> Function(String userId);
typedef NamasteContactSendCallback = Future<void> Function(ContactMatch contact);
typedef InviteContactCallback = Future<void> Function(ContactMatch contact);
typedef UserNameBuilder = Widget Function(String userId);

/// A unified card widget used for conversations, contacts, and invites
/// in the messages list.
class MessagesUnifiedCard extends StatelessWidget {
  final String? userId;
  final DmConversation? conversation;
  final ContactMatch? contact;
  final bool isInvite;
  final bool isDark;
  final Set<String> namastesSentThisSession;
  final CardTapCallback onCardTap;
  final NamasteSendCallback onSendNamaste;
  final NamasteContactSendCallback onSendNamasteToContact;
  final InviteContactCallback onInviteContact;
  final UserNameBuilder buildUserNameWidget;

  const MessagesUnifiedCard({
    super.key,
    this.userId,
    this.conversation,
    this.contact,
    this.isInvite = false,
    required this.isDark,
    required this.namastesSentThisSession,
    required this.onCardTap,
    required this.onSendNamaste,
    required this.onSendNamasteToContact,
    required this.onInviteContact,
    required this.buildUserNameWidget,
  });

  Color _getSpaceTypeColor(SpaceType? type) {
    if (type == null) return AppTheme.primaryColor;
    if (isPrivateSpaceType(type)) {
      return AppTheme.warningColor;
    }
    return AppTheme.successColor;
  }

  String _getSpaceTypeLabel(SpaceType? type) {
    if (type == null) return 'Private';
    return getSpaceTypeName(type);
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w';
    }
  }

  String _buildLastMessageTextWithoutTime(DmConversation conversation) {
    if (conversation.lastMessageContent != null &&
        conversation.lastMessageContent!.isNotEmpty) {
      final isGroupSpace = conversation.participants.length > 2;
      final isFromCurrentUser = conversation.lastMessageSenderId ==
          FirebaseAuth.instance.currentUser?.uid;

      String prefix = '';
      if (isGroupSpace && conversation.lastMessageSenderName != null) {
        prefix = isFromCurrentUser
            ? 'You: '
            : '${conversation.lastMessageSenderName}: ';
      } else if (!isGroupSpace && isFromCurrentUser) {
        prefix = 'You: ';
      }

      return '$prefix${conversation.lastMessageContent}';
    }

    if (!conversation.id.startsWith('dm_')) {
      final isGroupSpace = conversation.participants.length > 2;
      if (isGroupSpace) {
        return '${conversation.participants.length} members';
      } else {
        return 'No messages yet';
      }
    }

    return 'Start a conversation';
  }

  Widget _buildSpaceAvatarCompact(DmConversation conversation) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GramPicture(
            displayPicture: conversation.displayPicture,
            size: 44,
            spaceId: conversation.id,
            borderRadius: 14.0,
          ),
          if (conversation.spaceType != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: _getSpaceTypeColor(conversation.spaceType),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Center(
                  child: Text(
                    _getSpaceTypeLabel(conversation.spaceType),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardAvatar() {
    // User avatar for DMs and contacts on app
    if (userId != null) {
      return UserAvatar(
        userId: userId!,
        size: 44,
        borderRadius: BorderRadius.circular(22),
        loadFromFirestore: true,
      );
    }

    // Space avatar for group conversations
    if (conversation != null && !conversation!.id.startsWith('dm_')) {
      return _buildSpaceAvatarCompact(conversation!);
    }

    // Initial avatar for contacts not on app
    if (contact != null && isInvite) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: Text(
          contact!.name.isNotEmpty ? contact!.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }

    // Fallback
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Icon(Icons.person, color: AppTheme.primaryColor),
    );
  }

  Widget _buildCardContent() {
    // For DM conversations - show user name + last message
    if (conversation != null && conversation!.id.startsWith('dm_')) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildUserNameWidget(conversation!.otherUserId),
          SizedBox(height: AppDimensions.spacingXxs),
          Text(
            _buildLastMessageTextWithoutTime(conversation!),
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    // For group spaces - show space name + last message
    if (conversation != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conversation!.spaceName ?? 'Gram',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: AppDimensions.spacingXxs),
          Text(
            _buildLastMessageTextWithoutTime(conversation!),
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    // For contacts (on app or not)
    if (contact != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact!.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isInvite
                  ? (isDark ? AppTheme.textDarkColor : AppTheme.textLightColor)
                  : AppTheme.primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: AppDimensions.spacingXxs),
          Text(
            contact!.displayPhone,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppTheme.textSecondaryDarkColor
                  : AppTheme.textSecondaryLightColor,
            ),
          ),
        ],
      );
    }

    return SizedBox.shrink();
  }

  Widget _buildNamasteIconButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          if (isInvite && contact != null) {
            onInviteContact(contact!);
          } else if (userId != null) {
            onSendNamaste(userId!);
          } else if (contact?.userId != null) {
            onSendNamasteToContact(contact!);
          }
        },
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Image.asset(
            'assets/icons/namaste.png',
            width: 36,
            height: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildNamasteWithArrow() {
    final targetUserId = userId ?? contact?.userId;
    final hasNamasteSent =
        targetUserId != null && namastesSentThisSession.contains(targetUserId);

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arrow cue - always there behind, revealed when button fades
          Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            size: 26,
          ),
          // Namaste button on top (fades away when sent)
          if (!hasNamasteSent)
            NamasteButton(
              onTap: () async {
                if (userId != null) {
                  await onSendNamaste(userId!);
                } else if (contact?.userId != null) {
                  await onSendNamasteToContact(contact!);
                }
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    final bool isContactNotOnApp = contact != null && isInvite;

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
          onTap: () => onCardTap(
            conversation: conversation,
            contact: contact,
            isInvite: isInvite,
          ),
          child: Container(
            height: AppHeaderStyle.cardCompactHeight,
            padding: EdgeInsets.only(left: 20, right: 12),
            child: Row(
              children: [
                // Avatar with elevation
                Material(
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.4),
                  shape: CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: _buildCardAvatar(),
                ),
                SizedBox(width: AppDimensions.spacingMdLg),

                // Content
                Expanded(child: _buildCardContent()),

                // Trailing - Time first, then Namaste button (rightmost) with arrow behind
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Time for conversations (moved to left of namaste)
                    if (conversation != null) ...[
                      Text(
                        _formatTime(conversation!.lastActivity),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor.withValues(alpha: 0.5),
                        ),
                      ),
                      SizedBox(width: AppDimensions.spacingSm),
                    ],
                    // Stack for namaste button with arrow behind it
                    if (userId != null || (contact?.userId != null))
                      _buildNamasteWithArrow(),
                    // Invite button for contacts not on app
                    if (isContactNotOnApp) _buildNamasteIconButton(),
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
