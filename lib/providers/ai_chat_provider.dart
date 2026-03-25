import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:aurogram/services/ai/ai_chat_service.dart';
import 'package:aurogram/services/ai/gemini_service.dart';
import 'package:aurogram/services/location_service.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/models/thought_process.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Represents a single AI chat message
class AiMessage {
  final String id;
  final String role; // user | assistant | system
  final String content;
  final DateTime createdAt;
  final bool pending;
  final List<SearchResult>? searchResults;
  final ThoughtProcess? thoughtProcess;
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
    this.thoughtProcess,
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
    ThoughtProcess? thoughtProcess,
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
      thoughtProcess: thoughtProcess ?? this.thoughtProcess,
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

/// HolyCow system user ID - this should be a consistent system user
const String HOLYCOW_USER_ID = 'holycow_system_user';

/// Improved AI Chat Provider with proper session isolation
/// Uses clean state machine pattern for predictable UI updates
class AiChatProvider extends ChangeNotifier {
  final AiChatService _service;
  final LocationService _locationService;
  final GeminiService _geminiService = GeminiService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================================================================
  // STATE - Single source of truth
  // =========================================================================
  ChatSessionState _currentSession;

  // Streaming-related state (consolidated for clarity)
  StringBuffer? _streamingBuffer;
  String? _streamingMessageId;
  bool _hasFinalizedCurrentStream = false;
  String? _currentRequestId;
  String? _currentFirestorePath;

  // Feature flags
  bool _isDeepResearchMode = false;

  // Context
  Map<String, dynamic>? _astrologyContext;
  String? _chatSource; // 'astrology' | 'wellness'

  // Cached system prompt from backend (once per session / context)
  String? _cachedSystemPrompt;
  String? _cachedPromptKey;

  /// Clear conversation ID (called when starting new session)
  void _clearConversationId() {
    _currentSession = _currentSession.copyWith(conversationId: null);
  }

  AiChatProvider({
    required AiChatService service,
    required LocationService locationService,
  })  : _service = service,
        _locationService = locationService,
        _currentSession = ChatSessionState(
          chatId: 'chat-${DateTime.now().millisecondsSinceEpoch}',
        ) {
    // Initialize Gemini via Firebase AI Logic (no API key needed!)
    _initializeGemini();
  }

  /// Initialize Gemini service via Firebase AI Logic
  Future<void> _initializeGemini() async {
    try {
      // Firebase AI Logic handles auth automatically via Firebase
      await _geminiService.initialize();
      AppLogger.i('Gemini service initialized via Vertex AI',
          category: LogCategory.voice);
    } catch (e) {
      AppLogger.e('Failed to initialize Gemini',
          category: LogCategory.voice, error: e);
    }
  }

  // =========================================================================
  // GETTERS - Public API for UI
  // =========================================================================
  ChatSessionState get currentSession => _currentSession;
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
  // STATE TRANSITIONS - Clean state machine updates
  // =========================================================================

  /// Central state transition method - all state changes go through here
  void _transition(ChatSessionState newState) {
    _currentSession = newState;
    notifyListeners();
  }

  /// Update session state (legacy method for backward compatibility)
  void _updateSession(ChatSessionState newSession) {
    _currentSession = newSession;
    notifyListeners();
  }

  /// Toggle Deep Research mode
  void toggleDeepResearchMode() {
    _isDeepResearchMode = !_isDeepResearchMode;
    notifyListeners();
  }

  /// Get astrology context
  Map<String, dynamic>? get astrologyContext => _astrologyContext;

  /// Set astrology context for astro chat
  void setAstrologyContext(Map<String, dynamic> context) {
    _astrologyContext = context;
    _invalidatePromptCache();
    notifyListeners();
  }

  /// Clear astrology context when leaving astro chat
  void clearAstrologyContext() {
    _astrologyContext = null;
    _invalidatePromptCache();
    notifyListeners();
  }

  /// Set chat source for backend (astrology vs wellness)
  void setChatSource(String? value) {
    _chatSource = value;
    _invalidatePromptCache();
    notifyListeners();
  }

  /// Clear chat source when leaving chat page
  void clearChatSource() {
    _chatSource = null;
    _invalidatePromptCache();
    notifyListeners();
  }

  void _invalidatePromptCache() {
    _cachedSystemPrompt = null;
    _cachedPromptKey = null;
  }

  /// Start a new chat session (prevents mixing)
  void startNewSession() {
    AppLogger.i('Starting new chat session');
    _cleanupCurrentSession();
    _lastProcessedStepCount = 0;
    _invalidatePromptCache();

    // Clear the conversation ID so a new one is created for the new session
    _clearConversationId();

    // Each new session gets a unique chat ID for separate conversation storage
    _currentSession = ChatSessionState(
      chatId: 'chat-${DateTime.now().millisecondsSinceEpoch}',
    );

    notifyListeners();
  }

