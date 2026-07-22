import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/models/dm_conversation.dart';
import 'package:aurogram/shared/models/space_types.dart';
import 'package:aurogram/shared/models/contact_match.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';

typedef CardTapCallback = void Function({
  DmConversation? conversation,
  ContactMatch? contact,
  bool isInvite,
});
typedef NamasteSendCallback = Future<void> Function(String userId);
typedef NamasteContactSendCallback = Future<void> Function(ContactMatch contact);
typedef InviteContactCallback = Future<void> Function(ContactMatch contact);
typedef UserNameBuilder = Widget Function(String userId);

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

  String _formatTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays.abs() > 1825) return '';
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }

  String _buildLastMessageTextWithoutTime(DmConversation conversation) {
    if (conversation.lastMessageContent != null && conversation.lastMessageContent!.isNotEmpty) {
      final isFromCurrentUser = conversation.lastMessageSenderId == FirebaseAuth.instance.currentUser?.uid;
      return isFromCurrentUser ? 'You: ${conversation.lastMessageContent}' : conversation.lastMessageContent!;
    }
    return 'Started a conversation';
  }

  @override
  Widget build(BuildContext context) {
    if (conversation == null) return const SizedBox.shrink();

    // DmConversation doesn't have unread count directly without joining with other data in this model, 
    // so we'll omit the strong bolding for simplicity in this minimal card.
    final hasUnread = false; 
    
    final timeStr = _formatTime(conversation!.lastActivity);
    final previewText = _buildLastMessageTextWithoutTime(conversation!);
    
    final targetUserId = conversation!.participants.firstWhere(
      (id) => id != FirebaseAuth.instance.currentUser?.uid,
      orElse: () => conversation!.participants.first,
    );

    return InkWell(
      onTap: () => onCardTap(conversation: conversation),
      borderRadius: BorderRadius.circular(20),
      highlightColor: Colors.transparent,
      splashColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: hasUnread 
              ? (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5)) 
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  if (hasUnread) 
                    BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 12)
                ],
              ),
              child: UserAvatar(
                userId: targetUserId,
                size: 48,
                showBorder: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: buildUserNameWidget(targetUserId),
                      ),
                      if (timeStr.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                              color: hasUnread 
                                  ? (isDark ? Colors.white : Colors.black) 
                                  : (isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          previewText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                            color: hasUnread 
                                ? (isDark ? Colors.white70 : Colors.black87) 
                                : (isDark ? Colors.white54 : Colors.black54),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
