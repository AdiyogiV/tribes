import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/features/feed/data/datasources/space_db_service.dart';
import 'package:aurogram/shared/models/space_roles.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Mixin providing per-user conversation settings (pin, mute, archive)
/// and space permission helpers.
///
/// Consumers must expose:
///   - [firestore]
///   - [currentUser]
///   - [spaceDbService]
mixin ChatConversationSettings {
  FirebaseFirestore get firestore;
  User? get currentUser;
  SpaceDbService get spaceDbService;

  // ---------------------------------------------------------------------------
  // User-conversation settings document helper
  // ---------------------------------------------------------------------------

  DocumentReference _getUserConversationSettings(String conversationId) {
    final userId = currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');
    return firestore
        .collection('userConversationSettings')
        .doc('${userId}_$conversationId');
  }

  /// Returns the persisted settings map for [conversationId].
  Future<Map<String, dynamic>> getConversationSettings(
      String conversationId) async {
    try {
      final doc =
          await _getUserConversationSettings(conversationId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>? ?? {};
      }
      return {};
    } catch (e) {
      AppLogger.e('Error getting conversation settings',
          category: LogCategory.general, error: e);
      return {};
    }
  }

  /// Pin or unpin a conversation.
  Future<void> pinConversation(String conversationId, bool pinned) async {
    try {
      await _getUserConversationSettings(conversationId).set({
        'isPinned': pinned,
        'pinnedAt': pinned ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AppLogger.d(
          'Conversation ${pinned ? 'pinned' : 'unpinned'}: $conversationId',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Error pinning conversation',
          category: LogCategory.general, error: e);
      rethrow;
    }
  }

  /// Mute or unmute a conversation, optionally for a limited [duration].
  Future<void> muteConversation(
    String conversationId,
    bool muted, {
    Duration? duration,
  }) async {
    try {
      final mutedUntil = muted && duration != null
          ? Timestamp.fromDate(DateTime.now().add(duration))
          : null;

      await _getUserConversationSettings(conversationId).set({
        'isMuted': muted,
        'mutedUntil': mutedUntil,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AppLogger.d(
          'Conversation ${muted ? 'muted' : 'unmuted'}: $conversationId',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Error muting conversation',
          category: LogCategory.general, error: e);
      rethrow;
    }
  }

  /// Archive or unarchive a conversation.
  Future<void> archiveConversation(
      String conversationId, bool archived) async {
    try {
      await _getUserConversationSettings(conversationId).set({
        'isArchived': archived,
        'archivedAt': archived ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AppLogger.d(
          'Conversation ${archived ? 'archived' : 'unarchived'}: $conversationId',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Error archiving conversation',
          category: LogCategory.general, error: e);
      rethrow;
    }
  }

  /// Returns false when the conversation is actively muted.
  Future<bool> shouldSendNotification(String conversationId) async {
    try {
      final settings = await getConversationSettings(conversationId);
      final isMuted = settings['isMuted'] as bool? ?? false;

      if (!isMuted) return true;

      final mutedUntil = settings['mutedUntil'] as Timestamp?;
      if (mutedUntil != null &&
          mutedUntil.toDate().isBefore(DateTime.now())) {
        await muteConversation(conversationId, false);
        return true;
      }

      return false;
    } catch (e) {
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // Space permission helpers
  // ---------------------------------------------------------------------------

  /// Returns true when the current user may send messages in [spaceId].
  Future<bool> canSendMessage(String spaceId) async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final role = await spaceDbService.getSpaceRole(spaceId, user.uid);
      // Both public and private spaces: member/admin/creator can send.
      return role == SpaceRoles.member ||
          role == SpaceRoles.admin ||
          role == SpaceRoles.creator;
    } catch (e) {
      AppLogger.e('Error checking message permissions',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Returns true when [userId] (defaults to current user) is admin or creator.
  Future<bool> isAdminOrCreator(String spaceId, [String? userId]) async {
    final uid = userId ?? currentUser?.uid;
    if (uid == null) return false;

    try {
      final role = await spaceDbService.getSpaceRole(spaceId, uid);
      return role == SpaceRoles.admin || role == SpaceRoles.creator;
    } catch (e) {
      return false;
    }
  }
}
