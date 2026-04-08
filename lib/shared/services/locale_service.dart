import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Service to manage localization settings for the application
class LocaleService extends ChangeNotifier {
  static const String _localeKey = 'app_locale';

  Locale _currentLocale = Locale('en'); // Default to English
  SharedPreferences? _prefsInstance;
  bool _initialized = false;

  // Singleton instance
  static final LocaleService _instance = LocaleService._internal();
  factory LocaleService() => _instance;
  LocaleService._internal();

  /// Get system locale safely for all platforms (including web)
  /// Uses PlatformDispatcher instead of dart:io Platform which crashes on web
  Locale _getSystemLocale() {
    try {
      final locales = ui.PlatformDispatcher.instance.locales;
      if (locales.isNotEmpty) {
        return locales.first;
      }
    } catch (e) {
      // Fallback if PlatformDispatcher fails
    }
    return const Locale('en');
  }

  /// Initialize the service and load saved locale
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefsInstance = await SharedPreferences.getInstance();
      await initializeLocale();
      _initialized = true;
    } catch (e) {
      AppLogger.e('Failed to initialize LocaleService',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Get the current locale
  Locale get currentLocale => _currentLocale;

  /// Set a new locale and save it
  Future<void> setLocale(Locale locale) async {
    if (_currentLocale == locale) return;

    try {
      _currentLocale = locale;

      // Save to preferences
      if (_prefsInstance != null) {
        await _prefsInstance!.setString(_localeKey, locale.languageCode);
      }

      // Notify listeners to rebuild UI
      notifyListeners();

      AppLogger.i('Locale updated',
          category: LogCategory.general, data: {'locale': locale.languageCode});
    } catch (e) {
      AppLogger.e('Failed to set locale',
          category: LogCategory.general,
          data: {'error': e.toString(), 'locale': locale.languageCode});
    }
  }

  /// Initialize locale service with improved caching
  Future<void> initializeLocale() async {
    try {
      // Check for cached locale first to avoid slow disk reads during startup
      final cachedLocale = _getCachedLocale();
      if (cachedLocale != null) {
        _currentLocale = cachedLocale;
        notifyListeners();
        // Log that we're using cached locale for faster startup
        AppLogger.i('Using cached locale: $_currentLocale',
            category: LogCategory.general);

        // Load from preferences in background without blocking
        _loadFromPreferencesAsync();
        return;
      }

      // No cache, load synchronously
      await _loadFromPreferences();
    } catch (e) {
      AppLogger.e('Error initializing locale service',
          category: LogCategory.general, data: {'error': e.toString()});
      // Default to system locale if there's an error
      _currentLocale = _getSystemLocale();
      notifyListeners();
    }
  }

  /// Get cached locale from memory
  Locale? _getCachedLocale() {
    try {
      // Check if we've stored the locale in memory from a previous initialization
      final SharedPreferences? prefs = _prefsInstance;
      if (prefs != null) {
        final String? languageCode = prefs.getString(_localeKey);
        if (languageCode != null && languageCode.isNotEmpty) {
          return Locale(languageCode);
        }
      }
    } catch (e) {
      // Silently fail on cache check - we'll fall back to regular loading
    }
    return null;
  }

  /// Load locale from shared preferences
  Future<void> _loadFromPreferences() async {
    try {
      if (_prefsInstance != null) {
        final String? languageCode = _prefsInstance!.getString(_localeKey);
        if (languageCode != null && languageCode.isNotEmpty) {
          _currentLocale = Locale(languageCode);
          notifyListeners();
          AppLogger.d('Loaded locale from preferences: $_currentLocale',
              category: LogCategory.general);
        } else {
          // Use device locale if none is stored
          _currentLocale = _getSystemLocale();
          notifyListeners();
          AppLogger.d('Using device locale: $_currentLocale',
              category: LogCategory.general);
        }
      }
    } catch (e) {
      AppLogger.w('Error loading locale from preferences',
          category: LogCategory.general, data: {'error': e.toString()});
      // Default to system locale
      _currentLocale = _getSystemLocale();
      notifyListeners();
    }
  }

  /// Load locale from preferences in background
  Future<void> _loadFromPreferencesAsync() async {
    Future.microtask(() async {
      try {
        await _loadFromPreferences();
      } catch (e) {
        AppLogger.e('Error loading locale from preferences in background',
            category: LogCategory.general, data: {'error': e.toString()});
      }
    });
  }
}
