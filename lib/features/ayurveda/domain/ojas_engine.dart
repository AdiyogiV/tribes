/// Ojas (Vitality) Engine — Dart port of the watch-side OjasEngine v2.
///
/// Computes Ayurvedic vitality scores from health signals with full
/// transparency: per-signal contributors, modifiers, base/final breakdown.
///
/// Formula mirrors `ios/AuroWatch Watch App/Core/Health/OjasEngine.swift`.
library;

import 'dart:math';

// ─── Data Structures ──────────────────────────────────────────────────────────

/// Full result of an Ojas computation with transparent breakdown.
class OjasResult {
  final int score;
  final int baseScore;
  final String summary;
  final String agniType;
  final String agniDescription;
  final List<OjasContributor> contributors;
  final List<OjasModifier> modifiers;
  final int ceiling;
  final int signalCount;
  final bool isReliable;
  final DateTime computedAt;

  const OjasResult({
    required this.score,
    required this.baseScore,
    required this.summary,
    required this.agniType,
    required this.agniDescription,
    required this.contributors,
    required this.modifiers,
    required this.ceiling,
    required this.signalCount,
    required this.isReliable,
    required this.computedAt,
  });

  /// Sum of modifier deltas applied to base.
  int get modifierDelta =>
      modifiers.fold(0, (sum, m) => sum + m.delta.round());
}

/// One primary contributor to the Ojas score.
class OjasContributor {
  final String name;
  final String signal;
  final double score; // 0.0–1.0
  final String status; // good / moderate / low
  final double weight; // 0.0–1.0
  final String rawDisplay; // "42 ms"
  final String baselineDisplay; // "base 45 ± 12"
  final String explanation;

  const OjasContributor({
    required this.name,
    required this.signal,
    required this.score,
    required this.status,
    required this.weight,
    required this.rawDisplay,
    required this.baselineDisplay,
    required this.explanation,
  });

  /// Weighted contribution to final score on 0–100 scale.
  double get contribution => score * weight * 100;
}

/// A modifier that adds/subtracts from the base score.
class OjasModifier {
  final String name;
  final String detail;
  final double delta;
  final String? note; // e.g. "caps total at 60"

  const OjasModifier({
    required this.name,
    required this.detail,
    required this.delta,
    this.note,
  });
}

/// A single timestamped Ojas score for charting.
class OjasDataPoint {
  final double score;
  final DateTime timestamp;

  const OjasDataPoint({required this.score, required this.timestamp});
}

/// Personal health baselines computed from historical data.
class HealthBaseline {
  final double avgHRV;
  final double stdHRV;
  final double avgRHR;
  final double stdRHR;
  final double avgResp;
  final double? avgSleepOnset;
  final int sampleDays;

  const HealthBaseline({
    this.avgHRV = 45.0,
    this.stdHRV = 12.0,
    this.avgRHR = 68.0,
    this.stdRHR = 6.0,
    this.avgResp = 15.0,
    this.avgSleepOnset = 22.5,
    this.sampleDays = 0,
  });

  static const populationDefaults = HealthBaseline();
}

// ─── Engine ───────────────────────────────────────────────────────────────────

class OjasEngine {
  OjasEngine._();

