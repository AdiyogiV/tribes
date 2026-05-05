/// Nadi (Pulse) analysis engine — Dart port of NadiEngine.swift v2.
///
/// Maps Apple Watch passive cardiovascular + autonomic signals to Ayurvedic
/// Nadi qualities with full per-signal transparency.
///
/// Classical Nadi Pariksha examines pulse at the radial artery for:
///   Sarpa Gati (Vata)   — irregular, thin, fast
///   Manduka Gati (Pitta) — jumping, bounding, moderate
///   Hamsa Gati (Kapha)   — slow, steady, broad
library;

import 'dart:math';

// ─── Data Structures ──────────────────────────────────────────────────────────

/// Vector of three dosha proportions (sum ≈ 1.0).
class DoshaVector {
  final double vata;
  final double pitta;
  final double kapha;

  const DoshaVector({
    required this.vata,
    required this.pitta,
    required this.kapha,
  });
}

/// Per-signal contribution to the Nadi reading.
class NadiContributor {
  final String signal;
  final String label;
  final String rawDisplay;
  final String baselineDisplay;
  final DoshaVector doshaVector;
  final double weight;

  const NadiContributor({
    required this.signal,
    required this.label,
    required this.rawDisplay,
    required this.baselineDisplay,
    required this.doshaVector,
    required this.weight,
  });

  double get weightedVata => doshaVector.vata * weight;
  double get weightedPitta => doshaVector.pitta * weight;
  double get weightedKapha => doshaVector.kapha * weight;
}

/// Full Nadi analysis result.
class NadiReading {
  final double vata;
  final double pitta;
  final double kapha;
  final String dominant;
  final String gati;
  final double hrv;
  final double? restingHR;
  final double baselineHRV;
  final double confidence;
  final List<NadiContributor> contributors;
  final DateTime timestamp;

  const NadiReading({
    required this.vata,
    required this.pitta,
    required this.kapha,
    required this.dominant,
    required this.gati,
    required this.hrv,
    this.restingHR,
    required this.baselineHRV,
    required this.confidence,
    required this.contributors,
    required this.timestamp,
  });
}

/// Personal cardiovascular baseline.
class NadiBaseline {
  final double avgHRV;
  final double stdHRV;
  final double avgRHR;
  final double stdRHR;
  final double avgResp;
  final int sampleCount;

  const NadiBaseline({
    this.avgHRV = 45.0,
    this.stdHRV = 12.0,
    this.avgRHR = 68.0,
    this.stdRHR = 6.0,
    this.avgResp = 15.0,
    this.sampleCount = 0,
  });

  bool get isReliable => sampleCount >= 14;

  static const populationDefaults = NadiBaseline();
}

// ─── Engine ───────────────────────────────────────────────────────────────────

class NadiEngine {
  NadiEngine._();

