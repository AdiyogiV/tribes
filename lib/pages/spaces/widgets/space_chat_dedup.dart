import 'package:aurogram/models/chat_message.dart';

/// Deduplicates optimistic (sending) messages against real Firestore messages.
///
/// Extracted from space_chat_screen.dart to reduce file size.
class SpaceChatDedup {
  SpaceChatDedup._();

  /// Merges [sendingMessages] with [messages] from the server, replacing
  /// optimistic copies with the real ones and removing matched entries from
  /// [sendingMessages] in-place.
  static List<ChatMessage> deduplicateMessages(
    List<ChatMessage> messages,
    List<ChatMessage> sendingMessages,
  ) {
    final Map<String, ChatMessage> messageMap = {};
    final Set<String> usedRealMessageIds = {};

    for (final sending in sendingMessages) {
      final realMessage = messages.firstWhere(
        (real) => _isMatchingMessage(real, sending),
        orElse: () => ChatMessage(
          id: '',
          spaceId: '',
          senderId: '',
          senderName: '',
          content: '',
          messageType: '',
          reactions: {},
          readBy: [],
          timestamp: DateTime.now(),
        ),
      );

      if (realMessage.id.isNotEmpty) {
        messageMap[sending.id] = realMessage;
        usedRealMessageIds.add(realMessage.id);
      } else {
        messageMap[sending.id] = sending;
      }
    }

    for (final message in messages) {
      if (!usedRealMessageIds.contains(message.id)) {
        messageMap[message.id] = message;
      }
    }

    sendingMessages.removeWhere(
        (sending) => messages.any((real) => _isMatchingMessage(real, sending)));

    final allMessages = messageMap.values.toList();
    allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return allMessages;
  }

  static bool _isMatchingMessage(ChatMessage real, ChatMessage sending) {
    if (real.senderId != sending.senderId) return false;
    if (real.messageType != sending.messageType) return false;

    final timeDiff =
        real.timestamp.difference(sending.timestamp).inSeconds.abs();
    if (timeDiff > 30) return false;

    if (sending.messageType == 'audio') {
      return real.fileSize == sending.fileSize;
    }

    return real.content == sending.content;
  }
}
