/// Data model for health readings received from Apple Watch.
///
/// Maps directly to the `healthPayload()` dictionary sent by
/// `LocalCache.swift` on the watch via `transferUserInfo`,
/// plus the `nadiReading` payload with dosha percentages.
class WatchHealthData {
  // ── Ayurveda (computed on watch) ──
  final double? ojasScore;
  final String? ojasSummary;
  final String? agniType;
  final String? nadiDosha;            // dominant dosha string

  // ── Nadi detail (from nadiReading payload) ──
  final double? nadiVata;             // 0–1 proportion
  final double? nadiPitta;
  final double? nadiKapha;
  final String? nadiGati;             // "sarpa" / "manduka" / "hamsa"
  final double? nadiConfidence;       // 0–1
  final int? nadiSignalCount;

  // ── Core vitals ──
  final double? heartRate;
  final double? hrv;
  final double? restingHR;
  final double? spO2;
  final double? respRate;

  // ── Beat-to-beat HRV (richer than aggregated SDNN) ──
  final double? rmssd;                // ms
  final double? pnn50;                // 0–1
  final int? rrSampleCount;

  // ── Activity ──
  final int? steps;
  final double? activeEnergy;         // kcal
  final double? basalEnergy;          // kcal
  final double? mindfulMins;
  final double? exerciseMins;
  final int? standHours;
  final double? distance;             // meters
  final int? flights;                 // flights climbed
  final double? daylightMins;

  // ── Fitness ──
  final double? vo2Max;
  final double? hrRecovery;
  final double? walkingSteadiness;    // 0–100%
  final double? walkingHR;            // bpm
  final double? walkSpeed;            // m/s
  final double? stepLength;           // m
  final double? doubleSupport;        // 0–1
  final double? walkingAsymmetry;     // 0–1
  final double? stairAscent;          // flights/min
  final double? stairDescent;
  final double? sixMinuteWalk;        // meters
  final int? workoutCount;
  final double? workoutMins;

  // ── Running (advanced) ──
  final double? runSpeed;
  final double? runPower;
  final double? runStride;
  final double? runGroundContact;
  final double? runVerticalOsc;

  // ── Sleep ──
  final double? sleepHours;
  final double? deepSleepMins;
  final double? remSleepMins;
  final double? coreSleepMins;
  final double? sleepOnset;           // hour (e.g., 22.5 = 10:30 PM)

  // ── Body ──
  final double? wristTemp;            // °C deviation
  final double? bodyTemp;             // °C absolute
  final double? bodyMass;             // kg
  final double? bmi;
  final double? bodyFat;              // 0–1
  final double? leanMass;             // kg
  final double? height;               // m

  // ── Audio exposure ──
  final double? envAudioExposure;     // dB
  final double? headphoneAudioExposure;
  final int? envAudioEvents;          // count
  final int? headphoneAudioEvents;

  // ── Cardiac alerts ──
  final double? afibBurden;           // 0–1
  final int? highHRCount;
  final int? lowHRCount;
  final int? irregularRhythmCount;
  final int? ecgCount;

  // ── Safety / environmental ──
  final int? fallCount;
  final int? lowCardioFitnessCount;
  final int? sleepApneaCount;
  final double? uvExposure;           // MED

  // ── Workout detail (most recent) ──
  final String? workoutType;
  final double? workoutDuration;      // seconds
  final double? workoutKcal;
  final double? workoutAvgHR;
  final double? workoutMaxHR;

  // ── Backend engine results (computed by Cloud Functions) ──
  final double? engineOjasScore;
  final String? engineOjasSummary;
  final String? engineAgniType;
  final int? engineOjasSignalCount;
  final bool? engineOjasReliable;
  final double? engineNadiVata;
  final double? engineNadiPitta;
  final double? engineNadiKapha;
  final String? engineNadiDominant;
  final String? engineNadiGati;
  final double? engineNadiConfidence;
  final int? engineNadiSignalCount;

  // ── History / meta ──
  final List<double> ojasHistory;
  final List<Map<String, dynamic>> ojasHistoryTimestamped;
  final DateTime? timestamp;

