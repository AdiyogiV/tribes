import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/models/dm_conversation.dart';
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

/// Clean, minimalistic card with NO custom bottom borders or margins.
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

    final timeStr = _formatTime(conversation!.lastActivity);
    final previewText = _buildLastMessageTextWithoutTime(conversation!);
    
    final targetUserId = conversation!.participants.firstWhere(
      (id) => id != FirebaseAuth.instance.currentUser?.uid,
      orElse: () => conversation!.participants.first,
    );

    return InkWell(
      onTap: () => onCardTap(conversation: conversation),
      // Solid highlight color with no corner radius for true flush items
      highlightColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
      splashColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            UserAvatar(
              userId: targetUserId,
              size: 40,
              showBorder: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: DefaultTextStyle(
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          child: buildUserNameWidget(targetUserId),
                        ),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
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
