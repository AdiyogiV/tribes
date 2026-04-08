import 'dart:async' show unawaited;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:aurogram/core/logging/log_sanitizer.dart';
import 'package:aurogram/core/logging/log_file_sink.dart';

/// Log level for categorizing log messages
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
  fatal,
}

/// Category for grouping related log messages
enum LogCategory {
  network,
  database,
  auth,
  ui,
  navigation,
  media,
  performance,
  general,
  analytics,
  messaging,
  voice,
  storage,
}

/// A comprehensive logging utility for the application
/// Can be used both statically (AppLogger.i) or as an instance (logger.i)
class AppLogger {
  final FirebaseAnalytics _analytics;
  static LogLevel _minimumLogLevel = LogLevel.info;
  static bool _crashlyticsAvailable = false;
  static bool _fileLoggingEnabled = false;

  /// Creates a new AppLogger
  AppLogger({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance {
    // Check if Crashlytics is available (not available on web)
    if (!kIsWeb) {
      try {
        // Try to access FirebaseCrashlytics to see if it's properly initialized
        FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled;
        _crashlyticsAvailable = true;
      } catch (e) {
        _crashlyticsAvailable = false;
      }
    } else {
      _crashlyticsAvailable = false;
    }
  }

  /// Returns whether Crashlytics is available for the current platform
  static bool get isCrashlyticsAvailable => _crashlyticsAvailable;

  /// Sets the minimum log level to display
  static void setMinimumLogLevel(LogLevel level) {
    _minimumLogLevel = level;
  }

  /// Enable/disable file logging (opt-in).
  ///
  /// This is intentionally off by default and should be enabled via a runtime
  /// flag (e.g. Remote Config / AppConfig) or debug tooling.
  static void setFileLoggingEnabled(bool enabled) {
    _fileLoggingEnabled = enabled;
    LogFileSink.setEnabled(enabled);
  }

  // STATIC METHODS

  /// Log a message at the verbose level (static)
  static void v(String message,
      {LogCategory category = LogCategory.general,
      Map<String, Object?>? data}) {
    _log(LogLevel.verbose, message, category, data);
  }

  /// Log a message at the debug level (static)
  static void d(String message,
      {LogCategory category = LogCategory.general,
      Map<String, Object?>? data}) {
    _log(LogLevel.debug, message, category, data);
  }

  /// Log a message at the info level (static)
  static void i(String message,
      {LogCategory category = LogCategory.general,
      Map<String, Object?>? data}) {
    _log(LogLevel.info, message, category, data);
  }

  /// Log a message at the warning level (static)
  static void w(String message,
      {LogCategory category = LogCategory.general,
      Map<String, Object?>? data}) {
    _log(LogLevel.warning, message, category, data);
  }

  /// Log a message at the error level (static)
  static void e(
    String message, {
    LogCategory category = LogCategory.general,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    // Include error details in the log data
    final logData = <String, Object?>{...?data};
    if (error != null) {
      logData['error'] = error.toString();
    }
    _log(LogLevel.error, message, category, logData.isNotEmpty ? logData : null);

    // Also print error and stack trace to console for debugging
    if (error != null) {
      print('  Error: $error');
      if (stackTrace != null) {
        print('  StackTrace: $stackTrace');
      }
    }

    if (error != null && stackTrace != null && _crashlyticsAvailable) {
      try {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: message,
        );
      } catch (e) {
        // Continue execution without crashing the app
      }
    }
  }

  /// Log a message at the fatal level (static)
  static void f(
    String message, {
    LogCategory category = LogCategory.general,
    required dynamic error,
    required StackTrace stackTrace,
    Map<String, Object?>? data,
  }) {
    _log(LogLevel.fatal, message, category, data);

    if (_crashlyticsAvailable) {
      try {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: message,
          fatal: true,
        );
      } catch (e) {
        // Log to console as fallback
      }
    } else {
      // For platforms where Crashlytics is not available, log to console
    }
  }

  // INSTANCE METHODS (same functionality as static methods but callable on instances)

  /// Log a message at the verbose level (instance method)
  void verbose(String message,
      {LogCategory category = LogCategory.general,
      Map<String, Object?>? data}) {
    AppLogger.v(message, category: category, data: data);
  }

  /// Log a message at the debug level (instance method)
  void debug(String message,
      {LogCategory category = LogCategory.general,
      Map<String, Object?>? data}) {
    AppLogger.d(message, category: category, data: data);
  }

  /// Log a message at the info level (instance method)
  void info(String message,
      {LogCategory category = LogCategory.general,
      Map<String, Object?>? data}) {
    AppLogger.i(message, category: category, data: data);
  }

  /// Log a message at the warning level (instance method)
  void warn(String message,
      {LogCategory category = LogCategory.general,
      Map<String, Object?>? data}) {
    AppLogger.w(message, category: category, data: data);
  }

  /// Log a message at the error level (instance method)
  void error(
    String message, {
    LogCategory category = LogCategory.general,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    _log(LogLevel.error, message, category, data);

    if (error != null && stackTrace != null && _crashlyticsAvailable) {
      try {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: message,
        );
      } catch (e) {
        // Continue execution without crashing the app
      }
    }
  }

  /// Log a message at the fatal level (instance method)
  void fatal(
    String message, {
    LogCategory category = LogCategory.general,
    required dynamic error,
    required StackTrace stackTrace,
    Map<String, Object?>? data,
  }) {
    _log(LogLevel.fatal, message, category, data);

    if (_crashlyticsAvailable) {
      try {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: message,
          fatal: true,
        );
      } catch (e) {
        // Log to console as fallback
      }
    } else {
      // For platforms where Crashlytics is not available, log to console
    }
  }

  /// Track an analytics event
  Future<void> trackEvent(String eventName,
      {Map<String, Object>? parameters}) async {
    try {
      // Log the event with Firebase Analytics
      await _analytics.logEvent(
        name: eventName,
        parameters:
            parameters != null ? Map<String, Object>.from(parameters) : null,
      );

      // Log for debugging purposes
      AppLogger.d(
        'Analytics event: $eventName',
        category: LogCategory.analytics,
        data: parameters,
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to track analytics event',
        category: LogCategory.analytics,
        error: e,
        stackTrace: stack,
        data: {'eventName': eventName},
      );
    }
  }

  /// Internal logging method
  static void _log(
    LogLevel level,
    String message,
    LogCategory category,
    Map<String, Object?>? data,
  ) {
    if (level.index < _minimumLogLevel.index) {
      return;
    }

    final levelTag = level.toString().split('.').last.toUpperCase();
    final categoryTag = category.toString().split('.').last;
    final timestamp = DateTime.now().toIso8601String();
    final sanitized = LogSanitizer.sanitizeData(data);
    final dataString = sanitized != null ? ' - data: $sanitized' : '';

    // Simple console logging implementation
    final line = '[$timestamp] [$levelTag] [$categoryTag] $message$dataString';
    print(line);

    if (_fileLoggingEnabled) {
      // Fire-and-forget to avoid blocking UI.
      unawaited(LogFileSink.writeLine(line));
    }
  }
}
