/// Data model for health readings received from Apple Watch.
///
/// Maps directly to the `healthPayload()` dictionary sent by
/// `LocalCache.swift` on the watch via `transferUserInfo`.
class WatchHealthData {
  final double? ojasScore;
  final String? ojasSummary;
  final String? agniType;
  final String? nadiDosha;
  final double? hrv;
  final double? restingHR;
  final double? sleepHours;
  final double? deepSleepMins;
  final double? remSleepMins;
  final double? wristTemp;
  final double? respRate;
  final double? vo2Max;
  final int? steps;
  final double? hrRecovery;
  final double? spO2;
  final double? activeEnergy;
  final double? mindfulMins;
  final List<double> ojasHistory;
  final DateTime? timestamp;

  const WatchHealthData({
    this.ojasScore,
    this.ojasSummary,
    this.agniType,
    this.nadiDosha,
    this.hrv,
    this.restingHR,
    this.sleepHours,
    this.deepSleepMins,
    this.remSleepMins,
    this.wristTemp,
    this.respRate,
    this.vo2Max,
    this.steps,
    this.hrRecovery,
    this.spO2,
    this.activeEnergy,
    this.mindfulMins,
    this.ojasHistory = const [],
    this.timestamp,
  });

  /// Parse from the raw dictionary sent by the watch.
  factory WatchHealthData.fromMap(Map<String, dynamic> map) {
    return WatchHealthData(
      ojasScore: _toDouble(map['ojasScore']),
      ojasSummary: map['ojasSummary'] as String?,
      agniType: map['agniType'] as String?,
      nadiDosha: map['nadiDosha'] as String?,
      hrv: _toDouble(map['hrv']),
      restingHR: _toDouble(map['restingHR']),
      sleepHours: _toDouble(map['sleepHours']),
      deepSleepMins: _toDouble(map['deepSleepMins']),
      remSleepMins: _toDouble(map['remSleepMins']),
      wristTemp: _toDouble(map['wristTemp']),
      respRate: _toDouble(map['respRate']),
      vo2Max: _toDouble(map['vo2Max']),
      steps: _toInt(map['steps']),
      hrRecovery: _toDouble(map['hrRecovery']),
      spO2: _toDouble(map['spO2']),
      activeEnergy: _toDouble(map['activeEnergy']),
      mindfulMins: _toDouble(map['mindfulMins']),
      ojasHistory: _toDoubleList(map['ojasHistory']),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              ((map['timestamp'] as num) * 1000).toInt())
          : null,
    );
  }

  /// True when at least one health signal is available.
  bool get hasData =>
      ojasScore != null ||
      hrv != null ||
      restingHR != null ||
      sleepHours != null ||
      spO2 != null ||
      steps != null;

  /// Number of active signals being tracked.
  int get signalCount {
    int count = 0;
    if (hrv != null) count++;
    if (restingHR != null) count++;
    if (sleepHours != null) count++;
    if (deepSleepMins != null) count++;
    if (remSleepMins != null) count++;
    if (wristTemp != null) count++;
    if (respRate != null) count++;
    if (vo2Max != null) count++;
    if (steps != null) count++;
    if (hrRecovery != null) count++;
    if (spO2 != null) count++;
    if (activeEnergy != null) count++;
    if (mindfulMins != null) count++;
    return count;
  }

  /// Normalized SpO2 (always 0-100 range).
  double? get normalizedSpO2 {
    if (spO2 == null) return null;
    return spO2! > 1 ? spO2 : spO2! * 100;
  }

  /// How long ago this data was received.
  String get freshness {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// True if data is less than 2 hours old.
  bool get isFresh {
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp!).inHours < 2;
  }

  // ── Helpers ──

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static List<double> _toDoubleList(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v
          .map((e) => _toDouble(e))
          .whereType<double>()
          .toList();
    }
    return [];
  }
}
