import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Service to manage onboarding/FTUE state
/// Tracks whether user has seen the first-time experience
/// Extends ChangeNotifier to allow widgets to rebuild when state changes
class OnboardingService extends ChangeNotifier {
  static const String _keyFtueShown = 'ftue_shown_v1';
  static const String _keyFtueShownAt = 'ftue_shown_at';
  static const String _keyNotificationPromptPending =
      'notification_prompt_pending';

  // Singleton instance
  static final OnboardingService _instance = OnboardingService._internal();
  factory OnboardingService() => _instance;
  OnboardingService._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;
  bool _ftueShown = false;

  /// Flag to indicate notification prompt should be shown after onboarding
  /// This is set when onboarding completes and cleared after prompt is shown
  bool _notificationPromptPending = false;

  /// Whether the service has been initialized
  bool get isInitialized => _initialized;

  /// Whether FTUE has been shown to the user
  /// Returns false if not initialized (will show FTUE by default)
  bool get ftueShown => _ftueShown;

  /// Whether notification permission prompt should be shown
  /// Set after onboarding completes, cleared after prompt is shown
  bool get notificationPromptPending => _notificationPromptPending;

  /// Initialize the service - call this early in app startup
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _ftueShown = _prefs?.getBool(_keyFtueShown) ?? false;
      _notificationPromptPending =
          _prefs?.getBool(_keyNotificationPromptPending) ?? false;
      _initialized = true;

      AppLogger.i('OnboardingService initialized',
          category: LogCategory.general,
          data: {
            'ftueShown': _ftueShown,
            'notificationPromptPending': _notificationPromptPending,
          });
    } catch (e) {
      AppLogger.e('Failed to initialize OnboardingService',
          category: LogCategory.general, error: e);
      // Default to showing FTUE on error
      _ftueShown = false;
      _notificationPromptPending = false;
      _initialized = true;
    }
  }

  /// Mark FTUE as shown - call when user dismisses or completes FTUE
  /// This will notify listeners to trigger UI rebuilds
  /// Also sets notification prompt pending flag for first TabHandler load
  Future<void> markFtueShown() async {
    final wasAlreadyShown = _ftueShown;
    _ftueShown = true;

    if (!wasAlreadyShown) {
      // Set notification prompt pending - will be shown on first TabHandler load
      _notificationPromptPending = true;

      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        await prefs.setBool(_keyFtueShown, true);
        await prefs.setString(
            _keyFtueShownAt, DateTime.now().toIso8601String());
        await prefs.setBool(_keyNotificationPromptPending, true);

        AppLogger.i('FTUE marked as shown, notification prompt pending',
            category: LogCategory.general);
      } catch (e) {
        AppLogger.e('Failed to persist FTUE shown flag',
            category: LogCategory.general, error: e);
      }
    }

    // ALWAYS notify listeners to rebuild UI (e.g., TabHandler)
    // This ensures navigation happens even if ftueShown was already true
    notifyListeners();
  }

  /// Clear the notification prompt pending flag after showing the prompt
  Future<void> clearNotificationPromptPending() async {
    _notificationPromptPending = false;

    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(_keyNotificationPromptPending, false);
    } catch (e) {
      AppLogger.e('Failed to clear notification prompt flag',
          category: LogCategory.general, error: e);
    }
  }

  /// Check if FTUE should be shown for first-time users
  /// Call this to decide whether to show FTUE page
  bool shouldShowFtue() {
    // If not initialized, try sync check
    if (!_initialized) {
      return true; // Default to showing FTUE
    }
    return !_ftueShown;
  }

  /// Reset FTUE state (for testing or re-onboarding)
  Future<void> resetFtue() async {
    _ftueShown = false;

    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.remove(_keyFtueShown);
      await prefs.remove(_keyFtueShownAt);

      AppLogger.i('FTUE state reset', category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Failed to reset FTUE state',
          category: LogCategory.general, error: e);
    }
  }
}
