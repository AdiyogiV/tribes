import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  StreamSubscription<DocumentSnapshot>? _userDocSub;
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

    // Listen for backend engine results on the user document
    _listenForBackendEngine();

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
    } else if (type == 'nadiReading') {
      // nadiReading payloads carry the actual dosha percentages (vata/pitta/kapha)
      // computed by the watch NadiEngine — much richer than the crude heuristic.
      final nadiData = WatchHealthData.fromMap(data);
      if (_healthData != null) {
        // Merge dosha values into existing health data
        _healthData = _healthData!.copyWithNadi(
          nadiVata: nadiData.nadiVata,
          nadiPitta: nadiData.nadiPitta,
          nadiKapha: nadiData.nadiKapha,
          nadiDosha: nadiData.nadiDosha,
          nadiGati: nadiData.nadiGati,
          nadiConfidence: nadiData.nadiConfidence,
          nadiSignalCount: nadiData.nadiSignalCount,
        );
      } else {
        _healthData = nadiData;
      }
      AppLogger.i('WatchHealthProvider: merged nadiReading',
          category: LogCategory.general,
          data: {
            'dominant': nadiData.nadiDosha,
            'vata': nadiData.nadiVata,
            'pitta': nadiData.nadiPitta,
            'kapha': nadiData.nadiKapha,
            'confidence': nadiData.nadiConfidence,
          });
      notifyListeners();
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

  // ── Backend Engine Listener ─────────────────────────────────────────────

  /// Listen for backend-computed Ojas and Nadi from the user document.
  /// The Cloud Function writes `ayurvedaData.latestOjas` and
  /// `ayurvedaData.latestNadi` after processing each healthSnapshot.
  void _listenForBackendEngine() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _userDocSub?.cancel();
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;

      final ayurveda = data['ayurvedaData'] as Map<String, dynamic>?;
      if (ayurveda == null) return;

      final latestOjas = ayurveda['latestOjas'] as Map<String, dynamic>?;
      final latestNadi = ayurveda['latestNadi'] as Map<String, dynamic>?;

      if (latestOjas == null && latestNadi == null) return;

      // Merge backend results into the current healthData
      if (_healthData != null) {
        _healthData = _healthData!.copyWithBackendEngine(
          engineOjasScore: _toDouble(latestOjas?['score']),
          engineOjasSummary: latestOjas?['summary'] as String?,
          engineAgniType: latestOjas?['agniType'] as String?,
          engineOjasSignalCount: _toInt(latestOjas?['signalCount']),
          engineOjasReliable: latestOjas?['isReliable'] as bool?,
          engineNadiVata: _toDouble(latestNadi?['vata']),
          engineNadiPitta: _toDouble(latestNadi?['pitta']),
          engineNadiKapha: _toDouble(latestNadi?['kapha']),
          engineNadiDominant: latestNadi?['dominant'] as String?,
          engineNadiGati: latestNadi?['gati'] as String?,
          engineNadiConfidence: _toDouble(latestNadi?['confidence']),
          engineNadiSignalCount: _toInt(latestNadi?['signalCount']),
        );

        AppLogger.i('WatchHealthProvider: merged backend engine results',
            category: LogCategory.general,
            data: {
              'ojasScore': latestOjas?['score'],
              'nadiDominant': latestNadi?['dominant'],
              'nadiConfidence': latestNadi?['confidence'],
            });
        notifyListeners();
      }
    }, onError: (e) {
      AppLogger.w('WatchHealthProvider: backend engine listener error',
          category: LogCategory.general, data: {'error': e.toString()});
    });
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return null;
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
      case 'rmssd': return d.rmssd;
      case 'pnn50': return d.pnn50 != null ? d.pnn50! * 100 : null;
      case 'steps': return d.steps?.toDouble();
      case 'activeEnergy': return d.activeEnergy;
      case 'basalEnergy': return d.basalEnergy;
      case 'mindfulMins': return d.mindfulMins;
      case 'exerciseMins': return d.exerciseMins;
      case 'standHours': return d.standHours?.toDouble();
      case 'distance': return d.distance;
      case 'daylightMins': return d.daylightMins;
      case 'vo2Max': return d.vo2Max;
      case 'hrRecovery': return d.hrRecovery;
      case 'walkingSteadiness': return d.walkingSteadiness;
      case 'walkingHR': return d.walkingHR;
      case 'walkSpeed': return d.walkSpeed;
      case 'sleepHours': return d.sleepHours;
      case 'deepSleepMins': return d.deepSleepMins;
      case 'remSleepMins': return d.remSleepMins;
      case 'wristTemp': return d.wristTemp;
      case 'workoutMins': return d.workoutMins;
      default: return null;
    }
  }

  /// Get timestamped dosha balance series from LocalStore.
  /// Returns rolling dosha computations using all available batch readings.
  Future<List<({DateTime time, Map<String, double> doshas})>>
      doshaTimeSeries({int days = 7}) async {
    final store = LocalStore.instance;
    if (!store.isReady) return [];
    return store.computeDoshaTimeSeries(days: days);
  }

  /// Get timestamped metric series from LocalStore for detailed charts.
  /// Returns (time, value) pairs — preserves the actual measurement times.
  ///
  /// Use this instead of [metricTrend] when you need real timestamps
  /// for granular chart display (minute/hour resolution).
  ///
  /// Special case: 'ojasScore' computes a rolling Ojas time series from
  /// all available batch readings for maximum granularity.
  Future<List<({DateTime time, double value})>> metricTimeSeries(
    String metric, {
    int days = 7,
  }) async {
    final store = LocalStore.instance;
    if (!store.isReady) return [];

    // For Ojas, use the rolling computation for richer data
    if (metric == 'ojasScore') {
      return store.computeOjasTimeSeries(days: days);
    }

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
    _userDocSub?.cancel();
    super.dispose();
  }
}