  /// Fetch system prompt from backend once per session/context; cache and return.
  Future<String?> _getChatSystemPrompt(String? location) async {
    final key =
        '${_chatSource ?? "astrology"}|${_astrologyContext != null}|$location';
    if (_cachedPromptKey == key && _cachedSystemPrompt != null) {
      return _cachedSystemPrompt;
    }
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('getChatPromptConfig');
      final result = await callable.call(<String, dynamic>{
        'chatSource': _chatSource ?? 'astrology',
        'astrologyContext': _astrologyContext,
        'userLocation': location,
        'isVoice': true,
      });
      final data = result.data as Map<String, dynamic>?;
      final prompt = data?['systemPrompt'] as String?;
      if (prompt != null && prompt.isNotEmpty) {
        _cachedSystemPrompt = prompt;
        _cachedPromptKey = key;
        return prompt;
      }
    } catch (e) {
      AppLogger.e('getChatPromptConfig failed',
          category: LogCategory.voice, error: e);
    }
    return null;
  }

  /// Add a welcome greeting message from the AI
  /// Called when user opens HolyCow with no active conversation
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
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;

    // Get the exact content we have right now
    final currentContent = _streamingBuffer?.toString() ?? '';

    // Find the streaming message to preserve its thought process
    final streamingMessage = _currentSession.messages
        .where((m) => m.id == _streamingMessageId)
        .firstOrNull;

    // Preserve thought process - deep copy all steps we have so far
    ThoughtProcess? preservedThoughts;
    if (streamingMessage?.thoughtProcess != null) {
      final tp = streamingMessage!.thoughtProcess!;
      // Create a deep copy of steps to prevent any reference issues
      final copiedSteps = tp.steps
          .map((step) => ThoughtStep(
                id: step.id,
                type: step.type,
                message: step.message,
                query: step.query,
                results: step.results != null ? List.from(step.results!) : null,
                metadata:
                    step.metadata != null ? Map.from(step.metadata!) : null,
                timestamp: step.timestamp,
                sequence: step.sequence,
                isComplete: true, // Mark each step as complete
              ))
          .toList();

      // Mark as complete so it renders properly (not as "thinking...")
      preservedThoughts = ThoughtProcess(
        id: tp.id,
        steps: copiedSteps,
        isComplete: true, // Mark complete so UI shows it properly
        isExpanded: tp.isExpanded,
        startedAt: tp.startedAt,
        completedAt: DateTime.now(),
      );
      AppLogger.i('Preserving ${copiedSteps.length} thought steps');
    }

    // Build messages list - remove streaming/pending messages
    final messages = List<AiMessage>.from(_currentSession.messages)
      ..removeWhere((m) => m.id.startsWith('streaming-') || m.pending);

    // Always create a message to preserve thoughts, even if no text content
    // This ensures thought steps are visible even if stopped early
    final hasContent = currentContent.isNotEmpty;
    final hasThoughts =
        preservedThoughts != null && preservedThoughts.steps.isNotEmpty;

    if (hasContent || hasThoughts) {
      final partialMessage = AiMessage(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: hasContent ? currentContent : '', // Keep empty if no text yet
        createdAt: DateTime.now(),
        pending: false,
        thoughtProcess: preservedThoughts,
      );
      messages.add(partialMessage);
    }

    // Clear streaming state
    _streamingBuffer = null;
    _streamingMessageId = null;
    _currentRequestId = null;
    _currentFirestorePath = null;
    _hasFinalizedCurrentStream = true;
    _lastProcessedStepCount = 0;

    // Update session - ready for user to continue chatting
    _updateSession(_currentSession.copyWith(
      messages: messages,
      isStreaming: false,
      isThinking: false,
    ));

    // Save conversation if we have any content or thoughts
    if (hasContent || hasThoughts) {
      _saveConversationAsDM();
    }

