import 'package:flutter/foundation.dart';

import 'ai_chat_models.dart';

/// Mixin for managing AI chat context (astrology context + chat source).
///
/// The system prompt is now built entirely server-side (the backend fetches the
/// user's astrology/ayurveda/memory from Firestore via the ID token), so this
/// mixin no longer fetches or caches a prompt.
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

  // =========================================================================
  // Public API
  // =========================================================================

  /// Get astrology context (kept for dedicated astro/wellness pages that pass
  /// context explicitly; the unified HolyCow chat loads it server-side).
  Map<String, dynamic>? get astrologyContext => _astrologyContext;

  /// Get chat source
  String? get chatSource => _chatSource;

  /// Set astrology context for astro chat
  void setAstrologyContext(Map<String, dynamic> context) {
    _astrologyContext = context;
    notifyListeners();
  }

  /// Clear astrology context when leaving astro chat
  void clearAstrologyContext() {
    _astrologyContext = null;
    notifyListeners();
  }

  /// Set chat source for backend (astrology vs wellness)
  void setChatSource(String? value) {
    _chatSource = value;
    notifyListeners();
  }

  /// Clear chat source when leaving chat page
  void clearChatSource() {
    _chatSource = null;
    notifyListeners();
  }

  /// Retained as a no-op for backwards compatibility with callers. The system
  /// prompt is no longer cached on the client — the backend builds it per request.
  void invalidatePromptCache() {}
}
