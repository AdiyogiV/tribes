import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Service to manage anonymous message feature enable/disable preference
///
/// NOTE: Feature globally disabled to comply with App Store Guideline 1.2
/// (anonymous chat is not permitted). All entry points return disabled.
/// To re-enable, remove the `_featureKilled` flag below.
class AnonymousMessageSettingsService {
  /// Global kill switch – set to `true` to disable the entire feature.
  static const bool _featureKilled = true;
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
  /// Returns false when feature is killed (App Store Guideline 1.2 compliance)
  Future<bool> isEnabled() async {
    if (_featureKilled) return false;

    if (!_initialized) {
      await initialize();
    }

    if (_cachedValue != null) {
      return _cachedValue!;
    }

    try {
      final enabled = _prefs?.getBool(_keyAnonymousMessagesEnabled) ?? true;
      _cachedValue = enabled;
      return enabled;
    } catch (e) {
      AppLogger.e('Failed to read anonymous messages setting',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  /// Set anonymous messages enabled/disabled
  /// No-op when feature is killed.
  Future<bool> setEnabled(bool enabled) async {
    if (_featureKilled) return false;

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
