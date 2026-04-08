import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Best-effort recovery for Firestore when reads hang or time out.
/// Keeps attempts throttled to avoid thrashing the SDK.
class FirestoreRecovery {
  static bool _isRecovering = false;
  static DateTime? _lastRecovery;
  static const Duration _minInterval = Duration(seconds: 30);

  static Future<bool> attemptRecovery({required String context}) async {
    if (_isRecovering) {
      AppLogger.d('Firestore recovery already in progress',
          category: LogCategory.database, data: {'context': context});
      return false;
    }

    if (_lastRecovery != null &&
        DateTime.now().difference(_lastRecovery!) < _minInterval) {
      AppLogger.d('Firestore recovery throttled',
          category: LogCategory.database, data: {'context': context});
      return false;
    }

    _isRecovering = true;
    _lastRecovery = DateTime.now();
    AppLogger.w('Firestore recovery starting',
        category: LogCategory.database, data: {'context': context});

    try {
      // Ensure network is enabled (no-op if already enabled).
      await FirebaseFirestore.instance
          .enableNetwork()
          .timeout(const Duration(seconds: 5));

      // Quick server probe to verify Firestore responsiveness.
      await FirebaseFirestore.instance
          .collection('globalFeed')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));

      AppLogger.i('Firestore recovery succeeded',
          category: LogCategory.database, data: {'context': context});
      return true;
    } catch (e) {
      AppLogger.w('Firestore recovery failed',
          category: LogCategory.database,
          data: {'context': context, 'error': e.toString()});
      return false;
    } finally {
      _isRecovering = false;
    }
  }
}