  /// Compute Ojas with full transparency — contributors + modifiers.
  /// Returns null if insufficient data (need at least HRV or sleep).
  static OjasResult? compute({
    double? hrv,
    double? restingHR,
    double? sleepHours,
    double? deepSleepMins,
    double? remSleepMins,
    double? sleepOnsetHour,
    double? spO2,
    double? wristTemp,
    double? respRate,
    double? vo2Max,
    int? steps,
    double? hrRecovery,
    double? activeEnergy,
    double? mindfulMins,
    int? standHours,
    double? daylightMins,
    double? envAudioExposure,
    double? afibBurden,
    int? highHRCount,
    int? irregularRhythmCount,
    int? sleepApneaCount,
    int? fallCount,
    int? lowCardioFitnessCount,
    double? walkingSteadiness,
    double? rmssd,
    double? uvExposure,
    double? heartRate,
    double? exerciseMins,
    double? coreSleepMins,
    double? pnn50,
    double? walkingHR,
    double? walkingAsymmetry,
    double? walkingDoubleSupport,
    double? headphoneAudioExposure,
    int? lowHRCount,
    double? bodyTemp,
    HealthBaseline? baseline,
    DateTime? timestamp,
  }) {
    if (hrv == null && sleepHours == null) return null;
    final base = baseline ?? HealthBaseline.populationDefaults;

    // ── PRIMARY CONTRIBUTORS ─────────────────────────────────────────
    final contributors = <OjasContributor>[];
    double weightedSum = 0;
    double totalWeight = 0;

    // 1. HRV — 35%
    if (hrv != null) {
      final s = _hrvScore(hrv, base.avgHRV, base.stdHRV);
      const w = 0.35;
      contributors.add(OjasContributor(
        name: 'HRV',
        signal: 'pulse',
        score: s,
        status: _signalStatus(s),
        weight: w,
        rawDisplay: '${hrv.round()} ms',
        baselineDisplay: 'base ${base.avgHRV.round()} ± ${base.stdHRV.round()}',
        explanation: 'Z-score from personal baseline. Closer to your norm = better recovery.',
      ));
      weightedSum += s * w;
      totalWeight += w;
    }

    // 2. Sleep — 22%
    if (sleepHours != null) {
      final s = _sleepScore(sleepHours, deepSleepMins, remSleepMins, coreSleepMins);
      const w = 0.22;
      final archParts = <String>[
        if (deepSleepMins != null) 'deep ${deepSleepMins.round()}m',
        if (remSleepMins != null) 'rem ${remSleepMins.round()}m',
        if (coreSleepMins != null) 'core ${coreSleepMins.round()}m',
      ];
      contributors.add(OjasContributor(
        name: 'Sleep',
        signal: 'sleep',
        score: s,
        status: _signalStatus(s),
        weight: w,
        rawDisplay: '${sleepHours.toStringAsFixed(1)} h',
        baselineDisplay: archParts.isEmpty ? 'ideal 7–8.5 h' : archParts.join(' · '),
        explanation: 'Duration peaks at 7.5 h. Deep + REM + core architecture adds bonus.',
      ));
      weightedSum += s * w;
      totalWeight += w;
    }

    // 3. Resting HR — 18%
    if (restingHR != null) {
      final s = _restingHRScore(restingHR, base.avgRHR, base.stdRHR);
      const w = 0.18;
      contributors.add(OjasContributor(
        name: 'RHR',
        signal: 'restingHR',
        score: s,
        status: _signalStatus(s),
        weight: w,
        rawDisplay: '${restingHR.round()} bpm',
        baselineDisplay: 'base ${base.avgRHR.round()} ± ${base.stdRHR.round()}',
        explanation: 'Lower than your baseline = better cardiac efficiency.',
      ));
      weightedSum += s * w;
      totalWeight += w;
    }

    // 4. Wrist Temp — 10%
    if (wristTemp != null) {
      final s = _temperatureScore(wristTemp);
      const w = 0.10;
      contributors.add(OjasContributor(
        name: 'Warmth',
        signal: 'warmth',
        score: s,
        status: _signalStatus(s),
        weight: w,
        rawDisplay: '${wristTemp >= 0 ? "+" : ""}${wristTemp.toStringAsFixed(2)}°C',
        baselineDisplay: 'vs your norm',
        explanation: 'Stable wrist temp = no illness/stress signal.',
      ));
      weightedSum += s * w;
      totalWeight += w;
    }

    // 5. Respiration — 8%
    if (respRate != null) {
      final s = _respiratoryScore(respRate, base.avgResp);
      const w = 0.08;
      contributors.add(OjasContributor(
        name: 'Breath',
        signal: 'breath',
        score: s,
        status: _signalStatus(s),
        weight: w,
        rawDisplay: '${respRate.toStringAsFixed(1)} /min',
        baselineDisplay: 'base ${base.avgResp.toStringAsFixed(1)}',
        explanation: '12–20 normal; close to baseline preferred.',
      ));
      weightedSum += s * w;
      totalWeight += w;
    }

    // 6. Activity blend — 7%
    final stepsS = steps != null ? _movementScore(steps) : null;
    final energyS = activeEnergy != null ? _activeEnergyScore(activeEnergy) : null;
    if (stepsS != null || energyS != null) {
      final blended = [stepsS, energyS].whereType<double>().toList();
      final s = blended.reduce((a, b) => a + b) / blended.length;
      const w = 0.07;
      final parts = <String>[
        if (steps != null) '$steps steps',
        if (activeEnergy != null) '${activeEnergy.round()} kcal',
      ];
      contributors.add(OjasContributor(
        name: 'Activity',
        signal: 'movement',
        score: s,
        status: _signalStatus(s),
        weight: w,
        rawDisplay: parts.join(' · '),
        baselineDisplay: '5–12k steps · 200–800 kcal',
        explanation: 'Daily movement and active energy blended.',
      ));
      weightedSum += s * w;
      totalWeight += w;
    }

    if (totalWeight <= 0) return null;

    // Base 0–100 score (renormalized over available primary weight)
    final baseScoreVal = (weightedSum / totalWeight) * 100;

    // ── MODIFIERS ────────────────────────────────────────────────────
    final modifiers = <OjasModifier>[];
    double modSum = 0;
    double ceilingVal = 100;

    // HR Recovery (±5)
    if (hrRecovery != null) {
      final double delta;
      if (hrRecovery >= 25) { delta = 5; }
      else if (hrRecovery >= 15) { delta = 2; }
      else if (hrRecovery >= 8) { delta = -1; }
      else { delta = -5; }
      modifiers.add(OjasModifier(
        name: 'HR Recovery', detail: '${hrRecovery.round()} bpm drop', delta: delta,
      ));
      modSum += delta;
    }

    // Stand hours (±4)
    if (standHours != null) {
      final double delta;
      if (standHours >= 12) { delta = 2; }
      else if (standHours >= 8) { delta = 0; }
      else if (standHours >= 5) { delta = -2; }
      else { delta = -4; }
      modifiers.add(OjasModifier(
        name: 'Stand Hours', detail: '$standHours h', delta: delta,
      ));
      modSum += delta;
    }

    // SpO₂ cap
    if (spO2 != null) {
      final pct = spO2 > 1 ? spO2 : spO2 * 100;
      if (pct < 92) {
        ceilingVal = min(ceilingVal, 60);
        modifiers.add(OjasModifier(
          name: 'SpO₂ Cap', detail: '${pct.round()}%', delta: 0, note: 'caps total at 60',
        ));
      } else if (pct < 95) {
        modifiers.add(OjasModifier(name: 'SpO₂', detail: '${pct.round()}%', delta: -2));
        modSum += -2;
      }
    }

    // Daylight (±5)
    if (daylightMins != null) {
      final double delta;
      if (daylightMins >= 120) { delta = 3; }
      else if (daylightMins >= 60) { delta = 1; }
      else if (daylightMins >= 30) { delta = 0; }
      else { delta = -5; }
      modifiers.add(OjasModifier(
        name: 'Daylight', detail: '${daylightMins.round()} min', delta: delta,
      ));
      modSum += delta;
    }

    // Audio exposure
    if (envAudioExposure != null && envAudioExposure > 85) {
      final delta = envAudioExposure > 90 ? -5.0 : -2.0;
      modifiers.add(OjasModifier(
        name: 'Audio Load', detail: '${envAudioExposure.round()} dB', delta: delta,
      ));
      modSum += delta;
    }

    // Mindfulness (+5)
    if (mindfulMins != null && mindfulMins > 0) {
      final double delta;
      if (mindfulMins >= 20) { delta = 5; }
      else if (mindfulMins >= 10) { delta = 3; }
      else { delta = 1; }
      modifiers.add(OjasModifier(
        name: 'Mindful', detail: '${mindfulMins.round()} min', delta: delta,
      ));
      modSum += delta;
    }

    // Cardiac alerts
    final irregCount = irregularRhythmCount ?? 0;
    final afib = afibBurden ?? 0;
    final highHR = highHRCount ?? 0;
    if (irregCount > 0 || afib > 0 || highHR > 0) {
      final delta = afib > 0 ? -10.0 : -5.0;
      final detail = afib > 0
          ? 'afib ${(afib * 100).toStringAsFixed(1)}%'
          : '$irregCount irreg · $highHR high';
      modifiers.add(OjasModifier(name: 'Cardiac Alerts', detail: detail, delta: delta));
      modSum += delta;
    }

    // Walking steadiness
    if (walkingSteadiness != null && walkingSteadiness < 0.4) {
      modifiers.add(OjasModifier(
        name: 'Gait Steadiness', detail: '${(walkingSteadiness * 100).round()}%', delta: -5,
      ));
      modSum += -5;
    }

    // Sleep apnea
    if (sleepApneaCount != null && sleepApneaCount > 0) {
      final delta = sleepApneaCount >= 3 ? -10.0 : -5.0;
      modifiers.add(OjasModifier(
        name: 'Sleep Apnea',
        detail: '$sleepApneaCount event${sleepApneaCount == 1 ? "" : "s"}',
        delta: delta,
      ));
      modSum += delta;
    }

    // Falls
    if (fallCount != null && fallCount > 0) {
      modifiers.add(OjasModifier(name: 'Falls', detail: '$fallCount today', delta: -10));
      modSum += -10;
    }

    // Low cardio fitness
    if (lowCardioFitnessCount != null && lowCardioFitnessCount > 0) {
      modifiers.add(OjasModifier(
        name: 'Low Cardio Fit',
        detail: '$lowCardioFitnessCount alert${lowCardioFitnessCount == 1 ? "" : "s"}',
        delta: -3,
      ));
      modSum += -3;
    }

    // Vagal tone (RMSSD)
    if (rmssd != null) {
      if (rmssd >= 50) {
        final delta = rmssd >= 80 ? 5.0 : 3.0;
        modifiers.add(OjasModifier(
          name: 'Vagal Tone', detail: 'RMSSD ${rmssd.round()} ms', delta: delta,
        ));
        modSum += delta;
      } else if (rmssd < 15) {
        modifiers.add(OjasModifier(
          name: 'Vagal Tone', detail: 'RMSSD ${rmssd.round()} ms', delta: -3,
        ));
        modSum += -3;
      }
    }

    // UV
    if (uvExposure != null && uvExposure > 6) {
      modifiers.add(OjasModifier(
        name: 'UV Load', detail: '${uvExposure.toStringAsFixed(1)} MED', delta: -2,
      ));
      modSum += -2;
    }

    // Heart Rate Stress — current HR / resting HR ratio (Nadi Pariksha proxy)
    if (heartRate != null && restingHR != null && restingHR! > 0) {
      final ratio = heartRate / restingHR!;
      if (ratio <= 1.10) {
        modifiers.add(OjasModifier(
          name: 'Pulse Calm',
          detail: '${heartRate.round()} bpm (${ratio.toStringAsFixed(1)}× RHR)',
          delta: 2,
        ));
        modSum += 2;
      } else if (ratio > 2.0) {
        modifiers.add(OjasModifier(
          name: 'Pulse Stress',
          detail: '${heartRate.round()} bpm (${ratio.toStringAsFixed(1)}× RHR)',
          delta: -5,
        ));
        modSum += -5;
      } else if (ratio > 1.5) {
        modifiers.add(OjasModifier(
          name: 'Pulse Elevated',
          detail: '${heartRate.round()} bpm (${ratio.toStringAsFixed(1)}× RHR)',
          delta: -3,
        ));
        modSum += -3;
      }
    }

    // VO₂ Max — aerobic capacity / Prana reservoir
    if (vo2Max != null) {
      final double delta;
      if (vo2Max >= 50) { delta = 5; }
      else if (vo2Max >= 42) { delta = 3; }
      else if (vo2Max >= 35) { delta = 0; }
      else if (vo2Max >= 25) { delta = -2; }
      else { delta = -5; }
      if (delta != 0) {
        modifiers.add(OjasModifier(
          name: 'Cardio Fitness',
          detail: '${vo2Max.toStringAsFixed(1)} mL/kg/min',
          delta: delta,
        ));
        modSum += delta;
      }
    }

    // Exercise minutes — Vyayama (half-capacity effort is ideal in Ayurveda)
    if (exerciseMins != null && exerciseMins > 0) {
      final double delta;
      if (exerciseMins > 150) { delta = -2; }
      else if (exerciseMins >= 20) { delta = 3; }
      else if (exerciseMins >= 10) { delta = 1; }
      else { delta = 0; }
      if (delta != 0) {
        modifiers.add(OjasModifier(
          name: 'Exercise', detail: '${exerciseMins.round()} min', delta: delta,
        ));
        modSum += delta;
      }
    }

    // PNN50 — parasympathetic strength (supplements RMSSD vagal tone)
    if (pnn50 != null) {
      if (pnn50 >= 0.25) {
        modifiers.add(OjasModifier(
          name: 'Vagal PNN50', detail: '${(pnn50 * 100).toStringAsFixed(1)}%', delta: 2,
        ));
        modSum += 2;
      } else if (pnn50 < 0.03) {
        modifiers.add(OjasModifier(
          name: 'Vagal PNN50', detail: '${(pnn50 * 100).toStringAsFixed(1)}%', delta: -2,
        ));
        modSum += -2;
      }
    }

    // Walking HR efficiency — cardiac recovery during movement
    if (walkingHR != null && restingHR != null && restingHR! > 0) {
      final ratio = walkingHR / restingHR!;
      if (ratio < 1.3) {
        modifiers.add(OjasModifier(
          name: 'Walk Efficiency',
          detail: '${walkingHR.round()} / ${restingHR!.round()} bpm',
          delta: 3,
        ));
        modSum += 3;
      } else if (ratio > 1.8) {
        modifiers.add(OjasModifier(
          name: 'Walk Efficiency',
          detail: '${walkingHR.round()} / ${restingHR!.round()} bpm',
          delta: -3,
        ));
        modSum += -3;
      }
    }

    // Gait asymmetry — structural Vata imbalance
    if (walkingAsymmetry != null && walkingAsymmetry > 0.10) {
      modifiers.add(OjasModifier(
        name: 'Gait Asymmetry',
        detail: '${(walkingAsymmetry * 100).toStringAsFixed(0)}%',
        delta: -2,
      ));
      modSum += -2;
    }

    // Gait double support — instability indicator
    if (walkingDoubleSupport != null && walkingDoubleSupport > 0.30) {
      modifiers.add(OjasModifier(
        name: 'Gait Support',
        detail: '${(walkingDoubleSupport * 100).toStringAsFixed(0)}% dbl',
        delta: -2,
      ));
      modSum += -2;
    }

    // Headphone audio — additional ear stress (separate from environmental)
    if (headphoneAudioExposure != null && headphoneAudioExposure > 85) {
      final delta = headphoneAudioExposure > 90 ? -3.0 : -1.0;
      modifiers.add(OjasModifier(
        name: 'Headphone Load',
        detail: '${headphoneAudioExposure.round()} dB',
        delta: delta,
      ));
      modSum += delta;
    }

    // Low HR events — bradycardia (Kapha excess / cardiac concern)
    if (lowHRCount != null && lowHRCount > 0) {
      modifiers.add(OjasModifier(
        name: 'Low HR Events',
        detail: '$lowHRCount alert${lowHRCount == 1 ? "" : "s"}',
        delta: -2,
      ));
      modSum += -2;
    }

    // Body temperature — fever = active illness = Ojas critically depleted
    if (bodyTemp != null) {
      if (bodyTemp > 38.0) {
        ceilingVal = min(ceilingVal, 55);
        modifiers.add(OjasModifier(
          name: 'Fever Cap', detail: '${bodyTemp.toStringAsFixed(1)}°C', delta: 0,
          note: 'caps total at 55',
        ));
      } else if (bodyTemp > 37.5) {
        modifiers.add(OjasModifier(
          name: 'Warm Temp', detail: '${bodyTemp.toStringAsFixed(1)}°C', delta: -3,
        ));
        modSum += -3;
      }
    }

    // ── FINAL SCORE ──────────────────────────────────────────────────
    final preFinal = baseScoreVal + modSum;
    final finalScore = min(ceilingVal, max(0, preFinal)).round();

    final agni = _computeAgniType(
      sleepHours: sleepHours,
      sleepOnsetHour: sleepOnsetHour,
      avgSleepOnset: base.avgSleepOnset,
      wristTemp: wristTemp,
      restingHR: restingHR,
      avgRHR: base.avgRHR,
      steps: steps,
      hrRecovery: hrRecovery,
    );

    return OjasResult(
      score: finalScore,
      baseScore: baseScoreVal.round(),
      summary: _summary(finalScore),
      agniType: agni.$1,
      agniDescription: agni.$2,
      contributors: contributors,
      modifiers: modifiers,
      ceiling: ceilingVal.round(),
      signalCount: contributors.length + modifiers.length,
      isReliable: base.sampleDays >= 14,
      computedAt: timestamp ?? DateTime.now(),
    );
  }

