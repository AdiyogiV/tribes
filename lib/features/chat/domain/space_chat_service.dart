import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/models/dm_conversation.dart';
export 'package:aurogram/shared/models/chat_message.dart';
export 'package:aurogram/shared/models/dm_conversation.dart';
import 'package:aurogram/shared/models/space_types.dart';
import 'package:aurogram/features/feed/data/datasources/space_db_service.dart';
import 'package:aurogram/features/chat/domain/chat_notification_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/services/analytics_service.dart';
import 'package:aurogram/features/profile/domain/follow_service.dart';

// Mixin imports
import 'package:aurogram/features/chat/domain/chat_message_operations.dart';
import 'package:aurogram/features/chat/domain/chat_stream_handlers.dart';
import 'package:aurogram/features/chat/domain/chat_presence.dart';
import 'package:aurogram/features/chat/domain/chat_conversation_settings.dart';

// Re-export mixin files so existing imports continue to work
export 'package:aurogram/features/chat/domain/chat_message_operations.dart';
export 'package:aurogram/features/chat/domain/chat_stream_handlers.dart';
export 'package:aurogram/features/chat/domain/chat_presence.dart';
export 'package:aurogram/features/chat/domain/chat_conversation_settings.dart';

class SpaceChatService
    with
        ChatMessageOperations,
        ChatStreamHandlers,
        ChatPresence,
        ChatConversationSettings {
  // Singleton pattern
  static final SpaceChatService _instance = SpaceChatService._internal();
  factory SpaceChatService() => _instance;
  SpaceChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SpaceDbService _spaceDbService = SpaceDbService();
  final ChatNotificationService _notificationService =
      ChatNotificationService();

  // =========================================================================
  // Public getters required by mixins
  // =========================================================================

  @override
  FirebaseFirestore get firestore => _firestore;

  @override
  CollectionReference get messagesCollection =>
      _firestore.collection('spaceChats');

  @override
  CollectionReference get usersCollection => _firestore.collection('users');

  @override
  User? get currentUser => _auth.currentUser;

  @override
  ChatNotificationService get notificationService => _notificationService;

  @override
  SpaceDbService get spaceDbService => _spaceDbService;

  // =========================================================================
  // Utility helpers used by mixins and the rest of the app
  // =========================================================================

  /// Checks if a conversation ID represents a DM (starts with 'dm_')
  @override
  bool isDirectMessage(String conversationId) {
    return conversationId.startsWith('dm_');
  }

  /// Gets the other user's ID from a DM conversation ID
  String? getOtherUserId(String dmConversationId) {
    if (!isDirectMessage(dmConversationId) || currentUser == null) {
      return null;
    }

    try {
      final parts = dmConversationId.substring(3).split('_');
      return parts.firstWhere(
        (userId) => userId != currentUser!.uid,
        orElse: () => '',
      );
    } catch (e) {
      AppLogger.e('Error extracting other user ID from DM conversation',
          category: LogCategory.general, error: e);
      return null;
    }
  }

  // =========================================================================
  // Direct Message creation (required by ChatMessageOperations mixin)
  // =========================================================================

  /// Get FollowService instance
  FollowService get _followService => FollowService();

  /// Creates a direct message conversation between current user and another user
  @override
  Future<String> createDirectMessage(String otherUserId) async {
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if users are mutual followers
      final isMutual = await _followService.isMutualFollow(otherUserId);

      // Create a deterministic conversation ID
      final participants = [currentUser!.uid, otherUserId]..sort();
      final conversationId = 'dm_${participants.join('_')}';

      AppLogger.i('Creating/checking DM conversation: $conversationId',
          category: LogCategory.general, data: {'isMutual': isMutual});

      // Check if conversation already exists
      final existingConversation = await _firestore
          .collection('dmConversations')
          .doc(conversationId)
          .get();

      if (!existingConversation.exists) {
        // Create new DM conversation with request status
        final status = isMutual ? 'accepted' : 'pending';

        await _firestore
            .collection('dmConversations')
            .doc(conversationId)
            .set({
          'participants': participants,
          'status': status,
          'requestedBy': currentUser!.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActivity': FieldValue.serverTimestamp(),
        });

        AppLogger.i(
            'Created new DM conversation: $conversationId (status: $status)',
            category: LogCategory.general);

        if (isMutual) {
          AnalyticsService().trackDmStarted();
        }
      } else {
        // If conversation exists but is pending and we're mutual now, accept it
        final existingData = existingConversation.data();
        final existingStatus = existingData?['status'] as String?;

        if (existingStatus == 'pending' && isMutual) {
          await _firestore
              .collection('dmConversations')
              .doc(conversationId)
              .update({
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

  // =========================================================================
  // Conversation metadata (required by ChatMessageOperations mixin)
  // =========================================================================

  /// Updates conversation metadata with last message info (WhatsApp approach)
  @override
  Future<void> updateConversationMetadata(
      String conversationId, Map<String, dynamic> lastMessageData) async {
    try {
      AppLogger.d(
          '🔄 Updating metadata for conversation: $conversationId, isDM: ${isDirectMessage(conversationId)}',
          category: LogCategory.general);
      AppLogger.d('📄 Metadata to update: $lastMessageData',
          category: LogCategory.general);

      if (isDirectMessage(conversationId)) {
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

  // =========================================================================
  // Message request management
  // =========================================================================

  /// Accept a pending message request
  Future<bool> acceptMessageRequest(String conversationId) async {
    if (currentUser == null) return false;

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
      if (status == 'pending' && requestedBy != currentUser!.uid) {
        await _firestore
            .collection('dmConversations')
            .doc(conversationId)
            .update({
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
    if (currentUser == null) return false;

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
      if (status == 'pending' && requestedBy != currentUser!.uid) {
        await _firestore
            .collection('dmConversations')
            .doc(conversationId)
            .update({
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

  // =========================================================================
  // Reporting
  // =========================================================================

  /// Report a chat message for inappropriate content
  /// Required for App Store compliance (Guideline 1.2)
  Future<bool> reportChatMessage(String messageId, String reason) async {
    try {
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('reports').add({
        'messageId': messageId,
        'messageType': 'chat',
        'reportedBy': currentUser!.uid,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      AppLogger.i('Chat message reported',
          category: LogCategory.general, data: {'messageId': messageId});
      return true;
    } catch (e) {
      AppLogger.e('Error reporting chat message',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  // =========================================================================
  // Conversations listing
  // =========================================================================

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

  /// Gets all conversations for the current user (both DMs and spaces)
  Stream<List<DmConversation>> getUserDmConversations() {
    if (currentUser == null) {
      AppLogger.w('No authenticated user for DM conversations',
          category: LogCategory.general);
      return Stream.value([]);
    }

    // Return cached stream if same user and stream exists
    if (_cachedConversationsStream != null &&
        _lastUserId == currentUser!.uid) {
      return _cachedConversationsStream!;
    }

    try {
      _lastUserId = currentUser!.uid;
      _cachedConversationsStream = _getCombinedConversationsRealTime()
          .asBroadcastStream();
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
      if (currentUser == null) {
        AppLogger.w('No authenticated user, returning empty conversations',
            category: LogCategory.general);
        yield <DmConversation>[];
        return;
      }

      AppLogger.d(
          '🚀 Starting real-time conversations stream for user: ${currentUser!.uid}',
          category: LogCategory.general);

      try {
        final query = _firestore
            .collection('dmConversations')
            .where('participants', arrayContains: currentUser!.uid);

        AppLogger.d('📡 DM Conversations query setup complete',
            category: LogCategory.general,
            data: {'userId': currentUser!.uid});

        await for (final dmSnapshot in query.snapshots().handleError((error) {
          AppLogger.e('🔥 DM Conversations query error: $error',
              category: LogCategory.general, error: error);

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

          throw error;
        })) {
          AppLogger.d('📥 DM Conversations snapshot received',
              category: LogCategory.general,
              data: {'docCount': dmSnapshot.docs.length});

          try {
            if (currentUser == null) {
              AppLogger.w('User logged out during stream, breaking',
                  category: LogCategory.general);
              break;
            }

            final conversations = <DmConversation>[];

            try {
              final dmFutures = dmSnapshot.docs.map((doc) async {
                try {
                  return await _processDmConversation(doc)
                      .timeout(const Duration(seconds: 5));
                } catch (e) {
                  AppLogger.e(
                      'Error processing DM conversation ${doc.id}: $e',
                      category: LogCategory.general,
                      data: {'docId': doc.id, 'error': e.toString()});
                  return null;
                }
              });

              final dmResults = await Future.wait(dmFutures);
              final successfulDms =
                  dmResults.where((c) => c != null).length;
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
              AppLogger.e(
                  '🔥 Error processing DM conversations batch: $e',
                  category: LogCategory.general, error: e);
            }

            // Get current user spaces snapshot with timeout
            try {
              if (currentUser == null) {
                AppLogger.w(
                    'User logged out before fetching spaces, breaking',
                    category: LogCategory.general);
                break;
              }

              final userSpacesSnapshot = await _firestore
                  .collection('userSpaces')
                  .doc(currentUser!.uid)
                  .collection('spaces')
                  .where('role', whereIn: ['member', 'owner', 'creator'])
                  .get()
                  .timeout(const Duration(seconds: 10));

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
                  'sampleOtherUserIds': conversations
                      .take(3)
                      .map((c) => c.otherUserId)
                      .toList(),
                  'hasConversations': conversations.isNotEmpty,
                });

            yield conversations;
          } catch (e, stackTrace) {
            AppLogger.e(
                '🔥 ERROR processing snapshot in conversations stream: $e',
                category: LogCategory.general,
                error: e);
            AppLogger.e('🔥 STACK TRACE: $stackTrace',
                category: LogCategory.general);
            yield <DmConversation>[];
          }
        }
      } catch (queryError) {
        AppLogger.e('🔥 DM Conversations query failed: $queryError',
            category: LogCategory.general, error: queryError);
        yield <DmConversation>[];
        return;
      }
    } catch (e, stackTrace) {
      if (currentUser == null ||
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
      yield <DmConversation>[];
    }
  }

  /// Process a DM conversation document
  Future<DmConversation?> _processDmConversation(
      DocumentSnapshot doc) async {
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
        (id) => id != currentUser!.uid,
        orElse: () => currentUser!.uid,
      );

      final lastMessageData =
          data['lastMessage'] as Map<String, dynamic>?;
      DateTime lastActivity;
      String? lastMessageContent;
      String? lastMessageSenderId;
      String? lastMessageSenderName;

      if (lastMessageData != null) {
        lastActivity =
            (lastMessageData['timestamp'] as Timestamp?)?.toDate() ??
                (data['lastActivity'] as Timestamp?)?.toDate() ??
                (data['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.now();
        lastMessageContent = lastMessageData['content'] as String?;
        lastMessageSenderId = lastMessageData['senderId'] as String?;
        lastMessageSenderName = lastMessageData['senderName'] as String?;
      } else {
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

      final lastMessageData =
          spaceData['lastMessage'] as Map<String, dynamic>?;
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
        lastMessageTime =
            (spaceData['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
      }

      String displayName;
      if (members.length == 2) {
        displayName = members.firstWhere(
          (id) => id != currentUser!.uid,
          orElse: () => currentUser!.uid,
        );
      } else {
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
        displayPicture: spaceData['displayPicture'] as String?,
        spaceType: parsedSpaceType,
        spaceName: spaceName,
      );
    } catch (e) {
      AppLogger.e(
          'Error processing space conversation ${userSpaceDoc.id}',
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

    if (spaceTypeValue is int) {
      try {
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
}
