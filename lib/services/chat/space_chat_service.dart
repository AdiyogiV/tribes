import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/models/space_roles.dart';
import 'package:aurogram/models/space_types.dart';
import 'package:aurogram/services/data/space_db_service.dart';
import 'package:aurogram/services/chat/chat_notification_service.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/services/analytics_service.dart';
import 'package:aurogram/services/follow_service.dart';

enum MessageStatus { sending, sent, delivered }

// Typing indicator user
class TypingUser {
  final String userId;
  final String userName;

  TypingUser({
    required this.userId,
    required this.userName,
  });
}

// User that can be mentioned in chat
class MentionableUser {
  final String userId;
  final String name;
  final String? avatar;

  MentionableUser({
    required this.userId,
    required this.name,
    this.avatar,
  });
}

class ChatMessage {
  final String id;
  final String spaceId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final String
      messageType; // 'text', 'image', 'video', 'audio', 'file', 'call', 'namaste', 'shared_content'
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? fileSize;
  final String? replyTo;
  final Map<String, String> reactions; // userId -> reactionType
  final List<String> readBy;
  final DateTime timestamp;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final MessageStatus status;

  // Call-specific fields (for messageType == 'call')
  final String? callType; // 'voice' or 'video'
  final String? callStatus; // 'answered', 'missed', 'rejected', 'cancelled'
  final int? callDuration; // Duration in seconds (for answered calls)
  final bool? isOutgoing; // true if this user initiated the call

  // Shared content fields (for messageType == 'shared_content')
  final Map<String, dynamic>?
      sharedContent; // {type, id, title, subtitle, imageUrl, authorName}
  final bool isForwarded; // true if message was forwarded
  final String? forwardedFrom; // Original message ID if forwarded

  ChatMessage({
    required this.id,
    required this.spaceId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.messageType,
    this.mediaUrl,
    this.thumbnailUrl,
    this.fileSize,
    this.replyTo,
    required this.reactions,
    required this.readBy,
    required this.timestamp,
    this.editedAt,
    this.deletedAt,
    this.status = MessageStatus.sent,
    this.callType,
    this.callStatus,
    this.callDuration,
    this.isOutgoing,
    this.sharedContent,
    this.isForwarded = false,
    this.forwardedFrom,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    try {
      // Simple status - just sent or delivered (no read receipts)
      MessageStatus status = MessageStatus.delivered;
      final senderId = json['senderId'] ?? '';

      return ChatMessage(
        id: json['id'] ?? '',
        spaceId: json['spaceId'] ?? '',
        senderId: senderId,
        senderName: json['senderName'] ?? '',
        senderAvatar: json['senderAvatar'],
        content: json['content'] ?? '',
        messageType: json['messageType'] ?? 'text',
        mediaUrl: json['mediaUrl'],
        thumbnailUrl: json['thumbnailUrl'],
        fileSize: json['fileSize'],
        replyTo: json['replyTo'],
        reactions: Map<String, String>.from(json['reactions'] ?? {}),
        readBy: List<String>.from(json['readBy'] ?? []),
        timestamp: json['timestamp'] != null
            ? (json['timestamp'] as Timestamp).toDate()
            : DateTime.now(),
        editedAt: json['editedAt'] != null
            ? (json['editedAt'] as Timestamp).toDate()
            : null,
        deletedAt: json['deletedAt'] != null
            ? (json['deletedAt'] as Timestamp).toDate()
            : null,
        status: status,
        // Call-specific fields
        callType: json['callType'],
        callStatus: json['callStatus'],
        callDuration: json['callDuration'],
        isOutgoing: json['isOutgoing'],
        // Shared content fields
        sharedContent: json['sharedContent'] != null
            ? Map<String, dynamic>.from(json['sharedContent'])
            : null,
        isForwarded: json['isForwarded'] ?? false,
        forwardedFrom: json['forwardedFrom'],
      );
    } catch (e) {
      AppLogger.e('Error parsing ChatMessage from JSON',
          category: LogCategory.general, error: e);
      // Return a default message to prevent crashes
      return ChatMessage(
        id: json['id'] ?? 'error',
        spaceId: json['spaceId'] ?? '',
        senderId: json['senderId'] ?? '',
        senderName: json['senderName'] ?? 'Unknown',
        content: json['content'] ?? 'Error loading message',
        messageType: 'text',
        reactions: {},
        readBy: [],
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );
    }
  }

  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'spaceId': spaceId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'messageType': messageType,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'fileSize': fileSize,
      'replyTo': replyTo,
      'reactions': reactions,
      'readBy': readBy,
      'timestamp': Timestamp.fromDate(timestamp),
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };

    // Add call-specific fields if this is a call message
    if (messageType == 'call') {
      json['callType'] = callType;
      json['callStatus'] = callStatus;
      json['callDuration'] = callDuration;
      json['isOutgoing'] = isOutgoing;
    }

    // Add shared content fields if this is a shared content message
    if (messageType == 'shared_content' && sharedContent != null) {
      json['sharedContent'] = sharedContent;
    }

    // Add forwarded fields if this is a forwarded message
    if (isForwarded) {
      json['isForwarded'] = true;
      json['forwardedFrom'] = forwardedFrom;
    }

    return json;
  }
}

class SpaceChatService {
  // Singleton pattern
  static final SpaceChatService _instance = SpaceChatService._internal();
  factory SpaceChatService() => _instance;
  SpaceChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SpaceDbService _spaceDbService = SpaceDbService();
  final ChatNotificationService _notificationService =
      ChatNotificationService();

  // Collections
  CollectionReference get _messages => _firestore.collection('spaceChats');
  CollectionReference get _users => _firestore.collection('users');

  // Get current user
  User? get _currentUser => _auth.currentUser;

  // Get real-time messages for a space
  Stream<List<ChatMessage>> getMessages(String spaceId) {
    try {
      return _messages
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
              // Continue with other messages instead of returning null
            }
          }
          // Reverse to show oldest first
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

