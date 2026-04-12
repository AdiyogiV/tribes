import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:aurogram/shared/models/watch_health_data.dart';
import 'package:aurogram/shared/services/watch_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Provides watch health data to the Flutter widget tree.
///
/// Listens to `WatchService.onWatchData` for `type: 'healthData'` payloads
/// and exposes the latest `WatchHealthData` via `ChangeNotifier`.
///
/// Usage:
///   `Provider.of<WatchHealthProvider>(context).healthData`
class WatchHealthProvider extends ChangeNotifier {
  WatchHealthData? _healthData;
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _initialized = false;

  /// The latest health data from the watch, or null if none received yet.
  WatchHealthData? get healthData => _healthData;

  /// True after at least one health payload has been received.
  bool get hasData => _healthData?.hasData == true;

  /// Initialize and start listening. Safe to call multiple times.
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _sub = WatchService.instance.onWatchData.listen(_handleWatchData);
    AppLogger.d('WatchHealthProvider: listening for watch health data',
        category: LogCategory.general);
  }

  void _handleWatchData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type != 'healthData') return;

    _healthData = WatchHealthData.fromMap(data);
    AppLogger.d('WatchHealthProvider: received health data',
        category: LogCategory.general,
        data: {
          'ojas': _healthData?.ojasScore,
          'signals': _healthData?.signalCount,
          'fresh': _healthData?.isFresh,
        });
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
