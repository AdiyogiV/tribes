import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/models/dm_conversation.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/shared/models/contact_match.dart';

/// Helper enum for ListView.builder items in messages page
enum MessageListItemType {
  sectionLabel,
  conversation,
  messageRequest,
  contactOnApp,
  contactNotOnApp,
  userSearchResult,
  findFriends,
  showMore,
  spacer,
  emptyState,
}

/// Helper class for ListView.builder items in messages page
class MessageListItem {
  final MessageListItemType type;
  final String? title;
  final int? count;
  final DmConversation? conversation;
  final ContactMatch? contactOnApp;
  final ContactMatch? contactNotOnApp;
  final QueryDocumentSnapshot? userDoc;

  MessageListItem._({
    required this.type,
    this.title,
    this.count,
    this.conversation,
    this.contactOnApp,
    this.contactNotOnApp,
    this.userDoc,
  });

  factory MessageListItem.sectionLabel(String title, int count) =>
      MessageListItem._(
          type: MessageListItemType.sectionLabel, title: title, count: count);

  factory MessageListItem.conversation(DmConversation conv) =>
      MessageListItem._(
          type: MessageListItemType.conversation, conversation: conv);

  factory MessageListItem.messageRequest(DmConversation request) =>
      MessageListItem._(
          type: MessageListItemType.messageRequest, conversation: request);

  factory MessageListItem.sectionHeader(String title) =>
      MessageListItem._(
          type: MessageListItemType.sectionLabel, title: title);

  factory MessageListItem.contactOnApp(ContactMatch contact) =>
      MessageListItem._(
          type: MessageListItemType.contactOnApp, contactOnApp: contact);

  factory MessageListItem.contactNotOnApp(ContactMatch contact) =>
      MessageListItem._(
          type: MessageListItemType.contactNotOnApp, contactNotOnApp: contact);

  factory MessageListItem.userSearchResult(QueryDocumentSnapshot doc) =>
      MessageListItem._(
          type: MessageListItemType.userSearchResult, userDoc: doc);

  factory MessageListItem.findFriends() =>
      MessageListItem._(type: MessageListItemType.findFriends);

  factory MessageListItem.showMore(String type, int count) => MessageListItem._(
      type: MessageListItemType.showMore, title: type, count: count);

  factory MessageListItem.spacer() =>
      MessageListItem._(type: MessageListItemType.spacer);

  factory MessageListItem.emptyState() =>
      MessageListItem._(type: MessageListItemType.emptyState);
}
