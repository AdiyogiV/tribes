import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Possible environments for the app
enum Environment {
  development,
  staging,
  production,
}

/// Configuration for the app
class AppConfig {
  Environment environment;
  late final FirebaseRemoteConfig _remoteConfig;
  late final PackageInfo _packageInfo;
  bool _initialized = false;
  bool _isInitializing = false;
  Map<String, dynamic> _config = {};

  // Singleton instance
  static final AppConfig _instance =
      AppConfig._internal(Environment.production);
  factory AppConfig({Environment env = Environment.production}) {
    _instance._setEnvironment(env);
    return _instance;
  }

  AppConfig._internal(this.environment);

  void _setEnvironment(Environment env) {
    if (!_initialized) {
      environment = env;
    }
  }

  /// Initialize the configuration
  Future<bool> initialize() async {
    // Return immediately if already initialized or currently initializing
    if (_initialized) return true;
    if (_isInitializing) {
      AppLogger.d('AppConfig initialization already in progress',
          category: LogCategory.general);
      return false;
    }

    _isInitializing = true;

    try {
      // Initialize package info first
      _packageInfo = await PackageInfo.fromPlatform();

      // Initialize default config values early
      _config = _getDefaultValues();

      // Initialize Remote Config with proper error handling
      try {
        _remoteConfig = FirebaseRemoteConfig.instance;
        await _loadDefaults();
        await _loadRemoteConfig();
      } catch (e) {
        AppLogger.w(
          'Failed to initialize Firebase Remote Config, using defaults',
          category: LogCategory.general,
          data: {'error': e.toString()},
        );
      }

      // Apply performance optimizations by setting values in the _config map
      _config['enable_hardware_acceleration'] = true;
      _config['use_memory_cache'] = true;
      _config['image_cache_size'] = 200;
      _config['image_cache_size_mb'] = 50;
      _config['enable_background_optimization'] = true;
      _config['prefetch_assets'] = true;
      _config['max_video_preload'] = 2;
      _config['ui_animation_scale'] = 0.8;
      _config['enable_push_notifications'] = true;

      _initialized = true;
      _isInitializing = false;

      AppLogger.i(
        'AppConfig initialized with environment: ${environment.name}, platform: ${kIsWeb ? 'Web' : 'Native'}',
        category: LogCategory.general,
      );

      return true;
    } catch (e) {
      _isInitializing = false;

      // Still mark as initialized to avoid repeated failures
      _initialized = true;

      AppLogger.e(
        'Failed to initialize AppConfig',
        category: LogCategory.general,
        error: e,
      );
      return false;
    }
  }

  /// Get the appropriate minimum fetch interval based on environment and platform
  Duration _getMinimumFetchInterval() {
    // Web should have more frequent updates
    if (kIsWeb) {
      switch (environment) {
        case Environment.development:
          return const Duration(minutes: 1);
        case Environment.staging:
          return const Duration(minutes: 5);
        case Environment.production:
          return const Duration(hours: 1);
      }
    } else {
      // Mobile apps
      switch (environment) {
        case Environment.development:
          return const Duration(minutes: 5);
        case Environment.staging:
          return const Duration(hours: 1);
        case Environment.production:
          return const Duration(hours: 12);
      }
    }
  }

  /// Get a string value from remote config
  String getString(String key, {String defaultValue = ''}) {
    if (!_initialized) {
      AppLogger.w(
        'AppConfig not initialized, returning default value for $key',
        category: LogCategory.general,
      );
      return defaultValue;
    }

    try {
      return _remoteConfig.getString(key);
    } catch (e) {
      AppLogger.w(
        'Error getting string for key $key',
        category: LogCategory.general,
        data: {'error': e.toString()},
      );
      return defaultValue;
    }
  }

  /// Get a boolean value from remote config
  bool getBool(String key, {bool defaultValue = false}) {
    if (!_initialized) {
      AppLogger.w(
        'AppConfig not initialized, returning default value for $key',
        category: LogCategory.general,
      );
      return _config[key] ?? defaultValue;
    }

    try {
      return _remoteConfig.getBool(key);
    } catch (e) {
      // Fallback to local config if remote config fails
      final localValue = _config[key];
      if (localValue != null && localValue is bool) {
        return localValue;
      }

      AppLogger.w(
        'Error getting boolean for key $key',
        category: LogCategory.general,
        data: {'error': e.toString()},
      );
      return defaultValue;
    }
  }

  /// Get an integer value from remote config
  int getInt(String key, {int defaultValue = 0}) {
    if (!_initialized) {
      AppLogger.w(
        'AppConfig not initialized, returning default value for $key',
        category: LogCategory.general,
      );
      return _config[key] ?? defaultValue;
    }

    try {
      return _remoteConfig.getInt(key);
    } catch (e) {
      // Fallback to local config if remote config fails
      final localValue = _config[key];
      if (localValue != null && localValue is int) {
        return localValue;
      }

      AppLogger.w(
        'Error getting integer for key $key',
        category: LogCategory.general,
        data: {'error': e.toString()},
      );
      return defaultValue;
    }
  }

  /// Get a double value from remote config
  double getDouble(String key, {double defaultValue = 0.0}) {
    if (!_initialized) {
      AppLogger.w(
        'AppConfig not initialized, returning default value for $key',
        category: LogCategory.general,
      );
      return defaultValue;
    }

    try {
      return _remoteConfig.getDouble(key);
    } catch (e) {
      AppLogger.w(
        'Error getting double for key $key',
        category: LogCategory.general,
        data: {'error': e.toString()},
      );
      return defaultValue;
    }
  }

