import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/dm_conversation.dart';
import 'package:aurogram/shared/models/contact_match.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/pages/tabs/widgets/messages_empty_state.dart';
import 'package:aurogram/features/chat/presentation/pages/messages_unified_card.dart';
import 'package:aurogram/features/chat/presentation/pages/messages_section_widgets.dart';

/// Builds the full messages list with conversations, contacts on app,
/// contacts not on app, and empty states.
class MessagesAllSections extends StatelessWidget {
  final List<DmConversation> conversations;
  final ContactSyncResult? contactResult;
  final bool hasRequestedContactPermission;
  final Set<String> activeUserIds;
  final Set<String> namastesSentThisSession;
  final int conversationsLimit;
  final int contactsNotOnAppLimit;
  final bool isLoadingContacts;
  final CardTapCallback onCardTap;
  final NamasteSendCallback onSendNamaste;
  final NamasteContactSendCallback onSendNamasteToContact;
  final InviteContactCallback onInviteContact;
  final UserNameBuilder buildUserNameWidget;
  final VoidCallback onSyncContacts;
  final ValueChanged<String> onShowMore;

  const MessagesAllSections({
    super.key,
    required this.conversations,
    required this.contactResult,
    required this.hasRequestedContactPermission,
    required this.activeUserIds,
    required this.namastesSentThisSession,
    required this.conversationsLimit,
    required this.contactsNotOnAppLimit,
    required this.isLoadingContacts,
    required this.onCardTap,
    required this.onSendNamaste,
    required this.onSendNamasteToContact,
    required this.onInviteContact,
    required this.buildUserNameWidget,
    required this.onSyncContacts,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter out pending requests (they're shown in separate page)
    final acceptedConversations = conversations
        .where((c) => c.status != 'pending' && c.status != 'declined')
        .toList();

    // Filter contacts to exclude those with active chats (no duplicates!)
    final contactsOnApp = contactResult?.onApp
            .where(
                (c) => c.userId != null && !activeUserIds.contains(c.userId))
            .toList() ??
        [];
    final contactsNotOnApp = contactResult?.notOnApp ?? [];

    final hasChats = acceptedConversations.isNotEmpty;
    final hasContactsOnApp = contactsOnApp.isNotEmpty;
    final hasContactsNotOnApp = contactsNotOnApp.isNotEmpty;
    final hasNoContent = !hasChats && !hasContactsOnApp && !hasContactsNotOnApp;

    // Build items list for ListView.builder
    final items = <Widget>[];

    // Add chats section
    if (hasChats) {
      for (final conv in acceptedConversations.take(conversationsLimit)) {
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
      if (acceptedConversations.length > conversationsLimit) {
        items.add(MessagesShowMoreButton(
          type: 'conversations',
          remaining: acceptedConversations.length - conversationsLimit,
          isDark: isDark,
          onShowMore: onShowMore,
        ));
      }
      items.add(SizedBox(height: AppDimensions.spacingLg));
    }

    // Show find friends prompt if no contacts synced
    if (contactResult == null && !hasRequestedContactPermission) {
      items.add(MessagesFindFriendsCard(
        isDark: isDark,
        isLoading: isLoadingContacts,
        onTap: onSyncContacts,
      ));
    } else {
      // Contacts on app section
      if (hasContactsOnApp) {
        items.add(MessagesSectionLabel(
            title: 'on aurogram', count: contactsOnApp.length, isDark: isDark));
        for (final contact in contactsOnApp) {
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
        items.add(SizedBox(height: AppDimensions.spacingLg));
      }

      // Contacts not on app section
      if (hasContactsNotOnApp) {
        items.add(MessagesSectionLabel(
            title: 'contacts',
            count: contactsNotOnApp.length,
            isDark: isDark));
        for (final contact in contactsNotOnApp.take(contactsNotOnAppLimit)) {
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
        if (contactsNotOnApp.length > contactsNotOnAppLimit) {
          items.add(MessagesShowMoreButton(
            type: 'contacts',
            remaining: contactsNotOnApp.length - contactsNotOnAppLimit,
            isDark: isDark,
            onShowMore: onShowMore,
          ));
        }
      }
    }

    // Empty state
    if (hasNoContent && contactResult != null) {
      items.add(MessagesEmptyState(isDark: isDark));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding:
          EdgeInsets.only(top: AppHeaderStyle.contentTopPadding, bottom: 220),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }
}
