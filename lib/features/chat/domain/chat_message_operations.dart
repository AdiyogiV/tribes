import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/models/chat_message.dart';
import 'package:aurogram/shared/services/analytics_service.dart';
import 'package:aurogram/features/chat/domain/chat_notification_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Mixin providing message CRUD operations (send, edit, delete, react, search).
///
/// Consumers must expose:
///   - [firestore]
///   - [messagesCollection]
///   - [usersCollection]
///   - [currentUser]
///   - [notificationService]
///   - [isDirectMessage]
///   - [canSendMessage]
///   - [isAdminOrCreator]
///   - [updateConversationMetadata]
///   - [createDirectMessage]
mixin ChatMessageOperations {
  FirebaseFirestore get firestore;
  CollectionReference get messagesCollection;
  CollectionReference get usersCollection;
  User? get currentUser;
  ChatNotificationService get notificationService;

  bool isDirectMessage(String conversationId);
  Future<bool> canSendMessage(String spaceId);
  Future<bool> isAdminOrCreator(String spaceId, [String? userId]);
  Future<void> updateConversationMetadata(
      String conversationId, Map<String, dynamic> lastMessageData);
  Future<String> createDirectMessage(String otherUserId);

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, String?>> _getUserInfo(String uid) async {
    final userDoc = await usersCollection.doc(uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final userName = userData != null
        ? (userData['name'] as String? ??
            userData['nickname'] as String? ??
            'Unknown User')
        : 'Unknown User';
    final userAvatar =
        userData != null ? (userData['displayPicture'] as String? ?? '') : null;
    return {'name': userName, 'avatar': userAvatar};
  }

  // ---------------------------------------------------------------------------
  // Send messages
  // ---------------------------------------------------------------------------

  /// Send a plain text message.
  Future<void> sendTextMessage(
    String spaceId,
    String content, {
    String? replyTo,
    List<String>? mentionedUserIds,
  }) async {
    try {
      AppLogger.d('Sending text message to space: $spaceId',
          category: LogCategory.general);

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      if (!isDirectMessage(spaceId)) {
        final canSend = await canSendMessage(spaceId);
        AppLogger.d('Permission check result: $canSend',
            category: LogCategory.general);
        if (!canSend) {
          throw Exception(
              'You do not have permission to send messages in this space');
        }
      } else {
        AppLogger.d('DM detected, checking conversation status',
            category: LogCategory.general);
        final conversationDoc = await firestore
            .collection('dmConversations')
            .doc(spaceId)
            .get();

        if (conversationDoc.exists) {
          final status = conversationDoc.data()?['status'] as String?;
          if (status == 'pending') {
            final requestedBy =
                conversationDoc.data()?['requestedBy'] as String?;
            if (requestedBy != currentUser!.uid) {
              throw Exception(
                  'This conversation is pending. Please accept the message request first.');
            }
          }
        }
      }

      // Check if user is deleted
      final deletedDoc = await firestore
          .collection('deletedUsers')
          .doc(currentUser!.uid)
          .get();
      if (deletedDoc.exists) {
        throw Exception('Cannot send message: Your account has been deleted');
      }

      final info = await _getUserInfo(currentUser!.uid);
      final userName = info['name']!;
      final userAvatar = info['avatar'];

      AppLogger.d('Got user info: $userName', category: LogCategory.general);

      final messageData = {
        'spaceId': spaceId,
        'senderId': currentUser!.uid,
        'senderName': userName,
        'senderAvatar': userAvatar,
        'content': content,
        'messageType': 'text',
        'replyTo': replyTo,
        'reactions': {},
        'readBy': [currentUser!.uid],
        'timestamp': FieldValue.serverTimestamp(),
        if (mentionedUserIds != null && mentionedUserIds.isNotEmpty)
          'mentionedUserIds': mentionedUserIds,
      };

      await messagesCollection.add(messageData);
      AppLogger.d('Message sent successfully', category: LogCategory.general);

      AnalyticsService().trackMessageSent(
        conversationType: isDirectMessage(spaceId) ? 'dm' : 'space',
      );

      await updateConversationMetadata(spaceId, {
        'content': content,
        'senderId': currentUser!.uid,
        'senderName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      });

      try {
        await notificationService.sendChatNotification(
          spaceId: spaceId,
          senderId: currentUser!.uid,
          senderName: userName,
          messageContent: content,
          messageType: 'text',
        );
      } catch (e) {
        AppLogger.e('Failed to send message notification',
            category: LogCategory.general);
      }
    } catch (e) {
      AppLogger.e('Error sending text message',
          category: LogCategory.general, error: e);
      rethrow;
    }
  }

  /// Send a namaste greeting message.
  Future<void> sendNamasteMessage(String spaceId) async {
    try {
      AppLogger.d('Sending namaste message to: $spaceId',
          category: LogCategory.general);

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final info = await _getUserInfo(currentUser!.uid);
      final userName = info['name']!;
      final userAvatar = info['avatar'];

      final messageData = {
        'spaceId': spaceId,
        'senderId': currentUser!.uid,
        'senderName': userName,
        'senderAvatar': userAvatar,
        'content': '🙏',
        'messageType': 'namaste',
        'reactions': {},
        'readBy': [currentUser!.uid],
        'timestamp': FieldValue.serverTimestamp(),
      };

      await messagesCollection.add(messageData);
      AppLogger.d('Namaste message sent successfully',
          category: LogCategory.general);

      try {
        await notificationService.sendChatNotification(
          spaceId: spaceId,
          senderId: currentUser!.uid,
          senderName: userName,
          messageContent: '🙏 Namaste',
          messageType: 'namaste',
        );
      } catch (e) {
        AppLogger.e('Failed to send namaste notification',
            category: LogCategory.general);
      }
    } catch (e) {
      AppLogger.e('Error sending namaste message',
          category: LogCategory.general, error: e);
      rethrow;
    }
  }

  /// Send shared content (post, profile, space, insight) to a conversation.
  Future<void> sendSharedContent({
    required String spaceId,
    required Map<String, dynamic> sharedContent,
    String? message,
  }) async {
    try {
      AppLogger.d('Sending shared content to: $spaceId',
          category: LogCategory.general);

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      if (spaceId.startsWith('dm_')) {
        final parts = spaceId.split('_');
        if (parts.length == 3) {
          final otherUserId =
              parts[1] == currentUser!.uid ? parts[2] : parts[1];
          await createDirectMessage(otherUserId);
        }
      } else {
        final canSend = await canSendMessage(spaceId);
        if (!canSend) {
          throw Exception(
              'You do not have permission to send messages in this space');
        }
      }

      final info = await _getUserInfo(currentUser!.uid);
      final userName = info['name']!;
      final userAvatar = info['avatar'];

      final contentType = sharedContent['type'] as String? ?? 'content';
      final contentTitle =
          sharedContent['title'] as String? ?? 'Shared $contentType';

      final messageData = {
        'spaceId': spaceId,
        'senderId': currentUser!.uid,
        'senderName': userName,
        'senderAvatar': userAvatar,
        'content': message ?? 'Shared a $contentType',
        'messageType': 'shared_content',
        'sharedContent': sharedContent,
        'reactions': {},
        'readBy': [currentUser!.uid],
        'timestamp': FieldValue.serverTimestamp(),
      };

      await messagesCollection.add(messageData);
      AppLogger.d('Shared content message sent successfully',
          category: LogCategory.general);

      await updateConversationMetadata(spaceId, {
        'content':
            message?.isNotEmpty == true ? message : 'Shared a $contentType',
        'senderId': currentUser!.uid,
        'senderName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'shared_content',
      });

      try {
        await notificationService.sendChatNotification(
          spaceId: spaceId,
          senderId: currentUser!.uid,
          senderName: userName,
          messageContent: message?.isNotEmpty == true
              ? message!
              : 'Shared a $contentType: $contentTitle',
          messageType: 'shared_content',
        );
      } catch (e) {
        AppLogger.e('Failed to send shared content notification',
            category: LogCategory.general);
      }
    } catch (e) {
      AppLogger.e('Error sending shared content',
          category: LogCategory.general, error: e);
      rethrow;
    }
  }

  /// Forward a message to another conversation.
  Future<void> forwardMessage({
    required String targetSpaceId,
    required ChatMessage originalMessage,
    String? additionalMessage,
  }) async {
    try {
      AppLogger.d('Forwarding message to: $targetSpaceId',
          category: LogCategory.general);

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      if (targetSpaceId.startsWith('dm_')) {
        final parts = targetSpaceId.split('_');
        if (parts.length == 3) {
          final otherUserId =
              parts[1] == currentUser!.uid ? parts[2] : parts[1];
          await createDirectMessage(otherUserId);
        }
      } else {
        final canSend = await canSendMessage(targetSpaceId);
        if (!canSend) {
          throw Exception(
              'You do not have permission to send messages in this space');
        }
      }

      final info = await _getUserInfo(currentUser!.uid);
      final userName = info['name']!;
      final userAvatar = info['avatar'];

      final messageData = {
        'spaceId': targetSpaceId,
        'senderId': currentUser!.uid,
        'senderName': userName,
        'senderAvatar': userAvatar,
        'content': originalMessage.content,
        'messageType': originalMessage.messageType,
        'mediaUrl': originalMessage.mediaUrl,
        'thumbnailUrl': originalMessage.thumbnailUrl,
        'fileSize': originalMessage.fileSize,
        'isForwarded': true,
        'forwardedFrom': originalMessage.id,
        'reactions': {},
        'readBy': [currentUser!.uid],
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (originalMessage.messageType == 'shared_content' &&
          originalMessage.sharedContent != null) {
        messageData['sharedContent'] = originalMessage.sharedContent;
      }

      await messagesCollection.add(messageData);
      AppLogger.d('Message forwarded successfully',
          category: LogCategory.general);

      String previewContent;
      switch (originalMessage.messageType) {
        case 'image':
          previewContent = '📷 Forwarded a photo';
          break;
        case 'video':
          previewContent = '🎬 Forwarded a video';
          break;
        case 'audio':
          previewContent = '🎵 Forwarded an audio';
          break;
        case 'file':
          previewContent = '📎 Forwarded a file';
          break;
        case 'shared_content':
          final type = originalMessage.sharedContent?['type'] ?? 'content';
          previewContent = 'Forwarded a $type';
          break;
        default:
          previewContent = originalMessage.content.length > 50
              ? '${originalMessage.content.substring(0, 50)}...'
              : originalMessage.content;
      }

      await updateConversationMetadata(targetSpaceId, {
        'content': previewContent,
        'senderId': currentUser!.uid,
        'senderName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'type': originalMessage.messageType,
      });

      try {
        await notificationService.sendChatNotification(
          spaceId: targetSpaceId,
          senderId: currentUser!.uid,
          senderName: userName,
          messageContent: previewContent,
          messageType: originalMessage.messageType,
        );
      } catch (e) {
        AppLogger.e('Failed to send forward notification',
            category: LogCategory.general);
      }
    } catch (e) {
      AppLogger.e('Error forwarding message',
          category: LogCategory.general, error: e);
      rethrow;
    }
  }

  /// Send a call record message.
  Future<void> sendCallMessage({
    required String spaceId,
    required String callType,
    required String callStatus,
    required int callDuration,
    required bool isOutgoing,
    required String otherUserName,
  }) async {
    try {
      AppLogger.d('Sending call message to: $spaceId',
          category: LogCategory.general);

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final info = await _getUserInfo(currentUser!.uid);
      final userName = info['name']!;

      String content;
      if (callStatus == 'answered') {
        content = callType == 'video' ? 'Video call' : 'Voice call';
      } else if (callStatus == 'missed') {
        content = isOutgoing
            ? 'Call not answered'
            : 'Missed ${callType == 'video' ? 'video' : 'voice'} call';
      } else if (callStatus == 'rejected') {
        content = isOutgoing
            ? 'Call declined'
            : 'Declined ${callType == 'video' ? 'video' : 'voice'} call';
      } else {
        content = 'Call cancelled';
      }

      final messageData = {
        'spaceId': spaceId,
        'senderId': currentUser!.uid,
        'senderName': userName,
        'content': content,
        'messageType': 'call',
        'callType': callType,
        'callStatus': callStatus,
        'callDuration': callDuration,
        'isOutgoing': isOutgoing,
        'reactions': {},
        'readBy': [currentUser!.uid],
        'timestamp': FieldValue.serverTimestamp(),
      };

      await messagesCollection.add(messageData);
      AppLogger.d('Call message sent successfully',
          category: LogCategory.general);

      await updateConversationMetadata(spaceId, {
        'content': content,
        'senderId': currentUser!.uid,
        'senderName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'call',
      });
    } catch (e) {
      AppLogger.e('Error sending call message',
          category: LogCategory.general, error: e);
      // Don't rethrow - call recording failure shouldn't break the app
    }
  }

  /// Send a group-call record message.
  Future<void> sendGroupCallMessage({
    required String spaceId,
    required int callDuration,
    required int participantCount,
  }) async {
    try {
      AppLogger.d('Sending group call message to: $spaceId',
          category: LogCategory.general);

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final info = await _getUserInfo(currentUser!.uid);
      final userName = info['name']!;

      final durationStr = _formatCallDuration(callDuration);
      final content =
          'Group call • $durationStr • $participantCount participants';

      final messageData = {
        'senderId': currentUser!.uid,
        'senderName': userName,
        'content': content,
        'messageType': 'group_call',
        'callDuration': callDuration,
        'participantCount': participantCount,
        'reactions': {},
        'readBy': [currentUser!.uid],
        'timestamp': FieldValue.serverTimestamp(),
      };

      await messagesCollection.add(messageData);
      AppLogger.d('Group call message sent successfully',
          category: LogCategory.general);

      await updateConversationMetadata(spaceId, {
        'content': content,
        'senderId': currentUser!.uid,
        'senderName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'group_call',
      });
    } catch (e) {
      AppLogger.e('Error sending group call message',
          category: LogCategory.general, error: e);
    }
  }

  String _formatCallDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes < 60) {
      return secs > 0 ? '${minutes}m ${secs}s' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  /// Send a media message.
  Future<void> sendMediaMessage(
    String spaceId,
    String mediaUrl,
    String messageType, {
    String? thumbnailUrl,
    int? fileSize,
    String? replyTo,
  }) async {
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    if (isDirectMessage(spaceId)) {
      final parts = spaceId.split('_');
      if (parts.length == 3) {
        final otherUserId =
            parts[1] == currentUser!.uid ? parts[2] : parts[1];
        await createDirectMessage(otherUserId);
      }
    }

    final info = await _getUserInfo(currentUser!.uid);
    final userName = info['name']!;
    final userAvatar = info['avatar'];

    final messageData = {
      'spaceId': spaceId,
      'senderId': currentUser!.uid,
      'senderName': userName,
      'senderAvatar': userAvatar,
      'content': '',
      'messageType': messageType,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'fileSize': fileSize,
      'replyTo': replyTo,
      'reactions': {},
      'readBy': [currentUser!.uid],
      'timestamp': FieldValue.serverTimestamp(),
    };

    await messagesCollection.add(messageData);

    await notificationService.sendChatNotification(
      spaceId: spaceId,
      senderId: currentUser!.uid,
      senderName: userName,
      messageContent: '',
      messageType: messageType,
    );
  }

  // ---------------------------------------------------------------------------
  // Message mutations
  // ---------------------------------------------------------------------------

  /// Mark a single message as read by the current user.
  Future<void> markMessageAsRead(String messageId) async {
    final user = currentUser;
    if (user == null) return;

    await messagesCollection.doc(messageId).update({
      'readBy': FieldValue.arrayUnion([user.uid]),
    });
  }

  /// Mark all unread messages in a space as read.
  Future<void> markAllMessagesAsRead(String spaceId) async {
    final user = currentUser;
    if (user == null) return;
    final userId = user.uid;

    final messagesSnapshot =
        await messagesCollection.where('spaceId', isEqualTo: spaceId).get();

    final batch = firestore.batch();
    for (var doc in messagesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final deletedAt = data['deletedAt'];
      final senderId = data['senderId'];
      final readBy = List<String>.from(data['readBy'] ?? []);

      if (deletedAt == null &&
          senderId != userId &&
          !readBy.contains(userId)) {
        readBy.add(userId);
        batch.update(doc.reference, {'readBy': readBy});
      }
    }
    await batch.commit();
  }

  /// Add a reaction to a message.
  Future<void> addReaction(String messageId, String reactionType) async {
    final user = currentUser;
    if (user == null) return;

    await messagesCollection.doc(messageId).update({
      'reactions.${user.uid}': reactionType,
    });
  }

  /// Remove the current user's reaction from a message.
  Future<void> removeReaction(String messageId) async {
    final user = currentUser;
    if (user == null) return;

    await messagesCollection.doc(messageId).update({
      'reactions.${user.uid}': FieldValue.delete(),
    });
  }

  /// Soft-delete a message (admin, creator, or sender only).
  Future<void> deleteMessage(String messageId) async {
    final user = currentUser;
    if (user == null) return;

    final messageDoc = await messagesCollection.doc(messageId).get();
    final messageData = messageDoc.data() as Map<String, dynamic>?;
    if (messageData == null) return;

    final spaceId = messageData['spaceId'];
    final senderId = messageData['senderId'];

    final canDelete =
        senderId == user.uid || await isAdminOrCreator(spaceId, user.uid);

    if (!canDelete) {
      throw Exception('You do not have permission to delete this message');
    }

    await messagesCollection.doc(messageId).update({
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Edit the content of a text message (sender only).
  Future<void> editMessage(String messageId, String newContent) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to edit messages');
    }

    final trimmedContent = newContent.trim();
    if (trimmedContent.isEmpty) {
      throw Exception('Message content cannot be empty');
    }

    final messageDoc = await messagesCollection.doc(messageId).get();
    final messageData = messageDoc.data() as Map<String, dynamic>?;

    if (messageData == null) {
      throw Exception('Message not found');
    }

    final senderId = messageData['senderId'];
    final messageType = messageData['messageType'] ?? 'text';
    final deletedAt = messageData['deletedAt'];

    if (senderId != user.uid) {
      throw Exception('You can only edit your own messages');
    }

    if (deletedAt != null) {
      throw Exception('Cannot edit a deleted message');
    }

    if (messageType != 'text') {
      throw Exception('Only text messages can be edited');
    }

    await messagesCollection.doc(messageId).update({
      'content': trimmedContent,
      'editedAt': FieldValue.serverTimestamp(),
    });

    AppLogger.i('Message edited successfully',
        category: LogCategory.general, data: {'messageId': messageId});
  }

  /// Returns true if the current user can edit [message].
  bool canEditMessage(ChatMessage message) {
    final user = currentUser;
    if (user == null) return false;
    if (message.senderId != user.uid) return false;
    if (message.messageType != 'text') return false;
    if (message.deletedAt != null) return false;
    return true;
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Search messages within a conversation (client-side filtering).
  Future<List<ChatMessage>> searchMessages(
      String spaceId, String query) async {
    if (query.trim().isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();

    try {
      final futures = <Future<List<ChatMessage>>>[
        _searchMessagesQuery(
          messagesCollection
              .where('spaceId', isEqualTo: spaceId)
              .orderBy('timestamp', descending: true)
              .limit(500),
          spaceId,
          normalizedQuery,
        ),
      ];

      // Legacy storage fallbacks
      if (spaceId.startsWith('dm_')) {
        futures.add(
          _searchMessagesQuery(
            firestore
                .collection('dmConversations')
                .doc(spaceId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .limit(500),
            spaceId,
            normalizedQuery,
          ),
        );
      } else {
        futures.add(
          _searchMessagesQuery(
            firestore
                .collection('spaces')
                .doc(spaceId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .limit(500),
            spaceId,
            normalizedQuery,
          ),
        );
      }

      final resultsById = <String, ChatMessage>{};
      final queryResults = await Future.wait(futures, eagerError: false);

      for (final resultSet in queryResults) {
        for (final message in resultSet) {
          final existing = resultsById[message.id];
          if (existing == null ||
              message.timestamp.isAfter(existing.timestamp)) {
            resultsById[message.id] = message;
          }
        }
      }

      final mergedResults = resultsById.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return mergedResults;
    } catch (e) {
      AppLogger.e('Error searching messages',
          category: LogCategory.general, error: e);
      return [];
    }
  }

  Future<List<ChatMessage>> _searchMessagesQuery(
    Query query,
    String spaceId,
    String normalizedQuery,
  ) async {
    try {
      QuerySnapshot snapshot;
      try {
        snapshot = await query.get();
      } catch (e) {
        AppLogger.w('Search query failed, trying cache',
            category: LogCategory.general,
            data: {'spaceId': spaceId, 'error': e.toString()});
        try {
          snapshot = await query.get(const GetOptions(source: Source.cache));
        } catch (cacheError) {
          AppLogger.w('Search cache query failed',
              category: LogCategory.general,
              data: {'spaceId': spaceId, 'error': cacheError.toString()});
          return [];
        }
      }

      final results = <ChatMessage>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final message = ChatMessage.fromJson({
            'id': doc.id,
            'spaceId': data['spaceId'] ?? spaceId,
            ...data,
          });

          if (message.deletedAt != null) continue;
          if (_messageMatchesQuery(message, normalizedQuery)) {
            results.add(message);
          }
        } catch (e) {
          continue;
        }
      }

      return results;
    } catch (e) {
      AppLogger.w('Error searching messages in query',
          category: LogCategory.general,
          data: {'spaceId': spaceId, 'error': e.toString()});
      return [];
    }
  }

  bool _messageMatchesQuery(ChatMessage message, String normalizedQuery) {
    if (message.content.toLowerCase().contains(normalizedQuery)) return true;
    if (message.senderName.toLowerCase().contains(normalizedQuery)) return true;

    final sharedContent = message.sharedContent;
    if (sharedContent != null) {
      final fieldsToCheck = [
        sharedContent['title'],
        sharedContent['subtitle'],
        sharedContent['authorName'],
        sharedContent['type'],
      ];
      for (final value in fieldsToCheck) {
        if (value is String && value.toLowerCase().contains(normalizedQuery)) {
          return true;
        }
      }
    }
    return false;
  }
}