  // ─── Individual Signal Scoring (0.0–1.0) ──────────────────────────────

  static double _sleepScore(double hours, double? deepMins, double? remMins, double? coreMins) {
    double dur;
    if (hours < 4.0) {
      dur = 0.15;
    } else if (hours < 6.0) {
      dur = 0.3 + (hours - 4.0) / 2.0 * 0.3;
    } else if (hours <= 9.0) {
      dur = max(0.7, 1.0 - (hours - 7.5).abs() * 0.1);
    } else {
      dur = max(0.5, 1.0 - (hours - 9.0) * 0.15);
    }

    double deep = 0;
    if (deepMins != null) {
      if (deepMins >= 45 && deepMins <= 90) {
        deep = 0.10;
      } else if (deepMins >= 30) {
        deep = 0.05;
      }
    }

    double rem = 0;
    if (remMins != null) {
      if (remMins >= 60 && remMins <= 120) {
        rem = 0.05;
      } else if (remMins >= 30) {
        rem = 0.02;
      }
    }

    double core = 0;
    if (coreMins != null) {
      if (coreMins >= 180 && coreMins <= 300) {
        core = 0.03;
      } else if (coreMins >= 120) {
        core = 0.01;
      }
    }

    return min(1.0, dur + deep + rem + core);
  }

