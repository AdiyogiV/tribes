import 'package:aurogram/features/ai_chat/domain/ai_chat_models.dart';

/// Abstract read-only interface for AI chat state.
///
/// Features outside `ai_chat/` should depend on this interface,
/// not the concrete [AiChatProvider]. This enables:
///   - Loose coupling between features
///   - Easier testing (mock this instead of the full provider)
///   - Clear boundary of what external features may observe
///
/// Only **read-only** properties are exposed here. Mutating methods
/// (sendMessage, startNewSession, etc.) belong to a separate action
/// interface or to the concrete provider, depending on your needs.
abstract class AiChatStateReader {
  // ---------------------------------------------------------------------------
  // Streaming / loading state
  // ---------------------------------------------------------------------------

  /// Whether the AI is currently streaming a response.
  bool get isStreaming;

  /// Whether the AI is in the "thinking" (sending) phase before streaming.
  bool get isThinking;

  /// Whether the chat is idle (not streaming, not thinking, no error).
  bool get isIdle;

  // ---------------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------------

  /// Whether the current session is in an error state.
  bool get hasError;

  /// Human-readable error message, if any.
  String? get error;

  // ---------------------------------------------------------------------------
  // Session metadata
  // ---------------------------------------------------------------------------

  /// The current chat phase (idle, sending, streaming, error).
  ChatPhase get phase;

  /// Unique ID of the current chat session.
  String get chatId;

  /// Firestore conversation document ID, if persisted.
  String? get conversationId;

  /// Whether "Deep Research" mode is enabled.
  bool get isDeepResearchMode;

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  /// The ordered list of messages in the current session.
  List<AiMessage> get messages;

  /// Whether the conversation only contains the initial greeting message.
  bool get hasOnlyGreeting;

  // ---------------------------------------------------------------------------
  // Full session (for search results, etc.)
  // ---------------------------------------------------------------------------

  /// The underlying session state object.
  ///
  /// External code currently accesses `currentSession.searchResults`.
  /// Prefer adding dedicated getters here over exposing the full object
  /// once usage stabilises.
  ChatSessionState get currentSession;

  // ---------------------------------------------------------------------------
  // Authentication (from persistence mixin)
  // ---------------------------------------------------------------------------

  /// Whether the current Firebase user is authenticated.
  bool get isUserAuthenticated;
}
