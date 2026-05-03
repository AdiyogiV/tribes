import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:aurogram/shared/models/watch_health_data.dart';
import 'package:aurogram/shared/services/watch_service.dart';
import 'package:aurogram/shared/services/local_store.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Provides watch health data to the Flutter widget tree.
///
/// Data flow (local-first):
///   1. Subscribes to live watch data stream (real-time updates)
///   2. Every incoming reading is stored in LocalStore (sqflite)
///   3. On initialization, hydrates from LocalStore (instant, no network)
///   4. History and trend data come from LocalStore SQL queries
///
/// The old Firestore hydration is gone — LocalStore is the source of truth
/// for the UI. Firestore sync happens in the background via LocalStore.
///
/// Usage:
///   `context.watch<WatchHealthProvider>().healthData`
///   `context.read<WatchHealthProvider>().history` (for trend charts)
class WatchHealthProvider extends ChangeNotifier {
  WatchHealthData? _healthData;
  List<WatchHealthData> _history = [];
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _initialized = false;

  /// The latest health data from the watch, or null if none received yet.
  WatchHealthData? get healthData => _healthData;

  /// Historical health snapshots (oldest first).
  /// With LocalStore, this can contain dozens of data points per day
  /// instead of one-per-day from the old Firestore approach.
  List<WatchHealthData> get history => _history;

  /// True after at least one health payload has been received.
  bool get hasData => _healthData?.hasData == true;

  /// True when enough history exists for trend charts (at least 2 data points).
  bool get hasHistory => _history.length >= 2;

  /// Initialize and start listening. Safe to call multiple times.
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Subscribe to live watch data
    _sub = WatchService.instance.onWatchData.listen(_handleWatchData);

    // Replay any data that arrived before we subscribed
    final buffered = WatchService.instance.drainReplayBuffer();
    for (final data in buffered) {
      _handleWatchData(data);
    }

    // Hydrate from local DB immediately (instant, no network)
    _hydrateFromLocalStore();

