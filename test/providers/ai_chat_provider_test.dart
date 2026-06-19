import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  group('AiMessage', () {
    test('creates with required fields', () {
      final message = AiMessage(
        id: 'test-1',
        role: 'user',
        content: 'Hello',
        createdAt: DateTime.now(),
      );

      expect(message.id, 'test-1');
      expect(message.role, 'user');
      expect(message.content, 'Hello');
      expect(message.pending, false);
      expect(message.isVoiceMessage, false);
    });

    test('copyWith preserves unchanged values', () {
      final original = AiMessage(
        id: 'test-1',
        role: 'user',
        content: 'Hello',
        createdAt: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(content: 'Updated');

      expect(updated.id, 'test-1');
      expect(updated.role, 'user');
      expect(updated.content, 'Updated');
      expect(updated.createdAt, DateTime(2024, 1, 1));
    });

    test('marks voice messages correctly', () {
      final voiceMessage = AiMessage(
        id: 'voice-1',
        role: 'user',
        content: '🎤 Voice message',
        createdAt: DateTime.now(),
        isVoiceMessage: true,
        audioDuration: 5,
      );

      expect(voiceMessage.isVoiceMessage, true);
      expect(voiceMessage.audioDuration, 5);
    });
  });

  group('ChatPhase', () {
    test('has all required phases', () {
      expect(ChatPhase.values, contains(ChatPhase.idle));
      expect(ChatPhase.values, contains(ChatPhase.sending));
      expect(ChatPhase.values, contains(ChatPhase.streaming));
      expect(ChatPhase.values, contains(ChatPhase.error));
    });
  });

  group('AiChatError', () {
    test('fromException classifies rate limit errors', () {
      final error = AiChatError.fromException('Rate limit exceeded (429)');

      expect(error.type, AiErrorType.rateLimit);
      expect(error.isRetryable, true);
      expect(error.message, contains('Too many requests'));
    });

    test('fromException classifies network errors', () {
      final error = AiChatError.fromException('Network connection failed');

      expect(error.type, AiErrorType.network);
      expect(error.isRetryable, true);
      expect(error.message, contains('Network error'));
    });

    test('fromException classifies timeout errors', () {
      final error = AiChatError.fromException('Request timed out');

      expect(error.type, AiErrorType.timeout);
      expect(error.isRetryable, true);
      expect(error.message, contains('timed out'));
    });

    test('fromException classifies server errors', () {
      final error = AiChatError.fromException('500 Internal Server Error');

      expect(error.type, AiErrorType.serverError);
      expect(error.isRetryable, true);
      expect(error.message, contains('Server'));
    });

    test('fromException defaults to unknown', () {
      final error = AiChatError.fromException('Some random error');

      expect(error.type, AiErrorType.unknown);
      expect(error.isRetryable, true);
      expect(error.message, contains('went wrong'));
    });
  });

  group('ChatSessionState', () {
    test('creates with default values', () {
      final state = ChatSessionState(chatId: 'test-chat');

      expect(state.chatId, 'test-chat');
      expect(state.messages, isEmpty);
      expect(state.phase, ChatPhase.idle);
      expect(state.isStreaming, false);
      expect(state.isThinking, false);
      expect(state.error, isNull);
      expect(state.canRetry, false);
    });

    test('convenience getters reflect phase', () {
      final idleState = ChatSessionState(
        chatId: 'test',
        phase: ChatPhase.idle,
      );
      expect(idleState.isStreaming, false);
      expect(idleState.isThinking, false);

      final sendingState = ChatSessionState(
        chatId: 'test',
        phase: ChatPhase.sending,
      );
      expect(sendingState.isStreaming, false);
      expect(sendingState.isThinking, true);

      final streamingState = ChatSessionState(
        chatId: 'test',
        phase: ChatPhase.streaming,
      );
      expect(streamingState.isStreaming, true);
      expect(streamingState.isThinking, false);

      final errorState = ChatSessionState(
        chatId: 'test',
        phase: ChatPhase.error,
      );
      expect(errorState.hasError, true);
    });

    test('canRetry reflects error retryability', () {
      final retryableError = AiChatError(
        message: 'Test',
        type: AiErrorType.network,
        isRetryable: true,
      );

      final stateWithRetryable = ChatSessionState(
        chatId: 'test',
        phase: ChatPhase.error,
        chatError: retryableError,
      );
      expect(stateWithRetryable.canRetry, true);

      final nonRetryableError = AiChatError(
        message: 'Test',
        type: AiErrorType.unknown,
        isRetryable: false,
      );

      final stateWithNonRetryable = ChatSessionState(
        chatId: 'test',
        phase: ChatPhase.error,
        chatError: nonRetryableError,
      );
      expect(stateWithNonRetryable.canRetry, false);
    });

    test('copyWith handles legacy parameters', () {
      final original = ChatSessionState(
        chatId: 'test',
        phase: ChatPhase.idle,
      );

      // Legacy isStreaming=true should set phase to streaming
      final streaming = original.copyWith(isStreaming: true);
      expect(streaming.phase, ChatPhase.streaming);

      // Legacy isThinking=true should set phase to sending
      final thinking = original.copyWith(isThinking: true);
      expect(thinking.phase, ChatPhase.sending);

      // Legacy parameters false should set phase to idle
      final idle = ChatSessionState(
        chatId: 'test',
        phase: ChatPhase.streaming,
      ).copyWith(isStreaming: false, isThinking: false);
      expect(idle.phase, ChatPhase.idle);
    });

    test('addUserMessage transitions to sending phase', () {
      final state = ChatSessionState(chatId: 'test');
      final userMessage = AiMessage(
        id: 'msg-1',
        role: 'user',
        content: 'Hello',
        createdAt: DateTime.now(),
      );

      final newState = state.addUserMessage(userMessage);

      expect(newState.messages.length, 1);
      expect(newState.messages.first.content, 'Hello');
      expect(newState.phase, ChatPhase.sending);
    });

    test('addAiMessagePlaceholder adds pending message', () {
      final state = ChatSessionState(chatId: 'test');

      final newState = state.addAiMessagePlaceholder('streaming-1');

      expect(newState.messages.length, 1);
      expect(newState.messages.first.id, 'streaming-1');
      expect(newState.messages.first.role, 'assistant');
      expect(newState.messages.first.pending, true);
      expect(newState.phase, ChatPhase.streaming);
    });

    test('updateStreamingContent updates message content', () {
      final state = ChatSessionState(
        chatId: 'test',
        messages: [
          AiMessage(
            id: 'streaming-1',
            role: 'assistant',
            content: 'Hello',
            createdAt: DateTime.now(),
            pending: true,
          ),
        ],
        phase: ChatPhase.streaming,
      );

      final updated = state.updateStreamingContent('streaming-1', 'Hello world');

      expect(updated.messages.first.content, 'Hello world');
    });

    test('finalizeMessage transitions to idle phase', () {
      final state = ChatSessionState(
        chatId: 'test',
        messages: [
          AiMessage(
            id: 'streaming-1',
            role: 'assistant',
            content: 'Hello world',
            createdAt: DateTime.now(),
            pending: true,
          ),
        ],
        phase: ChatPhase.streaming,
      );

      final finalized = state.finalizeMessage(
        'streaming-1',
        'Hello world - complete',
        newId: 'msg-ai-123',
      );

      expect(finalized.messages.first.id, 'msg-ai-123');
      expect(finalized.messages.first.content, 'Hello world - complete');
      expect(finalized.messages.first.pending, false);
      expect(finalized.phase, ChatPhase.idle);
    });
  });

}