  const WatchHealthData({
    this.ojasScore,
    this.ojasSummary,
    this.agniType,
    this.nadiDosha,
    this.nadiVata,
    this.nadiPitta,
    this.nadiKapha,
    this.nadiGati,
    this.nadiConfidence,
    this.nadiSignalCount,
    this.heartRate,
    this.hrv,
    this.restingHR,
    this.spO2,
    this.respRate,
    this.rmssd,
    this.pnn50,
    this.rrSampleCount,
    this.steps,
    this.activeEnergy,
    this.basalEnergy,
    this.mindfulMins,
    this.exerciseMins,
    this.standHours,
    this.distance,
    this.flights,
    this.daylightMins,
    this.vo2Max,
    this.hrRecovery,
    this.walkingSteadiness,
    this.walkingHR,
    this.walkSpeed,
    this.stepLength,
    this.doubleSupport,
    this.walkingAsymmetry,
    this.stairAscent,
    this.stairDescent,
    this.sixMinuteWalk,
    this.workoutCount,
    this.workoutMins,
    this.runSpeed,
    this.runPower,
    this.runStride,
    this.runGroundContact,
    this.runVerticalOsc,
    this.sleepHours,
    this.deepSleepMins,
    this.remSleepMins,
    this.coreSleepMins,
    this.sleepOnset,
    this.wristTemp,
    this.bodyTemp,
    this.bodyMass,
    this.bmi,
    this.bodyFat,
    this.leanMass,
    this.height,
    this.envAudioExposure,
    this.headphoneAudioExposure,
    this.envAudioEvents,
    this.headphoneAudioEvents,
    this.afibBurden,
    this.highHRCount,
    this.lowHRCount,
    this.irregularRhythmCount,
    this.ecgCount,
    this.fallCount,
    this.lowCardioFitnessCount,
    this.sleepApneaCount,
    this.uvExposure,
    this.workoutType,
    this.workoutDuration,
    this.workoutKcal,
    this.workoutAvgHR,
    this.workoutMaxHR,
    this.engineOjasScore,
    this.engineOjasSummary,
    this.engineAgniType,
    this.engineOjasSignalCount,
    this.engineOjasReliable,
    this.engineNadiVata,
    this.engineNadiPitta,
    this.engineNadiKapha,
    this.engineNadiDominant,
    this.engineNadiGati,
    this.engineNadiConfidence,
    this.engineNadiSignalCount,
    this.ojasHistory = const [],
    this.ojasHistoryTimestamped = const [],
    this.timestamp,
  });

