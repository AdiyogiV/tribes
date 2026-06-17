import 'dart:async';

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
  // Deferred-send state (audio-only voice, upload still in flight)
  // =========================================================================
  // When a voice message has no on-device transcript, the backend needs the
  // Storage URL to "hear" the audio. That URL arrives a few seconds AFTER the
  // recording finishes (background upload). We park the request here and fire
  // it from updateLastVoiceMessageUrl once the URL is ready.
  bool _pendingVoiceSend = false;
  String? _pendingVoiceSessionId;
  String _pendingVoiceTranscript = '';

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
        // No on-device transcript and the audio URL isn't ready yet. A
        // background upload is in flight (every voice entry point wires
        // onAudioUrlUploaded / onAudioUploadSkipped). Defer the AI request:
        //   - URL arrives          -> updateLastVoiceMessageUrl resumes it
        //   - upload skipped/failed -> markLastVoiceMessageAsLocalOnly cancels
        AppLogger.i('Voice -> deferring send until audio upload resolves',
            category: LogCategory.voice);
        _pendingVoiceSend = true;
        _pendingVoiceSessionId = sessionId;
        _pendingVoiceTranscript = transcript.trim();
        updateSession(currentSession.copyWith(isThinking: true));
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

    // Resume a deferred audio-only send now that the backend has a URL to hear.
    if (_pendingVoiceSend) {
      _pendingVoiceSend = false;
      final sessionId = _pendingVoiceSessionId ?? currentSession.chatId;
      final transcript = _pendingVoiceTranscript;
      _pendingVoiceSessionId = null;
      _pendingVoiceTranscript = '';
      AppLogger.i('Resuming deferred voice send with uploaded URL',
          category: LogCategory.voice, data: {'audioUrl': audioUrl});
      unawaited(processAiResponse(
          transcript.isNotEmpty ? transcript : 'Voice message', sessionId,
          audioUrl: audioUrl));
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

    // A deferred send was waiting on this upload, but it won't arrive
    // (skipped for logged-out users, or failed). Surface it instead of
    // leaving the UI stuck on "thinking".
    if (_pendingVoiceSend) {
      _pendingVoiceSend = false;
      _pendingVoiceSessionId = null;
      _pendingVoiceTranscript = '';
      AppLogger.w('Deferred voice send cancelled: audio upload unavailable',
          category: LogCategory.voice);
      updateSession(currentSession.copyWith(
        error: 'Could not upload your voice message. Please try again.',
        isStreaming: false,
        isThinking: false,
      ));
    }
  }
}