  /// Analyze available signals and produce a fully-itemized NadiReading.
  /// Returns null only if HRV is missing (the irreducible primary).
  static NadiReading? analyze({
    required double? hrv,
    double? rmssd,
    double? pnn50,
    double? restingHR,
    double? walkingHR,
    double? respiratoryRate,
    double? sleepHours,
    double? deepSleepMins,
    double? remSleepMins,
    double? wristTempDeviation,
    double? walkingAsymmetry,
    double? walkingDoubleSupport,
    int? irregularRhythmCount,
    double? afibBurden,
    int? highHRCount,
    int? sleepApneaCount,
    int? fallCount,
    NadiBaseline? baseline,
  }) {
    if (hrv == null) return null;
    final base = baseline ?? NadiBaseline.populationDefaults;
    final contributors = <NadiContributor>[];

    // 1. HRV deviation (weight 0.30)
    final hrvZ = _zScore(hrv, base.avgHRV, max(base.stdHRV, 5.0));
    contributors.add(NadiContributor(
      signal: 'hrv',
      label: 'HRV',
      rawDisplay: '${hrv.round()} ms',
      baselineDisplay: 'base ${base.avgHRV.round()} · z${hrvZ >= 0 ? "+" : ""}${hrvZ.toStringAsFixed(2)}',
      doshaVector: _doshaForHRV(hrvZ),
      weight: 0.30,
    ));

    // 2. RHR deviation (weight 0.15)
    if (restingHR != null) {
      final rhrZ = _zScore(restingHR, base.avgRHR, max(base.stdRHR, 4.0));
      contributors.add(NadiContributor(
        signal: 'restingHR',
        label: 'RHR',
        rawDisplay: '${restingHR.round()} bpm',
        baselineDisplay: 'base ${base.avgRHR.round()} · z${rhrZ >= 0 ? "+" : ""}${rhrZ.toStringAsFixed(2)}',
        doshaVector: _doshaForRHR(rhrZ),
        weight: 0.15,
      ));
    }

    // 3. Walking-HR / RHR ratio (weight 0.10)
    if (walkingHR != null && restingHR != null && restingHR > 0) {
      final ratio = walkingHR / restingHR;
      contributors.add(NadiContributor(
        signal: 'walkingHRRatio',
        label: 'Walk/Rest',
        rawDisplay: '${ratio.toStringAsFixed(2)}x',
        baselineDisplay: 'ideal 1.5–1.8',
        doshaVector: _doshaForWalkRatio(ratio),
        weight: 0.10,
      ));
    }

    // 4. Respiratory rate (weight 0.15)
    if (respiratoryRate != null) {
      contributors.add(NadiContributor(
        signal: 'respiration',
        label: 'Breath',
        rawDisplay: '${respiratoryRate.toStringAsFixed(1)} /min',
        baselineDisplay: 'base ${base.avgResp.toStringAsFixed(1)}',
        doshaVector: _doshaForResp(respiratoryRate, base.avgResp),
        weight: 0.15,
      ));
    }

    // 5. Sleep architecture (weight 0.12)
    if (sleepHours != null) {
      final archParts = <String>[
        if (deepSleepMins != null) 'deep ${deepSleepMins.round()}m',
        if (remSleepMins != null) 'rem ${remSleepMins.round()}m',
      ];
      contributors.add(NadiContributor(
        signal: 'sleep',
        label: 'Sleep',
        rawDisplay: '${sleepHours.toStringAsFixed(1)} h',
        baselineDisplay: archParts.isEmpty ? 'ideal 7–8.5 h' : archParts.join(' · '),
        doshaVector: _doshaForSleep(sleepHours, deepSleepMins),
        weight: 0.12,
      ));
    }

    // 6. Wrist temperature (weight 0.08)
    if (wristTempDeviation != null) {
      contributors.add(NadiContributor(
        signal: 'wristTemp',
        label: 'Warmth',
        rawDisplay: '${wristTempDeviation >= 0 ? "+" : ""}${wristTempDeviation.toStringAsFixed(2)}°C',
        baselineDisplay: 'vs your norm',
        doshaVector: _doshaForTemp(wristTempDeviation),
        weight: 0.08,
      ));
    }

    // 7. Gait quality (weight 0.05)
    if (walkingAsymmetry != null || walkingDoubleSupport != null) {
      final asym = walkingAsymmetry ?? 0;
      final dbl = walkingDoubleSupport ?? 0;
      contributors.add(NadiContributor(
        signal: 'gait',
        label: 'Gait',
        rawDisplay: 'asym ${(asym * 100).round()}% · dbl ${(dbl * 100).round()}%',
        baselineDisplay: 'smoother = steadier',
        doshaVector: _doshaForGait(asym, dbl),
        weight: 0.05,
      ));
    }

    // 8. Cardiac alerts (weight 0.05)
    final irreg = irregularRhythmCount ?? 0;
    final afib = afibBurden ?? 0;
    final highHR = highHRCount ?? 0;
    if (irreg > 0 || afib > 0 || highHR > 0) {
      contributors.add(NadiContributor(
        signal: 'cardiacAlerts',
        label: 'Alerts',
        rawDisplay: '$irreg irreg · $highHR high',
        baselineDisplay: afib > 0 ? 'afib ${(afib * 100).toStringAsFixed(1)}%' : 'none = steady',
        doshaVector: _doshaForAlerts(irreg, afib, highHR),
        weight: 0.05,
      ));
    }

    // 9. RMSSD / pNN50 — beat-to-beat (weight 0.15)
    if (rmssd != null) {
      final pnn = pnn50 ?? 0;
      contributors.add(NadiContributor(
        signal: 'rmssd',
        label: 'RMSSD',
        rawDisplay: '${rmssd.round()} ms',
        baselineDisplay: 'pNN50 ${(pnn * 100).round()}%',
        doshaVector: _doshaForBeatToBeat(rmssd, pnn),
        weight: 0.15,
      ));
    }

    // 10. Sleep apnea (weight 0.05)
    if (sleepApneaCount != null && sleepApneaCount > 0) {
      contributors.add(NadiContributor(
        signal: 'sleepApnea',
        label: 'Apnea',
        rawDisplay: '$sleepApneaCount events',
        baselineDisplay: 'during sleep',
        doshaVector: _doshaForApnea(sleepApneaCount),
        weight: 0.05,
      ));
    }

    // 11. Falls (weight 0.03)
    if (fallCount != null && fallCount > 0) {
      contributors.add(NadiContributor(
        signal: 'falls',
        label: 'Falls',
        rawDisplay: '$fallCount today',
        baselineDisplay: 'stability',
        doshaVector: const DoshaVector(vata: 0.80, pitta: 0.15, kapha: 0.05),
        weight: 0.03,
      ));
    }

    // ── Aggregate weighted dosha proportions ──────────────────────────
    double v = 0, p = 0, k = 0;
    double availableWeight = 0;
    for (final c in contributors) {
      v += c.weightedVata;
      p += c.weightedPitta;
      k += c.weightedKapha;
      availableWeight += c.weight;
    }
    if (availableWeight <= 0) return null;

    final total = v + p + k;
    if (total <= 0) return null;
    final vN = v / total;
    final pN = p / total;
    final kN = k / total;

    final confidence = min(1.0, availableWeight / 1.0);

    final String dominant;
    final String gati;
    if (vN >= pN && vN >= kN) {
      dominant = 'Vata'; gati = 'Sarpa';
    } else if (pN >= vN && pN >= kN) {
      dominant = 'Pitta'; gati = 'Manduka';
    } else {
      dominant = 'Kapha'; gati = 'Hamsa';
    }

    return NadiReading(
      vata: vN,
      pitta: pN,
      kapha: kN,
      dominant: dominant,
      gati: gati,
      hrv: hrv,
      restingHR: restingHR,
      baselineHRV: base.avgHRV,
      confidence: confidence,
      contributors: contributors,
      timestamp: DateTime.now(),
    );
  }

