import 'package:flutter/foundation.dart';
import 'package:aurogram/shared/services/location_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import 'ai_chat_models.dart';
import 'ai_chat_context_mixin.dart';
import 'ai_chat_streaming_mixin.dart';

/// Mixin for AI chat voice/audio message handling.
///
/// ONE PATH: voice messages are routed through the same backend SSE endpoint
/// as text (see [AiChatStreamingMixin.processAiResponse]). There is no longer a
/// client-direct Gemini path — the backend owns context, memory, and search.
mixin AiChatVoiceMixin on ChangeNotifier, AiChatContextMixin, AiChatStreamingMixin {
  // =========================================================================
  // State that must be provided by the host class
  // =========================================================================
  @override
  ChatSessionState get currentSession;
  @override
  void updateSession(ChatSessionState newSession);
  @override
  LocationService get locationService;

  // =========================================================================
  // Retry state (exposed for the orchestrator)
  // =========================================================================
  String? lastFailedMessageContent;
  bool lastFailedWasVoice = false;
  String? lastFailedAudioPath;

  // =========================================================================
  // Voice message API
  // =========================================================================

  /// Send a voice message. Adds the voice bubble to the UI, then routes the
  /// request to the backend — preferring the uploaded audio URL (so Gemini can
  /// hear tone/Hinglish natively) and falling back to the on-device transcript.
  ///
  /// [localAudioPath] - local file (kept only for retry bookkeeping)
  /// [audioUrl] - Firebase Storage URL (for playback + backend audio understanding)
  /// [transcript] - on-device transcription (used as text fallback + display)
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

    AppLogger.i('Received voice message',
        category: LogCategory.voice,
        data: {
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
      AppLogger.w('Voice message rejected: no content',
          category: LogCategory.voice);
      return;
    }

    final sessionId = currentSession.chatId;

    try {
      // Clear any previous errors
      updateSession(currentSession.copyWith(error: null));

      // Add user voice message to UI (transcript shown as the bubble text)
      final userMessage = AiMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        content: transcript.isNotEmpty ? transcript.trim() : 'Voice message',
        createdAt: DateTime.now(),
        isVoiceMessage: true,
        audioUrl: audioUrl,
        audioDuration: durationInSeconds,
      );

      updateSession(currentSession.copyWith(
        messages: [...currentSession.messages, userMessage],
      ));

      // Route through the unified backend SSE path.
      final hasUrl =
          audioUrl != null && audioUrl.isNotEmpty && audioUrl != 'local';
      if (hasUrl) {
        AppLogger.i('Voice -> backend (audio URL)',
            category: LogCategory.voice);
        await processAiResponse(
            transcript.isNotEmpty ? transcript : 'Voice message', sessionId,
            audioUrl: audioUrl);
      } else if (transcript.trim().isNotEmpty) {
        AppLogger.i('Voice -> backend (on-device transcript as text)',
            category: LogCategory.voice);
        await processAiResponse(transcript.trim(), sessionId);
      } else {
        AppLogger.w('Voice message has no transcript and no audio URL',
            category: LogCategory.voice);
        updateSession(currentSession.copyWith(
          error: 'Could not capture your voice message. Please try again.',
          isStreaming: false,
          isThinking: false,
        ));
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

  /// Update the most recent user voice message with the uploaded audio URL.
  /// Called after the background upload completes (enables playback).
  void updateLastVoiceMessageUrl(String audioUrl) {
    final messages = List<AiMessage>.from(currentSession.messages);

    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.role == 'user' &&
          msg.isVoiceMessage &&
          (msg.audioUrl == null || msg.audioUrl!.isEmpty)) {
        messages[i] = msg.copyWith(audioUrl: audioUrl);
        updateSession(currentSession.copyWith(messages: messages));
        AppLogger.i('Updated voice message with audioUrl',
            category: LogCategory.voice,
            data: {'messageId': msg.id, 'audioUrl': audioUrl});
        break;
      }
    }
  }

  /// Mark the most recent voice message as "local only" (no upload).
  /// Called when upload is skipped (logged-out user) or failed. The "local"
  /// marker tells the UI not to show a loading indicator.
  void markLastVoiceMessageAsLocalOnly() {
    final messages = List<AiMessage>.from(currentSession.messages);

    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.role == 'user' &&
          msg.isVoiceMessage &&
          (msg.audioUrl == null || msg.audioUrl!.isEmpty)) {
        messages[i] = msg.copyWith(audioUrl: 'local');
        updateSession(currentSession.copyWith(messages: messages));
        AppLogger.d('Marked voice message as local-only',
            category: LogCategory.voice, data: {'messageId': msg.id});
        break;
      }
    }
  }
}
