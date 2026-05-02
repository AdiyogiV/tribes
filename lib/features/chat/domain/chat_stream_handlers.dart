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
  Stream<List<ChatMessage>> getMediaMessages(String spaceId,
      {int limit = 50}) {
    try {
      return messagesCollection
          .where('spaceId', isEqualTo: spaceId)
          .where('messageType',
              whereIn: ['image', 'video', 'audio', 'file'])
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
                  if (message.deletedAt == null &&
                      message.mediaUrl != null) {
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

  /// Stream of unread message count for the given [spaceId] and [userId].
  /// ⚠️ PERF: This streams ALL messages in a space with NO .limit() — every
  /// message document is downloaded on each update just to count unreads.
  Stream<int> getUnreadCount(String spaceId, String userId) {
    return messagesCollection
        .where('spaceId', isEqualTo: spaceId)
        .snapshots()
        .map((snapshot) {
      int unreadCount = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final deletedAt = data['deletedAt'];
        final senderId = data['senderId'];
        final readBy = List<String>.from(data['readBy'] ?? []);

        if (deletedAt == null &&
            senderId != userId &&
            !readBy.contains(userId)) {
          unreadCount++;
        }
      }
      // Diagnostic: how many docs are we downloading just to count unreads?
      AppLogger.w('⏱️ PERF getUnreadCount: processed ALL messages in space',
          category: LogCategory.performance,
          data: {
            'spaceId': spaceId,
            'totalDocsDownloaded': snapshot.docs.length,
            'unreadCount': unreadCount,
            'wastedDocs': snapshot.docs.length - unreadCount,
          });
      return unreadCount;
    });
  }
}
