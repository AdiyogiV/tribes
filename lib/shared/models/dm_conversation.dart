import 'package:aurogram/models/space_types.dart';

/// Represents a direct message conversation
class DmConversation {
  final String id;
  final String otherUserId;
  final List<String> participants;
  final DateTime lastActivity;
  final DateTime createdAt;
  final String? lastMessageContent;
  final String? lastMessageSenderId;
  final String? lastMessageSenderName;
  // Space-specific fields (null for actual DMs)
  final String? displayPicture;
  final SpaceType? spaceType;
  final String? spaceName;
  // Context type for AI conversations (e.g., 'astrology' for astrology-initiated chats)
  final String? contextType;
  // First user message for AI conversations (used as conversation title)
  final String? firstUserMessage;
  // Conversation management settings
  final bool isPinned;
  final bool isMuted;
  final bool isArchived;
  final DateTime? mutedUntil;
  // Message request status: 'pending', 'accepted', 'declined' (null = accepted for backward compat)
  final String? status;
  final String? requestedBy; // Who initiated the conversation

  const DmConversation({
    required this.id,
    required this.otherUserId,
    required this.participants,
    required this.lastActivity,
    required this.createdAt,
    this.lastMessageContent,
    this.lastMessageSenderId,
    this.lastMessageSenderName,
    this.displayPicture,
    this.spaceType,
    this.spaceName,
    this.contextType,
    this.firstUserMessage,
    this.isPinned = false,
    this.isMuted = false,
    this.isArchived = false,
    this.mutedUntil,
    this.status,
    this.requestedBy,
  });

  /// Create a copy with updated fields
  DmConversation copyWith({
    bool? isPinned,
    bool? isMuted,
    bool? isArchived,
    DateTime? mutedUntil,
  }) {
    return DmConversation(
      id: id,
      otherUserId: otherUserId,
      participants: participants,
      lastActivity: lastActivity,
      createdAt: createdAt,
      lastMessageContent: lastMessageContent,
      lastMessageSenderId: lastMessageSenderId,
      lastMessageSenderName: lastMessageSenderName,
      displayPicture: displayPicture,
      spaceType: spaceType,
      spaceName: spaceName,
      contextType: contextType,
      firstUserMessage: firstUserMessage,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      mutedUntil: mutedUntil ?? this.mutedUntil,
      status: status,
      requestedBy: requestedBy,
    );
  }
}