  /// Parse from the raw dictionary sent by the watch (healthData or nadiReading).
  factory WatchHealthData.fromMap(Map<String, dynamic> map) {
    return WatchHealthData(
      // Ayurveda
      ojasScore: _toDouble(map['ojasScore']),
      ojasSummary: map['ojasSummary'] as String?,
      agniType: map['agniType'] as String?,
      nadiDosha: map['nadiDosha'] ?? map['dominant'] as String?,

      // Nadi detail (from nadiReading)
      nadiVata: _toDouble(map['vata']),
      nadiPitta: _toDouble(map['pitta']),
      nadiKapha: _toDouble(map['kapha']),
      nadiGati: map['gati'] as String?,
      nadiConfidence: _toDouble(map['confidence']),
      nadiSignalCount: _toInt(map['signalCount']),

      // Core vitals
      heartRate: _toDouble(map['heartRate']),
      hrv: _toDouble(map['hrv']),
      restingHR: _toDouble(map['restingHR']),
      spO2: _toDouble(map['spO2']),
      respRate: _toDouble(map['respRate']),

      // Beat-to-beat HRV
      rmssd: _toDouble(map['rmssd']),
      pnn50: _toDouble(map['pnn50']),
      rrSampleCount: _toInt(map['rrSamples']),

      // Activity
      steps: _toInt(map['steps']),
      activeEnergy: _toDouble(map['activeEnergy']),
      basalEnergy: _toDouble(map['basalEnergy']),
      mindfulMins: _toDouble(map['mindfulMins']),
      exerciseMins: _toDouble(map['exerciseMins']),
      standHours: _toInt(map['standHours']),
      distance: _toDouble(map['distance']),
      flights: _toInt(map['flights']),
      daylightMins: _toDouble(map['daylightMins']),

      // Fitness
      vo2Max: _toDouble(map['vo2Max']),
      hrRecovery: _toDouble(map['hrRecovery']),
      walkingSteadiness: _toDouble(map['walkingSteadiness']),
      walkingHR: _toDouble(map['walkingHR']),
      walkSpeed: _toDouble(map['walkSpeed']),
      stepLength: _toDouble(map['stepLen']),
      doubleSupport: _toDouble(map['dblSup']),
      walkingAsymmetry: _toDouble(map['asym']),
      stairAscent: _toDouble(map['stairUp']),
      stairDescent: _toDouble(map['stairDn']),
      sixMinuteWalk: _toDouble(map['sixMinWalk']),
      workoutCount: _toInt(map['workoutCount']),
      workoutMins: _toDouble(map['workoutMins']),

      // Running
      runSpeed: _toDouble(map['runSpeed']),
      runPower: _toDouble(map['runPower']),
      runStride: _toDouble(map['runStride']),
      runGroundContact: _toDouble(map['runGC']),
      runVerticalOsc: _toDouble(map['runVO']),

      // Sleep
      sleepHours: _toDouble(map['sleepHours']),
      deepSleepMins: _toDouble(map['deepSleepMins']),
      remSleepMins: _toDouble(map['remSleepMins']),
      coreSleepMins: _toDouble(map['coreSleepMins']),
      sleepOnset: _toDouble(map['sleepOnset']),

      // Body
      wristTemp: _toDouble(map['wristTemp']),
      bodyTemp: _toDouble(map['bodyTemp']),
      bodyMass: _toDouble(map['bodyMass']),
      bmi: _toDouble(map['bmi']),
      bodyFat: _toDouble(map['bodyFat']),
      leanMass: _toDouble(map['leanMass']),
      height: _toDouble(map['height']),

      // Audio
      envAudioExposure: _toDouble(map['envAudio']),
      headphoneAudioExposure: _toDouble(map['headAudio']),
      envAudioEvents: _toInt(map['envAudioEvents']),
      headphoneAudioEvents: _toInt(map['headAudioEvents']),

      // Cardiac
      afibBurden: _toDouble(map['afibBurden']),
      highHRCount: _toInt(map['highHRCount']),
      lowHRCount: _toInt(map['lowHRCount']),
      irregularRhythmCount: _toInt(map['irregCount']),
      ecgCount: _toInt(map['ecgCount']),

      // Safety / environment
      fallCount: _toInt(map['fallCount']),
      lowCardioFitnessCount: _toInt(map['lowCardioFitCount']),
      sleepApneaCount: _toInt(map['apneaCount']),
      uvExposure: _toDouble(map['uvExposure']),

      // Workout detail
      workoutType: map['workoutType'] as String?,
      workoutDuration: _toDouble(map['workoutDuration']),
      workoutKcal: _toDouble(map['workoutKcal']),
      workoutAvgHR: _toDouble(map['workoutAvgHR']),
      workoutMaxHR: _toDouble(map['workoutMaxHR']),

      // History
      ojasHistory: _toDoubleList(map['ojasHistoryFlat'] ?? map['ojasHistory']),
      ojasHistoryTimestamped: _toTimestampedList(map['ojasHistory']),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              ((map['timestamp'] as num) * 1000).toInt())
          : null,
    );
  }

  /// Create a copy with updated nadi values (for merging nadiReading into healthData).
  WatchHealthData copyWithNadi({
    double? nadiVata,
    double? nadiPitta,
    double? nadiKapha,
    String? nadiDosha,
    String? nadiGati,
    double? nadiConfidence,
    int? nadiSignalCount,
  }) {
    return WatchHealthData(
      ojasScore: ojasScore,
      ojasSummary: ojasSummary,
      agniType: agniType,
      nadiDosha: nadiDosha ?? this.nadiDosha,
      nadiVata: nadiVata ?? this.nadiVata,
      nadiPitta: nadiPitta ?? this.nadiPitta,
      nadiKapha: nadiKapha ?? this.nadiKapha,
      nadiGati: nadiGati ?? this.nadiGati,
      nadiConfidence: nadiConfidence ?? this.nadiConfidence,
      nadiSignalCount: nadiSignalCount ?? this.nadiSignalCount,
      heartRate: heartRate,
      hrv: hrv,
      restingHR: restingHR,
      spO2: spO2,
      respRate: respRate,
      rmssd: rmssd,
      pnn50: pnn50,
      rrSampleCount: rrSampleCount,
      steps: steps,
      activeEnergy: activeEnergy,
      basalEnergy: basalEnergy,
      mindfulMins: mindfulMins,
      exerciseMins: exerciseMins,
      standHours: standHours,
      distance: distance,
      flights: flights,
      daylightMins: daylightMins,
      vo2Max: vo2Max,
      hrRecovery: hrRecovery,
      walkingSteadiness: walkingSteadiness,
      walkingHR: walkingHR,
      walkSpeed: walkSpeed,
      stepLength: stepLength,
      doubleSupport: doubleSupport,
      walkingAsymmetry: walkingAsymmetry,
      stairAscent: stairAscent,
      stairDescent: stairDescent,
      sixMinuteWalk: sixMinuteWalk,
      workoutCount: workoutCount,
      workoutMins: workoutMins,
      runSpeed: runSpeed,
      runPower: runPower,
      runStride: runStride,
      runGroundContact: runGroundContact,
      runVerticalOsc: runVerticalOsc,
      sleepHours: sleepHours,
      deepSleepMins: deepSleepMins,
      remSleepMins: remSleepMins,
      coreSleepMins: coreSleepMins,
      sleepOnset: sleepOnset,
      wristTemp: wristTemp,
      bodyTemp: bodyTemp,
      bodyMass: bodyMass,
      bmi: bmi,
      bodyFat: bodyFat,
      leanMass: leanMass,
      height: height,
      envAudioExposure: envAudioExposure,
      headphoneAudioExposure: headphoneAudioExposure,
      envAudioEvents: envAudioEvents,
      headphoneAudioEvents: headphoneAudioEvents,
      afibBurden: afibBurden,
      highHRCount: highHRCount,
      lowHRCount: lowHRCount,
      irregularRhythmCount: irregularRhythmCount,
      ecgCount: ecgCount,
      fallCount: fallCount,
      lowCardioFitnessCount: lowCardioFitnessCount,
      sleepApneaCount: sleepApneaCount,
      uvExposure: uvExposure,
      workoutType: workoutType,
      workoutDuration: workoutDuration,
      workoutKcal: workoutKcal,
      workoutAvgHR: workoutAvgHR,
      workoutMaxHR: workoutMaxHR,
      engineOjasScore: engineOjasScore,
      engineOjasSummary: engineOjasSummary,
      engineAgniType: engineAgniType,
      engineOjasSignalCount: engineOjasSignalCount,
      engineOjasReliable: engineOjasReliable,
      engineNadiVata: engineNadiVata,
      engineNadiPitta: engineNadiPitta,
      engineNadiKapha: engineNadiKapha,
      engineNadiDominant: engineNadiDominant,
      engineNadiGati: engineNadiGati,
      engineNadiConfidence: engineNadiConfidence,
      engineNadiSignalCount: engineNadiSignalCount,
      ojasHistory: ojasHistory,
      ojasHistoryTimestamped: ojasHistoryTimestamped,
      timestamp: timestamp,
    );
  }

  /// Create a copy with backend engine results merged in.
  WatchHealthData copyWithBackendEngine({
    double? engineOjasScore,
    String? engineOjasSummary,
    String? engineAgniType,
    int? engineOjasSignalCount,
    bool? engineOjasReliable,
    double? engineNadiVata,
    double? engineNadiPitta,
    double? engineNadiKapha,
    String? engineNadiDominant,
    String? engineNadiGati,
    double? engineNadiConfidence,
    int? engineNadiSignalCount,
  }) {
    return WatchHealthData(
      ojasScore: ojasScore,
      ojasSummary: ojasSummary,
      agniType: agniType,
      nadiDosha: nadiDosha,
      nadiVata: nadiVata,
      nadiPitta: nadiPitta,
      nadiKapha: nadiKapha,
      nadiGati: nadiGati,
      nadiConfidence: nadiConfidence,
      nadiSignalCount: nadiSignalCount,
      heartRate: heartRate,
      hrv: hrv,
      restingHR: restingHR,
      spO2: spO2,
      respRate: respRate,
      rmssd: rmssd,
      pnn50: pnn50,
      rrSampleCount: rrSampleCount,
      steps: steps,
      activeEnergy: activeEnergy,
      basalEnergy: basalEnergy,
      mindfulMins: mindfulMins,
      exerciseMins: exerciseMins,
      standHours: standHours,
      distance: distance,
      flights: flights,
      daylightMins: daylightMins,
      vo2Max: vo2Max,
      hrRecovery: hrRecovery,
      walkingSteadiness: walkingSteadiness,
      walkingHR: walkingHR,
      walkSpeed: walkSpeed,
      stepLength: stepLength,
      doubleSupport: doubleSupport,
      walkingAsymmetry: walkingAsymmetry,
      stairAscent: stairAscent,
      stairDescent: stairDescent,
      sixMinuteWalk: sixMinuteWalk,
      workoutCount: workoutCount,
      workoutMins: workoutMins,
      runSpeed: runSpeed,
      runPower: runPower,
      runStride: runStride,
      runGroundContact: runGroundContact,
      runVerticalOsc: runVerticalOsc,
      sleepHours: sleepHours,
      deepSleepMins: deepSleepMins,
      remSleepMins: remSleepMins,
      coreSleepMins: coreSleepMins,
      sleepOnset: sleepOnset,
      wristTemp: wristTemp,
      bodyTemp: bodyTemp,
      bodyMass: bodyMass,
      bmi: bmi,
      bodyFat: bodyFat,
      leanMass: leanMass,
      height: height,
      envAudioExposure: envAudioExposure,
      headphoneAudioExposure: headphoneAudioExposure,
      envAudioEvents: envAudioEvents,
      headphoneAudioEvents: headphoneAudioEvents,
      afibBurden: afibBurden,
      highHRCount: highHRCount,
      lowHRCount: lowHRCount,
      irregularRhythmCount: irregularRhythmCount,
      ecgCount: ecgCount,
      fallCount: fallCount,
      lowCardioFitnessCount: lowCardioFitnessCount,
      sleepApneaCount: sleepApneaCount,
      uvExposure: uvExposure,
      workoutType: workoutType,
      workoutDuration: workoutDuration,
      workoutKcal: workoutKcal,
      workoutAvgHR: workoutAvgHR,
      workoutMaxHR: workoutMaxHR,
      engineOjasScore: engineOjasScore ?? this.engineOjasScore,
      engineOjasSummary: engineOjasSummary ?? this.engineOjasSummary,
      engineAgniType: engineAgniType ?? this.engineAgniType,
      engineOjasSignalCount: engineOjasSignalCount ?? this.engineOjasSignalCount,
      engineOjasReliable: engineOjasReliable ?? this.engineOjasReliable,
      engineNadiVata: engineNadiVata ?? this.engineNadiVata,
      engineNadiPitta: engineNadiPitta ?? this.engineNadiPitta,
      engineNadiKapha: engineNadiKapha ?? this.engineNadiKapha,
      engineNadiDominant: engineNadiDominant ?? this.engineNadiDominant,
      engineNadiGati: engineNadiGati ?? this.engineNadiGati,
      engineNadiConfidence: engineNadiConfidence ?? this.engineNadiConfidence,
      engineNadiSignalCount: engineNadiSignalCount ?? this.engineNadiSignalCount,
      ojasHistory: ojasHistory,
      ojasHistoryTimestamped: ojasHistoryTimestamped,
      timestamp: timestamp,
    );
  }

  /// True when backend engine has computed Nadi dosha breakdown.
  bool get hasBackendNadi =>
      engineNadiVata != null &&
      engineNadiPitta != null &&
      engineNadiKapha != null;

  /// True when backend engine has computed Ojas score.
  bool get hasBackendOjas => engineOjasScore != null;

  /// Best available Ojas score: backend > watch.
  double? get bestOjasScore => engineOjasScore ?? ojasScore;

  /// Best available Ojas summary: backend > watch.
  String? get bestOjasSummary => engineOjasSummary ?? ojasSummary;

  /// Best available Agni type: backend > watch.
  String? get bestAgniType => engineAgniType ?? agniType;

  /// True when at least one health signal is available.
  bool get hasData =>
      ojasScore != null ||
      heartRate != null ||
      hrv != null ||
      restingHR != null ||
      sleepHours != null ||
      spO2 != null ||
      steps != null;

  /// Number of active signals being tracked.
  int get signalCount {
    int count = 0;
    if (heartRate != null) count++;
    if (hrv != null) count++;
    if (restingHR != null) count++;
    if (spO2 != null) count++;
    if (respRate != null) count++;
    if (rmssd != null) count++;
    if (pnn50 != null) count++;
    if (steps != null) count++;
    if (activeEnergy != null) count++;
    if (basalEnergy != null) count++;
    if (mindfulMins != null) count++;
    if (exerciseMins != null) count++;
    if (standHours != null) count++;
    if (distance != null) count++;
    if (daylightMins != null) count++;
    if (vo2Max != null) count++;
    if (hrRecovery != null) count++;
    if (walkingSteadiness != null) count++;
    if (walkingHR != null) count++;
    if (walkSpeed != null) count++;
    if (sleepHours != null) count++;
    if (deepSleepMins != null) count++;
    if (remSleepMins != null) count++;
    if (wristTemp != null) count++;
    if (bodyTemp != null) count++;
    if (afibBurden != null) count++;
    if (ecgCount != null && ecgCount! > 0) count++;
    if (workoutCount != null && workoutCount! > 0) count++;
    return count;
  }

  /// Normalized SpO2 (always 0-100 range).
  double? get normalizedSpO2 {
    if (spO2 == null) return null;
    return spO2! > 1 ? spO2 : spO2! * 100;
  }

  /// True if the watch sent actual dosha percentages (not just the label).
  bool get hasNadiBreakdown =>
      nadiVata != null && nadiPitta != null && nadiKapha != null;

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

  /// Parse timestamped Ojas history: [{"s": score, "t": epochSec}, ...]
  static List<Map<String, dynamic>> _toTimestampedList(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v
          .whereType<Map>()
          .where((m) => m.containsKey('s') && m.containsKey('t'))
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }
}