    AppLogger.i('Stopped at current point - chat ready to continue');
  }

  /// Ensure a conversation exists for the current session
  /// Returns the conversation ID, or null if user is not authenticated
  /// Uses state's conversationId to avoid creating duplicates
  Future<String?> _ensureConversation() async {
    // Check if we already have a conversation ID in state
    if (_currentSession.conversationId != null) {
      return _currentSession.conversationId;
    }

    // Handle loaded conversations - extract ID from chatId
    if (_currentSession.chatId.startsWith('loaded-')) {
      final loadedId = _currentSession.chatId.substring('loaded-'.length);
      _transition(_currentSession.copyWith(conversationId: loadedId));
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

      await _firestore.collection('dmConversations').doc(conversationId).set({
        'participants': [currentUser.uid, HOLYCOW_USER_ID],
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'isAiConversation': true,
      });

      // Store in state for reuse
      _transition(_currentSession.copyWith(conversationId: conversationId));

      AppLogger.i('Created new AI conversation: $conversationId');
      return conversationId;
    } catch (e) {
      AppLogger.e('Error creating conversation: $e');
      return null;
    }
  }

  /// Save current AI conversation as DM messages
  /// Only saves NEW messages (those without Firestore IDs)
  Future<void> _saveConversationAsDM() async {
    if (_currentSession.messages.length < 2) {
      return; // Need at least user + AI message
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return; // Skip for unauthenticated users
    }

    try {
      // Ensure we have a conversation ID
      final conversationId = await _ensureConversation();
      if (conversationId == null) {
        return;
      }

      // Only save messages without Firestore IDs (new messages)
      // Messages with IDs like 'ai_chat_*' or 'dm_*' are already saved
      final messagesToSave = _currentSession.messages
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

      final batch = _firestore.batch();

      for (final message in messagesToSave) {
        final messageRef = _firestore
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
        final lastMessage = _currentSession.messages.last;
        final conversationRef =
            _firestore.collection('dmConversations').doc(conversationId);

        // Find the first user message for conversation title
        final firstUserMessage = _currentSession.messages
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
          // Use set with merge or setField only if not exists
          // For simplicity, we'll always set it - the first save will have the right value
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

  /// Check if user is authenticated
  bool get isUserAuthenticated => FirebaseAuth.instance.currentUser != null;

  /// Get recent AI conversations (DM conversations with HolyCow)
  Stream<List<DmConversation>> getRecentAiConversations({int limit = 10}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Return empty stream for unauthenticated users
      return Stream.value([]);
    }

    return _firestore
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

  /// Send a text message in the current session
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // CRITICAL: Wait for previous response to finish before sending new message
    if (_currentSession.isStreaming || _currentSession.isThinking) {
      AppLogger.w('Cannot send message - previous response still processing');
      return;
    }

    // Track for retry
    _lastFailedMessageContent = text;
    _lastFailedWasVoice = false;
    _lastFailedAudioPath = null;

    final sessionId = _currentSession.chatId;
    AppLogger.i('Sending message in session: $sessionId');

    try {
      // Clear any previous errors
      _updateSession(_currentSession.copyWith(error: null, chatError: null));

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

      _updateSession(_currentSession.copyWith(
        messages: [...currentMessages, userMessage],
      ));

      // Start AI response
      await _processAiResponse(text, sessionId);
    } catch (e, stackTrace) {
      AppLogger.e('Error sending message: $e\n$stackTrace');
      _updateSession(_currentSession.copyWith(
        error: 'Failed to send message: $e',
        isStreaming: false,
        isThinking: false,
      ));
    }
  }

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
    _lastFailedWasVoice = true;
    _lastFailedAudioPath = localAudioPath;
    _lastFailedMessageContent = transcript;

    AppLogger.i('🎙️ Received voice message',
        category: LogCategory.voice,
        data: {
          'transcript': transcript,
          'transcriptLength': transcript.length,
          'hasLocalAudio': localAudioPath != null,
          'hasAudioUrl': audioUrl != null,
          'duration': durationInSeconds,
          'hasAstroContext': _astrologyContext != null,
        });

    // Need either audio or transcript
    if (transcript.trim().isEmpty &&
        localAudioPath == null &&
        audioUrl == null) {
      AppLogger.w('⚠️ Voice message rejected: no content',
          category: LogCategory.voice);
      return;
    }

    final sessionId = _currentSession.chatId;

    try {
      // Clear any previous errors
      _updateSession(_currentSession.copyWith(error: null));

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

      _updateSession(_currentSession.copyWith(
        messages: [..._currentSession.messages, userMessage],
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
        await _processAiResponse(
            transcript.isNotEmpty ? transcript : 'Voice message', sessionId,
            audioUrl: audioUrl);
      } else {
        // No audio, just send transcript
        await _processAiResponse(transcript, sessionId);
      }
    } catch (e) {
      AppLogger.e('Error sending voice message: $e');
      _updateSession(_currentSession.copyWith(
        error: 'Failed to send voice message: $e',
        isStreaming: false,
        isThinking: false,
      ));
    }
  }

  /// Update the most recent user voice message with the uploaded audio URL
  /// This is called after background upload completes
  void updateLastVoiceMessageUrl(String audioUrl) {
    final messages = List<AiMessage>.from(_currentSession.messages);

    // Find the last user voice message without an audioUrl
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.role == 'user' &&
          msg.isVoiceMessage &&
          (msg.audioUrl == null || msg.audioUrl!.isEmpty)) {
        messages[i] = msg.copyWith(audioUrl: audioUrl);
        _updateSession(_currentSession.copyWith(messages: messages));
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
    final messages = List<AiMessage>.from(_currentSession.messages);

    // Find the last user voice message without an audioUrl
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.role == 'user' &&
          msg.isVoiceMessage &&
          (msg.audioUrl == null || msg.audioUrl!.isEmpty)) {
        // Use "local" as marker - UI will recognize this as "no upload needed"
        messages[i] = msg.copyWith(audioUrl: 'local');
        _updateSession(_currentSession.copyWith(messages: messages));
        AppLogger.d('📍 Marked voice message as local-only',
            category: LogCategory.voice, data: {'messageId': msg.id});
        break;
      }
    }
  }

  /// Process audio directly with Gemini via Firebase AI Logic
  /// This is faster than going through the backend (no upload/download)
  Future<void> _processAudioWithGemini({
    required String localAudioPath,
    required String sessionId,
    String? transcript,
  }) async {
    // Verify we're still in the same session
    if (_currentSession.chatId != sessionId) {
      AppLogger.w('Session changed during Gemini processing, aborting');
      return;
    }

    try {
      // Create placeholder streaming message
      // For voice messages, we skip the complex thought process and just show typing indicator
      final streamingMessageId =
          'streaming-${DateTime.now().millisecondsSinceEpoch}';
      final placeholderMessage = AiMessage(
        id: streamingMessageId,
        role: 'assistant',
        content: '',
        createdAt: DateTime.now(),
        pending: true,
        // No thoughtProcess for voice - just use typing indicator (simpler UX)
      );

      _updateSession(_currentSession.copyWith(
        messages: [..._currentSession.messages, placeholderMessage],
        isThinking: true,
        isStreaming: true,
      ));

      _streamingMessageId = streamingMessageId;
      _streamingBuffer = StringBuffer();

      // Get location if available
      String? location;
      try {
        location = await _locationService.getCurrentLocationString();
      } catch (e) {
        // Location is optional
      }

      // Build chat history for context (exclude current voice message and streaming)
      // We exclude the most recent user message since we're sending audio directly
      final allMessages = _currentSession.messages
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
        'totalMessages': _currentSession.messages.length,
        'filteredMessages': allMessages.length,
        'historyMessages': historyMessages.length,
        'historyPreview': historyMessages
            .take(3)
            .map((m) =>
                '${m.role}: ${m.content.length > 50 ? "${m.content.substring(0, 50)}..." : m.content}')
            .toList(),
      });

      // Fetch system prompt from backend once per session/context (fallback: GeminiService builds locally)
      final systemPrompt = await _getChatSystemPrompt(location);

      // Process audio with Gemini (streaming response)
      final responseStream = _geminiService.sendAudioMessage(
        audioPath: localAudioPath,
        astrologyContext: _astrologyContext ?? {},
        chatHistory: chatHistory,
        userLocation: location,
        systemPrompt: systemPrompt,
      );

      // Stream the response
      await for (final chunk in responseStream) {
        // Skip completion marker
        if (chunk.isComplete) continue;

        // Check if session changed
        if (_currentSession.chatId != sessionId) {
          AppLogger.w('Session changed during Gemini streaming, aborting');
          break;
        }

        _streamingBuffer!.write(chunk.text);

        // Update UI with streamed content
        final currentContent = _streamingBuffer.toString();
        final messages = List<AiMessage>.from(_currentSession.messages);
        final streamingIndex =
            messages.indexWhere((m) => m.id == streamingMessageId);

        if (streamingIndex != -1) {
          messages[streamingIndex] = messages[streamingIndex].copyWith(
            content: currentContent,
          );
          _updateSession(_currentSession.copyWith(
            messages: messages,
            isThinking: false, // Stop thinking once we have content
          ));
        }
      }

      // Finalize the message - IMPORTANT: Change ID from streaming-* to msg-*
      // so it gets included in chat history for future messages
      final finalContent = _streamingBuffer?.toString() ?? '';
      final messages = List<AiMessage>.from(_currentSession.messages);
      final streamingIndex =
          messages.indexWhere((m) => m.id == streamingMessageId);

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

      _updateSession(_currentSession.copyWith(
        messages: messages,
        isStreaming: false,
        isThinking: false,
      ));

      _streamingBuffer = null;
      _streamingMessageId = null;

      AppLogger.i('🤖 Gemini audio response complete',
          category: LogCategory.voice,
          data: {'responseLength': finalContent.length});

      // Save conversation to Firestore for recent chats
      _saveConversationAsDM();
    } catch (e) {
      AppLogger.e('Error processing audio with Gemini: $e',
          category: LogCategory.voice);

      // Update session with error
      _updateSession(_currentSession.copyWith(
        error: 'Failed to process voice message',
        isStreaming: false,
        isThinking: false,
      ));
    }
  }

  /// Process AI response with session isolation
  /// [audioUrl] is optional - if provided, backend will use Gemini for audio processing
  Future<void> _processAiResponse(String userText, String sessionId,
      {String? audioUrl}) async {
    // Verify we're still in the same session
    if (_currentSession.chatId != sessionId) {
      AppLogger.w('Session changed during processing, aborting');
      return;
    }

    try {
      // Clean up any existing streaming state
      _firestoreSubscription?.cancel();
      _firestoreSubscription = null;
      _currentFirestorePath = null;

      // Reset streaming state
      _streamingBuffer = null;
      _streamingMessageId = null;
      _hasFinalizedCurrentStream = false;
      _lastProcessedStepCount = 0;
      _currentRequestId = 'req-${DateTime.now().millisecondsSinceEpoch}';

      // Create placeholder streaming message WITH thought process attached
      // SINGLE SOURCE OF TRUTH: thoughts live on the message, not session
      final streamingMessageId =
          'streaming-${DateTime.now().millisecondsSinceEpoch}';
      final placeholderMessage = AiMessage(
        id: streamingMessageId,
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

      _updateSession(_currentSession.copyWith(
        messages: [..._currentSession.messages, placeholderMessage],
        isThinking: true,
        isStreaming: true,
      ));

      _streamingMessageId = streamingMessageId;

      AppLogger.i('Starting AI request: $_currentRequestId');

      // Get conversation messages (excluding streaming placeholders)
      final allMessages = List<AiMessage>.from(_currentSession.messages);
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
      _updateSession(_currentSession.copyWith(
        searchResults: const [],
      ));

      // Get location if available
      String? location;
      try {
        location = await _locationService.getCurrentLocationString();
      } catch (e) {
        // Location is optional, continue without it
      }

      // Verify session hasn't changed
      if (_currentSession.chatId != sessionId) {
        AppLogger.w('Session changed during setup, aborting');
        return;
      }

      _lastProcessedStepCount = 0;
      _updateSession(_currentSession.copyWith(isStreaming: true));

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

      final stream = _service.streamChat(
        messages: deduplicatedMessages,
        context: {
          if (location != null) 'location': location,
          'chatId': sessionId,
          if (_astrologyContext != null) 'astrologyContext': _astrologyContext,
          if (_chatSource != null) 'chatSource': _chatSource,
          if (audioUrl != null)
            'audioUrl': audioUrl, // For Gemini audio processing
        },
      );

      // CRITICAL: Capture the request ID at the start of this stream
      // This allows us to detect if this request was stopped/superseded
      final thisRequestId = _currentRequestId;

      await for (final event in stream) {
        // CRITICAL: Check if THIS request is still the active one
        // If _currentRequestId changed (user stopped or sent new message), abort this stream
        if (_currentRequestId != thisRequestId) {
          AppLogger.i(
              'Request $thisRequestId superseded by $_currentRequestId, stopping old stream');
          break;
        }

        // Check session on each event
        if (_currentSession.chatId != sessionId) {
          AppLogger.w('Session changed during streaming, aborting');
          _firestoreSubscription?.cancel();
          _firestoreSubscription = null;
          return;
        }

        // Check if already finalized (user clicked stop)
        if (_hasFinalizedCurrentStream) {
          AppLogger.i('Stream already finalized, breaking out');
          break;
        }

        final type = event['event'];

        if (type == 'session') {
          final chatId = event['chatId'] as String?;
          final firestorePath = event['firestorePath'] as String?;
          if (chatId != null && firestorePath != null) {
            _currentFirestorePath = firestorePath;
            // Listen for all users (including logged out) - Firestore rules allow public read
            // This enables thought steps streaming for guest users
            _listenToFirestoreUpdates(firestorePath, sessionId, thisRequestId!);
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
          final bufferText = _streamingBuffer?.toString() ?? '';

          // Use SSE content if available, otherwise use accumulated buffer
          final resolvedContent = finalText.isNotEmpty ? finalText : bufferText;

          AppLogger.i('SSE complete received for request: $thisRequestId, '
              'sseContent: ${finalText.length}, buffer: ${bufferText.length}, '
              'resolved: ${resolvedContent.length}');

          if (_currentRequestId == thisRequestId &&
              !_hasFinalizedCurrentStream) {
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
          if (_streamingBuffer != null && _streamingBuffer!.isNotEmpty) {
            AppLogger.w(
                'Backend error but we have partial content, saving: $error');
            if (_currentRequestId == thisRequestId &&
                !_hasFinalizedCurrentStream) {
              _finalizeStreamingResponse('', sessionId);
            }
          } else {
            throw Exception(error);
          }
        }
      }

      // If stream ended without 'complete' event, try to finalize from buffer
      // Only if THIS request is still active
      if (_currentRequestId == thisRequestId && !_hasFinalizedCurrentStream) {
        AppLogger.w(
            'SSE stream ended without complete event, finalizing from buffer');
        _finalizeStreamingResponse('', sessionId);
      }

      if (_currentSession.chatId != sessionId) {
        AppLogger.w('Session changed after streaming');
        return;
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error in AI response: $e\n$stackTrace');
      _handleResponseError(e, sessionId);
    }
  }

  /// Listen to Firestore for real-time AI processing updates
  StreamSubscription<DocumentSnapshot>? _firestoreSubscription;
  int _lastProcessedStepCount = 0;

  void _listenToFirestoreUpdates(
      String firestorePath, String sessionId, String requestId) {
    // Cancel any existing subscription
    _firestoreSubscription?.cancel();
    _lastProcessedStepCount = 0;

    // CRITICAL: Skip the initial snapshot if it's from a previous request
    // Firestore snapshots() fires immediately with current state, which might be
    // the completed state from the previous request if both use the same document
    bool isFirstSnapshot = true;

    // Listen to the Firestore document
    _firestoreSubscription = _firestore.doc(firestorePath).snapshots().listen(
      (snapshot) {
        // Verify this update is for the current request
        if (_currentRequestId != requestId ||
            _currentFirestorePath != firestorePath) {
          AppLogger.w(
              '⚠️ Firestore update ignored - request ID or path mismatch');
          AppLogger.w(
              '  Current request ID: $_currentRequestId, Expected: $requestId');
          AppLogger.w(
              '  Current path: $_currentFirestorePath, Expected: $firestorePath');
          _firestoreSubscription?.cancel();
          return;
        }

        if (_currentSession.chatId != sessionId) {
          _firestoreSubscription?.cancel();
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
            _lastProcessedStepCount = 0;
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
          // Don't call _handleResponseError for permission errors - chat can still work via SSE
          _firestoreSubscription?.cancel();
          _firestoreSubscription = null;
          return;
        }
        AppLogger.e('Firestore listener error: $error');
        _handleResponseError(error, sessionId);
      },
    );
  }

  /// Handle real-time Firestore updates
  /// SIMPLIFIED: Updates the streaming message's thoughtProcess directly
  void _handleFirestoreUpdate(
      Map<String, dynamic> data, String sessionId, String firestorePath) {
    if (_currentSession.chatId != sessionId) return;
    if (_currentFirestorePath != firestorePath) return;

    try {
      final status = data['status'] as String?;
      final thoughtStepsData = data['thoughtSteps'] as List<dynamic>?;
      final responseText = data['response'] as String?;
      final searchResultsData = data['searchResults'] as Map<String, dynamic>?;

      // Find the streaming message
      final streamingIndex = _currentSession.messages
          .indexWhere((m) => m.id == _streamingMessageId);

      if (streamingIndex == -1) return;

      final streamingMessage = _currentSession.messages[streamingIndex];

      // CRITICAL: Detect backend reset (step count decreased = new request started)
      // This happens when Firestore has stale data from previous request
      if (thoughtStepsData != null &&
          thoughtStepsData.length < _lastProcessedStepCount) {
        _lastProcessedStepCount = 0;

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
        final clearedMessages = List<AiMessage>.from(_currentSession.messages);
        clearedMessages[streamingIndex] = clearedMessage;
        _updateSession(_currentSession.copyWith(messages: clearedMessages));

        // Re-fetch the message after clearing
        // (the streamingIndex should still be valid, message was just updated)
      }

      // Process new thought steps - update the MESSAGE's thoughtProcess
      // Re-fetch streaming message in case it was just cleared above
      final currentStreamingMessage = _currentSession.messages[streamingIndex];
      if (thoughtStepsData != null &&
          thoughtStepsData.length > _lastProcessedStepCount) {
        final newStepsData = thoughtStepsData.sublist(_lastProcessedStepCount);
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
              List<AiMessage>.from(_currentSession.messages);
          updatedMessages[streamingIndex] = updatedMessage;

          _updateSession(_currentSession.copyWith(
            messages: updatedMessages,
            isThinking: status != 'completed',
          ));

          _lastProcessedStepCount = thoughtStepsData.length;
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
          _updateSession(
              _currentSession.copyWith(searchResults: searchResults));
        }
      }

      // NOTE: We do NOT handle streamText from Firestore anymore.
      // SSE 'token' events are the single source of truth for streaming text.
      // This eliminates race conditions between SSE and Firestore.

      // Handle completion - Firestore 'completed' is only a backup if SSE failed
      // SSE 'complete' event is authoritative and should have already finalized
      if (status == 'completed') {
        // Mark thoughts complete
        _markThoughtsComplete(sessionId);

        // Only finalize from Firestore if SSE didn't provide content
        // This handles edge cases where SSE connection dropped
        if (!_hasFinalizedCurrentStream &&
            responseText != null &&
            responseText.isNotEmpty) {
          AppLogger.i(
              'Firestore completing response (SSE backup) - length: ${responseText.length}');
          _finalizeStreamingResponse(responseText, sessionId);
        }

        // Cleanup listener - we're done
        _firestoreSubscription?.cancel();
        _firestoreSubscription = null;
      } else if (status == 'failed') {
        final error = data['error'] as String? ?? 'Unknown error';
        AppLogger.e('AI processing failed: $error');
        _handleResponseError(Exception(error), sessionId);
        _firestoreSubscription?.cancel();
        _firestoreSubscription = null;
      }
    } catch (e) {
      AppLogger.e('Error handling Firestore update: $e');
    }
  }

  /// Mark thought process as complete on the streaming message
  void _markThoughtsComplete(String sessionId) {
    if (_currentSession.chatId != sessionId) return;
    if (_streamingMessageId == null) return;

    final streamingIndex =
        _currentSession.messages.indexWhere((m) => m.id == _streamingMessageId);
    if (streamingIndex == -1) return;

    final streamingMessage = _currentSession.messages[streamingIndex];
    if (streamingMessage.thoughtProcess == null) return;

    final completedThoughts = streamingMessage.thoughtProcess!.complete();
    final updatedMessage = streamingMessage.copyWith(
      thoughtProcess: completedThoughts,
    );

    final updatedMessages = List<AiMessage>.from(_currentSession.messages);
    updatedMessages[streamingIndex] = updatedMessage;

    _updateSession(_currentSession.copyWith(
      messages: updatedMessages,
      isThinking: false,
    ));
  }

  /// Handle response errors with structured error types
  void _handleResponseError(dynamic error, String sessionId) {
    if (_currentSession.chatId != sessionId) return;

    final chatError = AiChatError.fromException(error);
    AppLogger.e('AI response error: ${chatError.message}',
        category: LogCategory.network,
        data: {
          'type': chatError.type.name,
          'isRetryable': chatError.isRetryable,
          'originalError': chatError.originalError,
        });

    _transition(_currentSession.copyWith(
      phase: ChatPhase.error,
      chatError: chatError,
      errorMessage: chatError.message,
    ));
  }

  /// Track the last failed message for retry
  String? _lastFailedMessageContent;
  bool _lastFailedWasVoice = false;
  String? _lastFailedAudioPath;

  /// Retry the last failed message
  Future<void> retryLastMessage() async {
    final error = _currentSession.chatError;
    if (error == null || !error.isRetryable) {
      AppLogger.w('Cannot retry - no retryable error');
      return;
    }

    // Clear error state
    _transition(_currentSession.copyWith(
      phase: ChatPhase.idle,
      chatError: null,
      errorMessage: null,
    ));

    // Retry based on what failed
    if (_lastFailedWasVoice && _lastFailedAudioPath != null) {
      await sendVoiceMessage(
        transcript: _lastFailedMessageContent ?? '',
        localAudioPath: _lastFailedAudioPath,
        durationInSeconds: 0, // Duration doesn't matter for retry
      );
    } else if (_lastFailedMessageContent != null) {
      await sendMessage(_lastFailedMessageContent!);
    }
  }

  /// Clear error state (user dismissed error)
  void clearError() {
    if (_currentSession.phase == ChatPhase.error) {
      _transition(_currentSession.copyWith(
        phase: ChatPhase.idle,
        chatError: null,
        errorMessage: null,
      ));
    }
  }

  /// Load a specific AI conversation from DM history
  Future<void> loadConversation(String conversationId) async {
    try {
      AppLogger.i('Loading AI conversation: $conversationId');
      _cleanupCurrentSession();

      // Clear the stored conversation ID - loaded conversations use their own ID
      // via the 'loaded-' prefix in chatId
      _clearConversationId();

      // Get messages from the DM conversation
      final messagesSnapshot = await _firestore
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
      _currentSession = ChatSessionState(
        chatId: 'loaded-$conversationId',
        messages: aiMessages,
      );

      notifyListeners();
      AppLogger.i(
          'Loaded ${aiMessages.length} messages from conversation: $conversationId');
    } catch (e) {
      AppLogger.e('Error loading AI conversation: $e');
      _updateSession(_currentSession.copyWith(
        error: 'Failed to load conversation: $e',
      ));
    }
  }

  /// Clear chat history
  Future<void> clearHistory() async {
    AppLogger.i('Clearing chat history');
    _cleanupCurrentSession();
    _lastProcessedStepCount = 0;

    // Clear stored conversation ID so a new one is created for the fresh session
    _clearConversationId();

    _currentSession = ChatSessionState(
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
      final conversationsSnapshot = await _firestore
          .collection('dmConversations')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      // Filter for AI conversations and delete them
      final batch = _firestore.batch();
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
          final messagesSnapshot = await _firestore
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

  /// Cleanup current session resources
  void _cleanupCurrentSession() {
    // Cancel Firestore listener
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
  }

  void _handleStreamingUpdate(String partialText, String sessionId) {
    if (_currentSession.chatId != sessionId) return;
    if (partialText.isEmpty || _hasFinalizedCurrentStream) return;

    _streamingBuffer ??= StringBuffer();
    var buffer = _streamingBuffer!;
    final currentContent = buffer.toString();

    // Update buffer based on partial text
    if (partialText == currentContent) {
      // No change
    } else if (partialText.length > currentContent.length &&
        partialText.startsWith(currentContent)) {
      buffer = StringBuffer(partialText);
      _streamingBuffer = buffer;
    } else if (currentContent.isEmpty) {
      buffer.write(partialText);
    } else if (!currentContent.endsWith(partialText)) {
      buffer.write(partialText);
    }

    final updatedContent = buffer.toString();
    final existingMessages = List<AiMessage>.from(_currentSession.messages);
    final streamingIndex =
        existingMessages.lastIndexWhere((m) => m.id.startsWith('streaming-'));

    if (streamingIndex == -1) return;

    // PRESERVE the existing thoughtProcess when updating content
    final existingMessage = existingMessages[streamingIndex];
    final updatedMessage = existingMessage.copyWith(
      content: updatedContent,
      searchResults: _currentSession.searchResults.isNotEmpty
          ? _currentSession.searchResults
          : null,
    );

    existingMessages[streamingIndex] = updatedMessage;

    _updateSession(_currentSession.copyWith(
      messages: existingMessages,
      isStreaming: true,
      isThinking: true,
      error: null,
    ));
  }

  void _finalizeStreamingResponse(String finalText, String sessionId) {
    // Verify session and request
    if (_currentSession.chatId != sessionId) {
      _firestoreSubscription?.cancel();
      _firestoreSubscription = null;
      return;
    }

    if (_currentRequestId == null || _hasFinalizedCurrentStream) {
      return;
    }

    _hasFinalizedCurrentStream = true;

    // Get content from either finalText or streaming buffer
    final content =
        finalText.isNotEmpty ? finalText : (_streamingBuffer?.toString() ?? '');

    AppLogger.i('Finalizing response - length: ${content.length}, '
        'preview: "${content.length > 50 ? content.substring(0, 50) : content}..."');

    // Find the streaming message to get its thoughtProcess
    final streamingMessage = _currentSession.messages
        .where((m) => m.id == _streamingMessageId)
        .firstOrNull;

    // Build final messages list - remove streaming/pending messages
    final messages = List<AiMessage>.from(_currentSession.messages)
      ..removeWhere((m) => m.id.startsWith('streaming-') || m.pending);

    // Add final message - only if there's actual visible content
    if (content.trim().isNotEmpty) {
      final aiMessage = AiMessage(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: content,
        createdAt: DateTime.now(),
        pending: false,
        searchResults: _currentSession.searchResults.isNotEmpty
            ? _currentSession.searchResults
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
    _streamingBuffer = null;
    _streamingMessageId = null;
    _currentRequestId = null;
    _currentFirestorePath = null;

    _updateSession(_currentSession.copyWith(
      messages: messages,
      isStreaming: false,
      isThinking: false,
    ));

    if (content.isNotEmpty) {
      _saveConversationAsDM();
    }

    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
  }

  @override
  void dispose() {
    _cleanupCurrentSession();
    super.dispose();
  }
}
