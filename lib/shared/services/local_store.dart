import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/models/watch_health_data.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/ayurveda/domain/ojas_engine.dart';

/// Local-first data store using sqflite.
///
/// Three tables:
///   1. `health_readings` — every health reading from the watch (time-series)
///   2. `cache` — generic JSON cache for profiles, recommendations, etc.
///   3. `sync_queue` — outbound queue for batched Firestore writes
///
/// Architecture:
///   Watch → Phone → LocalStore (instant) → UI reads from here
///                        ↓
///                   Firestore (background batch sync every 30 min)
///
/// Usage:
///   await LocalStore.instance.initialize();
///   await LocalStore.instance.insertReading(data);
///   final readings = await LocalStore.instance.getReadings(from: ..., to: ...);
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  Database? _db;
  Timer? _syncTimer;
  bool _syncing = false;

  /// How often to batch-sync to Firestore (seconds).
  static const int syncIntervalSeconds = 30 * 60; // 30 minutes

  /// How many days of readings to keep locally.
  static const int localRetentionDays = 14;

  /// Max readings per Firestore batch write.
  static const int _batchSize = 400; // Firestore limit is 500

  /// Whether the store is initialized and ready.
  bool get isReady => _db != null;

  // ─── Initialization ─────────────────────────────────────────────────────

  /// Open (or create) the local database. Call once at app startup.
  /// If the database is corrupted (e.g., partial creation), deletes and retries.
  Future<void> initialize() async {
    if (_db != null) return;

    final dbPath = p.join(await getDatabasesPath(), 'aurogram_health.db');

    try {
      _db = await openDatabase(
        dbPath,
        version: 2,
        onCreate: _createTables,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      AppLogger.w('LocalStore: init failed, deleting corrupt DB and retrying',
          category: LogCategory.general, data: {'error': e.toString()});

      // Delete the corrupted file and retry once
      try {
        final file = File(dbPath);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}

      _db = await openDatabase(
        dbPath,
        version: 2,
        onCreate: _createTables,
        onUpgrade: _onUpgrade,
      );
    }

    AppLogger.i('LocalStore: initialized at $dbPath',
        category: LogCategory.general);

    // Clean up old readings on startup
    unawaited(_pruneOldReadings());
  }

  Future<void> _createTables(Database db, int version) async {
    // Health readings — one row per watch payload
    await db.execute('''
      CREATE TABLE health_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        hrv REAL,
        resting_hr REAL,
        heart_rate REAL,
        steps INTEGER,
        spo2 REAL,
        resp_rate REAL,
        wrist_temp REAL,
        vo2_max REAL,
        active_energy REAL,
        sleep_hours REAL,
        deep_sleep_mins REAL,
        rem_sleep_mins REAL,
        mindful_mins REAL,
        hr_recovery REAL,
        ojas_score REAL,
        ojas_summary TEXT,
        agni_type TEXT,
        nadi_dosha TEXT,
        vata REAL,
        pitta REAL,
        kapha REAL,
        synced INTEGER DEFAULT 0,
        rmssd REAL,
        pnn50 REAL,
        walking_hr REAL,
        stand_hours INTEGER,
        exercise_mins REAL,
        basal_energy REAL,
        distance REAL,
        daylight_mins REAL,
        walking_speed REAL,
        step_length REAL,
        double_support REAL,
        walking_asymmetry REAL,
        workout_count INTEGER,
        workout_mins REAL,
        afib_burden REAL,
        high_hr_count INTEGER,
        irreg_rhythm_count INTEGER,
        ecg_count INTEGER,
        env_audio REAL,
        fall_count INTEGER,
        low_cardio_fit_count INTEGER,
        uv_exposure REAL,
        nadi_confidence REAL,
        nadi_gati TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_readings_time ON health_readings(timestamp)');
    await db.execute(
        'CREATE INDEX idx_readings_unsynced ON health_readings(synced) WHERE synced = 0');

    // Generic JSON cache
    await db.execute('''
      CREATE TABLE cache (
        key TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        expires_at INTEGER
      )
    ''');

    // Outbound sync queue
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        collection_path TEXT NOT NULL,
        doc_id TEXT,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        status TEXT DEFAULT 'pending'
      )
    ''');

    AppLogger.i('LocalStore: tables created (v$version)',
        category: LogCategory.general);
  }

  /// Migrate from v1 → v2: add columns for expanded signal set.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final newColumns = [
        'rmssd REAL',
        'pnn50 REAL',
        'walking_hr REAL',
        'stand_hours INTEGER',
        'exercise_mins REAL',
        'basal_energy REAL',
        'distance REAL',
        'daylight_mins REAL',
        'walking_speed REAL',
        'step_length REAL',
        'double_support REAL',
        'walking_asymmetry REAL',
        'workout_count INTEGER',
        'workout_mins REAL',
        'afib_burden REAL',
        'high_hr_count INTEGER',
        'irreg_rhythm_count INTEGER',
        'ecg_count INTEGER',
        'env_audio REAL',
        'fall_count INTEGER',
        'low_cardio_fit_count INTEGER',
        'uv_exposure REAL',
        'nadi_confidence REAL',
        'nadi_gati TEXT',
      ];
      for (final col in newColumns) {
        await db.execute('ALTER TABLE health_readings ADD COLUMN $col');
      }
      AppLogger.i('LocalStore: migrated v$oldVersion → v$newVersion '
          '(${newColumns.length} columns added)',
          category: LogCategory.general);
    }
  }

  // ─── Health Readings ────────────────────────────────────────────────────

  /// Insert a health reading from the watch.
  /// Smart dedup: skips if all key metric values are identical to the latest row.
  /// Timestamp-only rows (e.g., batch HR) always insert if they have unique timestamps.
  Future<void> insertReading(WatchHealthData data) async {
    final db = _db;
    if (db == null) return;

    final ts = data.timestamp?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;

    // Exact timestamp dedup: skip if we already have this exact reading (±5s)
    final existing = await db.rawQuery(
      'SELECT id FROM health_readings WHERE ABS(timestamp - ?) < 5000 LIMIT 1',
      [ts],
    );
    if (existing.isNotEmpty) return;

    // Value-change dedup: for full health payloads (multiple signals),
    // skip if all key metrics are identical to the most recent row.
    // This prevents 19 identical rows from repeated 3-min syncs.
    if (data.signalCount > 2) {
      final latest = await db.rawQuery(
        'SELECT heart_rate, hrv, resting_hr, spo2, resp_rate, steps, active_energy '
        'FROM health_readings ORDER BY timestamp DESC LIMIT 1',
      );
      if (latest.isNotEmpty) {
        final row = latest.first;
        final same = _valuesMatch(row['heart_rate'], data.heartRate) &&
            _valuesMatch(row['hrv'], data.hrv) &&
            _valuesMatch(row['resting_hr'], data.restingHR) &&
            _valuesMatch(row['spo2'], data.spO2) &&
            _valuesMatch(row['resp_rate'], data.respRate) &&
            _intValuesMatch(row['steps'], data.steps) &&
            _valuesMatch(row['active_energy'], data.activeEnergy);
        if (same) {
          AppLogger.d('LocalStore: skipped duplicate reading (values unchanged)',
              category: LogCategory.general);
          return;
        }
      }
    }

    await db.insert('health_readings', {
      'timestamp': ts,
      'hrv': data.hrv,
      'resting_hr': data.restingHR,
      'heart_rate': data.heartRate,
      'steps': data.steps,
      'spo2': data.spO2,
      'resp_rate': data.respRate,
      'wrist_temp': data.wristTemp,
      'vo2_max': data.vo2Max,
      'active_energy': data.activeEnergy,
      'sleep_hours': data.sleepHours,
      'deep_sleep_mins': data.deepSleepMins,
      'rem_sleep_mins': data.remSleepMins,
      'mindful_mins': data.mindfulMins,
      'hr_recovery': data.hrRecovery,
      'ojas_score': data.ojasScore,
      'ojas_summary': data.ojasSummary,
      'agni_type': data.agniType,
      'nadi_dosha': data.nadiDosha,
      'vata': data.nadiVata,
      'pitta': data.nadiPitta,
      'kapha': data.nadiKapha,
      'rmssd': data.rmssd,
      'pnn50': data.pnn50,
      'walking_hr': data.walkingHR,
      'stand_hours': data.standHours,
      'exercise_mins': data.exerciseMins,
      'basal_energy': data.basalEnergy,
      'distance': data.distance,
      'daylight_mins': data.daylightMins,
      'walking_speed': data.walkSpeed,
      'step_length': data.stepLength,
      'double_support': data.doubleSupport,
      'walking_asymmetry': data.walkingAsymmetry,
      'workout_count': data.workoutCount,
      'workout_mins': data.workoutMins,
      'afib_burden': data.afibBurden,
      'high_hr_count': data.highHRCount,
      'irreg_rhythm_count': data.irregularRhythmCount,
      'ecg_count': data.ecgCount,
      'env_audio': data.envAudioExposure,
      'fall_count': data.fallCount,
      'low_cardio_fit_count': data.lowCardioFitnessCount,
      'uv_exposure': data.uvExposure,
      'nadi_confidence': data.nadiConfidence,
      'nadi_gati': data.nadiGati,
      'synced': 0,
    });

    AppLogger.d('LocalStore: inserted reading',
        category: LogCategory.general,
        data: {'ts': ts, 'signals': data.signalCount});
  }

  /// Compare two numeric values with tolerance for floating-point noise.
  static bool _valuesMatch(dynamic dbVal, double? newVal) {
    if (dbVal == null && newVal == null) return true;
    if (dbVal == null || newVal == null) return false;
    final a = (dbVal as num).toDouble();
    return (a - newVal).abs() < 0.01;
  }

  static bool _intValuesMatch(dynamic dbVal, int? newVal) {
    if (dbVal == null && newVal == null) return true;
    if (dbVal == null || newVal == null) return false;
    return (dbVal as num).toInt() == newVal;
  }

  /// Insert a health reading from a raw map (e.g., directly from watch payload).
  Future<void> insertReadingFromMap(Map<String, dynamic> map) async {
    await insertReading(WatchHealthData.fromMap(map));
  }

  /// Get readings in a time range, oldest first.
  Future<List<WatchHealthData>> getReadings({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = _db;
    if (db == null) return [];

    final where = <String>[];
    final args = <dynamic>[];

    if (from != null) {
      where.add('timestamp >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('timestamp <= ?');
      args.add(to.millisecondsSinceEpoch);
    }

    final rows = await db.query(
      'health_readings',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp ASC',
    );

    return rows.map(_rowToHealthData).toList();
  }

  /// Get the latest reading (most recent timestamp).
  Future<WatchHealthData?> getLatestReading() async {
    final db = _db;
    if (db == null) return null;

    final rows = await db.query(
      'health_readings',
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _rowToHealthData(rows.first);
  }

  /// Get readings for a specific day.
  Future<List<WatchHealthData>> getReadingsForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return getReadings(from: start, to: end);
  }

  /// Get one representative reading per day for the last N days.
  /// Uses the last reading of each day. For trend charts.
  Future<List<WatchHealthData>> getDailySnapshots({int days = 7}) async {
    final db = _db;
    if (db == null) return [];

    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    // Get the last reading per calendar day
    final rows = await db.rawQuery('''
      SELECT * FROM health_readings
      WHERE timestamp >= ?
      AND id IN (
        SELECT id FROM health_readings h2
        WHERE h2.timestamp >= ?
        GROUP BY CAST(timestamp / 86400000 AS INTEGER)
        HAVING id = MAX(id)
      )
      ORDER BY timestamp ASC
    ''', [cutoff, cutoff]);

    return rows.map(_rowToHealthData).toList();
  }

  /// Get a specific metric's values over time (for sparkline/trend charts).
  /// Returns (timestamp, value) pairs, oldest first. Null values omitted.
  Future<List<({DateTime time, double value})>> getMetricTrend(
    String metric, {
    int days = 7,
  }) async {
    final db = _db;
    if (db == null) return [];

    final column = _metricToColumn(metric);
    if (column == null) return [];

    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      'SELECT timestamp, $column FROM health_readings '
      'WHERE timestamp >= ? AND $column IS NOT NULL '
      'ORDER BY timestamp ASC',
      [cutoff],
    );

    return rows.map((r) {
      return (
        time: DateTime.fromMillisecondsSinceEpoch(r['timestamp'] as int),
        value: (r[column] as num).toDouble(),
      );
    }).toList();
  }

  /// Compute a rolling dosha balance time series from all batch readings.
  ///
  /// Walks through all readings sorted by time, maintains rolling state,
  /// computes dosha balance at each meaningful point. Returns timestamped
  /// {vata, pitta, kapha} maps.
  Future<List<({DateTime time, Map<String, double> doshas})>>
      computeDoshaTimeSeries({int days = 7}) async {
    final db = _db;
    if (db == null) return [];

    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      'SELECT timestamp, heart_rate, hrv, resting_hr, spo2, resp_rate, '
      'steps, sleep_hours, wrist_temp, vata, pitta, kapha '
      'FROM health_readings '
      'WHERE timestamp >= ? '
      'ORDER BY timestamp ASC',
      [cutoff],
    );

    if (rows.isEmpty) return [];

    // Rolling latest-known values
    double? hrv, restingHR, spO2, respRate, sleepHours, wristTemp;
    int? steps;

    final result = <({DateTime time, Map<String, double> doshas})>[];
    DateTime? lastEmitted;

    for (final row in rows) {
      if (row['hrv'] != null) hrv = (row['hrv'] as num).toDouble();
      if (row['resting_hr'] != null) restingHR = (row['resting_hr'] as num).toDouble();
      if (row['spo2'] != null) spO2 = (row['spo2'] as num).toDouble();
      if (row['resp_rate'] != null) respRate = (row['resp_rate'] as num).toDouble();
      if (row['sleep_hours'] != null) sleepHours = (row['sleep_hours'] as num).toDouble();
      if (row['wrist_temp'] != null) wristTemp = (row['wrist_temp'] as num).toDouble();
      if (row['steps'] != null) steps = (row['steps'] as num).toInt();

      final ts = DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int);

      // Throttle: at most one point per 5 minutes
      if (lastEmitted != null && ts.difference(lastEmitted).inSeconds < 300) continue;

      // If row has stored dosha values, use them directly
      if (row['vata'] != null && row['pitta'] != null && row['kapha'] != null) {
        result.add((
          time: ts,
          doshas: {
            'vata': (row['vata'] as num).toDouble(),
            'pitta': (row['pitta'] as num).toDouble(),
            'kapha': (row['kapha'] as num).toDouble(),
          },
        ));
        lastEmitted = ts;
        continue;
      }

      // Need at least one biometric signal to compute dosha
      if (hrv == null && restingHR == null && sleepHours == null) continue;

      // Compute dosha from rolling state
      double v = 33, p = 33, k = 34;
      final hv = hrv, rhr = restingHR, wt = wristTemp;
      final sh = sleepHours, rr = respRate, so = spO2, st = steps;
      if (hv != null) {
        if (hv > 60) { v += 8; p -= 3; k -= 5; }
        else if (hv < 25) { k += 6; v -= 3; p -= 3; }
      }
      if (rhr != null) {
        if (rhr > 75) { p += 5; v += 3; k -= 5; }
        else if (rhr < 55) { k += 5; p -= 3; }
      }
      if (wt != null) {
        if (wt > 0.3) { p += 6; v -= 2; }
        else if (wt < -0.3) { v += 5; k += 2; p -= 4; }
      }
      if (sh != null) {
        if (sh < 6) { v += 6; p += 3; k -= 5; }
        else if (sh > 9) { k += 8; v -= 4; p -= 2; }
      }
      if (rr != null) {
        if (rr > 18) { v += 4; k -= 2; }
        else if (rr < 12) { k += 3; }
      }
      if (so != null && so < 94) { k += 4; v += 2; }
      if (st != null) {
        if (st < 2000) { k += 5; v -= 2; }
        else if (st > 15000) { v += 4; k -= 3; }
      }

      final total = v + p + k;
      if (total > 0) {
        v = (v / total) * 100;
        p = (p / total) * 100;
        k = (k / total) * 100;
      }

      result.add((time: ts, doshas: {'vata': v, 'pitta': p, 'kapha': k}));
      lastEmitted = ts;
    }

    return result;
  }

  /// Compute a rolling Ojas time series from all available batch readings.
  ///
  /// Algorithm: walks through all readings sorted by time, maintaining a
  /// "latest known" value for each signal. At each reading that brings new
  /// data, recomputes Ojas using the OjasEngine.
  ///
  /// This gives us minute-level Ojas granularity — far richer than the
  /// watch's periodic snapshot approach.
  Future<List<({DateTime time, double value})>> computeOjasTimeSeries({
    int days = 7,
  }) async {
    final db = _db;
    if (db == null) return [];

    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      'SELECT timestamp, heart_rate, hrv, resting_hr, spo2, resp_rate, '
      'steps, active_energy, sleep_hours, deep_sleep_mins, rem_sleep_mins, '
      'vo2_max, hr_recovery, wrist_temp, mindful_mins, ojas_score '
      'FROM health_readings '
      'WHERE timestamp >= ? '
      'ORDER BY timestamp ASC',
      [cutoff],
    );

    if (rows.isEmpty) return [];

    // Rolling latest-known values
    double? hrv, spO2, respRate, sleepHours, deepSleepMins, remSleepMins;
    double? vo2Max, hrRecovery, activeEnergy, wristTemp, mindfulMins;
    int? steps;

    final result = <({DateTime time, double value})>[];
    DateTime? lastEmitted;

    for (final row in rows) {
      // Update latest-known values (only if non-null in this row)
      if (row['hrv'] != null) hrv = (row['hrv'] as num).toDouble();
      if (row['spo2'] != null) spO2 = (row['spo2'] as num).toDouble();
      if (row['resp_rate'] != null) respRate = (row['resp_rate'] as num).toDouble();
      if (row['sleep_hours'] != null) sleepHours = (row['sleep_hours'] as num).toDouble();
      if (row['deep_sleep_mins'] != null) deepSleepMins = (row['deep_sleep_mins'] as num).toDouble();
      if (row['rem_sleep_mins'] != null) remSleepMins = (row['rem_sleep_mins'] as num).toDouble();
      if (row['vo2_max'] != null) vo2Max = (row['vo2_max'] as num).toDouble();
      if (row['hr_recovery'] != null) hrRecovery = (row['hr_recovery'] as num).toDouble();
      if (row['active_energy'] != null) activeEnergy = (row['active_energy'] as num).toDouble();
      if (row['wrist_temp'] != null) wristTemp = (row['wrist_temp'] as num).toDouble();
      if (row['mindful_mins'] != null) mindfulMins = (row['mindful_mins'] as num).toDouble();
      if (row['steps'] != null) steps = (row['steps'] as num).toInt();

      final ts = DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int);

      // Throttle: emit at most one point per 2 minutes to avoid chart clutter
      if (lastEmitted != null && ts.difference(lastEmitted).inSeconds < 120) continue;

      // If this row already has an ojas_score from the watch, prefer it
      if (row['ojas_score'] != null) {
        result.add((time: ts, value: (row['ojas_score'] as num).toDouble()));
        lastEmitted = ts;
        continue;
      }

      // Need at least HRV or sleep to compute
      if (hrv == null && sleepHours == null) continue;

      // Compute Ojas from rolling state
      final ojasResult = OjasEngine.compute(
        hrv: hrv,
        spO2: spO2,
        respRate: respRate,
        sleepHours: sleepHours,
        deepSleepMins: deepSleepMins,
        remSleepMins: remSleepMins,
        vo2Max: vo2Max,
        hrRecovery: hrRecovery,
        activeEnergy: activeEnergy,
        wristTemp: wristTemp,
        mindfulMins: mindfulMins,
        steps: steps,
        timestamp: ts,
      );

      if (ojasResult != null) {
        result.add((time: ts, value: ojasResult.score.toDouble()));
        lastEmitted = ts;
      }
    }

    return result;
  }

  /// Total number of readings in the local store.
  Future<int> get readingCount async {
    final db = _db;
    if (db == null) return 0;
    final result =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM health_readings');
    return result.first['cnt'] as int? ?? 0;
  }

  // ─── Generic Cache ──────────────────────────────────────────────────────

  /// Cache a JSON object under a key, with optional TTL.
  Future<void> cacheJson(
    String key,
    Map<String, dynamic> data, {
    Duration? ttl,
  }) async {
    final db = _db;
    if (db == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'cache',
      {
        'key': key,
        'data': jsonEncode(data),
        'updated_at': now,
        'expires_at': ttl != null ? now + ttl.inMilliseconds : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve a cached JSON object. Returns null if missing or expired.
  Future<Map<String, dynamic>?> getCached(String key) async {
    final db = _db;
    if (db == null) return null;

    final rows = await db.query('cache', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;

    final row = rows.first;
    final expiresAt = row['expires_at'] as int?;
    if (expiresAt != null &&
        expiresAt < DateTime.now().millisecondsSinceEpoch) {
      // Expired — delete and return null
      await db.delete('cache', where: 'key = ?', whereArgs: [key]);
      return null;
    }

    return jsonDecode(row['data'] as String) as Map<String, dynamic>;
  }

  /// Remove a cached item.
  Future<void> removeCached(String key) async {
    final db = _db;
    if (db == null) return;
    await db.delete('cache', where: 'key = ?', whereArgs: [key]);
  }

  // ─── Sync to Firestore ──────────────────────────────────────────────────

  /// Start the periodic sync timer. Call once after initialization.
  void startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: syncIntervalSeconds),
      (_) => syncToFirestore(),
    );
    AppLogger.i('LocalStore: sync timer started (every ${syncIntervalSeconds ~/ 60} min)',
        category: LogCategory.general);
  }

  /// Stop the sync timer (call on dispose).
  void stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Batch-sync unsynced health readings to Firestore.
  /// Called periodically, on app foreground, and on app pause.
  Future<void> syncToFirestore() async {
    if (_syncing) return; // Prevent concurrent syncs
    final db = _db;
    if (db == null) return;

    _syncing = true;
    try {
      // Get unsynced readings
      final rows = await db.query(
        'health_readings',
        where: 'synced = 0',
        orderBy: 'timestamp ASC',
        limit: _batchSize,
      );

      if (rows.isEmpty) {
        _syncing = false;
        return;
      }

      AppLogger.i('LocalStore: syncing ${rows.length} readings to Firestore',
          category: LogCategory.general);

      final firestore = FirebaseFirestore.instance;
      final uid = _getCurrentUid();
      if (uid == null) {
        _syncing = false;
        return;
      }

      // Group readings by day for daily summary docs
      final byDay = <String, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        final ts = row['timestamp'] as int;
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        final dayKey =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        byDay.putIfAbsent(dayKey, () => []).add(row);
      }

      // Write daily summary docs only (no subcollections).
      // Granular per-reading data lives in local sqflite — Firestore just
      // needs the latest snapshot per day for Cloud Function triggers and
      // cross-device availability. This matches existing security rules that
      // allow writes to healthSnapshots/{dayKey} but not nested subcollections.
      final batch = firestore.batch();
      final syncedIds = <int>[];

      for (final entry in byDay.entries) {
        final dayKey = entry.key;
        final dayReadings = entry.value;

        // Collect all reading IDs for this day so we can mark them synced
        for (final row in dayReadings) {
          syncedIds.add(row['id'] as int);
        }

        // Use the most recent reading as the daily summary
        final latestRow = dayReadings.last;
        final summaryRef = firestore
            .collection('users')
            .doc(uid)
            .collection('healthSnapshots')
            .doc(dayKey);

        batch.set(
          summaryRef,
          {
            ..._rowToFirestoreMap(latestRow),
            'updatedAt': FieldValue.serverTimestamp(),
            'readingCount': dayReadings.length,
            'source': 'localStore',
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      // Mark as synced
      for (final id in syncedIds) {
        await db.update(
          'health_readings',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      AppLogger.i('LocalStore: synced ${syncedIds.length} readings to Firestore',
          category: LogCategory.general,
          data: {'days': byDay.length});

      // If there are more unsynced readings, sync again
      final remaining = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM health_readings WHERE synced = 0');
      final count = remaining.first['cnt'] as int? ?? 0;
      if (count > 0) {
        AppLogger.d('LocalStore: $count more readings pending sync',
            category: LogCategory.general);
      }
    } catch (e) {
      AppLogger.w('LocalStore: sync failed, will retry next cycle',
          category: LogCategory.general, data: {'error': e.toString()});
    } finally {
      _syncing = false;
    }
  }

  // ─── Maintenance ────────────────────────────────────────────────────────

  /// Delete readings older than the retention period.
  Future<void> _pruneOldReadings() async {
    final db = _db;
    if (db == null) return;

    final cutoff = DateTime.now()
        .subtract(const Duration(days: localRetentionDays))
        .millisecondsSinceEpoch;

    final deleted = await db.delete(
      'health_readings',
      where: 'timestamp < ? AND synced = 1',
      whereArgs: [cutoff],
    );

    if (deleted > 0) {
      AppLogger.i('LocalStore: pruned $deleted old readings',
          category: LogCategory.general);
    }
  }

  /// Delete expired cache entries.
  Future<void> pruneExpiredCache() async {
    final db = _db;
    if (db == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.delete(
      'cache',
      where: 'expires_at IS NOT NULL AND expires_at < ?',
      whereArgs: [now],
    );
  }

  /// Get diagnostic info about the local store.
  Future<Map<String, dynamic>> diagnostics() async {
    final db = _db;
    if (db == null) return {'status': 'not initialized'};

    final totalReadings = await db
        .rawQuery('SELECT COUNT(*) as cnt FROM health_readings');
    final unsyncedReadings = await db
        .rawQuery('SELECT COUNT(*) as cnt FROM health_readings WHERE synced = 0');
    final cacheEntries = await db
        .rawQuery('SELECT COUNT(*) as cnt FROM cache');
    final oldestReading = await db
        .rawQuery('SELECT MIN(timestamp) as ts FROM health_readings');
    final newestReading = await db
        .rawQuery('SELECT MAX(timestamp) as ts FROM health_readings');

    return {
      'totalReadings': totalReadings.first['cnt'],
      'unsyncedReadings': unsyncedReadings.first['cnt'],
      'cacheEntries': cacheEntries.first['cnt'],
      'oldestReading': oldestReading.first['ts'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              oldestReading.first['ts'] as int)
              .toIso8601String()
          : null,
      'newestReading': newestReading.first['ts'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              newestReading.first['ts'] as int)
              .toIso8601String()
          : null,
    };
  }

  /// Close the database (call on app shutdown if needed).
  Future<void> close() async {
    stopSyncTimer();
    await _db?.close();
    _db = null;
  }

  // ─── Private Helpers ────────────────────────────────────────────────────

  WatchHealthData _rowToHealthData(Map<String, dynamic> row) {
    final ts = row['timestamp'] as int?;
    return WatchHealthData(
      heartRate: _toDouble(row['heart_rate']),
      hrv: _toDouble(row['hrv']),
      restingHR: _toDouble(row['resting_hr']),
      spO2: _toDouble(row['spo2']),
      respRate: _toDouble(row['resp_rate']),
      rmssd: _toDouble(row['rmssd']),
      pnn50: _toDouble(row['pnn50']),
      steps: row['steps'] as int?,
      activeEnergy: _toDouble(row['active_energy']),
      basalEnergy: _toDouble(row['basal_energy']),
      mindfulMins: _toDouble(row['mindful_mins']),
      exerciseMins: _toDouble(row['exercise_mins']),
      standHours: row['stand_hours'] as int?,
      distance: _toDouble(row['distance']),
      daylightMins: _toDouble(row['daylight_mins']),
      vo2Max: _toDouble(row['vo2_max']),
      hrRecovery: _toDouble(row['hr_recovery']),
      walkingSteadiness: _toDouble(row['walking_steadiness']),
      walkingHR: _toDouble(row['walking_hr']),
      walkSpeed: _toDouble(row['walking_speed']),
      stepLength: _toDouble(row['step_length']),
      doubleSupport: _toDouble(row['double_support']),
      walkingAsymmetry: _toDouble(row['walking_asymmetry']),
      workoutCount: row['workout_count'] as int?,
      workoutMins: _toDouble(row['workout_mins']),
      sleepHours: _toDouble(row['sleep_hours']),
      deepSleepMins: _toDouble(row['deep_sleep_mins']),
      remSleepMins: _toDouble(row['rem_sleep_mins']),
      wristTemp: _toDouble(row['wrist_temp']),
      envAudioExposure: _toDouble(row['env_audio']),
      afibBurden: _toDouble(row['afib_burden']),
      highHRCount: row['high_hr_count'] as int?,
      irregularRhythmCount: row['irreg_rhythm_count'] as int?,
      ecgCount: row['ecg_count'] as int?,
      fallCount: row['fall_count'] as int?,
      lowCardioFitnessCount: row['low_cardio_fit_count'] as int?,
      uvExposure: _toDouble(row['uv_exposure']),
      ojasScore: _toDouble(row['ojas_score']),
      ojasSummary: row['ojas_summary'] as String?,
      agniType: row['agni_type'] as String?,
      nadiDosha: row['nadi_dosha'] as String?,
      nadiVata: _toDouble(row['vata']),
      nadiPitta: _toDouble(row['pitta']),
      nadiKapha: _toDouble(row['kapha']),
      nadiConfidence: _toDouble(row['nadi_confidence']),
      nadiGati: row['nadi_gati'] as String?,
      timestamp: ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null,
    );
  }

  Map<String, dynamic> _rowToFirestoreMap(Map<String, dynamic> row) {
    // Convert DB row to the same shape the backend expects.
    // All new signals are included so the backend OjasEngine/NadiEngine
    // can compute from the full signal set.
    final map = <String, dynamic>{};

    // Core vitals
    if (row['heart_rate'] != null) map['heartRate'] = row['heart_rate'];
    if (row['hrv'] != null) map['hrv'] = row['hrv'];
    if (row['resting_hr'] != null) map['restingHR'] = row['resting_hr'];
    if (row['steps'] != null) map['steps'] = row['steps'];
    if (row['spo2'] != null) map['spO2'] = row['spo2'];
    if (row['resp_rate'] != null) map['respRate'] = row['resp_rate'];
    if (row['wrist_temp'] != null) map['wristTemp'] = row['wrist_temp'];
    if (row['vo2_max'] != null) map['vo2Max'] = row['vo2_max'];
    if (row['active_energy'] != null) map['activeEnergy'] = row['active_energy'];

    // Sleep
    if (row['sleep_hours'] != null) map['sleepHours'] = row['sleep_hours'];
    if (row['deep_sleep_mins'] != null) map['deepSleepMins'] = row['deep_sleep_mins'];
    if (row['rem_sleep_mins'] != null) map['remSleepMins'] = row['rem_sleep_mins'];
    if (row['mindful_mins'] != null) map['mindfulMins'] = row['mindful_mins'];
    if (row['hr_recovery'] != null) map['hrRecovery'] = row['hr_recovery'];

    // Beat-to-beat HRV
    if (row['rmssd'] != null) map['rmssd'] = row['rmssd'];
    if (row['pnn50'] != null) map['pnn50'] = row['pnn50'];

    // Activity
    if (row['basal_energy'] != null) map['basalEnergy'] = row['basal_energy'];
    if (row['exercise_mins'] != null) map['exerciseMins'] = row['exercise_mins'];
    if (row['stand_hours'] != null) map['standHours'] = row['stand_hours'];
    if (row['distance'] != null) map['distance'] = row['distance'];
    if (row['daylight_mins'] != null) map['daylightMins'] = row['daylight_mins'];

    // Fitness / gait
    if (row['walking_hr'] != null) map['walkingHR'] = row['walking_hr'];
    if (row['walking_speed'] != null) map['walkSpeed'] = row['walking_speed'];
    if (row['step_length'] != null) map['stepLen'] = row['step_length'];
    if (row['double_support'] != null) map['dblSup'] = row['double_support'];
    if (row['walking_asymmetry'] != null) map['asym'] = row['walking_asymmetry'];
    if (row['workout_count'] != null) map['workoutCount'] = row['workout_count'];
    if (row['workout_mins'] != null) map['workoutMins'] = row['workout_mins'];

    // Cardiac alerts
    if (row['afib_burden'] != null) map['afibBurden'] = row['afib_burden'];
    if (row['high_hr_count'] != null) map['highHRCount'] = row['high_hr_count'];
    if (row['irreg_rhythm_count'] != null) map['irregCount'] = row['irreg_rhythm_count'];
    if (row['ecg_count'] != null) map['ecgCount'] = row['ecg_count'];

    // Audio / environment
    if (row['env_audio'] != null) map['envAudio'] = row['env_audio'];

    // Safety
    if (row['fall_count'] != null) map['fallCount'] = row['fall_count'];
    if (row['low_cardio_fit_count'] != null) map['lowCardioFitCount'] = row['low_cardio_fit_count'];
    if (row['uv_exposure'] != null) map['uvExposure'] = row['uv_exposure'];

    // Ayurveda (watch-computed, preserved as baseline)
    if (row['ojas_score'] != null) map['watchOjasScore'] = row['ojas_score'];
    if (row['ojas_summary'] != null) map['watchOjasSummary'] = row['ojas_summary'];
    if (row['agni_type'] != null) map['watchAgniType'] = row['agni_type'];
    if (row['nadi_dosha'] != null) map['watchNadiDosha'] = row['nadi_dosha'];
    if (row['vata'] != null) map['watchNadiVata'] = row['vata'];
    if (row['pitta'] != null) map['watchNadiPitta'] = row['pitta'];
    if (row['kapha'] != null) map['watchNadiKapha'] = row['kapha'];
    if (row['nadi_confidence'] != null) map['watchNadiConfidence'] = row['nadi_confidence'];
    if (row['nadi_gati'] != null) map['watchNadiGati'] = row['nadi_gati'];

    if (row['timestamp'] != null) {
      map['timestamp'] = (row['timestamp'] as int) / 1000; // Back to seconds
    }
    map['type'] = 'healthData';
    return map;
  }

  String? _metricToColumn(String metric) {
    const mapping = {
      'heartRate': 'heart_rate',
      'hrv': 'hrv',
      'restingHR': 'resting_hr',
      'spO2': 'spo2',
      'respRate': 'resp_rate',
      'rmssd': 'rmssd',
      'pnn50': 'pnn50',
      'steps': 'steps',
      'activeEnergy': 'active_energy',
      'basalEnergy': 'basal_energy',
      'mindfulMins': 'mindful_mins',
      'exerciseMins': 'exercise_mins',
      'standHours': 'stand_hours',
      'distance': 'distance',
      'daylightMins': 'daylight_mins',
      'vo2Max': 'vo2_max',
      'hrRecovery': 'hr_recovery',
      'walkingHR': 'walking_hr',
      'walkSpeed': 'walking_speed',
      'sleepHours': 'sleep_hours',
      'deepSleepMins': 'deep_sleep_mins',
      'remSleepMins': 'rem_sleep_mins',
      'wristTemp': 'wrist_temp',
      'workoutMins': 'workout_mins',
      'ojasScore': 'ojas_score',
    };
    return mapping[metric];
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return null;
  }

  static String? _getCurrentUid() {
    return FirebaseAuth.instance.currentUser?.uid;
  }
}