  static double _hrvScore(double hrv, double baseline, double std) {
    final effectiveStd = max(std, 5.0);
    final z = (hrv - baseline).abs() / effectiveStd;
    if (z < 0.5) return 0.95;
    if (z < 1.0) return 0.85;
    if (z < 1.5) return 0.70;
    if (z < 2.0) return 0.55;
    return max(0.25, 0.55 - (z - 2.0) * 0.15);
  }

  static double _restingHRScore(double rhr, double baseline, double std) {
    final effectiveStd = max(std, 4.0);
    final z = (rhr - baseline) / effectiveStd;
    if (z <= -0.5) return 0.95;
    if (z <= 0.3) return 0.88;
    if (z <= 1.0) return 0.70;
    if (z <= 2.0) return 0.50;
    return 0.30;
  }

  static double _temperatureScore(double deviation) {
    final d = deviation.abs();
    if (d < 0.2) return 0.95;
    if (d < 0.5) return 0.80;
    if (d < 1.0) return 0.60;
    return max(0.30, 0.60 - (d - 1.0) * 0.2);
  }

  static double _respiratoryScore(double rate, double baseline) {
    if (rate >= 12 && rate <= 20) {
      final dev = (rate - baseline).abs();
      if (dev < 1.5) return 0.95;
      if (dev < 3.0) return 0.80;
      return 0.65;
    }
    return 0.40;
  }

