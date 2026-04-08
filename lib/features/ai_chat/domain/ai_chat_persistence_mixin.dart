import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/models/dm_conversation.dart';
import 'package:aurogram/models/thought_process.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import 'ai_chat_models.dart';

/// Mixin for AI chat Firestore persistence (save/load/clear conversations).
///
/// Requires the host class to provide [currentSession], [notifyListeners],
/// [transition], and [updateSession].
mixin AiChatPersistenceMixin on ChangeNotifier {
  // =========================================================================
  // State that must be provided by the host class
  // =========================================================================
  ChatSessionState get currentSession;
  set currentSessionDirect(ChatSessionState value);
  void transition(ChatSessionState newState);
  void updateSession(ChatSessionState newSession);
  FirebaseFirestore get firestore;
  void cleanupCurrentSession();

  // =========================================================================
  // Persistence logic
  // =========================================================================

  /// Check if user is authenticated
  bool get isUserAuthenticated => FirebaseAuth.instance.currentUser != null;

  /// Clear conversation ID (called when starting new session)
  void clearConversationId() {
    currentSessionDirect =
        currentSession.copyWith(conversationId: null);
  }

  /// Ensure a conversation exists for the current session
  /// Returns the conversation ID, or null if user is not authenticated
  /// Uses state's conversationId to avoid creating duplicates
  Future<String?> ensureConversation() async {
    // Check if we already have a conversation ID in state
    if (currentSession.conversationId != null) {
      return currentSession.conversationId;
    }

    // Handle loaded conversations - extract ID from chatId
    if (currentSession.chatId.startsWith('loaded-')) {
      final loadedId = currentSession.chatId.substring('loaded-'.length);
      transition(currentSession.copyWith(conversationId: loadedId));
      return loadedId;
    }

    // Skip for unauthenticated users
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      AppLogger.i('User not authenticated - chat won\'t be saved');
      return null;
    }

    try {
      // Create a new conversation
      final sessionTimestamp = DateTime.now().millisecondsSinceEpoch;
      final conversationId = 'ai_chat_${currentUser.uid}_$sessionTimestamp';

      await firestore.collection('dmConversations').doc(conversationId).set({
        'participants': [currentUser.uid, HOLYCOW_USER_ID],
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'isAiConversation': true,
      });

      // Store in state for reuse
      transition(currentSession.copyWith(conversationId: conversationId));

      AppLogger.i('Created new AI conversation: $conversationId');
      return conversationId;
    } catch (e) {
      AppLogger.e('Error creating conversation: $e');
      return null;
    }
  }

  /// Save current AI conversation as DM messages
  /// Only saves NEW messages (those without Firestore IDs)
  Future<void> saveConversationAsDM() async {
    if (currentSession.messages.length < 2) {
      return; // Need at least user + AI message
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return; // Skip for unauthenticated users
    }

    try {
      // Ensure we have a conversation ID
      final conversationId = await ensureConversation();
      if (conversationId == null) {
        return;
      }

      // Only save messages without Firestore IDs (new messages)
      // Messages with IDs like 'ai_chat_*' or 'dm_*' are already saved
      final messagesToSave = currentSession.messages
          .where((m) =>
              !m.id.startsWith('ai_chat_') &&
              !m.id.startsWith('dm_') &&
              m.content.isNotEmpty)
          .toList();

      if (messagesToSave.isEmpty) {
        return; // Nothing new to save
      }

      AppLogger.i(
          'Saving ${messagesToSave.length} messages to $conversationId');

      final batch = firestore.batch();

      for (final message in messagesToSave) {
        final messageRef = firestore
            .collection('dmConversations')
            .doc(conversationId)
            .collection('messages')
            .doc();

        final messageData = {
          'content': message.content,
          'senderId':
              message.role == 'user' ? currentUser.uid : HOLYCOW_USER_ID,
          'senderName': message.role == 'user' ? 'You' : 'holycow.ai',
          'timestamp': Timestamp.fromDate(message.createdAt),
          'type': 'text',
          // Save thought process and search results for AI messages
          if (message.thoughtProcess != null)
            'thoughtProcess': message.thoughtProcess!.toJson(),
          if (message.searchResults != null)
            'searchResults':
                message.searchResults!.map((r) => r.toJson()).toList(),
          // Save voice message fields
          'isVoiceMessage': message.isVoiceMessage,
          if (message.audioUrl != null) 'audioUrl': message.audioUrl,
          if (message.audioDuration != null)
            'audioDuration': message.audioDuration,
        };

        batch.set(messageRef, messageData);
      }

      // Update conversation last message only if we have messages to save
      if (messagesToSave.isNotEmpty) {
        final lastMessage = currentSession.messages.last;
        final conversationRef =
            firestore.collection('dmConversations').doc(conversationId);

        // Find the first user message for conversation title
        final firstUserMessage = currentSession.messages
            .where((m) => m.role == 'user')
            .firstOrNull
            ?.content;

        final updateData = <String, dynamic>{
          'lastActivity': FieldValue.serverTimestamp(),
          'lastMessage': {
            'content': lastMessage.content,
            'senderId':
                lastMessage.role == 'user' ? currentUser.uid : HOLYCOW_USER_ID,
            'senderName': lastMessage.role == 'user' ? 'You' : 'HolyCow',
            'timestamp': Timestamp.fromDate(lastMessage.createdAt),
          }
        };

        // Only set firstUserMessage if we found one (don't overwrite existing)
        if (firstUserMessage != null) {
          updateData['firstUserMessage'] = firstUserMessage;
        }

        batch.update(conversationRef, updateData);
      }

      await batch.commit();
      AppLogger.i('AI conversation saved as DM conversation: $conversationId');
    } catch (e) {
      AppLogger.e('Error saving AI conversation as DM: $e');
    }
  }

  /// Get recent AI conversations (DM conversations with HolyCow)
  Stream<List<DmConversation>> getRecentAiConversations({int limit = 10}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Return empty stream for unauthenticated users
      return Stream.value([]);
    }

    return firestore
        .collection('dmConversations')
        .where('participants', arrayContains: currentUser.uid)
        .snapshots()
        .map((snapshot) {
      // Filter client-side for AI conversations
      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final isAiConversation = data['isAiConversation'] == true;
        final containsHolyCow = participants.contains(HOLYCOW_USER_ID);

        // Check for both new AI conversations and legacy ones
        final isValidAiChat = isAiConversation ||
            (containsHolyCow && doc.id.startsWith('ai_chat_')) ||
            (containsHolyCow &&
                doc.id.startsWith('dm_') &&
                doc.id.contains('holycow_system_user'));

        return isValidAiChat;
      });

      final aiConversations = filteredDocs.map((doc) {
        final data = doc.data();
        return DmConversation(
          id: doc.id,
          otherUserId: HOLYCOW_USER_ID,
          participants: List<String>.from(data['participants'] ?? []),
          lastActivity: (data['lastActivity'] as Timestamp?)?.toDate() ??
              (data['lastMessage']?['timestamp'] as Timestamp?)?.toDate() ??
              (data['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastMessageContent: data['lastMessage']?['content'],
          lastMessageSenderId: data['lastMessage']?['senderId'],
          lastMessageSenderName:
              data['lastMessage']?['senderName'] ?? 'holycow.ai',
          spaceName: 'holycow.ai',
          firstUserMessage: data['firstUserMessage'] as String?,
        );
      }).toList();

      // Sort by last activity descending and take the limit
      aiConversations.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
      final limitedConversations = aiConversations.take(limit).toList();

      return limitedConversations;
    });
  }

  /// Load a specific AI conversation from DM history
  Future<void> loadConversation(String conversationId) async {
    try {
      AppLogger.i('Loading AI conversation: $conversationId');
      cleanupCurrentSession();

      // Clear the stored conversation ID - loaded conversations use their own ID
      // via the 'loaded-' prefix in chatId
      clearConversationId();

      // Get messages from the DM conversation
      final messagesSnapshot = await firestore
          .collection('dmConversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp')
          .get();

      final aiMessages = <AiMessage>[];
      for (final messageDoc in messagesSnapshot.docs) {
        final data = messageDoc.data();
        final senderId = data['senderId'] as String;
        final isUser = senderId != HOLYCOW_USER_ID;

        // Load thought process and search results if they exist
        ThoughtProcess? thoughtProcess;
        List<SearchResult>? searchResults;

        if (data['thoughtProcess'] != null) {
          try {
            thoughtProcess = ThoughtProcess.fromJson(
                Map<String, dynamic>.from(data['thoughtProcess']));
          } catch (e) {
            AppLogger.w(
                'Failed to parse thought process for message ${messageDoc.id}: $e');
          }
        }

        if (data['searchResults'] != null) {
          try {
            searchResults = (data['searchResults'] as List)
                .map((r) => SearchResult.fromJson(Map<String, dynamic>.from(r)))
                .toList();
          } catch (e) {
            AppLogger.w(
                'Failed to parse search results for message ${messageDoc.id}: $e');
          }
        }

        aiMessages.add(AiMessage(
          id: messageDoc.id,
          role: isUser ? 'user' : 'assistant',
          content: data['content'] as String? ?? '',
          createdAt:
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          pending: false,
          thoughtProcess: thoughtProcess,
          searchResults: searchResults,
          // Load voice message fields from Firestore
          isVoiceMessage: data['isVoiceMessage'] as bool? ?? false,
          audioUrl: data['audioUrl'] as String?,
          audioDuration: data['audioDuration'] as int?,
        ));
      }

      // Create new session with loaded messages
      currentSessionDirect = ChatSessionState(
        chatId: 'loaded-$conversationId',
        messages: aiMessages,
      );

      notifyListeners();
      AppLogger.i(
          'Loaded ${aiMessages.length} messages from conversation: $conversationId');
    } catch (e) {
      AppLogger.e('Error loading AI conversation: $e');
      updateSession(currentSession.copyWith(
        error: 'Failed to load conversation: $e',
      ));
    }
  }

  /// Clear chat history
  Future<void> clearHistory() async {
    AppLogger.i('Clearing chat history');
    cleanupCurrentSession();

    // Clear stored conversation ID so a new one is created for the fresh session
    clearConversationId();

    currentSessionDirect = ChatSessionState(
      chatId: 'chat-${DateTime.now().millisecondsSinceEpoch}',
    );

    notifyListeners();
  }

  /// Clear ALL AI conversation history from Firestore
  /// This deletes all past conversations, not just the current session
  Future<void> clearAllConversations() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      AppLogger.w('Cannot clear all conversations - user not authenticated');
      return;
    }

    AppLogger.i('Clearing ALL AI conversation history');

    try {
      // Get all AI conversations for this user
      final conversationsSnapshot = await firestore
          .collection('dmConversations')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      // Filter for AI conversations and delete them
      final batch = firestore.batch();
      int deletedCount = 0;

      for (final doc in conversationsSnapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final isAiConversation = data['isAiConversation'] == true;
        final containsHolyCow = participants.contains(HOLYCOW_USER_ID);

        // Check if this is an AI conversation
        final isValidAiChat = isAiConversation ||
            (containsHolyCow && doc.id.startsWith('ai_chat_')) ||
            (containsHolyCow &&
                doc.id.startsWith('dm_') &&
                doc.id.contains('holycow_system_user'));

        if (isValidAiChat) {
          // Delete all messages in the conversation first
          final messagesSnapshot = await firestore
              .collection('dmConversations')
              .doc(doc.id)
              .collection('messages')
              .get();

          for (final messageDoc in messagesSnapshot.docs) {
            batch.delete(messageDoc.reference);
          }

          // Delete the conversation document
          batch.delete(doc.reference);
          deletedCount++;
        }
      }

      await batch.commit();
      AppLogger.i('Deleted $deletedCount AI conversations');

      // Also clear the current session
      await clearHistory();
    } catch (e) {
      AppLogger.e('Error clearing all AI conversations: $e');
      rethrow;
    }
  }
}
