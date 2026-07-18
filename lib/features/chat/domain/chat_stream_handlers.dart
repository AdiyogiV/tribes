import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/models/chat_message.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Mixin providing real-time Firestore stream handlers for chat messages.
mixin ChatStreamHandlers {
  FirebaseFirestore get firestore;
  CollectionReference get messagesCollection;

  // ---------------------------------------------------------------------------
  // Real-time message streams
  // ---------------------------------------------------------------------------

  /// Get real-time messages for a space (newest 50, oldest-first order).
  Stream<List<ChatMessage>> getMessages(String spaceId) {
    try {
      return messagesCollection
          .where('spaceId', isEqualTo: spaceId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) {
        try {
          final messages = <ChatMessage>[];
          for (final doc in snapshot.docs) {
            try {
              final message = ChatMessage.fromJson({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              });
              if (message.deletedAt == null) {
                messages.add(message);
              }
            } catch (e) {
              AppLogger.e('Error parsing message document',
                  category: LogCategory.general, error: e);
            }
          }
          return messages.reversed.toList();
        } catch (e) {
          AppLogger.e('Error mapping message snapshot',
              category: LogCategory.general, error: e);
          return <ChatMessage>[];
        }
      }).handleError((error) {
        AppLogger.e('Error in messages stream',
            category: LogCategory.general, error: error);
        return <ChatMessage>[];
      });
    } catch (e) {
      AppLogger.e('Error setting up messages stream',
          category: LogCategory.general, error: e);
      return Stream.value(<ChatMessage>[]);
    }
  }

  /// Get media-only messages for a space (for media gallery).
  Stream<List<ChatMessage>> getMediaMessages(String spaceId, {int limit = 50}) {
    try {
      return messagesCollection
          .where('spaceId', isEqualTo: spaceId)
          .where('messageType', whereIn: ['image', 'video', 'audio', 'file'])
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            try {
              final messages = <ChatMessage>[];
              for (final doc in snapshot.docs) {
                try {
                  final message = ChatMessage.fromJson({
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  });
                  if (message.deletedAt == null && message.mediaUrl != null) {
                    messages.add(message);
                  }
                } catch (e) {
                  AppLogger.e('Error parsing media message',
                      category: LogCategory.general, error: e);
                }
              }
              return messages;
            } catch (e) {
              AppLogger.e('Error mapping media snapshot',
                  category: LogCategory.general, error: e);
              return <ChatMessage>[];
            }
          })
          .handleError((error) {
            AppLogger.e('Error in media messages stream',
                category: LogCategory.general, error: error);
            return <ChatMessage>[];
          });
    } catch (e) {
      AppLogger.e('Error setting up media messages stream',
          category: LogCategory.general, error: e);
      return Stream.value(<ChatMessage>[]);
    }
  }

  // ---------------------------------------------------------------------------
  // Unread count stream
  // ---------------------------------------------------------------------------

  /// Stream a bounded unread badge count for [spaceId].
  ///
  /// Firestore cannot express "array does not contain this user", so the old
  /// implementation downloaded the entire conversation on every update. Badge
  /// UI only needs a capped count; inspecting the newest 100 candidates keeps
  /// native CursorWindow and Dart allocations strictly bounded.
  Stream<int> getUnreadCount(String spaceId, String userId) {
    return messagesCollection
        .where('spaceId', isEqualTo: spaceId)
        .orderBy('timestamp', descending: true)
        .limit(unreadMessageScanLimit)
        .snapshots()
        .map((snapshot) => countUnreadMessages(
              snapshot.docs.map(
                (doc) => doc.data() as Map<String, dynamic>,
              ),
              userId,
            ));
  }
}

const int unreadMessageScanLimit = 100;
const int unreadBadgeLimit = 99;

/// Counts unread message maps without retaining parsed [ChatMessage] objects.
/// The result saturates at 99 because badges render "99+" above that point.
int countUnreadMessages(
  Iterable<Map<String, dynamic>> messages,
  String userId,
) {
  var count = 0;
  for (final data in messages) {
    final readBy = data['readBy'];
    final wasRead = readBy is Iterable && readBy.contains(userId);
    if (data['deletedAt'] == null && data['senderId'] != userId && !wasRead) {
      count++;
      if (count == unreadBadgeLimit) return unreadBadgeLimit;
    }
  }
  return count;
}