    AppLogger.i('WatchHealthProvider: initialized with local-first architecture',
        category: LogCategory.general);
  }

  void _handleWatchData(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    if (type == 'healthData') {
      _healthData = WatchHealthData.fromMap(data);
      AppLogger.i('WatchHealthProvider: received healthData',
          category: LogCategory.general,
          data: {
            'hasData': _healthData?.hasData,
            'signals': _healthData?.signalCount,
            'heartRate': _healthData?.heartRate,
            'hrv': _healthData?.hrv,
            'spO2': _healthData?.spO2,
            'steps': _healthData?.steps,
          });

      // Also add to history (in-memory, for immediate chart update)
      if (_healthData != null && _healthData!.hasData) {
        _appendToHistory(_healthData!);
      }

      // Handle batch readings — each gets its own DB row for granular charts
      _insertBatchHeartRateReadings(data);
      _insertBatchSignalReadings(data);

      notifyListeners();
    } else if (type == 'nadiReading' && _healthData == null) {
      // Use Nadi reading as initial health data if no full payload yet
      _healthData = WatchHealthData.fromMap(data);
      if (_healthData!.hasData) {
        AppLogger.i('WatchHealthProvider: using nadiReading as initial health data',
            category: LogCategory.general,
            data: {
              'signals': _healthData?.signalCount,
              'hrv': _healthData?.hrv,
            });
        notifyListeners();
      }
    }
  }

  // ── Local Store Hydration ──────────────────────────────────────────────

  /// Load latest reading and history from LocalStore.
  /// Instant, no network, works offline. Called once on init.
  Future<void> _hydrateFromLocalStore() async {
    final store = LocalStore.instance;
    if (!store.isReady) {
      AppLogger.d('WatchHealthProvider: LocalStore not ready, deferring hydration',
          category: LogCategory.general);
      // Retry after a short delay (LocalStore may still be initializing)
      await Future.delayed(const Duration(milliseconds: 500));
      if (!store.isReady) return;
    }

    try {
      // 1) Load the latest reading
      if (_healthData == null || !_healthData!.hasData) {
        final latest = await store.getLatestReading();
        if (latest != null && latest.hasData) {
          _healthData = latest;
          AppLogger.i('WatchHealthProvider: hydrated from LocalStore',
              category: LogCategory.general,
              data: {
                'signals': latest.signalCount,
                'hrv': latest.hrv,
                'steps': latest.steps,
                'age': latest.freshness,
              });
          notifyListeners();
        }
      }

      // 2) Load history for trend charts (last 7 days of all readings)
      final from = DateTime.now().subtract(const Duration(days: 7));
      final readings = await store.getReadings(from: from);

      if (readings.isNotEmpty) {
        _history = readings;
        AppLogger.i('WatchHealthProvider: loaded ${readings.length} readings from LocalStore',
            category: LogCategory.general);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.w('WatchHealthProvider: failed to hydrate from LocalStore',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Append a reading to the in-memory history list (avoids re-querying DB).
  void _appendToHistory(WatchHealthData data) {
    // Don't add duplicates (within 30s of last entry)
    if (_history.isNotEmpty) {
      final lastTs = _history.last.timestamp;
      final newTs = data.timestamp;
      if (lastTs != null && newTs != null) {
        if (newTs.difference(lastTs).inSeconds.abs() < 30) return;
      }
    }
    _history.add(data);

    // Trim to 7 days max in memory
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    _history.removeWhere(
        (d) => d.timestamp != null && d.timestamp!.isBefore(cutoff));
  }

  /// Insert batch heart rate readings as individual DB rows.
  /// Each reading from the watch gets its own row for granular charting.
  void _insertBatchHeartRateReadings(Map<String, dynamic> data) {
    final readings = data['heartRateReadings'];
    if (readings == null || readings is! List || readings.isEmpty) return;

    final store = LocalStore.instance;
    if (!store.isReady) return;

    int count = 0;
    for (final r in readings) {
      if (r is! Map) continue;
      final value = (r['v'] as num?)?.toDouble();
      final ts = (r['t'] as num?)?.toDouble();
      if (value == null || ts == null) continue;

      final hrReading = WatchHealthData(
        heartRate: value,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (ts * 1000).toInt()),
      );
      store.insertReading(hrReading);
      count++;
    }

    if (count > 0) {
      AppLogger.i('WatchHealthProvider: inserted $count batch HR readings',
          category: LogCategory.general);
    }
  }

  /// Insert batch readings for any signal type.
  /// The watch now sends batch arrays for HRV, SpO2, respRate, restingHR.
  void _insertBatchSignalReadings(Map<String, dynamic> data) {
    final store = LocalStore.instance;
    if (!store.isReady) return;

    // Map of payload key → WatchHealthData constructor
    final batchKeys = <String, WatchHealthData Function(double value, DateTime time)>{
      'hrvReadings': (v, t) => WatchHealthData(hrv: v, timestamp: t),
      'spO2Readings': (v, t) => WatchHealthData(spO2: v, timestamp: t),
      'respRateReadings': (v, t) => WatchHealthData(respRate: v, timestamp: t),
      'restingHRReadings': (v, t) => WatchHealthData(restingHR: v, timestamp: t),
    };

    for (final entry in batchKeys.entries) {
      final readings = data[entry.key];
      if (readings == null || readings is! List || readings.isEmpty) continue;

      int count = 0;
      for (final r in readings) {
        if (r is! Map) continue;
        final value = (r['v'] as num?)?.toDouble();
        final ts = (r['t'] as num?)?.toDouble();
        if (value == null || ts == null) continue;

        final reading = entry.value(
          value,
          DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt()),
        );
        store.insertReading(reading);
        count++;
      }

      if (count > 0) {
        AppLogger.i('WatchHealthProvider: inserted $count batch ${entry.key} readings',
            category: LogCategory.general);
      }
    }
  }

  // ── Helpers for trend extraction ────────────────────────────────────────

  /// Extract a specific metric's values from history (for sparkline charts).
  /// Returns oldest-first, null values omitted.
  ///
  /// With LocalStore, this returns many more data points than the old
  /// one-per-day approach — potentially dozens per day.
  List<double> metricTrend(String metric) {
    return _history
        .map((d) => _extractMetric(d, metric))
        .whereType<double>()
        .toList();
  }

  /// Extract a metric from a single health data snapshot.
  static double? _extractMetric(WatchHealthData d, String metric) {
    switch (metric) {
      case 'heartRate': return d.heartRate;
      case 'hrv': return d.hrv;
      case 'restingHR': return d.restingHR;
      case 'spO2': return d.normalizedSpO2;
      case 'respRate': return d.respRate;
      case 'steps': return d.steps?.toDouble();
      case 'activeEnergy': return d.activeEnergy;
      case 'mindfulMins': return d.mindfulMins;
      case 'vo2Max': return d.vo2Max;
      case 'hrRecovery': return d.hrRecovery;
      case 'walkingSteadiness': return d.walkingSteadiness;
      case 'sleepHours': return d.sleepHours;
      case 'deepSleepMins': return d.deepSleepMins;
      case 'remSleepMins': return d.remSleepMins;
      case 'wristTemp': return d.wristTemp;
      default: return null;
    }
  }

  /// Get timestamped metric series from LocalStore for detailed charts.
  /// Returns (time, value) pairs — preserves the actual measurement times.
  ///
  /// Use this instead of [metricTrend] when you need real timestamps
  /// for granular chart display (minute/hour resolution).
  Future<List<({DateTime time, double value})>> metricTimeSeries(
    String metric, {
    int days = 7,
  }) async {
    final store = LocalStore.instance;
    if (!store.isReady) return [];
    return store.getMetricTrend(metric, days: days);
  }

  /// Get in-memory timestamped data for sparklines (no DB query).
  /// Faster than [metricTimeSeries] but limited to loaded history.
  List<({DateTime time, double value})> metricTimeSeriesFromMemory(
    String metric,
  ) {
    final result = <({DateTime time, double value})>[];
    for (final d in _history) {
      final ts = d.timestamp;
      final val = _extractMetric(d, metric);
      if (ts != null && val != null) {
        result.add((time: ts, value: val));
      }
    }
    return result;
  }

  /// Reload history from LocalStore. Call after a sync or when returning
  /// from background to pick up any readings received while suspended.
  Future<void> refreshHistory() async {
    final store = LocalStore.instance;
    if (!store.isReady) return;

    final from = DateTime.now().subtract(const Duration(days: 7));
    final readings = await store.getReadings(from: from);
    if (readings.isNotEmpty) {
      _history = readings;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
