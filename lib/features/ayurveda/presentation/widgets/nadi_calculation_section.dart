import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/models/watch_health_data.dart';
import 'package:aurogram/features/ayurveda/domain/nadi_engine.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NadiCalculationSection — Per-signal contributor breakdown + weighted agg.
// ─────────────────────────────────────────────────────────────────────────────

/// Computes a NadiReading from raw watch signals and renders:
///   - Per-signal contributor rows with V/P/K mini-bars
///   - Weighted aggregation summary with final dominant dosha
class NadiCalculationSection extends StatelessWidget {
  final WatchHealthData data;

  const NadiCalculationSection({super.key, required this.data});

  NadiReading? _computeNadi() {
    return NadiEngine.analyze(
      hrv: data.hrv,
      rmssd: data.rmssd,
      pnn50: data.pnn50,
      restingHR: data.restingHR,
      walkingHR: data.walkingHR,
      respiratoryRate: data.respRate,
      sleepHours: data.sleepHours,
      deepSleepMins: data.deepSleepMins,
      remSleepMins: data.remSleepMins,
      wristTempDeviation: data.wristTemp,
      walkingAsymmetry: data.walkingAsymmetry,
      walkingDoubleSupport: data.doubleSupport,
      irregularRhythmCount: data.irregularRhythmCount,
      afibBurden: data.afibBurden,
      highHRCount: data.highHRCount,
      sleepApneaCount: data.sleepApneaCount,
      fallCount: data.fallCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reading = _computeNadi();
    if (reading == null || reading.contributors.isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Contributors card
        DetailCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('SIGNAL CONTRIBUTORS', isDark),
              const SizedBox(height: 12),
              ...reading.contributors.map((c) => _contributorRow(c, isDark)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Calculation card
        _buildCalculationCard(isDark, reading),
      ],
    );
  }

  // ── Contributor Row ────────────────────────────────────────────────────

  Widget _contributorRow(NadiContributor c, bool isDark) {
    final weightPct = (c.weight * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Name + raw value + weight
          Row(
            children: [
              Icon(_signalIcon(c.signal), size: 14,
                  color: isDark ? Colors.white54 : Colors.black45),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.black87,
                  ),
                ),
              ),
              Text(
                c.rawDisplay,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$weightPct%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Row 2: Mini V/P/K bars
          Row(
            children: [
              const SizedBox(width: 20),
              _miniDoshaBar('V', c.doshaVector.vata, vataColor, isDark),
              const SizedBox(width: 4),
              _miniDoshaBar('P', c.doshaVector.pitta, pittaColor, isDark),
              const SizedBox(width: 4),
              _miniDoshaBar('K', c.doshaVector.kapha, kaphaColor, isDark),
            ],
          ),
          // Row 3: Baseline
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 2),
            child: Text(
              c.baselineDisplay,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniDoshaBar(
      String label, double fraction, Color color, bool isDark) {
    return Expanded(
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '${(fraction * 100).round()}',
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  // ── Calculation Card ───────────────────────────────────────────────────

  Widget _buildCalculationCard(bool isDark, NadiReading reading) {
    return DetailCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('WEIGHTED AGGREGATION', isDark),
          const SizedBox(height: 12),

          _calcDoshaRow('Vata', reading.vata, vataColor, isDark),
          const SizedBox(height: 8),
          _calcDoshaRow('Pitta', reading.pitta, pittaColor, isDark),
          const SizedBox(height: 8),
          _calcDoshaRow('Kapha', reading.kapha, kaphaColor, isDark),

          const SizedBox(height: 12),
          Container(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 10),

          // Result row
          Row(
            children: [
              Text(
                'Dominant',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const Spacer(),
              Text(
                _nadiGlyph(reading.dominant),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 6),
              Text(
                '${reading.dominant} · ${reading.gati} gati',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: getDoshaColor(reading.dominant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${(reading.confidence * 100).round()}% confidence · '
            '${reading.contributors.length} signals',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _calcDoshaRow(
      String label, double fraction, Color color, bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 45,
          child: Text(
            '${(fraction * 100).toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Widget _sectionHeader(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: isDark
            ? AppTheme.primaryColor.withValues(alpha: 0.7)
            : AppTheme.primaryColor.withValues(alpha: 0.6),
      ),
    );
  }

  static String _nadiGlyph(String dosha) {
    switch (dosha.toLowerCase()) {
      case 'vata':
        return '🐍';
      case 'pitta':
        return '🐸';
      case 'kapha':
        return '🦢';
      default:
        return '◉';
    }
  }

  IconData _signalIcon(String signal) {
    switch (signal) {
      case 'hrv':
        return CupertinoIcons.waveform_path_ecg;
      case 'restingHR':
        return CupertinoIcons.heart_fill;
      case 'walkingHRRatio':
        return CupertinoIcons.person_fill;
      case 'respiration':
        return CupertinoIcons.wind;
      case 'sleep':
        return CupertinoIcons.moon_fill;
      case 'wristTemp':
        return CupertinoIcons.thermometer;
      case 'gait':
        return CupertinoIcons.person_2_fill;
      case 'cardiacAlerts':
        return CupertinoIcons.exclamationmark_triangle_fill;
      case 'rmssd':
        return CupertinoIcons.waveform;
      case 'sleepApnea':
        return CupertinoIcons.moon_zzz_fill;
      case 'falls':
        return CupertinoIcons.arrow_down_circle_fill;
      default:
        return CupertinoIcons.circle_fill;
    }
  }
}
