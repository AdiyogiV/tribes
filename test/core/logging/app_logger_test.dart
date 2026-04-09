// ignore_for_file: avoid_print
/// Tests for AppLogger — validates that static logging methods (i, d, w, e)
/// do not throw when called without Firebase initialization.
///
/// AppLogger internally uses debugPrint and guards Crashlytics calls behind
/// try/catch, so these methods should be safe to call in any environment.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/core/logging/app_logger.dart';

void main() {
  group('AppLogger', () {
    // Lower the minimum log level so all calls actually execute the _log path.
    setUpAll(() {
      AppLogger.setMinimumLogLevel(LogLevel.verbose);
    });

    test('AppLogger.i does not throw', () {
      expect(
        () => AppLogger.i('info message'),
        returnsNormally,
      );
    });

    test('AppLogger.d does not throw', () {
      expect(
        () => AppLogger.d('debug message'),
        returnsNormally,
      );
    });

    test('AppLogger.w does not throw', () {
      expect(
        () => AppLogger.w('warning message'),
        returnsNormally,
      );
    });

    test('AppLogger.e does not throw', () {
      expect(
        () => AppLogger.e('error message'),
        returnsNormally,
      );
    });

    test('AppLogger.v does not throw', () {
      expect(
        () => AppLogger.v('verbose message'),
        returnsNormally,
      );
    });

    test('AppLogger.e with error and stackTrace does not throw', () {
      expect(
        () => AppLogger.e(
          'error with details',
          error: Exception('test error'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('logging with category does not throw', () {
      expect(
        () => AppLogger.i('network message', category: LogCategory.network),
        returnsNormally,
      );
    });

    test('logging with data does not throw', () {
      expect(
        () => AppLogger.i('data message', data: {'key': 'value', 'count': 42}),
        returnsNormally,
      );
    });

    test('LogLevel enum has expected values', () {
      expect(LogLevel.values.length, equals(6));
      expect(LogLevel.verbose.index, lessThan(LogLevel.debug.index));
      expect(LogLevel.debug.index, lessThan(LogLevel.info.index));
      expect(LogLevel.info.index, lessThan(LogLevel.warning.index));
      expect(LogLevel.warning.index, lessThan(LogLevel.error.index));
      expect(LogLevel.error.index, lessThan(LogLevel.fatal.index));
    });

    test('LogCategory enum has expected values', () {
      expect(LogCategory.values.length, equals(12));
      expect(LogCategory.values, contains(LogCategory.network));
      expect(LogCategory.values, contains(LogCategory.auth));
      expect(LogCategory.values, contains(LogCategory.general));
    });

    test('setMinimumLogLevel does not throw', () {
      expect(
        () => AppLogger.setMinimumLogLevel(LogLevel.warning),
        returnsNormally,
      );
      // Restore for other tests.
      AppLogger.setMinimumLogLevel(LogLevel.verbose);
    });

    test('messages below minimum level are suppressed without error', () {
      AppLogger.setMinimumLogLevel(LogLevel.error);
      // These should not throw even though they are below minimum level.
      expect(() => AppLogger.v('suppressed'), returnsNormally);
      expect(() => AppLogger.d('suppressed'), returnsNormally);
      expect(() => AppLogger.i('suppressed'), returnsNormally);
      expect(() => AppLogger.w('suppressed'), returnsNormally);
      // Restore.
      AppLogger.setMinimumLogLevel(LogLevel.verbose);
    });
  });
}