  // ── Per-Signal Dosha Mapping ──────────────────────────────────────────

  static double _zScore(double value, double mean, double std) {
    if (std <= 0) return 0;
    return (value - mean) / std;
  }

  static DoshaVector _doshaForHRV(double z) {
    if (z > 1.0) return const DoshaVector(vata: 0.65, pitta: 0.25, kapha: 0.10);
    if (z > 0.3) return const DoshaVector(vata: 0.45, pitta: 0.40, kapha: 0.15);
    if (z > -0.3) return const DoshaVector(vata: 0.25, pitta: 0.55, kapha: 0.20);
    if (z > -1.0) return const DoshaVector(vata: 0.20, pitta: 0.40, kapha: 0.40);
    return const DoshaVector(vata: 0.15, pitta: 0.20, kapha: 0.65);
  }

  static DoshaVector _doshaForRHR(double z) {
    if (z > 1.0) return const DoshaVector(vata: 0.50, pitta: 0.40, kapha: 0.10);
    if (z > 0.3) return const DoshaVector(vata: 0.40, pitta: 0.45, kapha: 0.15);
    if (z > -0.3) return const DoshaVector(vata: 0.30, pitta: 0.45, kapha: 0.25);
    if (z > -1.0) return const DoshaVector(vata: 0.20, pitta: 0.30, kapha: 0.50);
    return const DoshaVector(vata: 0.10, pitta: 0.20, kapha: 0.70);
  }

  static DoshaVector _doshaForWalkRatio(double r) {
    if (r >= 2.0) return const DoshaVector(vata: 0.55, pitta: 0.35, kapha: 0.10);
    if (r >= 1.5) return const DoshaVector(vata: 0.30, pitta: 0.55, kapha: 0.15);
    if (r >= 1.3) return const DoshaVector(vata: 0.20, pitta: 0.40, kapha: 0.40);
    return const DoshaVector(vata: 0.15, pitta: 0.20, kapha: 0.65);
  }

