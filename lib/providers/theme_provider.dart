import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Theme mode options
enum AppThemeMode {
  /// Always light mode
  light,

  /// Always dark mode
  dark,

  /// Automatic based on time of day
  automatic,
}

/// Provides global dark mode state with persistence.
/// Supports automatic day/night switching:
/// - Light mode: 8 AM to 4 PM (8 hours)
/// - Dark mode: 4 PM to 8 AM (16 hours)
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKeyThemeMode = 'theme_mode';
  static const String _prefsKeyIsDark = 'is_dark_mode_enabled'; // Legacy key

  // Time boundaries for automatic theme switching
  // Light mode: 8 AM to 4 PM (8 hours)
  // Dark mode: 4 PM to 8 AM (16 hours)
  static const int _lightModeStartHour = 8; // 8 AM
  static const int _darkModeStartHour = 16; // 4 PM

  AppThemeMode _themeMode = AppThemeMode.automatic;
  bool _isDarkMode = true; // Default to dark until initialized
  bool _initialized = false;
  Timer? _autoThemeTimer;

  ThemeProvider() {
    _initialize();
  }

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _initialized;
  AppThemeMode get themeMode => _themeMode;

  /// Whether automatic theme is currently active
  bool get isAutomatic => _themeMode == AppThemeMode.automatic;

  /// Check if current time is during daytime (light mode hours)
  bool get isCurrentlyDayTime {
    final hour = DateTime.now().hour;
    return hour >= _lightModeStartHour && hour < _darkModeStartHour;
  }

  Future<void> _initialize() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // Try to load new theme mode preference
      final savedMode = prefs.getString(_prefsKeyThemeMode);
      if (savedMode != null) {
        _themeMode = AppThemeMode.values.firstWhere(
          (mode) => mode.name == savedMode,
          orElse: () => AppThemeMode.automatic,
        );
      } else {
        // Migrate from legacy boolean preference
        final legacyIsDark = prefs.getBool(_prefsKeyIsDark);
        if (legacyIsDark != null) {
          // If user had dark mode on, keep it as manual dark
          // Otherwise, migrate to automatic
          _themeMode =
              legacyIsDark ? AppThemeMode.dark : AppThemeMode.automatic;
          // Save the migrated preference
          await prefs.setString(_prefsKeyThemeMode, _themeMode.name);
        } else {
          // New user - default to automatic
          _themeMode = AppThemeMode.automatic;
        }
      }

      // Calculate initial dark mode state
      _updateDarkModeFromThemeMode();

      // Start auto-update timer if in automatic mode
      _setupAutoThemeTimer();
    } catch (e) {
      AppLogger.w('Failed to load theme preference',
          category: LogCategory.ui, data: {'error': e.toString()});
      _themeMode = AppThemeMode.automatic;
      _updateDarkModeFromThemeMode();
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  /// Updates _isDarkMode based on the current theme mode
  void _updateDarkModeFromThemeMode() {
    switch (_themeMode) {
      case AppThemeMode.light:
        _isDarkMode = false;
        break;
      case AppThemeMode.dark:
        _isDarkMode = true;
        break;
      case AppThemeMode.automatic:
        _isDarkMode = !isCurrentlyDayTime;
        break;
    }
  }

  /// Sets up a timer to check for theme changes every minute (only in automatic mode)
  void _setupAutoThemeTimer() {
    _autoThemeTimer?.cancel();

    if (_themeMode == AppThemeMode.automatic) {
      // Check every minute for time-based theme changes
      _autoThemeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        final shouldBeDark = !isCurrentlyDayTime;
        if (_isDarkMode != shouldBeDark) {
          _isDarkMode = shouldBeDark;
          notifyListeners();
          AppLogger.d(
              'Auto theme switched to ${_isDarkMode ? "dark" : "light"} mode',
              category: LogCategory.ui,
              data: {'hour': DateTime.now().hour});
        }
      });
    }
  }

  /// Set the theme mode (light, dark, or automatic)
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    _updateDarkModeFromThemeMode();
    _setupAutoThemeTimer();
    notifyListeners();

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyThemeMode, mode.name);
    } catch (e) {
      AppLogger.w('Failed to persist theme mode',
          category: LogCategory.ui, data: {'error': e.toString()});
    }
  }

  /// Toggle automatic mode on/off
  Future<void> toggleAutomatic() async {
    if (_themeMode == AppThemeMode.automatic) {
      // Switch to manual mode with current state
      await setThemeMode(_isDarkMode ? AppThemeMode.dark : AppThemeMode.light);
    } else {
      await setThemeMode(AppThemeMode.automatic);
    }
  }

  /// Legacy method - sets dark mode directly (switches to manual mode)
  Future<void> setDarkMode(bool value) async {
    final newMode = value ? AppThemeMode.dark : AppThemeMode.light;
    await setThemeMode(newMode);
  }

  /// Toggle between light and dark (switches to manual mode)
  Future<void> toggle() async {
    await setThemeMode(_isDarkMode ? AppThemeMode.light : AppThemeMode.dark);
  }

  /// Get a display string for the current theme mode
  String get themeModeLabel {
    switch (_themeMode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.automatic:
        return 'Auto';
    }
  }

  @override
  void dispose() {
    _autoThemeTimer?.cancel();
    super.dispose();
  }
}