  // Get media messages for a space (for media gallery)
  Stream<List<ChatMessage>> getMediaMessages(String spaceId, {int limit = 50}) {
    try {
      return _messages
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

  /// Search messages within a conversation
  /// Uses local filtering since Firestore doesn't support full-text search
  /// For large conversations, this fetches up to 500 messages and filters client-side
  Future<List<ChatMessage>> searchMessages(String spaceId, String query) async {
    if (query.trim().isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();

    try {
      final futures = <Future<List<ChatMessage>>>[
        _searchMessagesQuery(
          _messages
              .where('spaceId', isEqualTo: spaceId)
              .orderBy('timestamp', descending: true)
              .limit(500),
          spaceId,
          normalizedQuery,
        ),
      ];

      // Legacy storage fallbacks (older DMs/spaces stored in subcollections)
      if (spaceId.startsWith('dm_')) {
        futures.add(
          _searchMessagesQuery(
            _firestore
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
            _firestore
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
          // Skip malformed messages
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
    final content = message.content.toLowerCase();
    if (content.contains(normalizedQuery)) return true;

    final senderName = message.senderName.toLowerCase();
    if (senderName.contains(normalizedQuery)) return true;

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

  // Send a text message
  Future<void> sendTextMessage(String spaceId, String content,
      {String? replyTo, List<String>? mentionedUserIds}) async {
    try {
      AppLogger.d('Sending text message to space: $spaceId',
          category: LogCategory.general);

      if (_currentUser == null) {
        throw Exception('User not authenticated');
      }

      AppLogger.d('User authenticated: ${_currentUser!.uid}',
          category: LogCategory.general);

      // Check if user can send messages in this space
      if (!isDirectMessage(spaceId)) {
        final canSend = await _canSendMessage(spaceId);
        AppLogger.d('Permission check result: $canSend',
            category: LogCategory.general);

        if (!canSend) {
          throw Exception(
              'You do not have permission to send messages in this space');
        }
      } else {
        // For DMs, check if conversation is accepted
        AppLogger.d('DM detected, checking conversation status',
            category: LogCategory.general);
        final conversationDoc = await _firestore
            .collection('dmConversations')
            .doc(spaceId)
            .get();
        
        if (conversationDoc.exists) {
          final status = conversationDoc.data()?['status'] as String?;
          if (status == 'pending') {
            // Check if current user is the requester (they can send first message)
            final requestedBy = conversationDoc.data()?['requestedBy'] as String?;
            if (requestedBy != _currentUser!.uid) {
              throw Exception(
                  'This conversation is pending. Please accept the message request first.');
            }
          }
        }
      }

      // Get user info - check if user is deleted
      final userDoc = await _users.doc(_currentUser!.uid).get();
      final deletedDoc = await _firestore
          .collection('deletedUsers')
          .doc(_currentUser!.uid)
          .get();

      if (deletedDoc.exists) {
        throw Exception('Cannot send message: Your account has been deleted');
      }

      final userData = userDoc.data() as Map<String, dynamic>?;
      final userName = userData != null
          ? (userData['name'] as String? ??
              userData['nickname'] as String? ??
              'Unknown User')
          : 'Unknown User';
      final userAvatar = userData != null
          ? (userData['displayPicture'] as String? ?? '')
          : null;

      AppLogger.d('Got user info: $userName', category: LogCategory.general);

      // Create message
      final messageData = {
        'spaceId': spaceId,
        'senderId': _currentUser!.uid,
        'senderName': userName,
        'senderAvatar': userAvatar,
        'content': content,
        'messageType': 'text',
        'replyTo': replyTo,
        'reactions': {},
        'readBy': [_currentUser!.uid],
        'timestamp': FieldValue.serverTimestamp(),
        if (mentionedUserIds != null && mentionedUserIds.isNotEmpty)
          'mentionedUserIds': mentionedUserIds,
      };

      AppLogger.d('Message data prepared, sending...',
          category: LogCategory.general);

      await _messages.add(messageData);
      AppLogger.d('Message sent successfully', category: LogCategory.general);

      AnalyticsService().trackMessageSent(
        conversationType: isDirectMessage(spaceId) ? 'dm' : 'space',
      );

      // Update conversation metadata with last message info
      AppLogger.d('📝 Updating conversation metadata for: $spaceId',
          category: LogCategory.general);
      await _updateConversationMetadata(spaceId, {
        'content': content,
        'senderId': _currentUser!.uid,
        'senderName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      });
      AppLogger.d('✅ Conversation metadata updated for: $spaceId',
          category: LogCategory.general);

      // Send notification to space members or DM recipient
      try {
        await _notificationService.sendChatNotification(
          spaceId: spaceId,
          senderId: _currentUser!.uid,
          senderName: userName,
          messageContent: content,
          messageType: 'text',
        );
      } catch (e) {
        AppLogger.e('Failed to send message notification',
            category: LogCategory.general);
        // Don't throw - message was sent successfully
      }
    } catch (e) {
      AppLogger.e('Error sending text message',
          category: LogCategory.general, error: e);
      rethrow;
    }
  }

  /// Send a namaste greeting message in a DM conversation
  /// This creates a special 'namaste' type message that displays as a greeting
  Future<void> sendNamasteMessage(String spaceId) async {
    try {
      AppLogger.d('Sending namaste message to: $spaceId',
          category: LogCategory.general);

      if (_currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user info
      final userDoc = await _users.doc(_currentUser!.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userName = userData != null
          ? (userData['name'] as String? ??
              userData['nickname'] as String? ??
              'Unknown User')
          : 'Unknown User';
      final userAvatar = userData != null
          ? (userData['displayPicture'] as String? ?? '')
          : null;

      // Create namaste message
      final messageData = {
        'spaceId': spaceId,
        'senderId': _currentUser!.uid,
        'senderName': userName,
        'senderAvatar': userAvatar,
        'content': '🙏',
        'messageType': 'namaste',
        'reactions': {},
        'readBy': [_currentUser!.uid],
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _messages.add(messageData);
      AppLogger.d('Namaste message sent successfully',
          category: LogCategory.general);

      // Note: Don't update conversation metadata for namaste
      // It's a gesture that appears in chat but not in chat preview cards
      // We have separate tracking for namastes on profile

      // Send notification to DM recipient
      try {
        await _notificationService.sendChatNotification(
          spaceId: spaceId,
          senderId: _currentUser!.uid,
          senderName: userName,
          messageContent: '🙏 Namaste',
          messageType: 'namaste',
        );
      } catch (e) {
        AppLogger.e('Failed to send namaste notification',
            category: LogCategory.general);
        // Don't throw - message was sent successfully
      }
    } catch (e) {
      AppLogger.e('Error sending namaste message',
          category: LogCategory.general, error: e);
      rethrow;
    }
  }

  /// Send shared content (post, profile, space, insight) to a conversation
  Future<void> sendSharedContent({
    required String spaceId,
    required Map<String, dynamic> sharedContent,
    String? message,
  }) async {
    try {
      AppLogger.d('Sending shared content to: $spaceId',
          category: LogCategory.general);

      if (_currentUser == null) {
        throw Exception('User not authenticated');
      }

      // For DMs, check/create conversation first
      if (spaceId.startsWith('dm_')) {
        final parts = spaceId.split('_');
        if (parts.length == 3) {
          final otherUserId =
              parts[1] == _currentUser!.uid ? parts[2] : parts[1];
          await createDirectMessage(otherUserId);
        }
      } else {
        // Check permission for space messages
        final canSend = await _canSendMessage(spaceId);
        if (!canSend) {
          throw Exception(
              'You do not have permission to send messages in this space');
        }
      }

      // Get user info
      final userDoc = await _users.doc(_currentUser!.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userName = userData != null
          ? (userData['name'] as String? ??
              userData['nickname'] as String? ??
              'Unknown User')
          : 'Unknown User';
      final userAvatar = userData != null
          ? (userData['displayPicture'] as String? ?? '')
          : null;

      // Create shared content message
      final contentType = sharedContent['type'] as String? ?? 'content';
      final contentTitle =
          sharedContent['title'] as String? ?? 'Shared $contentType';

      final messageData = {
        'spaceId': spaceId,
        'senderId': _currentUser!.uid,
        'senderName': userName,
        'senderAvatar': userAvatar,
        'content': message ?? 'Shared a $contentType',
        'messageType': 'shared_content',
        'sharedContent': sharedContent,
        'reactions': {},
        'readBy': [_currentUser!.uid],
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _messages.add(messageData);
      AppLogger.d('Shared content message sent successfully',
          category: LogCategory.general);

      // Update conversation metadata
      await _updateConversationMetadata(spaceId, {
        'content':
            message?.isNotEmpty == true ? message : 'Shared a $contentType',
        'senderId': _currentUser!.uid,
        'senderName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'shared_content',
      });

      // Send notification
      try {
        await _notificationService.sendChatNotification(
          spaceId: spaceId,
          senderId: _currentUser!.uid,
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

  /// Forward a message to another conversation
  Future<void> forwardMessage({
    required String targetSpaceId,
    required ChatMessage originalMessage,
    String? additionalMessage,
  }) async {
    try {
      AppLogger.d('Forwarding message to: $targetSpaceId',
          category: LogCategory.general);

      if (_currentUser == null) {
        throw Exception('User not authenticated');
      }

      // For DMs, check/create conversation first
      if (targetSpaceId.startsWith('dm_')) {
        final parts = targetSpaceId.split('_');
        if (parts.length == 3) {
          final otherUserId =
              parts[1] == _currentUser!.uid ? parts[2] : parts[1];
          await createDirectMessage(otherUserId);
        }
      } else {
        // Check permission for space messages
        final canSend = await _canSendMessage(targetSpaceId);
        if (!canSend) {
          throw Exception(
              'You do not have permission to send messages in this space');
        }
      }

      // Get user info
      final userDoc = await _users.doc(_currentUser!.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userName = userData != null
          ? (userData['name'] as String? ??
              userData['nickname'] as String? ??
              'Unknown User')
          : 'Unknown User';
      final userAvatar = userData != null
          ? (userData['displayPicture'] as String? ?? '')
          : null;

      // Create forwarded message
      final messageData = {
        'spaceId': targetSpaceId,
        'senderId': _currentUser!.uid,
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
        'readBy': [_currentUser!.uid],
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Preserve shared content if forwarding a shared content message
      if (originalMessage.messageType == 'shared_content' &&
          originalMessage.sharedContent != null) {
        messageData['sharedContent'] = originalMessage.sharedContent;
      }

      await _messages.add(messageData);
      AppLogger.d('Message forwarded successfully',
          category: LogCategory.general);

      // Update conversation metadata
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

      await _updateConversationMetadata(targetSpaceId, {
        'content': previewContent,
        'senderId': _currentUser!.uid,
        'senderName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'type': originalMessage.messageType,
      });

      // Send notification
      try {
        await _notificationService.sendChatNotification(
          spaceId: targetSpaceId,
          senderId: _currentUser!.uid,
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

  /// Send a call message to record call history in the chat
  /// Called by CallService when a call ends
  Future<void> sendCallMessage({
    required String spaceId,
    required String callType, // 'voice' or 'video'
    required String callStatus, // 'answered', 'missed', 'rejected', 'cancelled'
    required int callDuration, // Duration in seconds
    required bool isOutgoing, // true if current user initiated the call
    required String otherUserName, // Name of the other participant
  }) async {
    try {
      AppLogger.d('Sending call message to: $spaceId',
          category: LogCategory.general);

      if (_currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user info
      final userDoc = await _users.doc(_currentUser!.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userName = userData != null
          ? (userData['name'] as String? ??
              userData['nickname'] as String? ??
              'Unknown User')
          : 'Unknown User';

      // Generate call content description
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

      // Create call message
      final messageData = {
        'spaceId': spaceId,
        'senderId': _currentUser!.uid,
        'senderName': userName,
        'content': content,
        'messageType': 'call',
        'callType': callType,
        'callStatus': callStatus,
        'callDuration': callDuration,
        'isOutgoing': isOutgoing,
        'reactions': {},
        'readBy': [_currentUser!.uid],
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _messages.add(messageData);
      AppLogger.d('Call message sent successfully',
          category: LogCategory.general);

      // Update conversation metadata with call info
      await _updateConversationMetadata(spaceId, {
        'content': content,
        'senderId': _currentUser!.uid,
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

  /// Send a group call message to record group call history in the gram chat
  /// Called by GroupCallService when a group call ends
  Future<void> sendGroupCallMessage({
    required String spaceId,
    required int callDuration, // Duration in seconds
    required int participantCount, // Number of participants
  }) async {
    try {
      AppLogger.d('Sending group call message to: $spaceId',
          category: LogCategory.general);

      if (_currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user info
      final userDoc = await _users.doc(_currentUser!.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userName = userData != null
          ? (userData['name'] as String? ??
              userData['nickname'] as String? ??
              'Unknown User')
          : 'Unknown User';

      // Generate call content description
      final durationStr = _formatCallDuration(callDuration);
      final content =
          'Group call • $durationStr • $participantCount participants';

      // Create call message
      final messageData = {
        'senderId': _currentUser!.uid,
        'senderName': userName,
        'content': content,
        'messageType': 'group_call',
        'callDuration': callDuration,
        'participantCount': participantCount,
        'reactions': {},
        'readBy': [_currentUser!.uid],
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _messages.add(messageData);
      AppLogger.d('Group call message sent successfully',
          category: LogCategory.general);

      // Update conversation metadata
      await _updateConversationMetadata(spaceId, {
        'content': content,
        'senderId': _currentUser!.uid,
        'senderName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'group_call',
      });
    } catch (e) {
      AppLogger.e('Error sending group call message',
          category: LogCategory.general, error: e);
      // Don't rethrow - call recording failure shouldn't break the app
    }
  }

  /// Format call duration for display
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

  // Send media message
  Future<void> sendMediaMessage(
      String spaceId, String mediaUrl, String messageType,
      {String? thumbnailUrl, int? fileSize, String? replyTo}) async {
    if (_currentUser == null) {
      throw Exception('User not authenticated');
    }

    // For DMs, ensure conversation exists
    if (isDirectMessage(spaceId)) {
      final parts = spaceId.split('_');
      if (parts.length == 3) {
        final otherUserId = parts[1] == _currentUser!.uid ? parts[2] : parts[1];
        await createDirectMessage(otherUserId);
      }
    }
    // Note: For spaces, we skip permission check here since the UI layer
    // already controls access to the chat. Users can only see chats they're part of.

    // Get user info
    final userDoc = await _users.doc(_currentUser!.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final userName = userData != null
        ? (userData['name'] as String? ??
            userData['nickname'] as String? ??
            'Unknown User')
        : 'Unknown User';
    final userAvatar =
        userData != null ? (userData['displayPicture'] as String? ?? '') : null;

    // Create message
    final messageData = {
      'spaceId': spaceId,
      'senderId': _currentUser!.uid,
      'senderName': userName,
      'senderAvatar': userAvatar,
      'content': '',
      'messageType': messageType,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'fileSize': fileSize,
      'replyTo': replyTo,
      'reactions': {},
      'readBy': [_currentUser!.uid],
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _messages.add(messageData);

    // Send notification to space members
    await _notificationService.sendChatNotification(
      spaceId: spaceId,
      senderId: _currentUser!.uid,
      senderName: userName,
      messageContent: '',
      messageType: messageType,
    );
  }

  // Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    // Capture user reference at start to prevent race conditions
    final user = _currentUser;
    if (user == null) return;

    await _messages.doc(messageId).update({
      'readBy': FieldValue.arrayUnion([user.uid]),
    });
  }

  // Add reaction to message
  Future<void> addReaction(String messageId, String reactionType) async {
    // Capture user reference at start to prevent race conditions
    final user = _currentUser;
    if (user == null) return;

    await _messages.doc(messageId).update({
      'reactions.${user.uid}': reactionType,
    });
  }

  // Remove reaction from message
  Future<void> removeReaction(String messageId) async {
    // Capture user reference at start to prevent race conditions
    final user = _currentUser;
    if (user == null) return;

    await _messages.doc(messageId).update({
      'reactions.${user.uid}': FieldValue.delete(),
    });
  }

  // Delete message (admin/creator only)
  Future<void> deleteMessage(String messageId) async {
    // Capture user reference at start to prevent race conditions
    final user = _currentUser;
    if (user == null) return;

    // Check if user can delete messages
    final messageDoc = await _messages.doc(messageId).get();
    final messageData = messageDoc.data() as Map<String, dynamic>?;

    if (messageData == null) return;

    final spaceId = messageData['spaceId'];
    final senderId = messageData['senderId'];

    // User can delete their own message or if they're admin/creator
    final canDelete =
        senderId == user.uid || await _isAdminOrCreator(spaceId, user.uid);

    if (!canDelete) {
      throw Exception('You do not have permission to delete this message');
    }

    await _messages.doc(messageId).update({
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  // Edit message (sender only, text messages only)
  Future<void> editMessage(String messageId, String newContent) async {
    // Capture user reference at start to prevent race conditions
    final user = _currentUser;
    if (user == null) {
      throw Exception('You must be logged in to edit messages');
    }

    // Validate new content
    final trimmedContent = newContent.trim();
    if (trimmedContent.isEmpty) {
      throw Exception('Message content cannot be empty');
    }

    // Get the message to verify ownership and type
    final messageDoc = await _messages.doc(messageId).get();
    final messageData = messageDoc.data() as Map<String, dynamic>?;

    if (messageData == null) {
      throw Exception('Message not found');
    }

    final senderId = messageData['senderId'];
    final messageType = messageData['messageType'] ?? 'text';
    final deletedAt = messageData['deletedAt'];

    // Only the sender can edit their own message
    if (senderId != user.uid) {
      throw Exception('You can only edit your own messages');
    }

    // Cannot edit deleted messages
    if (deletedAt != null) {
      throw Exception('Cannot edit a deleted message');
    }

    // Only text messages can be edited
    if (messageType != 'text') {
      throw Exception('Only text messages can be edited');
    }

    // Update the message
    await _messages.doc(messageId).update({
      'content': trimmedContent,
      'editedAt': FieldValue.serverTimestamp(),
    });

    AppLogger.i('Message edited successfully',
        category: LogCategory.general, data: {'messageId': messageId});
  }

  // Check if current user can edit a message
  bool canEditMessage(ChatMessage message) {
    final user = _currentUser;
    if (user == null) return false;

    // Only sender can edit
    if (message.senderId != user.uid) return false;

    // Only text messages can be edited
    if (message.messageType != 'text') return false;

    // Cannot edit deleted messages
    if (message.deletedAt != null) return false;

    return true;
  }

  // ============== Typing Indicators ==============

  // Throttle typing updates to prevent excessive writes
  DateTime? _lastTypingUpdate;
  static const _typingThrottleMs = 2000; // 2 seconds

  // Update typing status for current user in a space
  Future<void> setTyping(String spaceId, bool isTyping) async {
    final user = _currentUser;
    if (user == null) return;

    // Throttle typing=true updates to reduce Firestore writes
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
          _firestore.collection('typing').doc('${spaceId}_${user.uid}');

      if (isTyping) {
        // Use same name source as messages (Firestore profile) so typing shows correct name
        String userName = 'User';
        try {
          final userDoc = await _users.doc(user.uid).get();
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
        // Clear typing status
        await typingRef.delete();
        _lastTypingUpdate = null;
      }
    } catch (e) {
      // Silently fail - typing indicators are not critical
      AppLogger.w('Failed to update typing status',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  // Listen to typing indicators for a space
  Stream<List<TypingUser>> getTypingUsers(String spaceId) {
    final user = _currentUser;
    final currentUserId = user?.uid;

    return _firestore
        .collection('typing')
        .where('spaceId', isEqualTo: spaceId)
        .snapshots()
        .map((snapshot) {
      // Calculate cutoff on each snapshot to filter stale entries correctly
      final cutoff = DateTime.now().subtract(const Duration(seconds: 10));

      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            final updatedAt = data['updatedAt'] as Timestamp?;

            // Filter out stale entries and current user
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

  /// Get mentionable users for a space or DM
  /// Returns list of users who can be mentioned (excludes current user)
  Future<List<MentionableUser>> getMentionableUsers(String spaceId) async {
    final currentUserId = _currentUser?.uid;
    if (currentUserId == null) return [];

    try {
      final users = <MentionableUser>[];

      // For DMs, get the other participant
      if (spaceId.startsWith('dm_')) {
        final parts = spaceId.split('_');
        if (parts.length == 3) {
          final otherUserId = parts[1] == currentUserId ? parts[2] : parts[1];
          final userDoc = await _users.doc(otherUserId).get();
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

      // For spaces, get all members from spaceRoles
      final rolesSnapshot = await _firestore
          .collection('spaceRoles')
          .doc(spaceId)
          .collection('roles')
          .where('role', whereIn: ['creator', 'admin', 'member'])
          .limit(50)
          .get();

      // Fetch user details for each member
      for (final roleDoc in rolesSnapshot.docs) {
        if (roleDoc.id == currentUserId) continue; // Skip self

        try {
          final userDoc = await _users.doc(roleDoc.id).get();
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            users.add(MentionableUser(
              userId: roleDoc.id,
              name: data?['name'] ?? data?['nickname'] ?? 'User',
              avatar: data?['displayPicture'],
            ));
          }
        } catch (e) {
          // Skip users that can't be fetched
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

  // ========== CONVERSATION MANAGEMENT ==========

  /// Get the user-specific settings collection for a conversation
  DocumentReference _getUserConversationSettings(String conversationId) {
    final userId = _currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');
    return _firestore
        .collection('userConversationSettings')
        .doc('${userId}_$conversationId');
  }

  /// Get conversation settings for the current user
  Future<Map<String, dynamic>> getConversationSettings(
      String conversationId) async {
    try {
      final doc = await _getUserConversationSettings(conversationId).get();
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

  /// Pin or unpin a conversation
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

  /// Mute or unmute a conversation
  /// If duration is provided, mute will expire after that duration
  Future<void> muteConversation(String conversationId, bool muted,
      {Duration? duration}) async {
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

  /// Archive or unarchive a conversation
  Future<void> archiveConversation(String conversationId, bool archived) async {
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

  /// Check if notifications should be sent for a conversation
  /// Returns false if muted (and mute hasn't expired)
  Future<bool> shouldSendNotification(String conversationId) async {
    try {
      final settings = await getConversationSettings(conversationId);
      final isMuted = settings['isMuted'] as bool? ?? false;

      if (!isMuted) return true;

      // Check if mute has expired
      final mutedUntil = settings['mutedUntil'] as Timestamp?;
      if (mutedUntil != null && mutedUntil.toDate().isBefore(DateTime.now())) {
        // Mute expired, unmute automatically
        await muteConversation(conversationId, false);
        return true;
      }

      return false;
    } catch (e) {
      // Default to sending notifications on error
      return true;
    }
  }

  // Check if user can send messages in space
  Future<bool> _canSendMessage(String spaceId) async {
    // Capture user reference at start to prevent race conditions
    final user = _currentUser;
    if (user == null) return false;

    try {
      final role = await _spaceDbService.getSpaceRole(spaceId, user.uid);
      final space = await _spaceDbService.getSpace(spaceId);

      // Public spaces (open, public): anyone can send if they're a member
      if (space.spaceType.index <= 1) {
        // Public: open (0), public (1)
        return role == SpaceRoles.member ||
            role == SpaceRoles.admin ||
            role == SpaceRoles.creator;
      }

      // Private/Personal spaces: only members can send
      return role == SpaceRoles.member ||
          role == SpaceRoles.admin ||
          role == SpaceRoles.creator;
    } catch (e) {
      AppLogger.e('Error checking message permissions',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  // Check if user is admin or creator
  Future<bool> _isAdminOrCreator(String spaceId, [String? userId]) async {
    // Use provided userId or capture current user
    final uid = userId ?? _currentUser?.uid;
    if (uid == null) return false;

    try {
      final role = await _spaceDbService.getSpaceRole(spaceId, uid);
      return role == SpaceRoles.admin || role == SpaceRoles.creator;
    } catch (e) {
      return false;
    }
  }

  // Get unread message count for a space
  Stream<int> getUnreadCount(String spaceId) {
    // Capture user reference at start to prevent race conditions
    final user = _currentUser;
    if (user == null) return Stream.value(0);
    final userId = user.uid;

    return _messages
        .where('spaceId', isEqualTo: spaceId)
        .snapshots()
        .map((snapshot) {
      int unreadCount = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final deletedAt = data['deletedAt'];
        final senderId = data['senderId'];
        final readBy = List<String>.from(data['readBy'] ?? []);

        // Only count messages that are not deleted, not from current user, and not read
        if (deletedAt == null &&
            senderId != userId &&
            !readBy.contains(userId)) {
          unreadCount++;
        }
      }
      return unreadCount;
    });
  }

  // Mark all messages in a space as read
  Future<void> markAllMessagesAsRead(String spaceId) async {
    // Capture user reference at start to prevent race conditions
    final user = _currentUser;
    if (user == null) return;
    final userId = user.uid;

    final messagesSnapshot =
        await _messages.where('spaceId', isEqualTo: spaceId).get();

    final batch = _firestore.batch();
    for (var doc in messagesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final deletedAt = data['deletedAt'];
      final senderId = data['senderId'];
      final readBy = List<String>.from(data['readBy'] ?? []);

      // Only mark messages as read if they're not deleted, not from current user, and not already read
      if (deletedAt == null && senderId != userId && !readBy.contains(userId)) {
        readBy.add(userId);
        batch.update(doc.reference, {'readBy': readBy});
      }
    }
    await batch.commit();
  }

  // ========== DIRECT MESSAGE FUNCTIONALITY ==========

  /// Creates a direct message conversation between current user and another user
  Future<String> createDirectMessage(String otherUserId) async {
    if (_currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if users are mutual followers
      final isMutual = await _followService.isMutualFollow(otherUserId);
      
      // Create a deterministic conversation ID
      final participants = [_currentUser!.uid, otherUserId]..sort();
      final conversationId = 'dm_${participants.join('_')}';

      AppLogger.i('Creating/checking DM conversation: $conversationId',
          category: LogCategory.general,
          data: {'isMutual': isMutual});

      // Check if conversation already exists
      final existingConversation = await _firestore
          .collection('dmConversations')
          .doc(conversationId)
          .get();

      if (!existingConversation.exists) {
        // Create new DM conversation with request status
        // If not mutual followers, mark as pending request
        final status = isMutual ? 'accepted' : 'pending';
        
        await _firestore.collection('dmConversations').doc(conversationId).set({
          'participants': participants,
          'status': status, // 'pending' or 'accepted'
          'requestedBy': _currentUser!.uid, // Who initiated the conversation
          'createdAt': FieldValue.serverTimestamp(),
          'lastActivity': FieldValue.serverTimestamp(),
        });

        AppLogger.i('Created new DM conversation: $conversationId (status: $status)',
            category: LogCategory.general);

        if (isMutual) {
          AnalyticsService().trackDmStarted();
        }
      } else {
        // If conversation exists but is pending and we're mutual now, accept it
        final existingData = existingConversation.data();
        final existingStatus = existingData?['status'] as String?;
        
        if (existingStatus == 'pending' && isMutual) {
          await _firestore.collection('dmConversations').doc(conversationId).update({
            'status': 'accepted',
            'lastActivity': FieldValue.serverTimestamp(),
          });
          AppLogger.i('Auto-accepted pending conversation: $conversationId',
              category: LogCategory.general);
        } else {
          AppLogger.i('Reusing existing DM conversation: $conversationId',
              category: LogCategory.general);
        }
      }

      return conversationId;
    } catch (e) {
      AppLogger.e('Error creating direct message',
          category: LogCategory.general, error: e);
      throw Exception('Failed to create direct message: $e');
    }
  }

  /// Get FollowService instance
  FollowService get _followService => FollowService();

  // Cache the stream to prevent multiple subscriptions
  Stream<List<DmConversation>>? _cachedConversationsStream;
  String? _lastUserId;

  /// Clear the cached conversations stream (useful for logout/login)
  void clearConversationsCache() {
    _cachedConversationsStream = null;
    _lastUserId = null;
    AppLogger.d('Conversations stream cache cleared',
        category: LogCategory.general);
  }

  /// Accept a pending message request
  Future<bool> acceptMessageRequest(String conversationId) async {
    if (_currentUser == null) return false;

    try {
      final conversationDoc = await _firestore
          .collection('dmConversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) return false;

      final data = conversationDoc.data();
      final status = data?['status'] as String?;
      final requestedBy = data?['requestedBy'] as String?;

      // Only recipient can accept
      if (status == 'pending' && requestedBy != _currentUser!.uid) {
        await _firestore.collection('dmConversations').doc(conversationId).update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
          'lastActivity': FieldValue.serverTimestamp(),
        });

        AppLogger.i('Message request accepted: $conversationId',
            category: LogCategory.general);
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.e('Error accepting message request',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Decline a pending message request
  Future<bool> declineMessageRequest(String conversationId) async {
    if (_currentUser == null) return false;

    try {
      final conversationDoc = await _firestore
          .collection('dmConversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) return false;

      final data = conversationDoc.data();
      final status = data?['status'] as String?;
      final requestedBy = data?['requestedBy'] as String?;

      // Only recipient can decline
      if (status == 'pending' && requestedBy != _currentUser!.uid) {
        await _firestore.collection('dmConversations').doc(conversationId).update({
          'status': 'declined',
          'declinedAt': FieldValue.serverTimestamp(),
        });

        AppLogger.i('Message request declined: $conversationId',
            category: LogCategory.general);
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.e('Error declining message request',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Report a chat message for inappropriate content
  /// Required for App Store compliance (Guideline 1.2)
  Future<bool> reportChatMessage(String messageId, String reason) async {
    try {
      if (_currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('reports').add({
        'messageId': messageId,
        'messageType': 'chat',
        'reportedBy': _currentUser!.uid,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      AppLogger.i('Chat message reported',
          category: LogCategory.general,
          data: {'messageId': messageId});
      return true;
    } catch (e) {
      AppLogger.e('Error reporting chat message',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Gets all conversations for the current user (both DMs and spaces)
  Stream<List<DmConversation>> getUserDmConversations() {
    if (_currentUser == null) {
      AppLogger.w('No authenticated user for DM conversations',
          category: LogCategory.general);
      return Stream.value([]);
    }

    // Return cached stream if same user and stream exists
    if (_cachedConversationsStream != null &&
        _lastUserId == _currentUser!.uid) {
      return _cachedConversationsStream!;
    }

    try {
      _lastUserId = _currentUser!.uid;
      _cachedConversationsStream = _getCombinedConversationsRealTime()
          .asBroadcastStream(); // Make it a broadcast stream for multiple listeners
      return _cachedConversationsStream!;
    } catch (e) {
      AppLogger.e('Error setting up unified conversations stream',
          category: LogCategory.general, error: e);
      return Stream.value([]);
    }
  }

  /// Real-time conversations stream with actual last message timestamps
  Stream<List<DmConversation>> _getCombinedConversationsRealTime() async* {
    try {
      // Check if user is authenticated before starting stream
      if (_currentUser == null) {
        AppLogger.w('No authenticated user, returning empty conversations',
            category: LogCategory.general);
        yield <DmConversation>[];
        return;
      }

      AppLogger.d(
          '🚀 Starting real-time conversations stream for user: ${_currentUser!.uid}',
          category: LogCategory.general);

      // Set up real-time stream for DM conversations
      try {
        final query = _firestore
            .collection('dmConversations')
            .where('participants', arrayContains: _currentUser!.uid);

        AppLogger.d('📡 DM Conversations query setup complete',
            category: LogCategory.general, data: {'userId': _currentUser!.uid});

        await for (final dmSnapshot in query.snapshots().handleError((error) {
          // Log specific error details for debugging
          AppLogger.e('🔥 DM Conversations query error: $error',
              category: LogCategory.general, error: error);

          // Check if it's an index error
          if (error.toString().contains('index') ||
              error.toString().contains('requires an index')) {
            AppLogger.e(
                '🔥 Missing Firestore index for dmConversations.participants',
                category: LogCategory.general,
                data: {
                  'error': error.toString(),
                  'hint': 'Run: firebase deploy --only firestore:indexes'
                });
          }

          // Re-throw to be caught by outer try-catch
          throw error;
        })) {
          AppLogger.d('📥 DM Conversations snapshot received',
              category: LogCategory.general,
              data: {'docCount': dmSnapshot.docs.length});

          try {
            // Check if user logged out during stream execution
            if (_currentUser == null) {
              AppLogger.w('User logged out during stream, breaking',
                  category: LogCategory.general);
              break;
            }

            final conversations = <DmConversation>[];

            try {
              // Process DM conversations with real-time last message
              // Process DMs with timeout per conversation to avoid blocking
              final dmFutures = dmSnapshot.docs.map((doc) async {
                try {
                  return await _processDmConversation(doc)
                      .timeout(const Duration(seconds: 5)); // Increased timeout
                } catch (e) {
                  AppLogger.e('Error processing DM conversation ${doc.id}: $e',
                      category: LogCategory.general,
                      data: {'docId': doc.id, 'error': e.toString()});
                  return null;
                }
              });

              final dmResults = await Future.wait(dmFutures);
              final successfulDms = dmResults.where((c) => c != null).length;
              AppLogger.d('📊 DM Processing complete',
                  category: LogCategory.general,
                  data: {
                    'total': dmSnapshot.docs.length,
                    'successful': successfulDms,
                    'failed': dmSnapshot.docs.length - successfulDms,
                  });

              for (final dmConversation in dmResults) {
                if (dmConversation != null) {
                  conversations.add(dmConversation);
                }
              }
            } catch (e) {
              AppLogger.e('🔥 Error processing DM conversations batch: $e',
                  category: LogCategory.general, error: e);
              // Continue - we'll yield what we have (might be empty)
            }

            // Get current user spaces snapshot with timeout
            try {
              // Check again before querying user spaces
              if (_currentUser == null) {
                AppLogger.w('User logged out before fetching spaces, breaking',
                    category: LogCategory.general);
                break;
              }

              final userSpacesSnapshot = await _firestore
                  .collection('userSpaces')
                  .doc(_currentUser!.uid)
                  .collection('spaces')
                  .where('role', whereIn: ['member', 'owner', 'creator'])
                  .get()
                  .timeout(const Duration(
                      seconds: 10)); // Increased from 5 to 10 seconds

              // Process spaces with timeout per space to avoid blocking
              final spaceFutures =
                  userSpacesSnapshot.docs.map((userSpaceDoc) async {
                try {
                  return await _processSpaceConversation(userSpaceDoc)
                      .timeout(const Duration(seconds: 3));
                } catch (e) {
                  AppLogger.e(
                      'Error processing space conversation ${userSpaceDoc.id}: $e',
                      category: LogCategory.general);
                  return null;
                }
              });

              final spaceResults = await Future.wait(spaceFutures);
              for (final spaceConversation in spaceResults) {
                if (spaceConversation != null) {
                  conversations.add(spaceConversation);
                }
              }
            } catch (e) {
              AppLogger.e('Error fetching user spaces: $e',
                  category: LogCategory.general);
              // Continue with just DM conversations
            }

            // Sort by actual last message time (most recent first)
            conversations
                .sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

            AppLogger.d('✅ Yielding conversations',
                category: LogCategory.general,
                data: {
                  'count': conversations.length,
                  'conversationIds':
                      conversations.take(5).map((c) => c.id).toList(),
                  'sampleOtherUserIds':
                      conversations.take(3).map((c) => c.otherUserId).toList(),
                  'hasConversations': conversations.isNotEmpty,
                });

            // Always yield - even if empty, this keeps the stream alive and updates UI
            yield conversations;
          } catch (e, stackTrace) {
            AppLogger.e(
                '🔥 ERROR processing snapshot in conversations stream: $e',
                category: LogCategory.general,
                error: e);
            AppLogger.e('🔥 STACK TRACE: $stackTrace',
                category: LogCategory.general);
            // Yield empty list on error - UI will show empty state
            yield <DmConversation>[];
          }
        }
      } catch (queryError) {
        // Catch query-level errors (like missing index)
        AppLogger.e('🔥 DM Conversations query failed: $queryError',
            category: LogCategory.general, error: queryError);
        yield <DmConversation>[];
        return;
      }
    } catch (e, stackTrace) {
      // Check if user logged out (permission-denied or null user)
      if (_currentUser == null ||
          e.toString().contains('permission-denied') ||
          e.toString().contains('permission denied')) {
        AppLogger.w('User logged out or permission denied, stopping stream',
            category: LogCategory.general);
        yield <DmConversation>[];
        return;
      }

      AppLogger.e('🔥 OUTER ERROR in real-time conversations stream: $e',
          category: LogCategory.general, error: e);
      AppLogger.e('🔥 OUTER STACK TRACE: $stackTrace',
          category: LogCategory.general);
      // Yield empty list on error to prevent UI hanging
      yield <DmConversation>[];
    }
  }

  /// Process a DM conversation document
  Future<DmConversation?> _processDmConversation(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        AppLogger.w('DM conversation document ${doc.id} has no data',
            category: LogCategory.general);
        return null;
      }

      final participants = List<String>.from(data['participants'] ?? []);
      if (participants.isEmpty) {
        AppLogger.w('DM conversation ${doc.id} has no participants',
            category: LogCategory.general);
        return null;
      }

      final otherUserId = participants.firstWhere(
        (id) => id != _currentUser!.uid,
        orElse: () => _currentUser!.uid,
      );

      // Get last message info from denormalized data (WhatsApp approach - FAST!)
      final lastMessageData = data['lastMessage'] as Map<String, dynamic>?;
      DateTime lastActivity;
      String? lastMessageContent;
      String? lastMessageSenderId;
      String? lastMessageSenderName;

      if (lastMessageData != null) {
        lastActivity = (lastMessageData['timestamp'] as Timestamp?)?.toDate() ??
            (data['lastActivity'] as Timestamp?)?.toDate() ??
            (data['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.now();
        lastMessageContent = lastMessageData['content'] as String?;
        lastMessageSenderId = lastMessageData['senderId'] as String?;
        lastMessageSenderName = lastMessageData['senderName'] as String?;
      } else {
        // Fallback to conversation creation time (NOT DateTime.now()!)
        lastActivity = (data['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
      }

      return DmConversation(
        id: doc.id,
        otherUserId: otherUserId,
        participants: participants,
        lastActivity: lastActivity,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        lastMessageContent: lastMessageContent,
        lastMessageSenderId: lastMessageSenderId,
        lastMessageSenderName: lastMessageSenderName,
        status: data['status'] as String?,
        requestedBy: data['requestedBy'] as String?,
      );
    } catch (e) {
      AppLogger.e('Error processing DM conversation ${doc.id}',
          category: LogCategory.general, error: e);
      return null;
    }
  }

  /// Process a space conversation document
  Future<DmConversation?> _processSpaceConversation(
      DocumentSnapshot userSpaceDoc) async {
    try {
      final spaceId = userSpaceDoc.id;

      // Get the actual space data with timeout
      final spaceDoc = await _firestore
          .collection('spaces')
          .doc(spaceId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (!spaceDoc.exists) {
        AppLogger.w('Space document $spaceId does not exist',
            category: LogCategory.general);
        return null;
      }

      final spaceData = spaceDoc.data();
      if (spaceData == null) {
        AppLogger.w('Space document $spaceId has no data',
            category: LogCategory.general);
        return null;
      }
      final members = List<String>.from(spaceData['members'] ?? []);
      final spaceName = spaceData['name'] as String? ?? 'Unnamed Space';

      // Get last message info from space metadata (WhatsApp approach)
      final lastMessageData = spaceData['lastMessage'] as Map<String, dynamic>?;
      DateTime lastMessageTime;
      String? lastMessageContent;
      String? lastMessageSenderId;
      String? lastMessageSenderName;

      if (lastMessageData != null) {
        lastMessageTime =
            (lastMessageData['timestamp'] as Timestamp?)?.toDate() ??
                (spaceData['lastActivity'] as Timestamp?)?.toDate() ??
                (spaceData['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.now();
        lastMessageContent = lastMessageData['content'] as String?;
        lastMessageSenderId = lastMessageData['senderId'] as String?;
        lastMessageSenderName = lastMessageData['senderName'] as String?;
      } else {
        // Fallback to space creation time (NOT DateTime.now()!)
        lastMessageTime = (spaceData['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
      }

      // For spaces with 2 members, treat as DM-like conversation
      String displayName;
      if (members.length == 2) {
        // 1:1 space conversation - show other user
        displayName = members.firstWhere(
          (id) => id != _currentUser!.uid,
          orElse: () => _currentUser!.uid,
        );
      } else {
        // Group space - show space name
        displayName = spaceName;
      }

      final parsedSpaceType = _parseSpaceType(spaceData['spaceType']);

      return DmConversation(
        id: spaceId,
        otherUserId: displayName,
        participants: members,
        lastActivity: lastMessageTime,
        createdAt: (spaceData['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        lastMessageContent: lastMessageContent,
        lastMessageSenderId: lastMessageSenderId,
        lastMessageSenderName: lastMessageSenderName,
        // Space-specific fields
        displayPicture: spaceData['displayPicture'] as String?,
        spaceType: parsedSpaceType,
        spaceName: spaceName,
      );
    } catch (e) {
      AppLogger.e('Error processing space conversation ${userSpaceDoc.id}',
          category: LogCategory.general, error: e);
      return null;
    }
  }

  /// Checks if a conversation ID represents a DM (starts with 'dm_')
  bool isDirectMessage(String conversationId) {
    return conversationId.startsWith('dm_');
  }

  /// Gets the other user's ID from a DM conversation ID
  String? getOtherUserId(String dmConversationId) {
    if (!isDirectMessage(dmConversationId) || _currentUser == null) {
      return null;
    }

    try {
      final parts = dmConversationId.substring(3).split('_');
      return parts.firstWhere(
        (userId) => userId != _currentUser!.uid,
        orElse: () => '',
      );
    } catch (e) {
      AppLogger.e('Error extracting other user ID from DM conversation',
          category: LogCategory.general, error: e);
      return null;
    }
  }

  /// Parse SpaceType from dynamic value
  SpaceType? _parseSpaceType(dynamic spaceTypeValue) {
    AppLogger.d(
        '🔍 Parsing spaceType: $spaceTypeValue (${spaceTypeValue.runtimeType})',
        category: LogCategory.general);

    if (spaceTypeValue == null) return null;

    if (spaceTypeValue is SpaceType) return spaceTypeValue;

    if (spaceTypeValue is String) {
      switch (spaceTypeValue.toLowerCase()) {
        case 'open':
        case 'public':
        case 'community':
          return SpaceType.public;
        case 'private':
        case 'personal':
          return SpaceType.private;
        default:
          AppLogger.w('Unknown spaceType string: $spaceTypeValue',
              category: LogCategory.general);
          return null;
      }
    }

    // Check if it's an enum index (int)
    if (spaceTypeValue is int) {
      try {
        // Use helper function for backward compat
        return spaceTypeFromIndex(spaceTypeValue);
      } catch (e) {
        AppLogger.w('Invalid spaceType index: $spaceTypeValue',
            category: LogCategory.general);
        return null;
      }
    }

    AppLogger.w(
        'Unknown spaceType format: $spaceTypeValue (${spaceTypeValue.runtimeType})',
        category: LogCategory.general);
    return null;
  }

  /// Updates conversation metadata with last message info (WhatsApp approach)
  Future<void> _updateConversationMetadata(
      String conversationId, Map<String, dynamic> lastMessageData) async {
    try {
      AppLogger.d(
          '🔄 Updating metadata for conversation: $conversationId, isDM: ${isDirectMessage(conversationId)}',
          category: LogCategory.general);
      AppLogger.d('📄 Metadata to update: $lastMessageData',
          category: LogCategory.general);

      if (isDirectMessage(conversationId)) {
        // Update DM conversation metadata
        AppLogger.d('📝 Updating DM collection for: $conversationId',
            category: LogCategory.general);
        await _firestore
            .collection('dmConversations')
            .doc(conversationId)
            .update({
          'lastMessage': lastMessageData,
          'lastActivity': FieldValue.serverTimestamp(),
        });
        AppLogger.d('✅ DM metadata updated for: $conversationId',
            category: LogCategory.general);
      } else {
        // For spaces, update the space document with last message info
        AppLogger.d('📝 Updating spaces collection for: $conversationId',
            category: LogCategory.general);
        await _firestore.collection('spaces').doc(conversationId).update({
          'lastMessage': lastMessageData,
          'lastActivity': FieldValue.serverTimestamp(),
        });
        AppLogger.d('✅ Space metadata updated for: $conversationId',
            category: LogCategory.general);
      }
    } catch (e) {
      AppLogger.e(
          '❌ Failed to update conversation metadata for $conversationId',
          category: LogCategory.general,
          error: e);
      // Non-critical error, don't throw
    }
  }
}

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
      status: this.status,
      requestedBy: this.requestedBy,
    );
  }
}