  static DoshaVector _doshaForResp(double rate, double baseline) {
    final dev = rate - baseline;
    if (dev > 3) return const DoshaVector(vata: 0.65, pitta: 0.25, kapha: 0.10);
    if (dev > 1) return const DoshaVector(vata: 0.40, pitta: 0.45, kapha: 0.15);
    if (dev > -1) return const DoshaVector(vata: 0.25, pitta: 0.55, kapha: 0.20);
    if (dev > -3) return const DoshaVector(vata: 0.15, pitta: 0.40, kapha: 0.45);
    return const DoshaVector(vata: 0.10, pitta: 0.20, kapha: 0.70);
  }

  static DoshaVector _doshaForSleep(double hours, double? deepMins) {
    if (hours < 6.0) {
      final lowDeep = (deepMins ?? 60) < 30;
      return DoshaVector(vata: lowDeep ? 0.65 : 0.55, pitta: 0.30, kapha: lowDeep ? 0.05 : 0.15);
    }
    if (hours < 7.0) return const DoshaVector(vata: 0.40, pitta: 0.45, kapha: 0.15);
    if (hours < 8.5) return const DoshaVector(vata: 0.25, pitta: 0.50, kapha: 0.25);
    if (hours < 9.5) return const DoshaVector(vata: 0.15, pitta: 0.40, kapha: 0.45);
    return const DoshaVector(vata: 0.10, pitta: 0.20, kapha: 0.70);
  }

  static DoshaVector _doshaForTemp(double t) {
    if (t > 0.5) return const DoshaVector(vata: 0.20, pitta: 0.65, kapha: 0.15);
    if (t > 0.1) return const DoshaVector(vata: 0.25, pitta: 0.50, kapha: 0.25);
    if (t > -0.1) return const DoshaVector(vata: 0.20, pitta: 0.40, kapha: 0.40);
    if (t > -0.5) return const DoshaVector(vata: 0.50, pitta: 0.30, kapha: 0.20);
    return const DoshaVector(vata: 0.65, pitta: 0.20, kapha: 0.15);
  }

  static DoshaVector _doshaForGait(double asymmetry, double doubleSupport) {
    final irregularity = asymmetry + max(0.0, doubleSupport - 0.30);
    if (irregularity > 0.20) return const DoshaVector(vata: 0.65, pitta: 0.25, kapha: 0.10);
    if (irregularity > 0.10) return const DoshaVector(vata: 0.40, pitta: 0.45, kapha: 0.15);
    if (irregularity > 0.04) return const DoshaVector(vata: 0.25, pitta: 0.50, kapha: 0.25);
    return const DoshaVector(vata: 0.15, pitta: 0.40, kapha: 0.45);
  }

  static DoshaVector _doshaForBeatToBeat(double rmssd, double pnn50) {
    if (rmssd >= 60 && pnn50 >= 0.05) return const DoshaVector(vata: 0.20, pitta: 0.30, kapha: 0.50);
    if (rmssd >= 40 && pnn50 >= 0.03) return const DoshaVector(vata: 0.20, pitta: 0.55, kapha: 0.25);
    if (rmssd >= 25) return const DoshaVector(vata: 0.40, pitta: 0.45, kapha: 0.15);
    if (rmssd >= 15) return const DoshaVector(vata: 0.60, pitta: 0.30, kapha: 0.10);
    return const DoshaVector(vata: 0.75, pitta: 0.20, kapha: 0.05);
  }

  static DoshaVector _doshaForApnea(int count) {
    if (count >= 5) return const DoshaVector(vata: 0.75, pitta: 0.20, kapha: 0.05);
    if (count >= 2) return const DoshaVector(vata: 0.60, pitta: 0.30, kapha: 0.10);
    return const DoshaVector(vata: 0.45, pitta: 0.40, kapha: 0.15);
  }

  static DoshaVector _doshaForAlerts(int irregular, double afibBurden, int highHR) {
    final load = irregular.toDouble() + highHR.toDouble() + afibBurden * 50;
    if (load >= 5) return const DoshaVector(vata: 0.75, pitta: 0.20, kapha: 0.05);
    if (load >= 2) return const DoshaVector(vata: 0.60, pitta: 0.30, kapha: 0.10);
    if (load > 0) return const DoshaVector(vata: 0.45, pitta: 0.40, kapha: 0.15);
    return const DoshaVector(vata: 0.20, pitta: 0.40, kapha: 0.40);
  }
}
