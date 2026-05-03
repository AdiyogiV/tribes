/// Ojas (Vitality) Engine — Dart port of the watch-side OjasEngine.
///
/// Computes Ayurvedic vitality scores from stored health readings.
/// Used to produce granular Ojas timelines from batch data in SQLite.
///
/// Formula mirrors `ios/AuroWatch Watch App/Core/Health/OjasEngine.swift`.
library;

import 'dart:math';

// ─── Data Structures ──────────────────────────────────────────────────────────

class OjasResult {
  final int score;
  final String summary;
  final DateTime computedAt;
  final int signalCount;

  const OjasResult({
    required this.score,
    required this.summary,
    required this.computedAt,
    required this.signalCount,
  });
}

/// A single timestamped Ojas score for charting.
class OjasDataPoint {
  final double score;
  final DateTime timestamp;

  const OjasDataPoint({required this.score, required this.timestamp});
}

// ─── Engine ───────────────────────────────────────────────────────────────────

class OjasEngine {
  OjasEngine._();

  /// Compute Ojas from available signals at a point in time.
  /// Returns null if insufficient data (need at least HRV or sleep).
  static OjasResult? compute({
    double? hrv,
    double? restingHR,
    double? sleepHours,
    double? deepSleepMins,
    double? remSleepMins,
    double? spO2,
    double? wristTemp,
    double? respRate,
    double? vo2Max,
    int? steps,
    double? hrRecovery,
    double? activeEnergy,
    double? mindfulMins,
    DateTime? timestamp,
  }) {
    if (hrv == null && sleepHours == null) return null;

    double totalWeight = 0;
    double weightedSum = 0;
    int signalCount = 0;

    void addSignal(double score, double weight) {
      weightedSum += score * weight;
      totalWeight += weight;
      signalCount++;
    }

    // 1. Sleep (25%)
    if (sleepHours != null) {
      addSignal(_sleepScore(sleepHours, deepSleepMins, remSleepMins), 0.25);
    }

    // 2. HRV / Pulse (20%) — against population baseline
    if (hrv != null) {
      addSignal(_hrvScore(hrv, 45.0, 12.0), 0.20);
    }

    // 3. SpO2 / Oxygen (10%)
    if (spO2 != null) {
      addSignal(_spO2Score(spO2), 0.10);
    }

    // 4. Temperature / Warmth (8%)
    if (wristTemp != null) {
      addSignal(_temperatureScore(wristTemp), 0.08);
    }

    // 5. Respiratory rate / Breath (8%)
    if (respRate != null) {
      addSignal(_respiratoryScore(respRate, 15.0), 0.08);
    }

    // 6. VO2 Max / Fitness (7%)
    if (vo2Max != null) {
      addSignal(_vo2Score(vo2Max, 35.0), 0.07);
    }

    // 7. Steps / Movement (7%)
    if (steps != null) {
      addSignal(_movementScore(steps), 0.07);
    }

    // 8. HR Recovery (5%)
    if (hrRecovery != null) {
      addSignal(_recoveryScore(hrRecovery), 0.05);
    }

    // 9. Active Energy (5%)
    if (activeEnergy != null) {
      addSignal(_activeEnergyScore(activeEnergy), 0.05);
    }

    // 10. Mindfulness (5%)
    if (mindfulMins != null && mindfulMins > 0) {
      addSignal(_mindfulScore(mindfulMins), 0.05);
    }

    if (totalWeight <= 0) return null;

    // Normalize: redistribute weights proportionally
    final score = ((weightedSum / totalWeight) * 100).round().clamp(0, 100);
    final ts = timestamp ?? DateTime.now();

    return OjasResult(
      score: score,
      summary: _summary(score),
      computedAt: ts,
      signalCount: signalCount,
    );
  }

  // ─── Individual Signal Scoring (0.0–1.0) ──────────────────────────────────

  static double _sleepScore(double hours, double? deepMins, double? remMins) {
    // Duration component
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

    // Deep sleep bonus
    double deep = 0;
    if (deepMins != null) {
      if (deepMins >= 45 && deepMins <= 90) {
        deep = 0.10;
      } else if (deepMins >= 30) {
        deep = 0.05;
      }
    }

    // REM bonus
    double rem = 0;
    if (remMins != null) {
      if (remMins >= 60 && remMins <= 120) {
        rem = 0.05;
      } else if (remMins >= 30) {
        rem = 0.02;
      }
    }

    return min(1.0, dur + deep + rem);
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

  static double _spO2Score(double spo2) {
    final pct = spo2 > 1 ? spo2 : spo2 * 100;
    if (pct >= 97) return 0.95;
    if (pct >= 95) return 0.85;
    if (pct >= 93) return 0.65;
    if (pct >= 90) return 0.40;
    return 0.20;
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

  static double _vo2Score(double vo2, double baseline) {
    if (baseline > 0) {
      final change = (vo2 - baseline) / baseline;
      if (change >= 0) return min(1.0, 0.80 + change * 2.0);
      if (change > -0.05) return 0.75;
      return max(0.40, 0.75 + change * 3.0);
    }
    if (vo2 >= 40) return 0.90;
    if (vo2 >= 30) return 0.75;
    if (vo2 >= 20) return 0.55;
    return 0.40;
  }

  static double _movementScore(int steps) {
    if (steps >= 5000 && steps <= 12000) return 0.90;
    if (steps >= 3000) return 0.70;
    if (steps >= 1000) return 0.50;
    return 0.30;
  }

  static double _recoveryScore(double drop) {
    if (drop >= 30) return 0.95;
    if (drop >= 20) return 0.80;
    if (drop >= 12) return 0.65;
    return 0.40;
  }

  static double _activeEnergyScore(double kcal) {
    if (kcal >= 200 && kcal <= 800) return 0.90;
    if (kcal >= 100) return 0.70;
    if (kcal >= 50) return 0.50;
    return 0.30;
  }

  static double _mindfulScore(double minutes) {
    if (minutes >= 20) return 0.95;
    if (minutes >= 10) return 0.85;
    if (minutes >= 5) return 0.70;
    return 0.55;
  }

  static String _summary(int score) {
    if (score >= 85) return 'Vital';
    if (score >= 70) return 'Steady';
    if (score >= 55) return 'Moderate';
    if (score >= 40) return 'Depleted';
    return 'Rest';
  }
}