  /// Manual refresh of remote config values
  Future<bool> refreshConfig() async {
    if (!_initialized) {
      await initialize();
      return _initialized;
    }

    try {
      // Set a smaller minimum fetch interval for manual refresh
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 30),
        minimumFetchInterval: Duration.zero,
      ));

      final fetchResult = await _remoteConfig.fetchAndActivate();

      AppLogger.i(
        'Manual config refresh ${fetchResult ? 'succeeded' : 'completed without changes'}',
        category: LogCategory.general,
      );

      // Reset to normal fetch interval
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout:
            kIsWeb ? const Duration(seconds: 30) : const Duration(minutes: 1),
        minimumFetchInterval: _getMinimumFetchInterval(),
      ));

      return fetchResult;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to refresh remote config',
        category: LogCategory.general,
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Get the app version
  String get appVersion => _initialized
      ? '${_packageInfo.version}+${_packageInfo.buildNumber}'
      : 'Unknown';

  /// Get the app name (e.g. Aurogram) - useful for display
  String get appName => _initialized ? _packageInfo.appName : 'Aurogram';

  /// Get the package name (e.g. com.aurogram)
  String get packageName =>
      _initialized ? _packageInfo.packageName : 'app.aurogram';

  /// Check if the environment is production
  bool get isProduction => environment == Environment.production;

  /// Check if the environment is development
  bool get isDevelopment => environment == Environment.development;

  /// Check if the environment is staging
  bool get isStaging => environment == Environment.staging;

  /// Whether to show development features
  bool get showDevelopmentFeatures =>
      !isProduction || getBool('enable_dev_features', defaultValue: false);

  /// Whether the app is running on web
  bool get isWeb => kIsWeb;

  /// Whether crashlytics is enabled
  bool get isCrashlyticsEnabled =>
      !kIsWeb && getBool('enable_crashlytics', defaultValue: true);

  /// Default values for remote config
  Map<String, dynamic> _getDefaultValues() {
    return {
      // Feature flags
      'enable_dark_mode': false,
      'enable_push_notifications': true,
      'enable_analytics': true,
      'enable_offline_mode': false,
      'enable_crashlytics': true,
      'enable_dev_features': false,

      // API settings
      'api_timeout_seconds': 30,
      'max_retry_attempts': 3,

      // App settings
      'max_upload_size_mb': kIsWeb ? 50 : 100, // Smaller limit for web
      'max_video_duration_seconds':
          kIsWeb ? 120 : 300, // Shorter videos for web
      'cache_expiration_days': 7,

      // Maintenance
      'is_maintenance_mode': false,
      'maintenance_message':
          'We are performing scheduled maintenance. Please try again later.',

      // Web-specific settings
      'web_max_concurrent_uploads': 3,
      'web_enable_file_compression': true,
    };
  }

  /// Load default values into Remote Config
  Future<void> _loadDefaults() async {
    try {
      // Set default values for remote config
      await _remoteConfig.setDefaults({
        'image_cache_size': 200,
        'image_cache_size_mb': 50,
        'enable_push_notifications': true,
        'max_video_length_seconds': 60,
        'prefetch_feed_items': 5,
        'enable_hardware_acceleration': true,
        'enable_background_optimization': true,
        'use_memory_cache': true,
        'prefetch_assets': true,
        'max_video_preload': 2,
        'ui_animation_scale': 0.8,
      });
    } catch (e) {
      AppLogger.w(
        'Failed to set remote config defaults',
        category: LogCategory.general,
        data: {'error': e.toString()},
      );
    }
  }

  /// Load remote config values with proper error handling
  Future<void> _loadRemoteConfig() async {
    try {
      // Configure fetch settings based on environment
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout:
            kIsWeb ? const Duration(seconds: 30) : const Duration(minutes: 1),
        minimumFetchInterval: _getMinimumFetchInterval(),
      ));

      // Fetch and activate config with timeout
      bool updated = false;
      await _remoteConfig.fetchAndActivate().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          AppLogger.w(
            'Remote config fetch timed out, using cached values',
            category: LogCategory.general,
          );
          return false;
        },
      ).then((value) {
        updated = value;
      }).catchError((error) {
        AppLogger.w(
          'Error fetching remote config',
          category: LogCategory.general,
          data: {'error': error.toString()},
        );
        updated = false;
      });

      if (updated) {
        AppLogger.i(
          'Remote config updated',
          category: LogCategory.general,
        );
      } else {
        AppLogger.i(
          'Remote config fetch completed but no changes were applied',
          category: LogCategory.general,
        );
      }
    } catch (e) {
      AppLogger.w(
        'Error loading remote config',
        category: LogCategory.general,
        data: {'error': e.toString()},
      );
    }
  }

  /// Store local configuration values
  void storeLocalConfig(Map<String, dynamic> values) {
    if (values.isEmpty) return;

    try {
      // Merge values into local config
      values.forEach((key, value) {
        _config[key] = value;
      });

      AppLogger.d(
        'Local config values stored',
        category: LogCategory.general,
        data: {'keys': values.keys.toList()},
      );
    } catch (e) {
      AppLogger.w(
        'Failed to store local config values',
        category: LogCategory.general,
        data: {'error': e.toString()},
      );
    }
  }
}
