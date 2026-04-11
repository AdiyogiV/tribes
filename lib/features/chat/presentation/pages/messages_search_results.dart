import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show QueryDocumentSnapshot;
import 'package:aurogram/shared/models/dm_conversation.dart';
import 'package:aurogram/shared/models/contact_match.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/shared/services/search_service.dart';
import 'package:aurogram/features/chat/presentation/pages/messages_unified_card.dart';
import 'package:aurogram/features/chat/presentation/pages/messages_section_widgets.dart';

/// User search result card shown when searching for users to start a chat
class MessagesUserSearchResultCard extends StatelessWidget {
  final QueryDocumentSnapshot userDoc;
  final bool isDark;
  final Set<String> namastesSentThisSession;
  final void Function(String userId, String userName) onStartConversation;
  final NamasteSendCallback onSendNamaste;

  const MessagesUserSearchResultCard({
    super.key,
    required this.userDoc,
    required this.isDark,
    required this.namastesSentThisSession,
    required this.onStartConversation,
    required this.onSendNamaste,
  });

  @override
  Widget build(BuildContext context) {
    final userData = userDoc.data() as Map<String, dynamic>;
    final userName = userData['name'] as String? ??
        userData['nickname'] as String? ??
        'Unknown User';
    final userNickname = userData['nickname'] as String? ?? '';
    final displayPicture = userData['displayPicture'] as String?;
    final userId = userDoc.id;

    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    final hasNamasteSent = namastesSentThisSession.contains(userId);

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
          onTap: () => onStartConversation(userId, userName),
          child: Container(
            height: AppHeaderStyle.cardCompactHeight,
            padding: EdgeInsets.only(left: 20, right: 12),
            child: Row(
              children: [
                Material(
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.4),
                  shape: CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: UserAvatar(
                    userId: userId,
                    imageUrl:
                        (displayPicture != null && displayPicture.isNotEmpty)
                            ? displayPicture
                            : null,
                    size: 44,
                    borderRadius: BorderRadius.circular(22),
                    loadFromFirestore:
                        displayPicture == null || displayPicture.isEmpty,
                    nameInitials:
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  ),
                ),
                SizedBox(width: AppDimensions.spacingMdLg),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (userNickname.isNotEmpty) ...[
                        SizedBox(height: AppDimensions.spacingXxs),
                        Text(
                          '@$userNickname',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.primaryColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Namaste button with arrow
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.primaryColor.withValues(alpha: 0.4),
                        size: 26,
                      ),
                      if (!hasNamasteSent)
                        importNamasteButton(onSendNamaste, userId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper to create the namaste button inline (avoids importing NamasteButton directly)
Widget importNamasteButton(NamasteSendCallback onSendNamaste, String userId) {
  return _NamasteTapWidget(onTap: () => onSendNamaste(userId));
}

class _NamasteTapWidget extends StatelessWidget {
  final VoidCallback onTap;
  const _NamasteTapWidget({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
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
}

/// Builds the search results view with categorized sections
class MessagesSearchResultsView extends StatelessWidget {
  final List<DmConversation> conversations;
  final List<QueryDocumentSnapshot> userSearchResults;
  final bool isSearchingUsers;
  final String searchQuery;
  final ContactSyncResult? contactResult;
  final bool isDark;
  final Set<String> namastesSentThisSession;
  final CardTapCallback onCardTap;
  final NamasteSendCallback onSendNamaste;
  final NamasteContactSendCallback onSendNamasteToContact;
  final InviteContactCallback onInviteContact;
  final UserNameBuilder buildUserNameWidget;
  final void Function(String userId, String userName) onStartConversation;

  const MessagesSearchResultsView({
    super.key,
    required this.conversations,
    required this.userSearchResults,
    required this.isSearchingUsers,
    required this.searchQuery,
    required this.contactResult,
    required this.isDark,
    required this.namastesSentThisSession,
    required this.onCardTap,
    required this.onSendNamaste,
    required this.onSendNamasteToContact,
    required this.onInviteContact,
    required this.buildUserNameWidget,
    required this.onStartConversation,
  });

  @override
  Widget build(BuildContext context) {
    // Collect all user IDs already shown
    final shownUserIds = <String>{};
    for (final conv in conversations) {
      if (conv.id.startsWith('dm_')) {
        shownUserIds.add(conv.otherUserId);
      }
    }

    // Filter contacts by search query and exclude already shown
    final filteredContactsOnApp = contactResult?.onApp
            .where((c) =>
                SearchService.smartMatch(searchQuery, c.name) &&
                c.userId != null &&
                !shownUserIds.contains(c.userId))
            .toList() ??
        [];

    // Add contact user IDs to shown set
    for (final contact in filteredContactsOnApp) {
      if (contact.userId != null) {
        shownUserIds.add(contact.userId!);
      }
    }

    // Filter user search results to exclude already shown
    final filteredUserResults = userSearchResults
        .where((user) => !shownUserIds.contains(user.id))
        .toList();

    final filteredContactsNotOnApp = contactResult?.notOnApp
            .where((c) => SearchService.smartMatch(searchQuery, c.name))
            .toList() ??
        [];

    final hasConversations = conversations.isNotEmpty;
    final hasUsers = filteredUserResults.isNotEmpty;
    final hasContactsOnApp = filteredContactsOnApp.isNotEmpty;
    final hasContactsNotOnApp = filteredContactsNotOnApp.isNotEmpty;
    final hasResults =
        hasConversations || hasUsers || hasContactsOnApp || hasContactsNotOnApp;

    if (isSearchingUsers && !hasResults) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: List.generate(4, (_) => SkeletonListItem()),
        ),
      );
    }

    if (!hasResults) {
      return _buildNoResults(context);
    }

    // Build items list
    final items = <Widget>[];

    if (hasConversations) {
      items.add(MessagesSectionLabel(
          title: 'conversations', count: conversations.length, isDark: isDark));
      for (final conv in conversations) {
        items.add(MessagesUnifiedCard(
          userId: conv.id.startsWith('dm_') ? conv.otherUserId : null,
          conversation: conv,
          isDark: isDark,
          namastesSentThisSession: namastesSentThisSession,
          onCardTap: onCardTap,
          onSendNamaste: onSendNamaste,
          onSendNamasteToContact: onSendNamasteToContact,
          onInviteContact: onInviteContact,
          buildUserNameWidget: buildUserNameWidget,
        ));
      }
    }

    if (hasUsers) {
      items.add(MessagesSectionLabel(
          title: 'start new chat',
          count: filteredUserResults.length,
          isDark: isDark));
      for (final userDoc in filteredUserResults) {
        items.add(MessagesUserSearchResultCard(
          userDoc: userDoc,
          isDark: isDark,
          namastesSentThisSession: namastesSentThisSession,
          onStartConversation: onStartConversation,
          onSendNamaste: onSendNamaste,
        ));
      }
    }

    if (hasContactsOnApp) {
      items.add(MessagesSectionLabel(
          title: 'on aurogram',
          count: filteredContactsOnApp.length,
          isDark: isDark));
      for (final contact in filteredContactsOnApp) {
        items.add(MessagesUnifiedCard(
          userId: contact.userId,
          contact: contact,
          isDark: isDark,
          namastesSentThisSession: namastesSentThisSession,
          onCardTap: onCardTap,
          onSendNamaste: onSendNamaste,
          onSendNamasteToContact: onSendNamasteToContact,
          onInviteContact: onInviteContact,
          buildUserNameWidget: buildUserNameWidget,
        ));
      }
    }

    if (hasContactsNotOnApp) {
      items.add(MessagesSectionLabel(
          title: 'contacts',
          count: filteredContactsNotOnApp.length,
          isDark: isDark));
      for (final contact in filteredContactsNotOnApp.take(10)) {
        items.add(MessagesUnifiedCard(
          contact: contact,
          isInvite: true,
          isDark: isDark,
          namastesSentThisSession: namastesSentThisSession,
          onCardTap: onCardTap,
          onSendNamaste: onSendNamaste,
          onSendNamasteToContact: onSendNamasteToContact,
          onInviteContact: onInviteContact,
          buildUserNameWidget: buildUserNameWidget,
        ));
      }
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding:
          EdgeInsets.only(top: AppHeaderStyle.contentTopPadding, bottom: 210),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  Widget _buildNoResults(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 40,
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: AppDimensions.spacingXxl),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Try a different search term',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
