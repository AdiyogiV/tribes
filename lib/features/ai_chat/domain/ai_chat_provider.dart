import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_service.dart';
import 'package:aurogram/shared/services/location_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ai_chat_models.dart';
import 'ai_chat_context_mixin.dart';
import 'ai_chat_persistence_mixin.dart';
import 'ai_chat_streaming_mixin.dart';
import 'ai_chat_voice_mixin.dart';

/// Improved AI Chat Provider with proper session isolation
/// Uses clean state machine pattern for predictable UI updates
///
/// Composed of focused mixins:
/// - [AiChatContextMixin] - Astrology context + chat source
/// - [AiChatPersistenceMixin] - Firestore persistence (save/load/clear conversations)
/// - [AiChatStreamingMixin] - SSE streaming (single source of truth)
/// - [AiChatVoiceMixin] - Voice messages (routed through the backend SSE path)
class AiChatProvider extends ChangeNotifier
    with
        AiChatContextMixin,
        AiChatPersistenceMixin,
        AiChatStreamingMixin,
        AiChatVoiceMixin {
  final AiChatService _service;
  final LocationService _locationService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================================================================
  // STATE - Single source of truth
  // =========================================================================
  ChatSessionState _currentSession;

  // Feature flags
  bool _isDeepResearchMode = false;

  AiChatProvider({
    required AiChatService service,
    required LocationService locationService,
  })  : _service = service,
        _locationService = locationService,
        _currentSession = ChatSessionState(
          chatId: 'chat-${DateTime.now().millisecondsSinceEpoch}',
        );

  // =========================================================================
  // Mixin bridge — expose internal state to mixins
  // =========================================================================
  @override
  ChatSessionState get currentSession => _currentSession;

  @override
  set currentSessionDirect(ChatSessionState value) {
    _currentSession = value;
  }

  @override
  void transition(ChatSessionState newState) {
    _currentSession = newState;
    notifyListeners();
  }

  @override
  void updateSession(ChatSessionState newSession) {
    _currentSession = newSession;
    notifyListeners();
  }

  @override
  AiChatService get service => _service;

  @override
  LocationService get locationService => _locationService;

  @override
  FirebaseFirestore get firestore => _firestore;

  @override
  void cleanupCurrentSession() {
    // Cancel Firestore listener
    firestoreSubscription?.cancel();
    firestoreSubscription = null;
  }

  // =========================================================================
  // GETTERS - Public API for UI
  // =========================================================================
  List<AiMessage> get messages => _currentSession.messages;
  ChatPhase get phase => _currentSession.phase;
  bool get isStreaming => _currentSession.isStreaming;
  bool get isThinking => _currentSession.isThinking;
  bool get isIdle => _currentSession.phase == ChatPhase.idle;
  bool get hasError => _currentSession.phase == ChatPhase.error;
  String? get error => _currentSession.error;
  String get chatId => _currentSession.chatId;
  String? get conversationId => _currentSession.conversationId;
  bool get isDeepResearchMode => _isDeepResearchMode;

  // =========================================================================
  // SESSION MANAGEMENT
  // =========================================================================

  /// Toggle Deep Research mode
  void toggleDeepResearchMode() {
    _isDeepResearchMode = !_isDeepResearchMode;
    notifyListeners();
  }

  /// Start a new chat session (prevents mixing)
  void startNewSession() {
    AppLogger.i('Starting new chat session');
    cleanupCurrentSession();
    invalidatePromptCache();

    // Clear the conversation ID so a new one is created for the new session
    clearConversationId();

    // Each new session gets a unique chat ID for separate conversation storage
    _currentSession = ChatSessionState(
      chatId: 'chat-${DateTime.now().millisecondsSinceEpoch}',
    );

    notifyListeners();
  }

  // =========================================================================
  // GREETING MESSAGES
  // =========================================================================

  /// Add a welcome greeting message from the AI
  /// Called when user opens Baba with no active conversation
  /// [userName] is optional - if null, generic greetings are used
  void addWelcomeGreeting(String? userName) {
    // Only add greeting if there are no messages
    if (_currentSession.messages.isNotEmpty) return;

    // Collection of greeting messages - randomly selected
    final List<String> greetings;

    if (userName != null && userName.isNotEmpty) {
      // Personalized greetings with name - short and welcoming
      greetings = [
        "Namaskaram $userName! What's on your mind?",
        "Namaste $userName! can I help you with anything?",
        "Namaskar $userName! How are you feeling today?",
        "Namaste $userName! How's it going?",
        "Namaste $userName! What's up?",
      ];
    } else {
      // Generic greetings without name - short and welcoming
      greetings = [
        "Namaskaram there! What's on your mind?",
        "Namaste! How can I help?",
        "Namaste! Ask me anything.",
        "Namaste! What brings you here?",
        "Namaskar! What's up?",
      ];
    }

    // Pick a random greeting
    final randomIndex = DateTime.now().millisecond % greetings.length;
    final selectedGreeting = greetings[randomIndex];

    final greeting = AiMessage(
      id: 'greeting-${DateTime.now().millisecondsSinceEpoch}',
      role: 'assistant',
      content: selectedGreeting,
      createdAt: DateTime.now(),
    );

    _currentSession = _currentSession.copyWith(
      messages: [greeting],
    );

    notifyListeners();
  }

  /// Clear greeting message (used when starting fresh)
  void clearGreeting() {
    // Only clear if the only message is a greeting
    if (_currentSession.messages.length == 1 &&
        _currentSession.messages.first.id.startsWith('greeting-')) {
      _currentSession = _currentSession.copyWith(messages: []);
      notifyListeners();
    }
  }

  /// Check if current session only has a greeting (no real conversation)
  bool get hasOnlyGreeting {
    return _currentSession.messages.length == 1 &&
        _currentSession.messages.first.id.startsWith('greeting-');
  }

  // =========================================================================
  // STOP / RETRY / ERROR HANDLING
  // =========================================================================

  /// Stop the current streaming response immediately
  /// Keeps exact content at the point of stopping - no markers, no cleanup
  /// User can seamlessly continue the conversation after stopping
  void stopStreaming() {
    if (!_currentSession.isStreaming && !_currentSession.isThinking) {
      AppLogger.w('No active streaming to stop');
      return;
    }

    AppLogger.i('🛑 Stopping AI response - keeping current content');

    // Cancel Firestore subscription immediately
    firestoreSubscription?.cancel();
    firestoreSubscription = null;

    // Get the exact content we have right now
    final currentContent = streamingBuffer?.toString() ?? '';

    // Build messages list - remove streaming/pending messages
    final msgs = List<AiMessage>.from(_currentSession.messages)
      ..removeWhere((m) => m.id.startsWith('streaming-') || m.pending);

    // Keep whatever text we streamed so far as a finalized message.
    if (currentContent.isNotEmpty) {
      final partialMessage = AiMessage(
        id: currentAssistantMessageId ??
            'ai-${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: currentContent,
        createdAt: DateTime.now(),
        pending: false,
      );
      msgs.add(partialMessage);
    }

    // Clear streaming state
    streamingBuffer = null;
    streamingMessageId = null;
    currentAssistantMessageId = null;
    currentRequestId = null;
    currentFirestorePath = null;
    hasFinalizedCurrentStream = true;

    // Update session - ready for user to continue chatting
    updateSession(_currentSession.copyWith(
      messages: msgs,
      isStreaming: false,
      isThinking: false,
    ));

    // No client-side save: the backend keeps generating after a client stop and
    // is the sole writer of the durable dmConversations record.

    AppLogger.i('Stopped at current point - chat ready to continue');
  }

  // =========================================================================
  // SEND MESSAGE
  // =========================================================================

  /// Send a text message in the current session
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // CRITICAL: Wait for previous response to finish before sending new message
    if (_currentSession.isStreaming || _currentSession.isThinking) {
      AppLogger.w('Cannot send message - previous response still processing');
      return;
    }

    // Track for retry
    lastFailedMessageContent = text;
    lastFailedWasVoice = false;
    lastFailedAudioPath = null;

    final sessionId = _currentSession.chatId;
    AppLogger.i('Sending message in session: $sessionId');

    try {
      // Clear any previous errors
      updateSession(_currentSession.copyWith(error: null, chatError: null));

      // Get current messages and ensure previous assistant response is finalized
      // IMPORTANT: Create new list to avoid mutation issues
      final currentMessages = List<AiMessage>.from(_currentSession.messages)
        ..removeWhere((message) =>
            message.id.startsWith('streaming-') || message.pending);

      // Add user message
      final userMessage = AiMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        content: text.trim(),
        createdAt: DateTime.now(),
      );

      updateSession(_currentSession.copyWith(
        messages: [...currentMessages, userMessage],
      ));

      // Start AI response
      await processAiResponse(text, sessionId);
    } catch (e, stackTrace) {
      AppLogger.e('Error sending message: $e\n$stackTrace');
      updateSession(_currentSession.copyWith(
        error: 'Failed to send message: $e',
        isStreaming: false,
        isThinking: false,
      ));
    }
  }

  /// Retry the last failed message
  Future<void> retryLastMessage() async {
    final chatError = _currentSession.chatError;
    if (chatError == null || !chatError.isRetryable) {
      AppLogger.w('Cannot retry - no retryable error');
      return;
    }

    // Clear error state
    transition(_currentSession.copyWith(
      phase: ChatPhase.idle,
      chatError: null,
      errorMessage: null,
    ));

    // Retry based on what failed
    if (lastFailedWasVoice && lastFailedAudioPath != null) {
      await sendVoiceMessage(
        transcript: lastFailedMessageContent ?? '',
        localAudioPath: lastFailedAudioPath,
        durationInSeconds: 0, // Duration doesn't matter for retry
      );
    } else if (lastFailedMessageContent != null) {
      await sendMessage(lastFailedMessageContent!);
    }
  }

  /// Clear error state (user dismissed error)
  void clearError() {
    if (_currentSession.phase == ChatPhase.error) {
      transition(_currentSession.copyWith(
        phase: ChatPhase.idle,
        chatError: null,
        errorMessage: null,
      ));
    }
  }

  @override
  void dispose() {
    cleanupCurrentSession();
    super.dispose();
  }
}
