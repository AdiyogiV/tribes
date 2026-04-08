import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Utility class for handling errors consistently throughout the app
class ErrorHandler {
  /// Execute a function with error handling
  ///
  /// [action] The async function to execute
  /// [errorMessage] Message to log if an error occurs
  /// [recordError] Whether to report the error to Crashlytics
  /// [defaultValue] Default value to return if the action fails
  static Future<T> execute<T>(
    Future<T> Function() action,
    String errorMessage, {
    bool recordError = true,
    T? defaultValue,
  }) async {
    try {
      return await action();
    } catch (e, stack) {
      if (recordError) {
        AppLogger.e(
          errorMessage,
          category: LogCategory.general,
          error: e,
          stackTrace: stack,
        );
      } else {
        AppLogger.w('$errorMessage: $e', category: LogCategory.general);
      }

      if (defaultValue != null) {
        return defaultValue;
      }
      rethrow;
    }
  }

  /// Report an error without rethrowing
  static void report(
    dynamic error,
    StackTrace stackTrace, {
    String? reason,
    bool printLog = true,
    LogCategory category = LogCategory.general,
  }) {
    if (reason != null) {
      AppLogger.e(
        reason,
        category: category,
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
      if (printLog) {
        AppLogger.e('Error: $error', category: category);
      }
    }
  }

  /// Log an info message to the console
  static void logInfo(String message,
      {LogCategory category = LogCategory.general}) {
    AppLogger.i(message, category: category);
  }
}
