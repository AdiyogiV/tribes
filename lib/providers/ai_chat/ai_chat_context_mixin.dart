import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

import 'ai_chat_models.dart';

/// Mixin for managing AI chat context (astrology, chat source, system prompts).
///
/// Requires the host class to provide [currentSession], [notifyListeners],
/// and the [transition] method for state updates.
mixin AiChatContextMixin on ChangeNotifier {
  // =========================================================================
  // State that must be provided by the host class
  // =========================================================================
  ChatSessionState get currentSession;
  void transition(ChatSessionState newState);

  // =========================================================================
  // Context state
  // =========================================================================
  Map<String, dynamic>? _astrologyContext;
  String? _chatSource; // 'astrology' | 'wellness'

  // Cached system prompt from backend (once per session / context)
  String? _cachedSystemPrompt;
  String? _cachedPromptKey;

  // =========================================================================
  // Public API
  // =========================================================================

  /// Get astrology context
  Map<String, dynamic>? get astrologyContext => _astrologyContext;

  /// Get chat source
  String? get chatSource => _chatSource;

  /// Set astrology context for astro chat
  void setAstrologyContext(Map<String, dynamic> context) {
    _astrologyContext = context;
    invalidatePromptCache();
    notifyListeners();
  }

  /// Clear astrology context when leaving astro chat
  void clearAstrologyContext() {
    _astrologyContext = null;
    invalidatePromptCache();
    notifyListeners();
  }

  /// Set chat source for backend (astrology vs wellness)
  void setChatSource(String? value) {
    _chatSource = value;
    invalidatePromptCache();
    notifyListeners();
  }

  /// Clear chat source when leaving chat page
  void clearChatSource() {
    _chatSource = null;
    invalidatePromptCache();
    notifyListeners();
  }

  /// Invalidate the cached system prompt (e.g. when context changes)
  void invalidatePromptCache() {
    _cachedSystemPrompt = null;
    _cachedPromptKey = null;
  }

  /// Fetch system prompt from backend once per session/context; cache and return.
  Future<String?> getChatSystemPrompt(String? location) async {
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
}
