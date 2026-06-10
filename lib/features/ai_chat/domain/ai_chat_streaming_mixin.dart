import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/models/thought_process.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_service.dart';
import 'package:aurogram/shared/services/location_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import 'ai_chat_models.dart';
import 'ai_chat_context_mixin.dart';

/// Mixin for AI chat streaming, SSE processing, and Firestore real-time updates.
///
/// Requires the host class to provide session state, services, and persistence hooks.
mixin AiChatStreamingMixin on ChangeNotifier, AiChatContextMixin {
  // =========================================================================
  // State that must be provided by the host class
  // =========================================================================
  @override
  ChatSessionState get currentSession;
  @override
  void transition(ChatSessionState newState);
  void updateSession(ChatSessionState newSession);
  AiChatService get service;
  LocationService get locationService;
  FirebaseFirestore get firestore;
  // Provided by AiChatPersistenceMixin (the host class mixes both).
  bool get isUserAuthenticated;
  Future<String?> ensureConversation();

  // =========================================================================
  // Streaming state
  // =========================================================================
  StringBuffer? streamingBuffer;
  String? streamingMessageId;
  String? currentAssistantMessageId;
  bool hasFinalizedCurrentStream = false;
  String? currentRequestId;
  String? currentFirestorePath;
  StreamSubscription<DocumentSnapshot>? firestoreSubscription;
  int lastProcessedStepCount = 0;

  // =========================================================================
  // Streaming API
  // =========================================================================

  /// Process AI response with session isolation
  /// [audioUrl] is optional - if provided, backend will use Gemini for audio processing
  Future<void> processAiResponse(String userText, String sessionId,
      {String? audioUrl}) async {
    // Verify we're still in the same session
    if (currentSession.chatId != sessionId) {
      AppLogger.w('Session changed during processing, aborting');
      return;
    }

    try {
      // Clean up any existing streaming state
      firestoreSubscription?.cancel();
      firestoreSubscription = null;
      currentFirestorePath = null;

      // Reset streaming state
      streamingBuffer = null;
      streamingMessageId = null;
      hasFinalizedCurrentStream = false;
      lastProcessedStepCount = 0;
      currentRequestId = 'req-${DateTime.now().millisecondsSinceEpoch}';

      // Create placeholder streaming message WITH thought process attached
      // SINGLE SOURCE OF TRUTH: thoughts live on the message, not session
      final strmMsgId =
          'streaming-${DateTime.now().millisecondsSinceEpoch}';
      final placeholderMessage = AiMessage(
        id: strmMsgId,
        role: 'assistant',
        content: '',
        createdAt: DateTime.now(),
        pending: true,
        thoughtProcess: ThoughtProcess(
          id: 'thought-$sessionId',
          steps: [],
          isComplete: false,
          isExpanded: false,
          startedAt: DateTime.now(),
        ),
      );

      updateSession(currentSession.copyWith(
        messages: [...currentSession.messages, placeholderMessage],
        isThinking: true,
        isStreaming: true,
      ));

      streamingMessageId = strmMsgId;

      AppLogger.i('Starting AI request: $currentRequestId');

      // Get conversation messages (excluding streaming placeholders)
      final allMessages = List<AiMessage>.from(currentSession.messages);
      final conversationMessages = allMessages
          .where((message) =>
              !message.id.startsWith('streaming-') &&
              message.content.isNotEmpty)
          .toList();

      // Verify we have the user message
      final lastMessage =
          conversationMessages.isNotEmpty ? conversationMessages.last : null;
      if (lastMessage == null || lastMessage.role != 'user') {
        throw Exception('User message not found in conversation history');
      }

      if (lastMessage.content != userText.trim()) {
        throw Exception('User message content mismatch');
      }

      // Clear search results (but keep the streaming message in the list!)
      updateSession(currentSession.copyWith(
        searchResults: const [],
      ));

      // Get location if available
      String? location;
      try {
        location = await locationService.getCurrentLocationString();
      } catch (e) {
        // Location is optional, continue without it
      }

      // Verify session hasn't changed
      if (currentSession.chatId != sessionId) {
        AppLogger.w('Session changed during setup, aborting');
        return;
      }

      lastProcessedStepCount = 0;
      updateSession(currentSession.copyWith(isStreaming: true));

      // Build messages for API
      final messagesToSend = conversationMessages
          .map((m) => <String, dynamic>{'role': m.role, 'content': m.content})
          .toList();

      // Deduplicate messages BUT always keep the last user message
      // (user may legitimately send the same message twice)
      final deduplicatedMessages = <Map<String, dynamic>>[];
      final seenMessages = <String>{};

      // Find the last user message index - we must NEVER deduplicate this
      int lastUserMessageIndex = -1;
      for (int i = messagesToSend.length - 1; i >= 0; i--) {
        if (messagesToSend[i]['role'] == 'user') {
          lastUserMessageIndex = i;
          break;
        }
      }

      for (int i = 0; i < messagesToSend.length; i++) {
        final msg = messagesToSend[i];
        final key = '${msg['role']}:${msg['content']}';

        // Always include the last user message, even if duplicate
        if (i == lastUserMessageIndex) {
          // Remove any duplicate of this message that we already added
          deduplicatedMessages.removeWhere((m) =>
              m['role'] == msg['role'] && m['content'] == msg['content']);
          seenMessages.add(key);
          deduplicatedMessages.add(msg);
        } else if (!seenMessages.contains(key)) {
          seenMessages.add(key);
          deduplicatedMessages.add(msg);
        }
      }

      // Verify last message is from user (should always pass now)
      if (deduplicatedMessages.isEmpty ||
          deduplicatedMessages.last['role'] != 'user') {
        AppLogger.e(
            'Message validation failed. Messages: ${deduplicatedMessages.map((m) => "${m['role']}: ${(m['content'] as String).substring(0, (m['content'] as String).length.clamp(0, 30))}...").toList()}');
        throw Exception('Last message must be from user');
      }

      AppLogger.i('Sending ${deduplicatedMessages.length} messages to AI');

      // Resolve the durable conversation + deterministic message IDs BEFORE we
      // send, so the backend can stream straight into the durable message doc
      // (stream == store). Guests have no conversationId and fall back to the
      // ephemeral ai_chat_sessions doc.
      final userMessageId = conversationMessages.last.id;
      final assistantMessageId =
          'ai-${DateTime.now().millisecondsSinceEpoch}';
      currentAssistantMessageId = assistantMessageId;
      final conversationId =
          isUserAuthenticated ? await ensureConversation() : null;
      final durable = conversationId != null && conversationId.isNotEmpty;

      final stream = service.streamChat(
        messages: deduplicatedMessages,
        context: {
          if (location != null) 'location': location,
          'chatId': sessionId,
          // astrologyContext is now fetched server-side from Firestore
          // using the Firebase ID token sent in the Authorization header.
          // Kept here only as backwards-compat fallback for old/guest sessions.
          if (chatSource != null) 'chatSource': chatSource,
          if (audioUrl != null)
            'audioUrl': audioUrl, // For Gemini audio processing
          // Deterministic IDs: backend is the sole writer of the durable record.
          if (durable) 'conversationId': conversationId,
          'userMessageId': userMessageId,
          'assistantMessageId': assistantMessageId,
        },
      );

      // CRITICAL: Capture the request ID at the start of this stream
      // This allows us to detect if this request was stopped/superseded
      final thisRequestId = currentRequestId!;

      // Attach the Firestore listener IMMEDIATELY on the deterministic doc path.
      // Firestore is our real streaming transport — we must not wait for the SSE
      // 'session' event, which can be buffered until the very end on Flutter web.
      // Authed: the durable message doc. Guest: the ephemeral session doc.
      currentFirestorePath = durable
          ? 'dmConversations/$conversationId/messages/$assistantMessageId'
          : 'ai_chat_sessions/$sessionId';
      _listenToFirestoreUpdates(currentFirestorePath!, sessionId, thisRequestId);

      await for (final event in stream) {
        // CRITICAL: Check if THIS request is still the active one
        // If currentRequestId changed (user stopped or sent new message), abort this stream
        if (currentRequestId != thisRequestId) {
          AppLogger.i(
              'Request $thisRequestId superseded by $currentRequestId, stopping old stream');
          break;
        }

        // Check session on each event
        if (currentSession.chatId != sessionId) {
          AppLogger.w('Session changed during streaming, aborting');
          firestoreSubscription?.cancel();
          firestoreSubscription = null;
          return;
        }

        // Check if already finalized (user clicked stop)
        if (hasFinalizedCurrentStream) {
          AppLogger.i('Stream already finalized, breaking out');
          break;
        }

        final type = event['event'];

        if (type == 'session') {
          final chatId = event['chatId'] as String?;
          final firestorePath = event['firestorePath'] as String?;
          // Listener is already attached on the deterministic path above; only
          // (re)attach from the SSE event if for some reason it isn't running.
          if (chatId != null &&
              firestorePath != null &&
              firestoreSubscription == null) {
            currentFirestorePath = firestorePath;
            _listenToFirestoreUpdates(firestorePath, sessionId, thisRequestId);
          }
        } else if (type == 'token') {
          // SSE token events contain streaming text chunks from the backend
          final chunk = event['content'] as String?;
          if (chunk != null) {
            _handleStreamingUpdate(chunk, sessionId);
          }
        } else if (type == 'complete') {
          // SSE 'complete' is the PRIMARY source of truth for final content
          final finalText = event['content'] as String? ?? '';
          final bufferText = streamingBuffer?.toString() ?? '';

          // Use SSE content if available, otherwise use accumulated buffer
          final resolvedContent = finalText.isNotEmpty ? finalText : bufferText;

          AppLogger.i('SSE complete received for request: $thisRequestId, '
              'sseContent: ${finalText.length}, buffer: ${bufferText.length}, '
              'resolved: ${resolvedContent.length}');

          if (currentRequestId == thisRequestId &&
              !hasFinalizedCurrentStream) {
            if (resolvedContent.trim().isNotEmpty) {
              // We have content - finalize now
              _finalizeStreamingResponse(resolvedContent, sessionId);
            } else {
              // No content yet - wait briefly for Firestore backup
              // This handles edge cases where backend sent 'complete' but content came via Firestore
              AppLogger.i(
                  'SSE complete has no content, Firestore will provide backup');
            }
          }
        } else if (type == 'error') {
          final error = event['error'] as String? ?? 'Unknown error';
          // If we have partial content, save it instead of discarding
          if (streamingBuffer != null && streamingBuffer!.isNotEmpty) {
            AppLogger.w(
                'Backend error but we have partial content, saving: $error');
            if (currentRequestId == thisRequestId &&
                !hasFinalizedCurrentStream) {
              _finalizeStreamingResponse('', sessionId);
            }
          } else {
            throw Exception(error);
          }
        }
      }

      // If stream ended without 'complete' event, try to finalize from buffer
      // Only if THIS request is still active
      if (currentRequestId == thisRequestId && !hasFinalizedCurrentStream) {
        AppLogger.w(
            'SSE stream ended without complete event, finalizing from buffer');
        _finalizeStreamingResponse('', sessionId);
      }

      if (currentSession.chatId != sessionId) {
        AppLogger.w('Session changed after streaming');
        return;
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error in AI response: $e\n$stackTrace');
      handleResponseError(e, sessionId);
    }
  }

  /// Listen to Firestore for real-time AI processing updates
  void _listenToFirestoreUpdates(
      String firestorePath, String sessionId, String requestId) {
    // Cancel any existing subscription
    firestoreSubscription?.cancel();
    lastProcessedStepCount = 0;

    // CRITICAL: Skip the initial snapshot if it's from a previous request
    // Firestore snapshots() fires immediately with current state, which might be
    // the completed state from the previous request if both use the same document
    bool isFirstSnapshot = true;

    // Listen to the Firestore document
    firestoreSubscription = firestore.doc(firestorePath).snapshots().listen(
      (snapshot) {
        // Verify this update is for the current request
        if (currentRequestId != requestId ||
            currentFirestorePath != firestorePath) {
          AppLogger.w(
              '⚠️ Firestore update ignored - request ID or path mismatch');
          AppLogger.w(
              '  Current request ID: $currentRequestId, Expected: $requestId');
          AppLogger.w(
              '  Current path: $currentFirestorePath, Expected: $firestorePath');
          firestoreSubscription?.cancel();
          return;
        }

        if (currentSession.chatId != sessionId) {
          firestoreSubscription?.cancel();
          return;
        }

        if (!snapshot.exists) return;

        final data = snapshot.data();
        if (data == null) return;

        // CRITICAL: On first snapshot, check if this is already completed from a previous request
        // If it is, ignore it as it's stale data
        // BUT: If status is "processing", always process it (it's a new request)
        if (isFirstSnapshot) {
          isFirstSnapshot = false;
          final status = data['status'] as String?;

          // If status is "processing", this is a new request - process it immediately
          // Reset step counter since backend resets thoughtSteps array
          if (status == 'processing') {
            lastProcessedStepCount = 0;
            // Process the update (will handle thought steps on the message)
            _handleFirestoreUpdate(data, sessionId, firestorePath);
            return;
          }

          // Check completion/failure timestamp to ignore stale data
          // This applies to both "completed" and "failed" statuses
          if (status == 'completed' || status == 'failed') {
            final completedAt = data['completedAt'] as dynamic;
            final updatedAt = data['updatedAt'] as dynamic;

            // Use completedAt for completed status, or updatedAt for failed status
            final timestampData = status == 'completed'
                ? completedAt
                : (completedAt ?? updatedAt);

            if (timestampData != null) {
              int? dataTimestamp;
              if (timestampData is Timestamp) {
                dataTimestamp = timestampData.toDate().millisecondsSinceEpoch;
              } else if (timestampData is int) {
                dataTimestamp = timestampData;
              }

              if (dataTimestamp != null) {
                final requestTimestamp =
                    int.tryParse(requestId.replaceAll('req-', '')) ?? 0;
                if (dataTimestamp < requestTimestamp) {
                  AppLogger.w(
                      '⚠️ Ignoring stale Firestore snapshot from previous request (status: $status)');
                  AppLogger.w(
                      '  Data timestamp: $dataTimestamp, Request started: $requestTimestamp');
                  return;
                }
              }
            } else {
              // No timestamp available for completed/failed status - likely stale data
              // Ignore it and wait for fresh data from this request
              AppLogger.w(
                  '⚠️ Ignoring Firestore snapshot with $status status but no timestamp - likely stale');
              return;
            }
          }
        }

        _handleFirestoreUpdate(data, sessionId, firestorePath);
      },
      onError: (error) {
        // Handle permission errors gracefully for unauthenticated users
        final errorString = error.toString();
        if (errorString.contains('permission-denied') ||
            errorString.contains('permission_denied')) {
          AppLogger.w(
              'Firestore permission denied - user may not be authenticated');
          AppLogger.w('Chat will continue via SSE streaming only');
          // Don't call handleResponseError for permission errors - chat can still work via SSE
          firestoreSubscription?.cancel();
          firestoreSubscription = null;
          return;
        }
        AppLogger.e('Firestore listener error: $error');
        handleResponseError(error, sessionId);
      },
    );
  }

  /// Handle real-time Firestore updates
  /// SIMPLIFIED: Updates the streaming message's thoughtProcess directly
  void _handleFirestoreUpdate(
      Map<String, dynamic> data, String sessionId, String firestorePath) {
    if (currentSession.chatId != sessionId) return;
    if (currentFirestorePath != firestorePath) return;

    try {
      final status = data['status'] as String?;
      final thoughtStepsData = data['thoughtSteps'] as List<dynamic>?;
            final responseText =
          (data['content'] ?? data['response']) as String?;
      final searchResultsData = data['searchResults'] as Map<String, dynamic>?;

      // Find the streaming message
      final streamingIndex = currentSession.messages
          .indexWhere((m) => m.id == streamingMessageId);

      if (streamingIndex == -1) return;

      final streamingMessage = currentSession.messages[streamingIndex];

      // CRITICAL: Detect backend reset (step count decreased = new request started)
      // This happens when Firestore has stale data from previous request
      if (thoughtStepsData != null &&
          thoughtStepsData.length < lastProcessedStepCount) {
        lastProcessedStepCount = 0;

        // Clear stale thoughts from the message
        final clearedMessage = streamingMessage.copyWith(
          thoughtProcess: ThoughtProcess(
            id: 'thought-$sessionId',
            steps: [],
            isComplete: false,
            isExpanded: false,
            startedAt: DateTime.now(),
          ),
        );
        final clearedMessages = List<AiMessage>.from(currentSession.messages);
        clearedMessages[streamingIndex] = clearedMessage;
        updateSession(currentSession.copyWith(messages: clearedMessages));
      }

      // Process new thought steps - update the MESSAGE's thoughtProcess
      // Re-fetch streaming message in case it was just cleared above
      final currentStreamingMessage = currentSession.messages[streamingIndex];
      if (thoughtStepsData != null &&
          thoughtStepsData.length > lastProcessedStepCount) {
        final newStepsData = thoughtStepsData.sublist(lastProcessedStepCount);
        final newSteps = <ThoughtStep>[];

        for (final stepData in newStepsData) {
          if (stepData is Map<String, dynamic>) {
            try {
              List<SearchResult>? stepResults;
              if (stepData['results'] != null && stepData['results'] is List) {
                stepResults = (stepData['results'] as List)
                    .map((r) =>
                        SearchResult.fromJson(Map<String, dynamic>.from(r)))
                    .toList();
              }

              newSteps.add(ThoughtStep(
                id: stepData['id'] ??
                    'step-${DateTime.now().millisecondsSinceEpoch}',
                type: stepData['type'] ?? 'thinking',
                message: stepData['message'] ?? '',
                query: stepData['query'],
                results: stepResults,
                timestamp: DateTime.now(),
                sequence: stepData['sequence'] ?? 0,
                metadata: stepData,
              ));
            } catch (e) {
              AppLogger.w('Failed to parse thought step: $e');
            }
          }
        }

        if (newSteps.isNotEmpty) {
          final existingSteps =
              currentStreamingMessage.thoughtProcess?.steps ?? [];
          // Combine and sort by sequence to ensure correct order
          final allSteps = [...existingSteps, ...newSteps];
          allSteps.sort((a, b) => a.sequence.compareTo(b.sequence));

          final updatedThought = ThoughtProcess(
            id: currentStreamingMessage.thoughtProcess?.id ??
                'thought-$sessionId',
            steps: allSteps,
            isComplete: status == 'completed',
            isExpanded:
                currentStreamingMessage.thoughtProcess?.isExpanded ?? false,
            startedAt: currentStreamingMessage.thoughtProcess?.startedAt ??
                DateTime.now(),
          );

          // Update the message with new thoughts
          final updatedMessage =
              currentStreamingMessage.copyWith(thoughtProcess: updatedThought);
          final updatedMessages =
              List<AiMessage>.from(currentSession.messages);
          updatedMessages[streamingIndex] = updatedMessage;

          updateSession(currentSession.copyWith(
            messages: updatedMessages,
            isThinking: status != 'completed',
          ));

          lastProcessedStepCount = thoughtStepsData.length;
        }
      }

      // Handle search results
      if (searchResultsData != null) {
        final results = searchResultsData['results'] as List<dynamic>? ?? [];
        final searchResults = <SearchResult>[];
        for (final result in results) {
          if (result is Map<String, dynamic>) {
            try {
              searchResults.add(SearchResult.fromJson(result));
            } catch (e) {
              AppLogger.w('Failed to parse search result: $e');
            }
          }
        }

        if (searchResults.isNotEmpty) {
          updateSession(
              currentSession.copyWith(searchResults: searchResults));
        }
      }

      // Firestore is our streaming transport (SSE is unreliable on Flutter web +
      // Hosting/Cloud Run, which buffer the chunked response). The backend writes
      // `response` incrementally, so render it live while still processing.
      // responseText is the full accumulated text each tick; _handleStreamingUpdate
      // handles the cumulative-growth case correctly.
      if (responseText != null &&
          responseText.isNotEmpty &&
          status != 'completed' &&
          !hasFinalizedCurrentStream) {
        _handleStreamingUpdate(responseText, sessionId);
      }

      // Handle completion - Firestore 'completed' is the authoritative finalizer
      // SSE 'complete' event is authoritative and should have already finalized
      if (status == 'completed') {
        // Mark thoughts complete
        _markThoughtsComplete(sessionId);

        // Only finalize from Firestore if SSE didn't provide content
        // This handles edge cases where SSE connection dropped
        if (!hasFinalizedCurrentStream &&
            responseText != null &&
            responseText.isNotEmpty) {
          AppLogger.i(
              'Firestore completing response (SSE backup) - length: ${responseText.length}');
          _finalizeStreamingResponse(responseText, sessionId);
        }

        // Cleanup listener - we're done
        firestoreSubscription?.cancel();
        firestoreSubscription = null;
      } else if (status == 'failed') {
        final error = data['error'] as String? ?? 'Unknown error';
        AppLogger.e('AI processing failed: $error');
        handleResponseError(Exception(error), sessionId);
        firestoreSubscription?.cancel();
        firestoreSubscription = null;
      }
    } catch (e) {
      AppLogger.e('Error handling Firestore update: $e');
    }
  }

  /// Mark thought process as complete on the streaming message
  void _markThoughtsComplete(String sessionId) {
    if (currentSession.chatId != sessionId) return;
    if (streamingMessageId == null) return;

    final streamingIndex =
        currentSession.messages.indexWhere((m) => m.id == streamingMessageId);
    if (streamingIndex == -1) return;

    final streamingMessage = currentSession.messages[streamingIndex];
    if (streamingMessage.thoughtProcess == null) return;

    final completedThoughts = streamingMessage.thoughtProcess!.complete();
    final updatedMessage = streamingMessage.copyWith(
      thoughtProcess: completedThoughts,
    );

    final updatedMessages = List<AiMessage>.from(currentSession.messages);
    updatedMessages[streamingIndex] = updatedMessage;

    updateSession(currentSession.copyWith(
      messages: updatedMessages,
      isThinking: false,
    ));
  }

  /// Handle response errors with structured error types
  void handleResponseError(dynamic error, String sessionId) {
    if (currentSession.chatId != sessionId) return;

    final chatError = AiChatError.fromException(error);
    AppLogger.e('AI response error: ${chatError.message}',
        category: LogCategory.network,
        data: {
          'type': chatError.type.name,
          'isRetryable': chatError.isRetryable,
          'originalError': chatError.originalError,
        });

    transition(currentSession.copyWith(
      phase: ChatPhase.error,
      chatError: chatError,
      errorMessage: chatError.message,
    ));
  }

  void _handleStreamingUpdate(String partialText, String sessionId) {
    if (currentSession.chatId != sessionId) return;
    if (partialText.isEmpty || hasFinalizedCurrentStream) return;

    streamingBuffer ??= StringBuffer();
    var buffer = streamingBuffer!;
    final currentContent = buffer.toString();

    // Update buffer based on partial text
    if (partialText == currentContent) {
      // No change
    } else if (partialText.length > currentContent.length &&
        partialText.startsWith(currentContent)) {
      buffer = StringBuffer(partialText);
      streamingBuffer = buffer;
    } else if (currentContent.isEmpty) {
      buffer.write(partialText);
    } else if (!currentContent.endsWith(partialText)) {
      buffer.write(partialText);
    }

    final updatedContent = buffer.toString();
    final existingMessages = List<AiMessage>.from(currentSession.messages);
    final streamingIndex =
        existingMessages.lastIndexWhere((m) => m.id.startsWith('streaming-'));

    if (streamingIndex == -1) return;

    // PRESERVE the existing thoughtProcess when updating content
    final existingMessage = existingMessages[streamingIndex];
    final updatedMessage = existingMessage.copyWith(
      content: updatedContent,
      searchResults: currentSession.searchResults.isNotEmpty
          ? currentSession.searchResults
          : null,
    );

    existingMessages[streamingIndex] = updatedMessage;

    updateSession(currentSession.copyWith(
      messages: existingMessages,
      isStreaming: true,
      isThinking: true,
      error: null,
    ));
  }

  void _finalizeStreamingResponse(String finalText, String sessionId) {
    // Verify session and request
    if (currentSession.chatId != sessionId) {
      firestoreSubscription?.cancel();
      firestoreSubscription = null;
      return;
    }

    if (currentRequestId == null || hasFinalizedCurrentStream) {
      return;
    }

    hasFinalizedCurrentStream = true;

    // Get content from either finalText or streaming buffer
    final content =
        finalText.isNotEmpty ? finalText : (streamingBuffer?.toString() ?? '');

    AppLogger.i('Finalizing response - length: ${content.length}, '
        'preview: "${content.length > 50 ? content.substring(0, 50) : content}..."');

    // Find the streaming message to get its thoughtProcess
    final streamingMessage = currentSession.messages
        .where((m) => m.id == streamingMessageId)
        .firstOrNull;

    // Build final messages list - remove streaming/pending messages
    final messages = List<AiMessage>.from(currentSession.messages)
      ..removeWhere((m) => m.id.startsWith('streaming-') || m.pending);

    // Add final message - only if there's actual visible content.
    // Reuse the assistant message id we sent to the backend so the in-memory
    // message matches the durable Firestore doc (no duplicate on reload).
    if (content.trim().isNotEmpty) {
      final aiMessage = AiMessage(
        id: currentAssistantMessageId ??
            'ai-${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: content,
        createdAt: DateTime.now(),
        pending: false,
        searchResults: currentSession.searchResults.isNotEmpty
            ? currentSession.searchResults
            : null,
        thoughtProcess: streamingMessage?.thoughtProcess?.complete(),
      );
      messages.add(aiMessage);

      AppLogger.i(
          'Finalized response with ${aiMessage.thoughtProcess?.steps.length ?? 0} thought steps, '
          'content length: ${content.length}');
    } else {
      AppLogger.w('Skipping empty AI response');
    }

    // Clear streaming state
    streamingBuffer = null;
    streamingMessageId = null;
    currentAssistantMessageId = null;
    currentRequestId = null;
    currentFirestorePath = null;

    updateSession(currentSession.copyWith(
      messages: messages,
      isStreaming: false,
      isThinking: false,
    ));

    // No client-side save: the backend is the sole writer and has already
    // streamed this exact message into the durable dmConversations doc.

    firestoreSubscription?.cancel();
    firestoreSubscription = null;
  }
}
