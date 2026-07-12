import 'package:aurogram/shared/models/search_result.dart';

/// Represents a single AI chat message
class AiMessage {
  final String id;
  final String role; // user | assistant | system
  final String content;
  final DateTime createdAt;
  final bool pending;
  final List<SearchResult>? searchResults;
  final String? audioUrl; // For voice messages
  final int? audioDuration; // Duration in seconds
  final bool isVoiceMessage; // Flag to identify voice messages

  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.pending = false,
    this.searchResults,
    this.audioUrl,
    this.audioDuration,
    this.isVoiceMessage = false,
  });

  AiMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? createdAt,
    bool? pending,
    List<SearchResult>? searchResults,
    String? audioUrl,
    int? audioDuration,
    bool? isVoiceMessage,
  }) {
    return AiMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      pending: pending ?? this.pending,
      searchResults: searchResults ?? this.searchResults,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      isVoiceMessage: isVoiceMessage ?? this.isVoiceMessage,
    );
  }
}

/// Represents the phase of the chat conversation
/// Clean state machine approach - only one phase at a time
enum ChatPhase {
  /// Ready for user input
  idle,

  /// Processing user message, waiting for AI response to start
  sending,

  /// Actively receiving streamed response from AI
  streaming,

  /// An error occurred (recoverable - user can retry)
  error,
}

/// Types of errors that can occur during AI chat
enum AiErrorType {
  /// Network connectivity issue
  network,

  /// Rate limit exceeded
  rateLimit,

  /// Server error (5xx)
  serverError,

  /// AI service unavailable
  serviceUnavailable,

  /// Request timeout
  timeout,

  /// Unknown error
  unknown,
}

/// Structured error for AI chat operations
class AiChatError {
  final String message;
  final AiErrorType type;
  final bool isRetryable;
  final String? originalError;

  const AiChatError({
    required this.message,
    required this.type,
    required this.isRetryable,
    this.originalError,
  });

  factory AiChatError.fromException(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Rate limit errors
    if (errorStr.contains('rate limit') || errorStr.contains('429')) {
      return AiChatError(
        message: 'Too many requests. Please wait a moment and try again.',
        type: AiErrorType.rateLimit,
        isRetryable: true,
        originalError: error.toString(),
      );
    }

    // Network errors
    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('socket') ||
        errorStr.contains('unreachable')) {
      return AiChatError(
        message: 'Network error. Please check your connection.',
        type: AiErrorType.network,
        isRetryable: true,
        originalError: error.toString(),
      );
    }

    // Timeout errors
    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return AiChatError(
        message: 'Request timed out. Please try again.',
        type: AiErrorType.timeout,
        isRetryable: true,
        originalError: error.toString(),
      );
    }

    // Server errors
    if (errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503') ||
        errorStr.contains('server error')) {
      return AiChatError(
        message: 'Server is temporarily unavailable. Please try again.',
        type: AiErrorType.serverError,
        isRetryable: true,
        originalError: error.toString(),
      );
    }

    // Default unknown error
    return AiChatError(
      message: 'Something went wrong. Please try again.',
      type: AiErrorType.unknown,
      isRetryable: true,
      originalError: error.toString(),
    );
  }

  @override
  String toString() => message;
}

/// Represents the current state of a chat session
/// Single source of truth for all chat UI state
class ChatSessionState {
  final String chatId;
  final String? conversationId; // Firestore doc ID for persistence
  final List<AiMessage> messages;
  final ChatPhase phase;
  final String? errorMessage;
  final AiChatError? chatError; // Structured error for retry logic
  final List<SearchResult> searchResults;

  const ChatSessionState({
    required this.chatId,
    this.conversationId,
    this.messages = const [],
    this.phase = ChatPhase.idle,
    this.errorMessage,
    this.chatError,
    this.searchResults = const [],
  });

  // Convenience getters for backward compatibility
  bool get isStreaming => phase == ChatPhase.streaming;
  bool get isThinking => phase == ChatPhase.sending;
  String? get error => errorMessage ?? chatError?.message;
  bool get canRetry => chatError?.isRetryable == true;
  bool get hasError => phase == ChatPhase.error;

  ChatSessionState copyWith({
    String? chatId,
    String? conversationId,
    List<AiMessage>? messages,
    ChatPhase? phase,
    String? errorMessage,
    AiChatError? chatError,
    List<SearchResult>? searchResults,
    // Legacy parameters for backward compat
    bool? isStreaming,
    bool? isThinking,
    String? error,
  }) {
    // Handle legacy parameters
    ChatPhase newPhase = phase ?? this.phase;
    if (isStreaming == true) newPhase = ChatPhase.streaming;
    if (isThinking == true && phase == null) newPhase = ChatPhase.sending;
    if (isStreaming == false && isThinking == false && phase == null) {
      newPhase = ChatPhase.idle;
    }

    return ChatSessionState(
      chatId: chatId ?? this.chatId,
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      phase: newPhase,
      errorMessage: error ?? errorMessage,
      chatError: chatError ?? this.chatError,
      searchResults: searchResults ?? this.searchResults,
    );
  }

  /// Create a new state with a user message added
  ChatSessionState addUserMessage(AiMessage message) {
    return copyWith(
      messages: [...messages, message],
      phase: ChatPhase.sending,
    );
  }

  /// Create a new state with an AI message placeholder
  ChatSessionState addAiMessagePlaceholder(String messageId) {
    final placeholder = AiMessage(
      id: messageId,
      role: 'assistant',
      content: '',
      createdAt: DateTime.now(),
      pending: true,
    );
    return copyWith(
      messages: [...messages, placeholder],
      phase: ChatPhase.streaming,
    );
  }

  /// Update the streaming message content
  ChatSessionState updateStreamingContent(String messageId, String content) {
    final updatedMessages = messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(content: content);
      }
      return m;
    }).toList();
    return copyWith(messages: updatedMessages);
  }

  /// Finalize a streaming message
  ChatSessionState finalizeMessage(String messageId, String finalContent,
      {String? newId}) {
    final updatedMessages = messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(
          id: newId ?? m.id,
          content: finalContent,
          pending: false,
        );
      }
      return m;
    }).toList();
    return copyWith(
      messages: updatedMessages,
      phase: ChatPhase.idle,
    );
  }
}

/// Baba system user ID - this should be a consistent system user
const String HOLYCOW_USER_ID = 'holycow_system_user';