  static double _movementScore(int steps) {
    if (steps >= 5000 && steps <= 12000) return 0.90;
    if (steps >= 3000) return 0.70;
    if (steps >= 1000) return 0.50;
    return 0.30;
  }

  static double _activeEnergyScore(double kcal) {
    if (kcal >= 200 && kcal <= 800) return 0.90;
    if (kcal >= 100) return 0.70;
    if (kcal >= 50) return 0.50;
    return 0.30;
  }

  static String _signalStatus(double score) {
    if (score >= 0.75) return 'good';
    if (score >= 0.50) return 'moderate';
    return 'low';
  }

  static String _summary(int score) {
    if (score >= 85) return 'Vital';
    if (score >= 70) return 'Steady';
    if (score >= 55) return 'Moderate';
    if (score >= 40) return 'Depleted';
    return 'Rest';
  }

  static (String, String) _computeAgniType({
    double? sleepHours,
    double? sleepOnsetHour,
    double? avgSleepOnset,
    double? wristTemp,
    double? restingHR,
    double? avgRHR,
    int? steps,
    double? hrRecovery,
  }) {
    // Vishama (Vata): erratic sleep onset
    if (sleepOnsetHour != null) {
      final onsetVar = (sleepOnsetHour - (avgSleepOnset ?? 22.5)).abs();
      if (onsetVar > 1.0) return ('Vishama', 'Irregular rhythm');
    }
    // Tikshna (Pitta)
    final shortSleep = (sleepHours ?? 8) < 6;
    final warmTemp = (wristTemp ?? 0) > 0.4;
    final fastHR = restingHR != null && restingHR > (avgRHR ?? 68) * 1.08;
    if ((shortSleep && warmTemp) || (shortSleep && fastHR)) {
      return ('Tikshna', 'Running intense');
    }
    // Manda (Kapha)
    final longSleep = (sleepHours ?? 0) > 9.5;
    final lowSteps = (steps ?? 5000) < 3000;
    final slowRecovery = (hrRecovery ?? 25) < 12;
    if ((longSleep && lowSteps) || (lowSteps && slowRecovery)) {
      return ('Manda', 'Sluggish metabolism');
    }
    return ('Sama', 'Balanced digestion');
  }
}
