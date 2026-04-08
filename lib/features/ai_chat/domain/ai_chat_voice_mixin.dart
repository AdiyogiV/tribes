import 'package:flutter/foundation.dart';
import 'package:aurogram/features/ai_chat/domain/gemini_service.dart';
import 'package:aurogram/shared/services/location_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import 'ai_chat_models.dart';
import 'ai_chat_context_mixin.dart';
import 'ai_chat_streaming_mixin.dart';

/// Mixin for AI chat voice/audio message handling via Gemini.
///
/// Requires the host class to provide session state, services, and streaming hooks.
mixin AiChatVoiceMixin on ChangeNotifier, AiChatContextMixin, AiChatStreamingMixin {
  // =========================================================================
  // State that must be provided by the host class
  // =========================================================================
  @override
  ChatSessionState get currentSession;
  @override
  void updateSession(ChatSessionState newSession);
  GeminiService get geminiService;
  @override
  LocationService get locationService;

  // =========================================================================
  // Voice message API
  // =========================================================================

  /// Send a voice message with audio processing via Gemini (Firebase AI Logic)
  /// [localAudioPath] - Path to the local audio file (for Gemini processing)
  /// [audioUrl] - Firebase Storage URL (for playback, optional)
  /// [transcript] - On-device transcription (fallback display text)
  Future<void> sendVoiceMessage({
    required String transcript,
    String? localAudioPath,
    String? audioUrl,
    required int durationInSeconds,
  }) async {
    // Track for retry
    lastFailedWasVoice = true;
    lastFailedAudioPath = localAudioPath;
    lastFailedMessageContent = transcript;

    AppLogger.i('🎙️ Received voice message',
        category: LogCategory.voice,
        data: {
          'transcript': transcript,
          'transcriptLength': transcript.length,
          'hasLocalAudio': localAudioPath != null,
          'hasAudioUrl': audioUrl != null,
          'duration': durationInSeconds,
          'hasAstroContext': astrologyContext != null,
        });

    // Need either audio or transcript
    if (transcript.trim().isEmpty &&
        localAudioPath == null &&
        audioUrl == null) {
      AppLogger.w('⚠️ Voice message rejected: no content',
          category: LogCategory.voice);
      return;
    }

    final sessionId = currentSession.chatId;

    try {
      // Clear any previous errors
      updateSession(currentSession.copyWith(error: null));

      // Add user voice message to UI (show transcript as placeholder)
      final userMessage = AiMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        content: transcript.isNotEmpty ? transcript.trim() : '🎤 Voice message',
        createdAt: DateTime.now(),
        isVoiceMessage: true,
        audioUrl: audioUrl,
        audioDuration: durationInSeconds,
      );

      updateSession(currentSession.copyWith(
        messages: [...currentSession.messages, userMessage],
      ));

      // Decide: Use Gemini directly (faster) or backend (fallback)
      // Use Gemini if we have local audio path - no need to upload first!
      if (localAudioPath != null) {
        AppLogger.i(
            '🚀 Using Gemini directly for audio (Vertex AI + Google Search)',
            category: LogCategory.voice);
        await _processAudioWithGemini(
          localAudioPath: localAudioPath,
          sessionId: sessionId,
          transcript: transcript,
        );
      } else if (audioUrl != null) {
        // Fallback: Send to backend if we only have URL (shouldn't happen normally)
        AppLogger.i('📡 Falling back to backend for audio',
            category: LogCategory.voice);
        await processAiResponse(
            transcript.isNotEmpty ? transcript : 'Voice message', sessionId,
            audioUrl: audioUrl);
      } else {
        // No audio, just send transcript
        await processAiResponse(transcript, sessionId);
      }
    } catch (e) {
      AppLogger.e('Error sending voice message: $e');
      updateSession(currentSession.copyWith(
        error: 'Failed to send voice message: $e',
        isStreaming: false,
        isThinking: false,
      ));
    }
  }

  /// Update the most recent user voice message with the uploaded audio URL
  /// This is called after background upload completes
  void updateLastVoiceMessageUrl(String audioUrl) {
    final messages = List<AiMessage>.from(currentSession.messages);

    // Find the last user voice message without an audioUrl
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.role == 'user' &&
          msg.isVoiceMessage &&
          (msg.audioUrl == null || msg.audioUrl!.isEmpty)) {
        messages[i] = msg.copyWith(audioUrl: audioUrl);
        updateSession(currentSession.copyWith(messages: messages));
        AppLogger.i('🔗 Updated voice message with audioUrl',
            category: LogCategory.voice,
            data: {'messageId': msg.id, 'audioUrl': audioUrl});
        break;
      }
    }
  }

  /// Mark the most recent voice message as "local only" (no upload)
  /// This is called when upload is skipped (logged out user) or failed
  /// Uses special marker "local" so UI knows not to show loading indicator
  void markLastVoiceMessageAsLocalOnly() {
    final messages = List<AiMessage>.from(currentSession.messages);

    // Find the last user voice message without an audioUrl
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.role == 'user' &&
          msg.isVoiceMessage &&
          (msg.audioUrl == null || msg.audioUrl!.isEmpty)) {
        // Use "local" as marker - UI will recognize this as "no upload needed"
        messages[i] = msg.copyWith(audioUrl: 'local');
        updateSession(currentSession.copyWith(messages: messages));
        AppLogger.d('📍 Marked voice message as local-only',
            category: LogCategory.voice, data: {'messageId': msg.id});
        break;
      }
    }
  }

  // =========================================================================
  // Retry state (exposed for the orchestrator)
  // =========================================================================
  String? lastFailedMessageContent;
  bool lastFailedWasVoice = false;
  String? lastFailedAudioPath;

  /// Process audio directly with Gemini via Firebase AI Logic
  /// This is faster than going through the backend (no upload/download)
  Future<void> _processAudioWithGemini({
    required String localAudioPath,
    required String sessionId,
    String? transcript,
  }) async {
    // Verify we're still in the same session
    if (currentSession.chatId != sessionId) {
      AppLogger.w('Session changed during Gemini processing, aborting');
      return;
    }

    try {
      // Create placeholder streaming message
      // For voice messages, we skip the complex thought process and just show typing indicator
      final strmMsgId =
          'streaming-${DateTime.now().millisecondsSinceEpoch}';
      final placeholderMessage = AiMessage(
        id: strmMsgId,
        role: 'assistant',
        content: '',
        createdAt: DateTime.now(),
        pending: true,
        // No thoughtProcess for voice - just use typing indicator (simpler UX)
      );

      updateSession(currentSession.copyWith(
        messages: [...currentSession.messages, placeholderMessage],
        isThinking: true,
        isStreaming: true,
      ));

      streamingMessageId = strmMsgId;
      streamingBuffer = StringBuffer();

      // Get location if available
      String? location;
      try {
        location = await locationService.getCurrentLocationString();
      } catch (e) {
        // Location is optional
      }

      // Build chat history for context (exclude current voice message and streaming)
      // We exclude the most recent user message since we're sending audio directly
      final allMessages = currentSession.messages
          .where((m) => !m.id.startsWith('streaming-') && m.content.isNotEmpty)
          .toList();

      // Remove the last user message (current voice) - we're sending audio for that
      final historyMessages = allMessages.length > 1
          ? allMessages.sublist(0, allMessages.length - 1)
          : <AiMessage>[];

      final chatHistory = historyMessages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      // Log history details for debugging
      AppLogger.i('📜 Chat history built', category: LogCategory.voice, data: {
        'totalMessages': currentSession.messages.length,
        'filteredMessages': allMessages.length,
        'historyMessages': historyMessages.length,
        'historyPreview': historyMessages
            .take(3)
            .map((m) =>
                '${m.role}: ${m.content.length > 50 ? "${m.content.substring(0, 50)}..." : m.content}')
            .toList(),
      });

      // Fetch system prompt from backend once per session/context (fallback: GeminiService builds locally)
      final systemPrompt = await getChatSystemPrompt(location);

      // Process audio with Gemini (streaming response)
      final responseStream = geminiService.sendAudioMessage(
        audioPath: localAudioPath,
        astrologyContext: astrologyContext ?? {},
        chatHistory: chatHistory,
        userLocation: location,
        systemPrompt: systemPrompt,
      );

      // Stream the response
      await for (final chunk in responseStream) {
        // Skip completion marker
        if (chunk.isComplete) continue;

        // Check if session changed
        if (currentSession.chatId != sessionId) {
          AppLogger.w('Session changed during Gemini streaming, aborting');
          break;
        }

        streamingBuffer!.write(chunk.text);

        // Update UI with streamed content
        final currentContent = streamingBuffer.toString();
        final messages = List<AiMessage>.from(currentSession.messages);
        final streamingIndex =
            messages.indexWhere((m) => m.id == strmMsgId);

        if (streamingIndex != -1) {
          messages[streamingIndex] = messages[streamingIndex].copyWith(
            content: currentContent,
          );
          updateSession(currentSession.copyWith(
            messages: messages,
            isThinking: false, // Stop thinking once we have content
          ));
        }
      }

      // Finalize the message - IMPORTANT: Change ID from streaming-* to msg-*
      // so it gets included in chat history for future messages
      final finalContent = streamingBuffer?.toString() ?? '';
      final messages = List<AiMessage>.from(currentSession.messages);
      final streamingIndex =
          messages.indexWhere((m) => m.id == strmMsgId);

      if (streamingIndex != -1) {
        // Create permanent ID (not streaming-*) so this message is included in history
        final permanentId = 'msg-ai-${DateTime.now().millisecondsSinceEpoch}';
        messages[streamingIndex] = messages[streamingIndex].copyWith(
          id: permanentId, // Change from streaming-* to msg-* for history inclusion
          content: finalContent.isNotEmpty
              ? finalContent
              : 'I had trouble processing your voice message. Please try again.',
          pending: false,
          // No thought process for voice messages - keeps UI clean
        );
      }

      updateSession(currentSession.copyWith(
        messages: messages,
        isStreaming: false,
        isThinking: false,
      ));

      streamingBuffer = null;
      streamingMessageId = null;

      AppLogger.i('🤖 Gemini audio response complete',
          category: LogCategory.voice,
          data: {'responseLength': finalContent.length});

      // Save conversation to Firestore for recent chats
      saveConversationAsDM();
    } catch (e) {
      AppLogger.e('Error processing audio with Gemini: $e',
          category: LogCategory.voice);

      // Update session with error
      updateSession(currentSession.copyWith(
        error: 'Failed to process voice message',
        isStreaming: false,
        isThinking: false,
      ));
    }
  }
}
