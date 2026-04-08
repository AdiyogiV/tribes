import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/models/chat_message.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Mixin providing typing indicators and @-mention user resolution.
///
/// Consumers must expose:
///   - [firestore]
///   - [usersCollection]
///   - [currentUser]
mixin ChatPresence {
  FirebaseFirestore get firestore;
  CollectionReference get usersCollection;
  User? get currentUser;

  // ---------------------------------------------------------------------------
  // Typing indicators
  // ---------------------------------------------------------------------------

  DateTime? _lastTypingUpdate;
  static const _typingThrottleMs = 2000;

  /// Update the typing status for the current user in [spaceId].
  Future<void> setTyping(String spaceId, bool isTyping) async {
    final user = currentUser;
    if (user == null) return;

    if (isTyping) {
      final now = DateTime.now();
      if (_lastTypingUpdate != null &&
          now.difference(_lastTypingUpdate!).inMilliseconds <
              _typingThrottleMs) {
        return;
      }
      _lastTypingUpdate = now;
    }

    try {
      final typingRef =
          firestore.collection('typing').doc('${spaceId}_${user.uid}');

      if (isTyping) {
        String userName = 'User';
        try {
          final userDoc = await usersCollection.doc(user.uid).get();
          final userData = userDoc.data() as Map<String, dynamic>?;
          if (userData != null) {
            final name =
                userData['name'] as String? ?? userData['nickname'] as String?;
            if (name != null && name.toString().trim().isNotEmpty) {
              userName = name.toString().trim();
            }
          }
        } catch (_) {/* use fallback */}

        if (userName == 'User') {
          final authName = user.displayName?.trim();
          if (authName != null && authName.isNotEmpty) userName = authName;
        }

        await typingRef.set({
          'spaceId': spaceId,
          'userId': user.uid,
          'userName': userName,
          'isTyping': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await typingRef.delete();
        _lastTypingUpdate = null;
      }
    } catch (e) {
      AppLogger.w('Failed to update typing status',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Stream of users currently typing in [spaceId] (excludes current user).
  Stream<List<TypingUser>> getTypingUsers(String spaceId) {
    final currentUserId = currentUser?.uid;

    return firestore
        .collection('typing')
        .where('spaceId', isEqualTo: spaceId)
        .snapshots()
        .map((snapshot) {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 10));

      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            final updatedAt = data['updatedAt'] as Timestamp?;

            if (updatedAt == null) return null;
            if (updatedAt.toDate().isBefore(cutoff)) return null;
            if (data['userId'] == currentUserId) return null;

            final rawName = data['userName']?.toString().trim();
            final userName =
                (rawName != null && rawName.isNotEmpty) ? rawName : 'User';
            return TypingUser(
              userId: data['userId'] ?? '',
              userName: userName,
            );
          })
          .whereType<TypingUser>()
          .toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Mentionable users
  // ---------------------------------------------------------------------------

  /// Returns the list of users that can be @-mentioned in [spaceId].
  Future<List<MentionableUser>> getMentionableUsers(String spaceId) async {
    final currentUserId = currentUser?.uid;
    if (currentUserId == null) return [];

    try {
      final users = <MentionableUser>[];

      if (spaceId.startsWith('dm_')) {
        final parts = spaceId.split('_');
        if (parts.length == 3) {
          final otherUserId =
              parts[1] == currentUserId ? parts[2] : parts[1];
          final userDoc = await usersCollection.doc(otherUserId).get();
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            users.add(MentionableUser(
              userId: otherUserId,
              name: data?['name'] ?? data?['nickname'] ?? 'User',
              avatar: data?['displayPicture'],
            ));
          }
        }
        return users;
      }

      final rolesSnapshot = await firestore
          .collection('spaceRoles')
          .doc(spaceId)
          .collection('roles')
          .where('role', whereIn: ['creator', 'admin', 'member'])
          .limit(50)
          .get();

      for (final roleDoc in rolesSnapshot.docs) {
        if (roleDoc.id == currentUserId) continue;

        try {
          final userDoc = await usersCollection.doc(roleDoc.id).get();
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            users.add(MentionableUser(
              userId: roleDoc.id,
              name: data?['name'] ?? data?['nickname'] ?? 'User',
              avatar: data?['displayPicture'],
            ));
          }
        } catch (e) {
          continue;
        }
      }

      return users;
    } catch (e) {
      AppLogger.e('Error getting mentionable users',
          category: LogCategory.general, error: e);
      return [];
    }
  }
}
