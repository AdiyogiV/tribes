import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Service to manage anonymous message feature enable/disable preference
class AnonymousMessageSettingsService {
  static const String _keyAnonymousMessagesEnabled = 'anonymous_messages_enabled';
  
  // Singleton instance
  static final AnonymousMessageSettingsService _instance =
      AnonymousMessageSettingsService._internal();
  factory AnonymousMessageSettingsService() => _instance;
  AnonymousMessageSettingsService._internal();

  SharedPreferences? _prefs;
  bool? _cachedValue;
  bool _initialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    } catch (e) {
      AppLogger.e('Failed to initialize AnonymousMessageSettingsService',
          category: LogCategory.general, error: e);
    }
  }

  /// Check if anonymous messages are enabled
  /// Defaults to true if not set (for backward compatibility)
  Future<bool> isEnabled() async {
    if (!_initialized) {
      await initialize();
    }
    
    if (_cachedValue != null) {
      return _cachedValue!;
    }

    try {
      // Default to true if not set (backward compatibility)
      final enabled = _prefs?.getBool(_keyAnonymousMessagesEnabled) ?? true;
      _cachedValue = enabled;
      return enabled;
    } catch (e) {
      AppLogger.e('Failed to read anonymous messages setting',
          category: LogCategory.general, error: e);
      // Default to true on error
      return true;
    }
  }

  /// Set anonymous messages enabled/disabled
  Future<bool> setEnabled(bool enabled) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final success = await _prefs?.setBool(_keyAnonymousMessagesEnabled, enabled) ?? false;
      if (success) {
        _cachedValue = enabled;
      }
      return success;
    } catch (e) {
      AppLogger.e('Failed to save anonymous messages setting',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Clear cached value (useful for testing or when user logs out)
  void clearCache() {
    _cachedValue = null;
  }
}
